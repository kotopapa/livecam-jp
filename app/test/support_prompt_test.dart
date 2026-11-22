import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/support_prompt.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/ad_banner.dart';
import 'package:livecam_jp/ui/detail_screen.dart';
import 'package:livecam_jp/ui/tip_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fake_google_maps_platform.dart';
import 'l10n_test_app.dart';

Camera _cam(FeedType type) => Camera(
      id: 'c1', name: 'c1カメラ', category: 'road', prefecture: '38',
      feed: Feed(type: type, url: 'https://example.jp/page.html', cameraRef: 'X1'),
      operator: '例', attribution: '出典：例',
      sourcePageUrl: 'https://example.jp/page.html',
      lat: 35.4, lng: 138.4, coordAccuracy: CoordAccuracy.area,
    );

void main() {
  setUpAll(() => adDisposeDelay = Duration.zero);
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  setUp(() {
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
  });

  test('開いた回数を数え、20 回目から・お礼の期間外にだけ出す', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SupportPrompt.recordCameraOpen(), 1);
    expect(await SupportPrompt.recordCameraOpen(), 2);
    expect(SupportPrompt.shouldShow(openCount: 19, adFreeActive: false), isFalse);
    expect(SupportPrompt.shouldShow(openCount: 20, adFreeActive: false), isTrue);
    expect(SupportPrompt.shouldShow(openCount: 500, adFreeActive: true), isFalse);
  });

  Future<AppState> makeApp() async {
    final app = AppState(CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));
    await app.favorites.load();
    return app;
  }

  Future<void> pumpDetail(WidgetTester tester, Camera camera) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    DetailScreen.skipHotelFlagsFetch();
    await tester.pumpWidget(testApp(DetailScreen(camera: camera, app: await makeApp())));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('よく使う人のカメラ詳細に応援のお願いが出て、支援画面へ進める', (tester) async {
    SharedPreferences.setMockInitialValues({'camera_open_count': 19});
    await pumpDetail(tester, _cam(FeedType.mlitRoadinfo));
    final note = find.byKey(const ValueKey('detail_support_note'));
    expect(note, findsOneWidget);
    expect(find.textContaining('個人で開発・運営しています', findRichText: true), findsOneWidget);
    await tester.tap(note);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final tip = tester.widget<TipScreen>(find.byType(TipScreen));
    expect(tip.source, 'detail_note');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('使い始めの人には出さない', (tester) async {
    SharedPreferences.setMockInitialValues({'camera_open_count': 3});
    await pumpDetail(tester, _cam(FeedType.mlitRoadinfo));
    expect(find.byKey(const ValueKey('detail_support_note')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('広告のそばのリンクから支援画面へ進める', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(body: RemoveAdsLink(source: 'ad_anchor'))));
    expect(find.text('応援して広告を消す'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove_ads_link')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<TipScreen>(find.byType(TipScreen)).source, 'ad_anchor');
    await tester.pumpWidget(const SizedBox());
  });
}
