import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/amedas_snow.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/bosai_screen.dart';

Camera cam(String id, String name, double lat, double lng) => Camera(
      id: id, name: name, category: 'road', prefecture: '06',
      feed: const Feed(type: FeedType.mlitRoadinfo, url: 'u', cameraRef: 'r'),
      operator: 'テスト運営者', attribution: 'x',
      lat: lat, lng: lng, coordAccuracy: CoordAccuracy.exact,
    );

void main() {
  testWidgets('観測点の行をタップすると、その地点の周辺カメラが近い順に出る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState(CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));
    app.repository.cameras = [
      cam('far', '山形市内カメラ', 38.25, 140.33), // 約40km。20km の外
      cam('mid', '道行沢橋', 38.55, 139.93),
      cam('near', '月山第1TN鶴岡側', 38.5252, 139.9489),
    ];
    const station = SnowStation(
        id: '825600013', name: '八紘沢', lat: 38.525148, lng: 139.948867,
        municipality: '06203', source: '国交省', sourceId: 'mlit');
    const data = SnowPrefecture(prefCode: '06', municipalities: [
      SnowMunicipality(code: '06203', stations: [
        SnowObs(station: station, depth: 103),
      ]),
    ]);

    await tester.pumpWidget(
        testApp(SnowPrefectureScreen(app: app, title: '山形', data: data)));
    await tester.tap(find.textContaining('八紘沢'));
    await tester.pumpAndSettle();

    expect(find.text('八紘沢周辺のカメラ'), findsOneWidget);
    expect(find.text('月山第1TN鶴岡側'), findsOneWidget);
    expect(find.text('道行沢橋'), findsOneWidget);
    expect(find.text('山形市内カメラ'), findsNothing);
    expect(
        tester.getTopLeft(find.text('月山第1TN鶴岡側')).dy,
        lessThan(tester.getTopLeft(find.text('道行沢橋')).dy));
  });
}
