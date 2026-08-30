import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/camera.dart';

/// 避難場所レイヤー（国土地理院「指定緊急避難場所データ」を配信側で加工した
/// `/v1/shelters/index.json` と `/v1/shelters/<JIS2桁>.json`）。
///
/// - 表示中の地図範囲に掛かる都道府県の県ファイルだけを取得する
/// - 取得したJSONはメモリに保持し、一時ディレクトリにも保存する。
///   県ファイル自身の `version` が index.version と一致すればネットワークを使わない
/// - 同時取得は3県まで。失敗は静かに無視し、次の表示更新で再試行する
class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.hazards,
    required this.designated,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  /// 対応する災害種別（[ShelterIndex.hazards] のインデックス）
  final List<int> hazards;

  /// 指定避難所（滞在型）でもあるか
  final bool designated;

  LatLng get pos => LatLng(lat, lng);

  static Shelter? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final id = j['id'] as String? ?? '';
    if (lat == null || lng == null || id.isEmpty) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return Shelter(
      id: id,
      name: j['n'] as String? ?? '',
      address: j['a'] as String? ?? '',
      lat: lat,
      lng: lng,
      hazards: [
        for (final f in (j['f'] as List? ?? const []))
          if (f is num) f.toInt()
      ],
      designated: j['s'] == 1 || j['s'] == true,
    );
  }
}

class ShelterIndex {
  const ShelterIndex({
    required this.version,
    required this.hazards,
    required this.counts,
    required this.notice,
    required this.attribution,
  });

  final String version;
  final List<String> hazards;
  final Map<String, int> counts;
  final String notice;
  final String attribution;

  static ShelterIndex fromJson(Map<String, dynamic> j) => ShelterIndex(
        version: j['version'] as String? ?? '',
        hazards: [
          for (final h in (j['hazards'] as List? ?? ShelterLayers.defaultHazards)) '$h'
        ],
        counts: {
          for (final e in (j['counts'] as Map? ?? const {}).entries)
            '${e.key}': (e.value as num?)?.toInt() ?? 0
        },
        notice: j['notice'] as String? ?? '',
        attribution: j['attribution'] as String? ?? ShelterLayers.attribution,
      );
}

/// 純粋関数群（テスト対象）
class ShelterLayers {
  static const baseUrl = '${apiBaseUrl}shelters/';
  static const defaultHazards = ['洪水', '土砂', '高潮', '地震', '津波', '火事', '内水', '火山'];
  static const attribution = '出典：国土地理院「指定緊急避難場所データ」';
  static const disclaimer = '最新かつ詳細な状況は各市町村にご確認ください';

  /// 避難場所ピンを描画する最小ズーム
  static const minZoom = 11.0;

  /// 画面内がこの件数を超えたらクラスタ表示に切り替える
  static const clusterThreshold = 400;

  /// 県ファイルのJSONを解析する。壊れたレコードは読み飛ばす
  static List<Shelter> parseFile(Map<String, dynamic> json) => [
        for (final e in (json['shelters'] as List? ?? const []))
          if (e is Map<String, dynamic>) ?Shelter.fromJson(e)
      ];

  /// 表示範囲に掛かる都道府県コード（JIS2桁）。
  /// 範囲内のカメラの prefecture の集合を使い、1件も無ければ中心から最寄りの
  /// カメラの県を返す（海外カメラ=99 と不明=00 は除く）
  static Set<String> prefsForBounds(
    Iterable<Camera> cameras, {
    required double south,
    required double north,
    required double west,
    required double east,
    required LatLng center,
  }) {
    final prefs = <String>{};
    Camera? nearest;
    double nearestD = double.infinity;
    for (final c in cameras) {
      if (!c.hasLocation || c.isWorld || c.prefecture == '00') continue;
      final lat = c.lat!, lng = c.lng!;
      if (lat >= south && lat <= north && lng >= west && lng <= east) {
        prefs.add(c.prefecture);
      } else if (prefs.isEmpty) {
        final d = (lat - center.latitude) * (lat - center.latitude) +
            (lng - center.longitude) * (lng - center.longitude);
        if (d < nearestD) {
          nearestD = d;
          nearest = c;
        }
      }
    }
    if (prefs.isEmpty && nearest != null) prefs.add(nearest.prefecture);
    return prefs;
  }

  /// 表示範囲（余白込み）でのカリング
  static List<Shelter> cull(
    Iterable<Shelter> shelters, {
    required double south,
    required double north,
    required double west,
    required double east,
  }) =>
      [
        for (final s in shelters)
          if (s.lat >= south && s.lat <= north && s.lng >= west && s.lng <= east) s
      ];

  /// 災害種別で絞り込む。[hazard] が null なら全件
  static List<Shelter> filterByHazard(Iterable<Shelter> shelters, int? hazard) =>
      hazard == null
          ? shelters.toList()
          : [for (final s in shelters) if (s.hazards.contains(hazard)) s];

