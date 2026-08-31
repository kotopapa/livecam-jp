import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'l10n_test_app.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/map_screen.dart';

Camera _cam(String id, double lat, double lng,
        {String pref = '13', String? country}) =>
    Camera.tryParse({
      'id': id,
      'name': id,
      'category': 'scenic',
      'prefecture': pref,
      'country': ?country,
      'lat': lat,
      'lng': lng,
      'coord_accuracy': 'exact',
      'feed': {'type': 'still_image', 'url': 'https://example.jp/$id.jpg'},
      'operator': 'テスト',
      'source': {'page_url': 'https://example.jp/'},
    })!;

void main() {
  testWidgets('世界カメラ表示中に地図をズーム・移動してもクラッシュしない', (tester) async {
    final repo = CameraRepository(
      api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    );
    repo.cameras = [
      _cam('jp-1', 35.68, 139.76),
      _cam('jp-2', 43.06, 141.35, pref: '01'),
      _cam('world-sydney', -33.85, 151.21, pref: '99', country: 'AU'),
      _cam('world-ny', 40.71, -74.0, pref: '99', country: 'US'),
      _cam('world-fiji', -17.7, 178.8, pref: '99', country: 'FJ'),
      _cam('world-samoa', -13.8, -171.7, pref: '99', country: 'WS'),
    ];
    final app = AppState(repo);
    app.showWorld = true;

    await tester.pumpWidget(
        testApp(Scaffold(body: MapScreen(app: app))));
    await tester.pump(const Duration(milliseconds: 100));

    // 世界ズームまで引く → 横に大きくパン（経度±180跨ぎ相当） → ズームイン
    final map = find.byType(MapScreen);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 6; i++) {
      await tester.drag(map, const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var i = 0; i < 4; i++) {
      await tester.drag(map, const Offset(500, 120));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
