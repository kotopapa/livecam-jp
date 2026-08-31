import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/camera.dart';
import 'shelter_layers.dart' show ShelterLayers;

/// 防災拠点レイヤー（自治体オープンデータを配信側で集約した
/// `/v1/facilities/index.json` と `/v1/facilities/<JIS2桁>.json`）。
///
/// 構造・振る舞いは避難場所レイヤー（[ShelterLayers] / ShelterStore）を踏襲する:
/// - 表示中の地図範囲に掛かる都道府県の県ファイルだけを取得する
/// - 取得したJSONはメモリに保持し、一時ディレクトリにも保存する。
///   県ファイル自身の `version` が index.version と一致すればネットワークを使わない
/// - 同時取得は3県まで。失敗は凡例に出し、次の表示更新か利用者操作で再試行する
///
/// 避難場所と違い **公開している自治体しか無い**（2026-08-31時点で22都道府県）。
/// index.counts に無い県は取得を試みず、凡例で「データがまだ無い」と伝える。
class Facility {
  const Facility({
    required this.id,
    required this.pref,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.kind,
    required this.owner,
    required this.sourceIndex,
    required this.geocoded,
  });

  final String id;

  /// 県ファイルのJIS2桁（出典参照 [FacilitySource] の解決に使う）
  final String pref;
  final String name;
  final String address;
  final double lat;
  final double lng;

  /// 種別キー（water / stock / fire_water）
  final String kind;

  /// 提供自治体（データセットの org）
  final String owner;

  /// 県ファイル `sources[]` の添字
  final int sourceIndex;

  /// 住所から座標を補完したもの（`g:1`）
  final bool geocoded;

  LatLng get pos => LatLng(lat, lng);

  static Facility? fromJson(Map<String, dynamic> j, {String pref = ''}) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final id = j['id'] as String? ?? '';
    final kind = j['k'] as String? ?? '';
    if (lat == null || lng == null || id.isEmpty || kind.isEmpty) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return Facility(
      id: id,
      pref: pref,
      name: j['n'] as String? ?? '',
      address: j['a'] as String? ?? '',
      lat: lat,
      lng: lng,
      kind: kind,
      owner: j['o'] as String? ?? '',
      sourceIndex: (j['s'] as num?)?.toInt() ?? -1,
      geocoded: j['g'] == 1 || j['g'] == true,
    );
  }
}

/// 県ファイル `sources[]` の1件（データセットの出所・ライセンス）
class FacilitySource {
  const FacilitySource({
    required this.portal,
    required this.org,
    required this.title,
    required this.url,
    required this.license,
    required this.kind,
  });

  final String portal;
  final String org;
  final String title;
  final String url;
  final String license;
  final String kind;

  /// 「鹿角市『消防水利施設一覧』（CC BY）」相当の1行
  String get label {
    final t = title.isEmpty ? '（データセット）' : title;
    final head = org.isEmpty ? t : '$org「$t」';
    return license.isEmpty ? head : '$head（$license）';
  }

  static FacilitySource fromJson(Map<String, dynamic> j) => FacilitySource(
        portal: j['portal'] as String? ?? '',
        org: j['org'] as String? ?? '',
        title: j['title'] as String? ?? '',
        url: j['url'] as String? ?? '',
        license: j['license'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
      );
}

class FacilityIndex {
  const FacilityIndex({
    required this.version,
    required this.counts,
    required this.kinds,
    required this.total,
    required this.notice,
    required this.attribution,
  });

  final String version;

  /// JIS2桁 → 件数（**このキーに無い県はデータが存在しない**）
  final Map<String, int> counts;

  /// 種別キー → 正式名称
  final Map<String, String> kinds;
  final int total;
  final String notice;
  final String attribution;

  bool hasPref(String pref) => (counts[pref] ?? 0) > 0;

  /// 種別の表示名（index に無ければ既定の名称）
  String labelOf(String kind) =>
      kinds[kind] ?? FacilityLayers.defaultKinds[kind] ?? kind;

  static FacilityIndex fromJson(Map<String, dynamic> j) => FacilityIndex(
        version: j['version'] as String? ?? '',
        counts: {
          for (final e in (j['counts'] as Map? ?? const {}).entries)
            '${e.key}': (e.value as num?)?.toInt() ?? 0
        },
        kinds: {
          for (final e in (j['kinds'] as Map? ?? const {}).entries)
            '${e.key}': '${e.value}'
        },
        total: (j['total'] as num?)?.toInt() ?? 0,
        notice: j['notice'] as String? ?? '',
        attribution: j['attribution'] as String? ?? FacilityLayers.attribution,
      );
}

/// 純粋関数群（テスト対象）
class FacilityLayers {
  static const baseUrl = '${apiBaseUrl}facilities/';

