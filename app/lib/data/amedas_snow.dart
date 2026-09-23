import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../util/geo.dart';
import '../util/jst.dart';
import 'heat_alert.dart';

/// 気象庁アメダスの積雪深（冬季の災害速報タブ「積雪」）。
///
/// - 観測点の表は同梱アセット `assets/data/amedas_snow_stations.json`
///   （`tools/amedas_snow_stations.py` 生成。積雪深を観測する336地点に
///   国土地理院の逆ジオコーダで市区町村コードを付けたもの）
/// - 観測値は `bosai/amedas/data/map/<yyyyMMddHHmm00>.json`（10分ごと）。
///   積雪のある地点にだけ `snow`（積雪深cm）・`snow1h/6h/12h/24h`（降雪量cm）
///   のキーが現れる。無雪期はキー自体が無い
/// - 熱中症警戒情報の運用期間（4/22〜10/21）の外を「冬季」として扱い、
///   災害速報タブの3番目を熱中症→積雪に切り替える
/// 出典：気象庁ホームページ（アメダス）
class SnowStation {
  const SnowStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.municipality,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// JIS 市区町村コード（5桁）。政令市は区単位。海上等で引けなかったときは null
  final String? municipality;

  /// 都道府県コード（2桁）。市区町村が無ければ null
  String? get prefecture => municipality?.substring(0, 2);
}

/// 1観測点の現在値
class SnowObs {
  const SnowObs({
    required this.station,
    required this.depth,
    this.snow1h,
    this.snow6h,
    this.snow24h,
  });

  final SnowStation station;

  /// 積雪深（cm）
  final int depth;

  /// 降雪量（cm）。観測が無いときは null
  final int? snow1h;
  final int? snow6h;
  final int? snow24h;
}

/// 市区町村ごとのまとめ（観測点は積雪深の深い順）
class SnowMunicipality {
  const SnowMunicipality(
      {required this.code, required this.stations});

  final String code;
  final List<SnowObs> stations;

  int get maxDepth => stations.first.depth;
}

/// 都道府県ごとのまとめ（市区町村は最深の深い順）
class SnowPrefecture {
  const SnowPrefecture(
      {required this.prefCode, required this.municipalities});

  final String prefCode;
  final List<SnowMunicipality> municipalities;

  int get maxDepth => municipalities.first.maxDepth;

  /// 最深の観測点
  SnowObs get deepest => municipalities.first.stations.first;

  int get stationCount =>
      municipalities.fold(0, (n, m) => n + m.stations.length);
}

/// 1回分の観測（10分値）
class SnowReport {
  const SnowReport({required this.observedAt, required this.observations});

  /// 観測時刻（JST 壁時計。素の DateTime）
  final DateTime observedAt;

  /// 積雪深が 1cm 以上の観測点
  final List<SnowObs> observations;

  /// 都道府県＞市区町村＞観測点。都道府県は最深の深い順
  List<SnowPrefecture> byPrefecture() {
    final byPref = <String, Map<String, List<SnowObs>>>{};
    for (final o in observations) {
      final p = o.station.prefecture;
      final m = o.station.municipality;
      if (p == null || m == null) continue;
      byPref.putIfAbsent(p, () => {}).putIfAbsent(m, () => []).add(o);
    }
    final out = <SnowPrefecture>[];
    for (final e in byPref.entries) {
      final munis = <SnowMunicipality>[];
      for (final m in e.value.entries) {
        final st = [...m.value]..sort((a, b) => b.depth.compareTo(a.depth));
        munis.add(SnowMunicipality(code: m.key, stations: st));
      }
      munis.sort((a, b) => b.maxDepth.compareTo(a.maxDepth));
      out.add(SnowPrefecture(prefCode: e.key, municipalities: munis));
    }
    out.sort((a, b) {
      final c = b.maxDepth.compareTo(a.maxDepth);
      return c != 0 ? c : a.prefCode.compareTo(b.prefCode);
    });
    return out;
  }
}

class AmedasSnow {
  const AmedasSnow._();

