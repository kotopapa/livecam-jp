import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/route_corridor.dart';
import 'package:livecam_jp/models/camera.dart';

Camera _cam(String id, double lat, double lng) => Camera.tryParse({
      'id': id,
      'name': id,
      'lat': lat,
      'lng': lng,
      'category': 'road',
      'prefecture': '13',
      'feed': {'type': 'still_image', 'url': 'https://example.com/$id.jpg'},
      'source': {'page_url': 'https://example.com/', 'license': 'unknown'},
      'review': {'status': 'approved'},
    })!;

/// Google の公式サンプルのエンコード済みポリライン（精度5）。
/// デコード結果: (38.5,-120.2), (40.7,-120.95), (43.252,-126.453)
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
const _googleSamplePolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

Map<String, Object?> _googleRoutesJson({
  String polyline = _googleSamplePolyline,
  num distanceMeters = 12345,
  String duration = '600s',
}) => {
      'routes': [
        {
          'polyline': {'encodedPolyline': polyline},
          'distanceMeters': distanceMeters,
          'duration': duration,
        }
      ],
    };

void main() {
  // 東京駅(35.681,139.767) → 横浜駅(35.466,139.622) をほぼ直線で結ぶ経路
  final route = [
    const LatLng(35.681, 139.767),
    const LatLng(35.60, 139.72),
    const LatLng(35.53, 139.66),
    const LatLng(35.466, 139.622),
  ];

  test('経路から一定距離のカメラだけを、出発地からの順に返す', () {
    final cams = [
      _cam('yokohama', 35.467, 139.623), // 終点付近
      _cam('kawasaki', 35.60, 139.72), // 経路上
      _cam('tokyo', 35.682, 139.768), // 始点付近
      _cam('far', 35.70, 139.90), // 約12km離れ
      _cam('side', 35.605, 139.73), // 経路から約1km
    ];
    final r1 = RouteCorridor.camerasAlong(cams, route, widthM: 500);
    expect(r1.map((c) => c.camera.id).toList(), ['tokyo', 'kawasaki', 'yokohama']);
    expect(r1.first.alongM, lessThan(500));
    expect(r1.last.alongM, greaterThan(20000));
    final r2 = RouteCorridor.camerasAlong(cams, route, widthM: 2000);
    // side は経路上では kawasaki の少し手前に射影される（経路は南西向き）
    expect(r2.map((c) => c.camera.id).toList(),
        ['tokyo', 'side', 'kawasaki', 'yokohama']);
    expect(r2[1].offsetM, inInclusiveRange(400, 800));
  });

  test('間引き: 直線上の中間点は落ち、曲がり角は残る', () {
    final pts = [
      const LatLng(35.0, 139.0),
      const LatLng(35.0, 139.1), // 直線上
      const LatLng(35.0, 139.2),
      const LatLng(35.1, 139.2), // 曲がる
      const LatLng(35.2, 139.2),
    ];
    final s = RouteCorridor.simplify(pts, 50);
    expect(s, [pts[0], pts[2], pts[4]]);
    expect(RouteCorridor.simplify(pts.take(2).toList(), 50).length, 2);
  });

  test('ORS の GeoJSON 応答を経路にする（source=ors、出典はopenrouteservice）', () {
    final r = RouteCorridor.parseGeoJson({
      'type': 'FeatureCollection',
      'features': [
        {
          'geometry': {
            'coordinates': [
              [139.767, 35.681],
              [139.72, 35.60],
              [139.622, 35.466],
            ]
          },
          'properties': {
            'summary': {'distance': 31234.5, 'duration': 2400.0}
          },
        }
      ],
    })!;
    expect(r.points.length, 3);
    expect(r.points.first.latitude, 35.681);
    expect(r.distanceM, 31234.5);
    expect(r.durationS, 2400);
    expect(r.source, 'ors');
    expect(r.attribution, RouteCorridor.attribution);
    expect(RouteCorridor.parseGeoJson({'features': []}), isNull);
    expect(RouteCorridor.parseGeoJson('x'), isNull);
  });

  test('decodePolyline: Google公式サンプルを既知の3点にデコードする', () {
    final pts = RouteCorridor.decodePolyline(_googleSamplePolyline);
    expect(pts.length, 3);
    expect(pts[0].latitude, closeTo(38.5, 1e-4));
    expect(pts[0].longitude, closeTo(-120.2, 1e-4));
    expect(pts[1].latitude, closeTo(40.7, 1e-4));
    expect(pts[1].longitude, closeTo(-120.95, 1e-4));
    expect(pts[2].latitude, closeTo(43.252, 1e-4));
    expect(pts[2].longitude, closeTo(-126.453, 1e-4));
  });

  test('Google Routes API の応答を経路にする（source=google、出典はGoogle）', () {
    final r = RouteCorridor.parseGoogleRoutes(_googleRoutesJson())!;
    expect(r.points.length, 3);
    expect(r.distanceM, 12345);
    expect(r.durationS, 600);
    expect(r.source, 'google');
    expect(r.attribution, RouteCorridor.attributionGoogle);
    expect(RouteCorridor.parseGoogleRoutes({'routes': []}), isNull);
    expect(RouteCorridor.parseGoogleRoutes('x'), isNull);
    expect(
        RouteCorridor.parseGoogleRoutes({
          'routes': [{'polyline': {}}]
        }),
        isNull);
    expect(
        RouteCorridor.parseGoogleRoutes({
          'routes': [{'polyline': {'encodedPolyline': ''}}]
        }),
        isNull);
  });

  test('fetchRoute: Google が使えれば優先し、ORS は呼ばない', () async {
    var googleCalls = 0;
    var orsCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'routes.googleapis.com') {
        googleCalls++;
        expect(req.headers['X-Goog-Api-Key'], 'GKEY');
        expect(req.headers['X-Goog-FieldMask'], contains('encodedPolyline'));
        expect(req.headers['X-Ios-Bundle-Identifier'], 'jp.livecam.livecamJp');
        final body = jsonDecode(req.body) as Map;
        expect(body['travelMode'], 'DRIVE');
        expect(body['origin']['location']['latLng']['latitude'], route.first.latitude);
        return http.Response(jsonEncode(_googleRoutesJson()), 200);
      }
      orsCalls++;
      return http.Response('quota', 429);
    });
    final r = await RouteCorridor.fetchRoute(route.first, route.last,
        orsApiKey: 'ORSKEY',
        googleApiKey: 'GKEY',
        googleHeaders: const {'X-Ios-Bundle-Identifier': 'jp.livecam.livecamJp'},
        client: client);
    expect(r, isNotNull);
    expect(r!.source, 'google');
    expect(googleCalls, 1);
    expect(orsCalls, 0);
  });

  test('fetchRoute: Google が失敗（キー制限・割り当て超過等）したら ORS にフォールバック', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'routes.googleapis.com') {
        return http.Response('error', 403);
      }
      expect(req.headers['Authorization'], 'ORSKEY');
      return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [
                    [139.767, 35.681],
                    [139.622, 35.466],
                  ]
                },
                'properties': {
                  'summary': {'distance': 1, 'duration': 1}
                },
              }
            ]
          }),
          200);
    });
    final r = await RouteCorridor.fetchRoute(route.first, route.last,
        orsApiKey: 'ORSKEY', googleApiKey: 'GKEY', googleHeaders: const {}, client: client);
    expect(r, isNotNull);
    expect(r!.source, 'ors');
  });

  test('fetchRoute: Google キー無し・ORS キー無しなら両方呼ばず null', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 200);
    });
    final r = await RouteCorridor.fetchRoute(route.first, route.last,
        orsApiKey: '', googleApiKey: '', client: client);
    expect(r, isNull);
    expect(calls, 0);
  });

  test('fetchRoute: Google キー無し・ORS キーありなら ORS だけ呼ぶ', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.url.host, 'api.openrouteservice.org');
      return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [
                    [139.767, 35.681],
                    [139.622, 35.466],
                  ]
                },
                'properties': {
                  'summary': {'distance': 1, 'duration': 1}
                },
              }
            ]
          }),
          200);
    });
    final r = await RouteCorridor.fetchRoute(route.first, route.last,
        orsApiKey: 'ORSKEY', googleApiKey: '', client: client);
    expect(r, isNotNull);
    expect(r!.source, 'ors');
    expect(calls, 1);
  });
}