  /// 種別の並び順（チップ・凡例の順序）
  static const kindKeys = ['water', 'stock', 'fire_water'];

  /// index.kinds が取れないときの正式名称
  static const defaultKinds = {
    'water': '給水拠点・応急給水施設',
    'stock': '防災備蓄倉庫',
    'fire_water': '消防水利（消火栓・防火水槽）',
  };

  /// チップ・凡例用の短い名称
  static const shortLabels = {
    'water': '給水拠点',
    'stock': '防災備蓄倉庫',
    'fire_water': '消防水利',
  };

  /// 既定の絞り込み（消防水利は14万件と多く一般利用者向けではないためOFF）
  static const defaultSelectedKinds = {'water', 'stock'};

  static const attribution = '出典：各自治体のオープンデータ（CC BY 等）';
  static const disclaimer = '公開している自治体のみ。最新の情報は各自治体にご確認ください';

  /// この地域にデータがまだ無いときの案内
  static const noDataMessage = 'この地域のデータはまだありません';

  /// 防災拠点ピンを描画する最小ズーム（消防水利が密集するため避難場所より深い）
  static const minZoom = 13.0;

  /// 画面内がこの件数を超えたらクラスタ表示に切り替える
  static const clusterThreshold = 400;

  static String shortLabel(String kind) => shortLabels[kind] ?? kind;

  /// 県ファイルのJSONを解析する。壊れたレコードは読み飛ばす
  static List<Facility> parseFile(Map<String, dynamic> json) {
    final pref = json['pref'] as String? ?? '';
    return [
      for (final e in (json['facilities'] as List? ?? const []))
        if (e is Map<String, dynamic>) ?Facility.fromJson(e, pref: pref)
    ];
  }

  /// 県ファイルの `sources[]` を解析する
  static List<FacilitySource> parseSources(Map<String, dynamic> json) => [
        for (final e in (json['sources'] as List? ?? const []))
          if (e is Map<String, dynamic>) FacilitySource.fromJson(e)
      ];

  /// `s` の添字から出典を引く。範囲外・欠損は null
  static FacilitySource? resolveSource(
      List<FacilitySource> sources, int index) {
    if (index < 0 || index >= sources.length) return null;
    return sources[index];
  }

  /// 表示範囲に掛かる都道府県コード（JIS2桁）。
  /// 避難場所と同じ判定なので [ShelterLayers.prefsForBounds] をそのまま使う
  static Set<String> prefsForBounds(
    Iterable<Camera> cameras, {
    required double south,
    required double north,
    required double west,
    required double east,
    required LatLng center,
  }) =>
      ShelterLayers.prefsForBounds(cameras,
          south: south, north: north, west: west, east: east, center: center);

  /// index.counts に載っている県だけに絞る（index 未取得なら素通し）
  static Set<String> availablePrefs(
          Iterable<String> prefs, FacilityIndex? index) =>
      index == null
          ? prefs.toSet()
          : {
              for (final p in prefs)
                if (index.hasPref(p)) p
            };

  /// 表示範囲（余白込み）でのカリング
  static List<Facility> cull(
    Iterable<Facility> facilities, {
    required double south,
    required double north,
    required double west,
    required double east,
  }) =>
      [
        for (final f in facilities)
          if (f.lat >= south && f.lat <= north && f.lng >= west && f.lng <= east) f
      ];

  /// 種別で絞り込む（複数選択。空集合なら0件）
  static List<Facility> filterByKinds(
          Iterable<Facility> facilities, Set<String> kinds) =>
      [
        for (final f in facilities)
          if (kinds.contains(f.kind)) f
      ];

