import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' show GoogleMapsFlutterPlatform;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/jma_layers.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/data/quake_detail.dart';
import 'package:livecam_jp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_google_maps_platform.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final detailJson = File('test/fixtures/quake_detail_vxse53.json').readAsStringSync();

  setUp(() {
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    QuakeDetails.clearCache();
    QuakeDetails.fetcher = (uri) async => detailJson;
    JmaLayers.quakeFetcher = (period) async => [
          QuakePoint(
              at: DateTime.parse('2026-11-08T01:04:00+09:00'),
              place: '静岡県西部', magnitude: '5.7', maxIntensity: '5+',
              pos: const LatLng(34.9, 137.7),
              eid: '20261108010441', detailJson: 'x.json'),
          QuakePoint(
              at: DateTime.parse('2026-11-08T08:23:00+09:00'),
              place: '熊本県熊本地方', magnitude: '3.0', maxIntensity: '1',
              pos: const LatLng(32.5, 130.6),
              eid: 'e-kumamoto', detailJson: ''),
        ];
  });
  tearDown(() {
    JmaLayers.quakeFetcher = null;
  });

  testWidgets('災害速報からの「地図で各地の震度を見る」で、選んだ地震の見出しが出て戻れる', (tester) async {
    final app = AppState(CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('not found', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));
    await tester.pumpWidget(LiveCamApp(
      app: app, onboardingDone: true,
      localeController: LocaleController(initial: AppLanguage.ja),
    ));
    await tester.pump();

    app.navigationRequest.value = 'map/quake/20261108010441';
    await settle(tester);

    // 選んだ地震の見出し（震源地・M・深さ）と「戻る」
    expect(find.byKey(const Key('map_quake_selected')), findsOneWidget);
    expect(find.text('静岡県西部'), findsOneWidget);
    expect(find.textContaining('M5.7'), findsOneWidget);
    expect(find.textContaining('深さ約40km'), findsOneWidget);
    expect(find.text('震源の期間'), findsNothing, reason: '期間チップの代わりに見出しが出る');
    expect(find.text('この地震の各地の震度はまだ発表されていません'), findsNothing);

    await tester.tap(find.byKey(const Key('map_quake_back')));
    await settle(tester);
    expect(find.byKey(const Key('map_quake_selected')), findsNothing);
    expect(find.text('震源の期間'), findsOneWidget, reason: '震源一覧（期間チップ）に戻る');
  });

  testWidgets('各地の震度が無い地震（震度速報のみ）はその旨を出す', (tester) async {
    final app = AppState(CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('not found', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));
    await tester.pumpWidget(LiveCamApp(
      app: app, onboardingDone: true,
      localeController: LocaleController(initial: AppLanguage.ja),
    ));
    await tester.pump();
    app.navigationRequest.value = 'map/quake/e-kumamoto';
    await settle(tester);
    expect(find.text('熊本県熊本地方'), findsOneWidget);
    expect(find.text('この地震の各地の震度はまだ発表されていません'), findsOneWidget);
  });

  test('詳報の点の描き分け: 強い震度を後に描く順と、明るい塗りの文字色', () {
    final d = parseQuakeDetail(jsonDecode(detailJson) as Map<String, dynamic>);
    final areas = d.pointsFor(QuakeIntensityLevel.area);
    expect(areas.first.rank >= areas.last.rank, isTrue, reason: '強い順に並ぶ');
    expect(d.pointsFor(QuakeIntensityLevel.station).length >= d.pointsFor(QuakeIntensityLevel.city).length, isTrue);
  });
}