  static const attribution = '出典：気象庁ホームページ（アメダス 積雪深）';
  static const _base = 'https://www.jma.go.jp/bosai/amedas';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)',
  };
  static const nearestCount = 3;

  /// 冬季（熱中症警戒情報の運用期間外＝10/22〜4/21）。
  /// 災害速報タブの3番目をこの期間だけ「積雪」にする
  static bool isSeason(DateTime jst) => !HeatAlerts.isInSeason(jst);

  static Future<List<SnowStation>>? _loading;

  /// 同梱の観測点表（1回だけ読む）
  static Future<List<SnowStation>> loadStations() =>
      _loading ??= _loadStations();

  static Future<List<SnowStation>> _loadStations() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/amedas_snow_stations.json');
      return parseStations(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// テスト用に観測点表を差し替える
  static void setStations(List<SnowStation>? stations) {
    _loading = stations == null ? null : Future.value(stations);
    _cache = null;
  }

  static List<SnowStation> parseStations(Object? json) {
    if (json is! Map) return const [];
    final list = json['stations'];
    if (list is! List) return const [];
    final out = <SnowStation>[];
    for (final e in list) {
      if (e is! Map) continue;
      final id = e['id'], n = e['n'], lat = e['lat'], lng = e['lng'];
      if (id is! String || n is! String || lat is! num || lng is! num) continue;
      final m = e['m'];
      out.add(SnowStation(
        id: id,
        name: n,
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        municipality: m is String && m.length == 5 ? m : null,
      ));
    }
    return out;
  }

  /// 10分値の JSON（観測点ID → 要素）から積雪のある地点を取り出す
  static SnowReport parseMap(
      Object? json, List<SnowStation> stations, DateTime observedAt) {
    final byId = {for (final s in stations) s.id: s};
    final out = <SnowObs>[];
    if (json is Map) {
      for (final e in json.entries) {
        final st = byId[e.key];
        final v = e.value;
        if (st == null || v is! Map) continue;
        final depth = _cm(v['snow']);
        if (depth == null || depth <= 0) continue;
        out.add(SnowObs(
          station: st,
          depth: depth,
          snow1h: _cm(v['snow1h']),
          snow6h: _cm(v['snow6h']),
          snow24h: _cm(v['snow24h']),
        ));
      }
    }
    out.sort((a, b) => b.depth.compareTo(a.depth));
    return SnowReport(observedAt: observedAt, observations: out);
  }

  /// 要素は [値, 品質フラグ]。欠測は値が null
  static int? _cm(Object? v) {
    if (v is! List || v.isEmpty) return null;
    final n = v[0];
    return n is num ? n.round() : null;
  }

  static (String, SnowReport)? _cache;

  /// 最新の10分値。同じ観測時刻のあいだは再取得しない。失敗は null
  static Future<SnowReport?> fetch({http.Client? client}) async {
    try {
      final stations = await loadStations();
      if (stations.isEmpty) return null;
      final lt = await _get('$_base/data/latest_time.txt', client);
      if (lt == null) return _cache?.$2;
      // latest_time.txt は "+09:00" 付き。DateTime.parse は UTC に直すので
      // JST の壁時計へ戻してからファイル名を組む（端末のTZに依存しない）
      final at = toJstWallClock(DateTime.parse(lt.trim()));
      final key = '${at.year}${_two(at.month)}${_two(at.day)}'
          '${_two(at.hour)}${_two(at.minute)}00';
      final c = _cache;
      if (c != null && c.$1 == key) return c.$2;
      final body = await _get('$_base/data/map/$key.json', client);
      if (body == null) return c?.$2;
      final report = parseMap(jsonDecode(body), stations, at);
      _cache = (key, report);
      return report;
    } catch (_) {
      return _cache?.$2;
    }
  }

  static Future<String?> _get(String url, http.Client? client) async {
    final u = Uri.parse(url);
    final r = client == null
        ? await http.get(u, headers: _ua).timeout(const Duration(seconds: 15))
        : await client.get(u, headers: _ua).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return utf8.decode(r.bodyBytes);
  }

  /// 現在地に近い観測点（距離m付き、近い順）。積雪の有無は問わない
  static List<(SnowStation, double)> nearest(
      List<SnowStation> stations, double lat, double lng,
      {int count = nearestCount}) {
    final list = [
      for (final s in stations) (s, distanceMeters(lat, lng, s.lat, s.lng))
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(count).toList();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
