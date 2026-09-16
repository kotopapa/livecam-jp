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

  test('ORS の GeoJSON 応答を経路にする', () {
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
    expect(RouteCorridor.parseGeoJson({'features': []}), isNull);
    expect(RouteCorridor.parseGeoJson('x'), isNull);
  });

  test('geocode: Pelias 応答を「名称（地域 市区町村）」と座標にする', () {
    final hits = RouteCorridor.parseGeocode({
      'features': [
        {
          'geometry': {'coordinates': [139.645066, 35.452281]},
          'properties': {'name': '赤レンガ倉庫', 'region': '神奈川', 'locality': '横浜市'},
        },
        {
          'geometry': {'coordinates': [136.074534, 35.661958]},
          'properties': {'name': '赤レンガ倉庫', 'region': '福井', 'locality': '敦賀市'},
        },
        {
          'geometry': {'coordinates': [135.437597, 34.651466]},
          'properties': {'name': '赤レンガ倉庫横広場', 'region': '大阪', 'locality': '大阪'},
        },
        {'geometry': {'coordinates': ['x', 1]}, 'properties': {'name': '壊れ'}},
      ]
    });
    expect(hits.map((h) => h.$1).toList(),
        ['赤レンガ倉庫（神奈川 横浜市）', '赤レンガ倉庫（福井 敦賀市）', '赤レンガ倉庫横広場（大阪）']);
    expect(hits.first.$2.latitude, 35.452281);
    expect(RouteCorridor.parseGeocode({'features': []}), isEmpty);
    expect(RouteCorridor.parseGeocode(null), isEmpty);
  });

  test('geocode: キーが無ければ呼ばない', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"features":[]}', 200);
    });
    expect(await RouteCorridor.geocode('横浜', apiKey: '', client: client), isEmpty);
    expect(calls, 0);
    expect(await RouteCorridor.geocode('横浜', apiKey: 'KEY', client: client), isEmpty);
    expect(calls, 1);
  });

  test('fetchRoute: キーが無ければ呼ばない、200 以外は null', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.headers['Authorization'], 'KEY');
      final body = jsonDecode(req.body) as Map;
      expect((body['coordinates'] as List).length, 2);
      return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [
                    [139.767, 35.681],
                    [139.622, 35.466]
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
    expect(
        await RouteCorridor.fetchRoute(route.first, route.last,
            apiKey: '', client: client),
        isNull);
    expect(calls, 0);
    final r = await RouteCorridor.fetchRoute(route.first, route.last,
        apiKey: 'KEY', client: client);
    expect(r, isNotNull);
    expect(calls, 1);
    final bad = MockClient((_) async => http.Response('quota', 429));
    expect(
        await RouteCorridor.fetchRoute(route.first, route.last,
            apiKey: 'KEY', client: bad),
        isNull);
  });
}
