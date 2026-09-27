/// ルート沿いカメラ: 出発地と目的地の経路を引き、経路から一定距離（コリドー）内の
/// カメラだけを取り出す。
///
/// 経路は Google Routes API（ネイティブ側の Google Maps 用キーを NativeConfig
/// 経由で流用）を優先し、キー未設定・エラー・割り当て超過などで失敗したときは
/// openrouteservice（OSMベース。無料枠 1日2,000回・APIキー必要。キーはアプリに
/// 埋め込まず配信 manifest の `route_ors_key` で受け取る）にフォールバックする。
/// どちらも使えない環境では機能を出さない。
/// 出典表記は使ったサービスに応じて切り替える（[RouteResult.attribution]）
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/camera.dart';
import 'native_config.dart';

/// 経路計算の結果
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.source,
  });

  final List<LatLng> points;
  final double distanceM;
  final double durationS;

  /// 経路を計算したサービス: 'google' または 'ors'
  final String source;

  /// 出典表記（画面表示用）
  String get attribution =>
      source == 'google' ? RouteCorridor.attributionGoogle : RouteCorridor.attribution;
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
  static const attributionGoogle = '経路: Google';

  /// ルート検索シートで、実際に使うサービスが決まる前に出す案内文
  static const attributionNotice =
      '経路: Google（利用できない場合は openrouteservice / © OpenStreetMap contributors）';

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// 自動車経路。Google Routes API を優先し、キー未設定・エラー・割り当て超過
  /// などで使えないときは openrouteservice にフォールバックする。両方失敗なら null。
  /// [googleApiKey] / [googleHeaders] を渡すとテストで固定できる（null なら
  /// NativeConfig から都度取得）
  static Future<RouteResult?> fetchRoute(
    LatLng origin,
    LatLng destination, {
    required String orsApiKey,
    http.Client? client,
    String? googleApiKey,
    Map<String, String>? googleHeaders,
  }) async {
    final gKey = googleApiKey ?? await NativeConfig.instance.getGoogleMapsApiKey();
    if (gKey != null && gKey.isNotEmpty) {
      final headers = googleHeaders ?? await NativeConfig.instance.getAppRestrictionHeaders();
      final g = await _fetchGoogleRoute(origin, destination,
          apiKey: gKey, headers: headers, client: client);
      if (g != null) return g;
    }
    return _fetchOrsRoute(origin, destination, apiKey: orsApiKey, client: client);
  }

  /// Google Routes API (computeRoutes) の自動車経路。失敗は null
  static Future<RouteResult?> _fetchGoogleRoute(
    LatLng origin,
    LatLng destination, {
    required String apiKey,
    required Map<String, String> headers,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .post(
            Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
            headers: {
              ...headers,
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}
                }
              },
              'destination': {
                'location': {
                  'latLng': {
                    'latitude': destination.latitude,
                    'longitude': destination.longitude
                  }
                }
              },
              'travelMode': 'DRIVE',
              'polylineQuality': 'OVERVIEW',
              'languageCode': 'ja',
              'units': 'METRIC',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return parseGoogleRoutes(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// openrouteservice の自動車経路。失敗は null
  static Future<RouteResult?> _fetchOrsRoute(
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

  /// Google Routes API (computeRoutes) の応答 → RouteResult。
  /// duration は "1234s" 形式の文字列で返る
  static RouteResult? parseGoogleRoutes(Object? json) {
    if (json is! Map) return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first;
    if (route is! Map) return null;
    final polyline = route['polyline'];
    final encoded = polyline is Map ? polyline['encodedPolyline'] as String? : null;
    if (encoded == null || encoded.isEmpty) return null;
    final pts = decodePolyline(encoded);
    if (pts.length < 2) return null;
    final distance = route['distanceMeters'];
    final durationStr = route['duration']?.toString() ?? '';
    final durationS =
        double.tryParse(durationStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return RouteResult(
      points: pts,
      distanceM: distance is num ? distance.toDouble() : 0,
      durationS: durationS,
      source: 'google',
    );
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
      source: 'ors',
    );
  }

  /// Google のエンコード済みポリライン（精度5）をデコードする。
  /// google_maps_flutter にはデコーダが無いため自前実装（アルゴリズムは
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm）
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final len = encoded.length;
    while (index < len) {
      var result = 0;
      var shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
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