  /// Apple Maps / Google Maps の経路URL
  static Uri routeUri(Shelter s, {required bool android}) => android
      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}')
      : Uri.parse('https://maps.apple.com/?daddr=${s.lat},${s.lng}');
}

/// 県ファイルの取得・キャッシュ。UIは [addListener] で変更を受け取る
class ShelterStore extends ChangeNotifier {
  ShelterStore({this.cacheDir, http.Client? client, this.maxConcurrent = 3})
      : _client = client ?? http.Client();

  static const _ua = {'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'};

  /// キャッシュ先ディレクトリ（path_provider の一時ディレクトリ。null ならメモリのみ）
  final Directory? cacheDir;
  final http.Client _client;
  final int maxConcurrent;

  ShelterIndex? _index;
  Future<ShelterIndex?>? _indexFuture;
  final Map<String, List<Shelter>> _byPref = {};
  final Set<String> _inflight = {};
  final List<String> _queue = [];

  /// 取得に失敗した県 → 失敗時刻。凡例の「取得できませんでした」表示と
  /// 短時間の連続再試行の抑制に使う（[retryAfter] を過ぎれば自動で再試行）
  final Map<String, DateTime> _failedAt = {};
  static const retryAfter = Duration(seconds: 30);

  /// 未取得のまま失敗している県の集合
  Set<String> get failed => _failedAt.keys.where((p) => !_byPref.containsKey(p)).toSet();

  ShelterIndex? get index => _index;
  List<String> get hazards => _index?.hazards ?? ShelterLayers.defaultHazards;
  bool get loading => _inflight.isNotEmpty || _queue.isNotEmpty;

  /// メモリ上にある県の避難場所（未取得の県は含まない）
  Iterable<Shelter> sheltersFor(Iterable<String> prefs) sync* {
    for (final p in prefs) {
      final list = _byPref[p];
      if (list != null) yield* list;
    }
  }

  bool hasPref(String pref) => _byPref.containsKey(pref);

  File? _file(String name) =>
      cacheDir == null ? null : File('${cacheDir!.path}/shelters_$name.json');

  Future<Map<String, dynamic>?> _readDisk(String name) async {
    try {
      final f = _file(name);
      if (f == null || !await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String name, String raw) async {
    try {
      final f = _file(name);
      if (f == null) return;
      await f.parent.create(recursive: true);
      await f.writeAsString(raw);
    } catch (_) {
      // 一時ディレクトリに書けなくても致命的ではない
    }
  }

  Future<Map<String, dynamic>?> _fetch(String name) async {
    try {
      final r = await _client
          .get(Uri.parse('${ShelterLayers.baseUrl}$name.json'), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final raw = utf8.decode(r.bodyBytes);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      await _writeDisk(name, raw);
      return j;
    } catch (_) {
      return null;
    }
  }

  /// index.json。ネットワーク不通時はディスクの控えを使う。1セッション1回
  Future<ShelterIndex?> ensureIndex() {
    if (_index != null) return Future.value(_index);
    return _indexFuture ??= () async {
      final j = await _fetch('index') ?? await _readDisk('index');
      if (j != null) {
        _index = ShelterIndex.fromJson(j);
        notifyListeners();
      }
      _indexFuture = null;
      return _index;
    }();
  }

  /// 必要な県を要求する。既にメモリにあれば何もしない。
  /// 未取得分はディスク→ネットワークの順で解決し、完了ごとに通知する
  void request(Iterable<String> prefs, {bool force = false}) {
    final now = DateTime.now();
    for (final p in prefs) {
      if (_byPref.containsKey(p) || _inflight.contains(p) || _queue.contains(p)) continue;
      final t = _failedAt[p];
      if (!force && t != null && now.difference(t) < retryAfter) continue; // 直後の連打を抑制
      _queue.add(p);
    }
    _pump();
  }

  /// 失敗した県を利用者の操作で即時に再試行する
  void retry(Iterable<String> prefs) {
    for (final p in prefs) {
      _failedAt.remove(p);
    }
    request(prefs, force: true);
    notifyListeners();
  }

  void _pump() {
    while (_inflight.length < maxConcurrent && _queue.isNotEmpty) {
      final p = _queue.removeAt(0);
      _inflight.add(p);
      _load(p).whenComplete(() {
        _inflight.remove(p);
        _pump();
      });
    }
  }

  Future<void> _load(String pref) async {
    try {
      final idx = await ensureIndex();
      final version = idx?.version;
      // index が取れないときはディスクの県ファイルがあればそれを使う
      var j = await _readDisk(pref);
      if (j != null && version != null && j['version'] != version) j = null;
      j ??= await _fetch(pref);
      if (j == null) {
        // 失敗を記録して凡例に知らせる。次回の表示更新（30秒後以降）か
        // 利用者の再試行で取り直す
        _failedAt[pref] = DateTime.now();
        notifyListeners();
        return;
      }
      _failedAt.remove(pref);
      _byPref[pref] = ShelterLayers.parseFile(j);
      notifyListeners();
    } catch (_) {
      _failedAt[pref] = DateTime.now();
      notifyListeners();
    }
  }
}
