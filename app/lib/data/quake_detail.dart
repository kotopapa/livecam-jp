import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'quake_intensity.dart';

/// 気象庁 地震情報の詳報 JSON（`bosai/quake/data/<json>`。list.json の各報の
/// `json` 欄が指す）から、**各地の震度**を地図に落とすためのデータを取り出す。
///
/// 詳報（震源・震度情報 VXSE53/5k）の `Body.Intensity.Observation.Pref[].Area[].City[]
/// .IntensityStation[]` に観測点ごとの震度と座標（`latlon`）が入っている（2026-11-08
/// 実測。震度速報 VXSE51 には観測点が無い）。観測点は 4,000 超あるので、地図の
/// ズームに応じて 地域（Area、全国約190）→ 市区町村（City）→ 観測点 の 3 段階に
/// 集約して出す（代表点は配下の観測点の平均座標、震度はその最大）。
///
/// 取得は端末が選んだ地震についてだけ 1 回行い、メモリに控える（SPEC C2・C3）。

/// 地図に落とす 1 点（地域・市区町村・観測点のいずれか）
class QuakeIntensityPoint {
  const QuakeIntensityPoint({
    required this.name,
    required this.code,
    required this.intensity,
    required this.pos,
  });

  final String name;
  final String code;

  /// 気象庁の標準形（'1'〜'4','5-','5+','6-','6+','7'）
  final String intensity;
  final LatLng pos;

  int get rank => quakeIntensityRank(intensity);
}

/// 集約の段階
enum QuakeIntensityLevel { area, city, station }

class QuakeDetail {
  const QuakeDetail({
    required this.eid,
    required this.at,
    required this.place,
    required this.magnitude,
    required this.maxIntensity,
    required this.epicenter,
    required this.depthKm,
    required this.areas,
    required this.cities,
    required this.stations,
  });

  final String eid;
  final DateTime? at;
  final String place;
  final String magnitude;
  final String maxIntensity;
  final LatLng? epicenter;

  /// 震源の深さ（km）。不明なら null。0 は「ごく浅い」
  final int? depthKm;
  final List<QuakeIntensityPoint> areas;
  final List<QuakeIntensityPoint> cities;
  final List<QuakeIntensityPoint> stations;

  bool get hasIntensity => stations.isNotEmpty;

  /// ズームに応じた集約段階（広域=地域、県域=市区町村、市街地=観測点）
  static QuakeIntensityLevel levelForZoom(double zoom) {
    if (zoom < 7.5) return QuakeIntensityLevel.area;
    if (zoom < 9.5) return QuakeIntensityLevel.city;
    return QuakeIntensityLevel.station;
  }

  List<QuakeIntensityPoint> pointsFor(QuakeIntensityLevel level) => switch (level) {
        QuakeIntensityLevel.area => areas,
        QuakeIntensityLevel.city => cities,
        QuakeIntensityLevel.station => stations,
      };

  /// 全観測点を含む矩形（south, west, north, east）。観測点が無ければ null
  (double, double, double, double)? get bounds {
    if (stations.isEmpty) return null;
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in stations) {
      if (p.pos.latitude < s) s = p.pos.latitude;
      if (p.pos.latitude > n) n = p.pos.latitude;
      if (p.pos.longitude < w) w = p.pos.longitude;
      if (p.pos.longitude > e) e = p.pos.longitude;
    }
    final ep = epicenter;
    if (ep != null) {
      if (ep.latitude < s) s = ep.latitude;
      if (ep.latitude > n) n = ep.latitude;
      if (ep.longitude < w) w = ep.longitude;
      if (ep.longitude > e) e = ep.longitude;
    }
    return (s, w, n, e);
  }
}

/// 観測点名の末尾の「＊」「*」（気象庁以外の観測点を示す印）を取り除く
String stripStationMark(String name) => name.replaceAll(RegExp(r'[＊*]+$'), '').trim();

final RegExp _coordRe = RegExp(r'^([+-][\d.]+)([+-][\d.]+)(?:([+-]\d+))?');

/// 震源の座標文字列（"+34.9+137.7-40000/"）→ 緯度経度と深さ（km）
(LatLng?, int?) parseHypocenterCoordinate(String s) {
  final m = _coordRe.firstMatch(s.trim());
  if (m == null) return (null, null);
  final lat = double.tryParse(m.group(1)!);
  final lng = double.tryParse(m.group(2)!);
  int? depth;
  final d = m.group(3);
  if (d != null) {
    final meters = int.tryParse(d);
    if (meters != null) depth = (meters.abs() / 1000).round();
  }
  final pos = (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180)
      ? null
      : LatLng(lat, lng);
  return (pos, depth);
}

