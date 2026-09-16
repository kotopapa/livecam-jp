/// ルート沿いカメラ: 出発地と目的地の経路を引き、経路から一定距離（コリドー）内の
/// カメラだけを取り出す。
///
/// 経路は openrouteservice（OSMベース。無料枠 1日2,000回・APIキー必要）で計算する。
/// キーはアプリに埋め込まず、配信 manifest の `route_ors_key`（publish 時に GitHub の
/// Secret ORS_API_KEY から入れる）で受け取る。キーが無い環境では機能を出さない。
/// 経路データの出典表記: openrouteservice / © OpenStreetMap contributors
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/camera.dart';

/// 経路計算の結果
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceM,
    required this.durationS,
  });

  final List<LatLng> points;
  final double distanceM;
  final double durationS;
}

/// 経路上の位置付きのカメラ（一覧の並び順に使う）
class CorridorCamera {
  const CorridorCamera(this.camera, {required this.alongM, required this.offsetM});

  final Camera camera;

  /// 出発地からの経路上の距離（m）
  final double alongM;

  /// 経路からの垂直距離（m）
  final double offsetM;
}

class RouteCorridor {
  RouteCorridor._();

  static const attribution = '経路: openrouteservice / © OpenStreetMap contributors';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// openrouteservice の自動車経路。失敗は null
  static Future<RouteResult?> fetchRoute(
    LatLng origin,
    LatLng destination, {
    required String apiKey,
    http.Client? client,
  }) async {
    if (apiKey.isEmpty) return null;
    final c = client ?? http.Client();
    try {
      final r = await c
          .post(
            Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
            headers: {
              ..._ua,
              'Authorization': apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/geo+json, application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [origin.longitude, origin.latitude],
                [destination.longitude, destination.latitude],
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return parseGeoJson(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// 地名・施設名の検索（openrouteservice の Geocoding API。OSM ベースで
  /// 「赤レンガ倉庫」のような施設名に対応。無料枠 1日1,000回）。
  /// 国土地理院の住所検索は住所専用で、施設名を入れると部分一致の住所が返るため
  /// （「赤レンガ倉庫」→「福岡県赤村」）、こちらを主に使う。失敗は空
  static Future<List<(String, LatLng)>> geocode(
    String query, {
    required String apiKey,
    http.Client? client,
    int size = 8,
  }) async {
    final q = query.trim();
    if (apiKey.isEmpty || q.isEmpty) return const [];
    final c = client ?? http.Client();
    try {
      final uri = Uri.https('api.openrouteservice.org', '/geocode/search', {
        'api_key': apiKey,
        'text': q,
        'boundary.country': 'JP',
        'size': '$size',
        'lang': 'ja',
      });
      final r = await c.get(uri, headers: _ua).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const [];
      return parseGeocode(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return const [];
    } finally {
      if (client == null) c.close();
    }
  }

  /// Pelias 形式の応答 → (表示名, 座標)。表示名は「名称（地域 市区町村）」
  static List<(String, LatLng)> parseGeocode(Object? json) {
    if (json is! Map) return const [];
    final features = json['features'];
    if (features is! List) return const [];
    final out = <(String, LatLng)>[];
    final seen = <String>{};
    for (final f in features) {
      if (f is! Map) continue;
      final geom = f['geometry'];
      final coords = geom is Map ? geom['coordinates'] : null;
      if (coords is! List || coords.length < 2 || coords[0] is! num || coords[1] is! num) {
        continue;
      }
      final props = f['properties'];
      if (props is! Map) continue;
      final name = props['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final region = props['region']?.toString() ?? '';
      final locality = (props['locality'] ?? props['county'])?.toString() ?? '';
      final where = [region, if (locality.isNotEmpty && locality != region) locality]
          .where((e) => e.isNotEmpty)
          .join(' ');
      final label = where.isEmpty ? name : '$name（$where）';
      if (!seen.add(label)) continue;
      out.add((label, LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble())));
    }
    return out;
  }

  /// ORS の GeoJSON 応答（features[0].geometry.coordinates = [[lng,lat],...]）
  static RouteResult? parseGeoJson(Object? json) {
    if (json is! Map) return null;
    final features = json['features'];
    if (features is! List || features.isEmpty) return null;
    final f = features.first;
    if (f is! Map) return null;
    final geom = f['geometry'];
    final coords = geom is Map ? geom['coordinates'] : null;
    if (coords is! List) return null;
    final pts = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        pts.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    if (pts.length < 2) return null;
    final props = f['properties'];
    final summary = props is Map ? props['summary'] : null;
    double asDouble(Object? v) => v is num ? v.toDouble() : 0;
    return RouteResult(
      points: pts,
      distanceM: summary is Map ? asDouble(summary['distance']) : 0,
      durationS: summary is Map ? asDouble(summary['duration']) : 0,
    );
  }

  /// 経路の点列を間引く（Douglas–Peucker、許容誤差 m）。カメラ照合の計算量を抑える
  static List<LatLng> simplify(List<LatLng> pts, double toleranceM) {
    if (pts.length <= 2) return pts;
    final keep = List<bool>.filled(pts.length, false);
    keep[0] = true;
    keep[pts.length - 1] = true;
    final stack = <(int, int)>[(0, pts.length - 1)];
    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();
      var best = -1;
      var bestD = 0.0;
      for (var i = a + 1; i < b; i++) {
        final d = _segmentDistanceM(pts[i], pts[a], pts[b]).$1;
        if (d > bestD) {
          bestD = d;
          best = i;
        }
      }
      if (best >= 0 && bestD > toleranceM) {
        keep[best] = true;
        stack.add((a, best));
        stack.add((best, b));
      }
    }
    return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
  }

  /// 経路から [widthM] 以内のカメラを、出発地からの経路上距離の順に返す
  static List<CorridorCamera> camerasAlong(
    Iterable<Camera> cameras,
    List<LatLng> route, {
    required double widthM,
  }) {
    if (route.length < 2) return const [];
    final line = simplify(route, 30);
    // 外接矩形（幅ぶん広げる）で大まかに絞ってから線分距離を計算する
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final p in line) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final dLat = widthM / 110540;
    final dLng = widthM / (111320 * math.cos(((minLat + maxLat) / 2) * math.pi / 180));
    // 各線分の始点までの累積距離
    final cum = List<double>.filled(line.length, 0);
    for (var i = 1; i < line.length; i++) {
      cum[i] = cum[i - 1] + _meters(line[i - 1], line[i]);
    }
    final out = <CorridorCamera>[];
    for (final c in cameras) {
      if (!c.hasLocation) continue;
      final lat = c.lat!, lng = c.lng!;
      if (lat < minLat - dLat || lat > maxLat + dLat) continue;
      if (lng < minLng - dLng || lng > maxLng + dLng) continue;
      final p = LatLng(lat, lng);
      var bestD = double.infinity;
      var bestAlong = 0.0;
      for (var i = 1; i < line.length; i++) {
        final (d, t) = _segmentDistanceM(p, line[i - 1], line[i]);
        if (d < bestD) {
          bestD = d;
          bestAlong = cum[i - 1] + t * (cum[i] - cum[i - 1]);
        }
      }
      if (bestD <= widthM) {
        out.add(CorridorCamera(c, alongM: bestAlong, offsetM: bestD));
      }
    }
    out.sort((a, b) => a.alongM.compareTo(b.alongM));
    return out;
  }

  /// 点 p と線分 ab の距離（m）と、a からの位置 t（0〜1）。局所的な平面近似
  static (double, double) _segmentDistanceM(LatLng p, LatLng a, LatLng b) {
    final k = 111320 * math.cos(p.latitude * math.pi / 180);
    final ax = (a.longitude - p.longitude) * k, ay = (a.latitude - p.latitude) * 110540;
    final bx = (b.longitude - p.longitude) * k, by = (b.latitude - p.latitude) * 110540;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy)) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return (math.sqrt(cx * cx + cy * cy), t);
  }

  static double _meters(LatLng a, LatLng b) {
    final k = 111320 * math.cos(((a.latitude + b.latitude) / 2) * math.pi / 180);
    final dx = (b.longitude - a.longitude) * k;
    final dy = (b.latitude - a.latitude) * 110540;
    return math.sqrt(dx * dx + dy * dy);
  }
}