  /// 群の代表種別（クラスタの色付けに使う）。最多、同数なら [kindKeys] の順
  static String? dominantKind(Iterable<Facility> facilities) {
    final counts = <String, int>{};
    for (final f in facilities) {
      counts[f.kind] = (counts[f.kind] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    String? best;
    var bestCount = -1;
    for (final k in [
      ...kindKeys,
      ...counts.keys.where((k) => !kindKeys.contains(k))
    ]) {
      final c = counts[k];
      if (c != null && c > bestCount) {
        best = k;
        bestCount = c;
      }
    }
    return best;
  }

  /// SharedPreferences 保存用（順序を [kindKeys] に正規化してカンマ結合）
  static String encodeKinds(Set<String> kinds) =>
      [for (final k in kindKeys) if (kinds.contains(k)) k].join(',');

  /// 保存値の復元。未保存(null)は既定、空文字は「すべてOFF」として扱う
  static Set<String> decodeKinds(String? raw) {
    if (raw == null) return {...defaultSelectedKinds};
    return {
      for (final k in raw.split(','))
        if (kindKeys.contains(k.trim())) k.trim()
    };
  }

  /// Googleマップの経路URL（徒歩。避難場所と同じ方針）
  static Uri routeUri(Facility f) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${f.lat},${f.lng}&travelmode=walking');
}

/// 県ファイルの取得・キャッシュ。UIは [addListener] で変更を受け取る
class FacilityStore extends ChangeNotifier {
  FacilityStore({this.cacheDir, http.Client? client, this.maxConcurrent = 3})
      : _client = client ?? http.Client();

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// キャッシュ先ディレクトリ（path_provider の一時ディレクトリ。null ならメモリのみ）
  final Directory? cacheDir;
  final http.Client _client;
  final int maxConcurrent;

  FacilityIndex? _index;
  Future<FacilityIndex?>? _indexFuture;
  final Map<String, List<Facility>> _byPref = {};
  final Map<String, List<FacilitySource>> _sourcesByPref = {};
  final Set<String> _inflight = {};
  final List<String> _queue = [];

  /// index.counts に載っていない（＝まだデータが無い）と分かった県
  final Set<String> _unavailable = {};

  /// 取得に失敗した県 → 失敗時刻
  final Map<String, DateTime> _failedAt = {};
  static const retryAfter = Duration(seconds: 30);

  /// 未取得のまま失敗している県の集合
  Set<String> get failed =>
      _failedAt.keys.where((p) => !_byPref.containsKey(p)).toSet();

  FacilityIndex? get index => _index;
  bool get loading => _inflight.isNotEmpty || _queue.isNotEmpty;

  /// データがまだ無いと判明している県
  bool isUnavailable(String pref) => _unavailable.contains(pref);

  /// 対象の県がすべて「データ無し」か（1県でもあれば false）
  bool allUnavailable(Iterable<String> prefs) {
    var any = false;
    for (final p in prefs) {
      any = true;
      if (!_unavailable.contains(p)) return false;
    }
    return any;
  }

  /// メモリ上にある県の防災拠点（未取得の県は含まない）
  Iterable<Facility> facilitiesFor(Iterable<String> prefs) sync* {
    for (final p in prefs) {
      final list = _byPref[p];
      if (list != null) yield* list;
    }
  }

  bool hasPref(String pref) => _byPref.containsKey(pref);

  List<FacilitySource> sourcesFor(String pref) =>
      _sourcesByPref[pref] ?? const [];

  /// 拠点1件の出典（県ファイルの sources[s]）
  FacilitySource? sourceOf(Facility f) =>
      FacilityLayers.resolveSource(sourcesFor(f.pref), f.sourceIndex);

  File? _file(String name) =>
      cacheDir == null ? null : File('${cacheDir!.path}/facilities_$name.json');

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
          .get(Uri.parse('${FacilityLayers.baseUrl}$name.json'), headers: _ua)
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
  Future<FacilityIndex?> ensureIndex() {
    if (_index != null) return Future.value(_index);
    return _indexFuture ??= () async {
      final j = await _fetch('index') ?? await _readDisk('index');
      if (j != null) {
        _index = FacilityIndex.fromJson(j);
        notifyListeners();
      }
      _indexFuture = null;
      return _index;
    }();
  }

  /// 必要な県を要求する。既にメモリにある県・データが無い県は何もしない
  void request(Iterable<String> prefs, {bool force = false}) {
    final now = DateTime.now();
    var marked = false;
    for (final p in prefs) {
      if (_byPref.containsKey(p) ||
          _unavailable.contains(p) ||
          _inflight.contains(p) ||
          _queue.contains(p)) {
        continue;
      }
      // index が読めていれば、載っていない県はネットワークを使わない
      if (_index != null && !_index!.hasPref(p)) {
        _unavailable.add(p);
        marked = true;
        continue;
      }
      final t = _failedAt[p];
      if (!force && t != null && now.difference(t) < retryAfter) continue;
      _queue.add(p);
    }
    if (marked) notifyListeners();
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
      if (idx != null && !idx.hasPref(pref)) {
        // 22都道府県しか無い。対象外は取りに行かず「データ無し」として記録する
        _unavailable.add(pref);
        _failedAt.remove(pref);
        notifyListeners();
        return;
      }
      final version = idx?.version;
      // index が取れないときはディスクの県ファイルがあればそれを使う
      var j = await _readDisk(pref);
      if (j != null && version != null && j['version'] != version) j = null;
      j ??= await _fetch(pref);
      if (j == null) {
        _failedAt[pref] = DateTime.now();
        notifyListeners();
        return;
      }
      _failedAt.remove(pref);
      _byPref[pref] = FacilityLayers.parseFile(j);
      _sourcesByPref[pref] = FacilityLayers.parseSources(j);
      notifyListeners();
    } catch (_) {
      _failedAt[pref] = DateTime.now();
      notifyListeners();
    }
  }
}