/// 詳報 JSON → [QuakeDetail]。構造が想定と違っても落とさず、取れた分だけ返す
QuakeDetail parseQuakeDetail(Map<String, dynamic> json, {String eid = ''}) {
  final body = json['Body'] is Map ? json['Body'] as Map : const {};
  final eq = body['Earthquake'] is Map ? body['Earthquake'] as Map : const {};
  final hypo = eq['Hypocenter'] is Map ? eq['Hypocenter'] as Map : const {};
  final hArea = hypo['Area'] is Map ? hypo['Area'] as Map : const {};
  final (epicenter, depthKm) =
      parseHypocenterCoordinate(hArea['Coordinate']?.toString() ?? '');
  final head = json['Head'] is Map ? json['Head'] as Map : const {};
  final id = eid.isNotEmpty ? eid : (head['EventID']?.toString() ?? '');
  final at = DateTime.tryParse(eq['OriginTime']?.toString() ?? '');

  final intensity = body['Intensity'] is Map ? body['Intensity'] as Map : const {};
  final obs = intensity['Observation'] is Map ? intensity['Observation'] as Map : const {};
  final areas = <QuakeIntensityPoint>[];
  final cities = <QuakeIntensityPoint>[];
  final stations = <QuakeIntensityPoint>[];

  QuakeIntensityPoint? centroid(String name, String code, String maxInt, List<QuakeIntensityPoint> members) {
    if (members.isEmpty) return null;
    var lat = 0.0, lng = 0.0;
    var best = '';
    for (final m in members) {
      lat += m.pos.latitude;
      lng += m.pos.longitude;
      if (quakeIntensityRank(m.intensity) > quakeIntensityRank(best)) best = m.intensity;
    }
    final declared = normalizeIntensity(maxInt);
    final value = quakeIntensityRank(declared) >= quakeIntensityRank(best) ? declared : best;
    if (quakeIntensityRank(value) == 0) return null;
    return QuakeIntensityPoint(
        name: name, code: code, intensity: value,
        pos: LatLng(lat / members.length, lng / members.length));
  }

  for (final pref in obs['Pref'] is List ? obs['Pref'] as List : const []) {
    if (pref is! Map) continue;
    for (final area in pref['Area'] is List ? pref['Area'] as List : const []) {
      if (area is! Map) continue;
      final areaMembers = <QuakeIntensityPoint>[];
      for (final city in area['City'] is List ? area['City'] as List : const []) {
        if (city is! Map) continue;
        final cityMembers = <QuakeIntensityPoint>[];
        for (final st in city['IntensityStation'] is List ? city['IntensityStation'] as List : const []) {
          if (st is! Map) continue;
          final ll = st['latlon'];
          if (ll is! Map) continue;
          final lat = (ll['lat'] as num?)?.toDouble();
          final lng = (ll['lon'] as num?)?.toDouble();
          final v = normalizeIntensity(st['Int']?.toString() ?? '');
          if (lat == null || lng == null || quakeIntensityRank(v) == 0) continue;
          // 観測点名末尾の「＊」は気象庁以外（自治体・防災科研）の観測点の印。アプリでは出さない
          final p = QuakeIntensityPoint(
              name: stripStationMark(st['Name']?.toString() ?? ''),
              code: st['Code']?.toString() ?? '',
              intensity: v,
              pos: LatLng(lat, lng));
          cityMembers.add(p);
        }
        stations.addAll(cityMembers);
        areaMembers.addAll(cityMembers);
        final c = centroid(city['Name']?.toString() ?? '', city['Code']?.toString() ?? '',
            city['MaxInt']?.toString() ?? '', cityMembers);
        if (c != null) cities.add(c);
      }
      final a = centroid(area['Name']?.toString() ?? '', area['Code']?.toString() ?? '',
          area['MaxInt']?.toString() ?? '', areaMembers);
      if (a != null) areas.add(a);
    }
  }
  int byRank(QuakeIntensityPoint a, QuakeIntensityPoint b) => b.rank - a.rank;
  areas.sort(byRank);
  cities.sort(byRank);
  stations.sort(byRank);

  return QuakeDetail(
    eid: id,
    at: at,
    place: hArea['Name']?.toString() ?? '',
    magnitude: eq['Magnitude']?.toString() ?? '',
    maxIntensity: normalizeIntensity(obs['MaxInt']?.toString() ?? ''),
    epicenter: epicenter,
    depthKm: depthKm,
    areas: areas,
    cities: cities,
    stations: stations,
  );
}

/// 詳報の取得（選んだ地震ごとに 1 回。メモリに控える）
class QuakeDetails {
  QuakeDetails._();

  static const base = 'https://www.jma.go.jp/bosai/quake/data/';
  static const _ua = {'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'};
  static final Map<String, QuakeDetail> _cache = {};

  /// テストで差し替える取得関数（URL → 本文。失敗は例外）
  static Future<String> Function(Uri uri) fetcher = (uri) async {
    final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw http.ClientException('HTTP ${r.statusCode}', uri);
    return utf8.decode(r.bodyBytes);
  };

  /// [jsonName] は list.json の `json` 欄（例 `20261108011257_20261108010441_VXSE5k_2.json`）。
  /// 取得・解析に失敗したら null
  static Future<QuakeDetail?> fetch(String jsonName, {String eid = ''}) async {
    if (jsonName.isEmpty) return null;
    final cached = _cache[jsonName];
    if (cached != null) return cached;
    try {
      final body = await fetcher(Uri.parse('$base$jsonName'));
      final d = parseQuakeDetail(jsonDecode(body) as Map<String, dynamic>, eid: eid);
      _cache[jsonName] = d;
      return d;
    } catch (_) {
      return null;
    }
  }

  static void clearCache() => _cache.clear();
}
