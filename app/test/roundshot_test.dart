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
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/models/status.dart';
import 'package:livecam_jp/ui/ad_banner.dart';
import 'package:livecam_jp/ui/detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fake_google_maps_platform.dart';
import 'l10n_test_app.dart';

const _entry = 'https://zermatt.roundshot.com/cams/1';
const _latest = 'https://zermatt.roundshot.com/cams/1/2026/10/15/1200_half.jpg';

Camera rs(String id) => Camera(
      id: id, name: '$id パノラマ', category: 'scenic', prefecture: '00',
      feed: const Feed(type: FeedType.roundshot, url: _entry),
      operator: 'Zermatt Bergbahnen', attribution: '出典：Roundshot',
      sourcePageUrl: 'https://zermatt.roundshot.com/',
      lat: 46.0, lng: 7.7, coordAccuracy: CoordAccuracy.exact,
    );

CameraRepository newRepo() => CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    );

void main() {
  setUpAll(() => adDisposeDelay = Duration.zero);
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  setUp(() {
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
  });

  test('FeedType.parse: roundshot と未知の type', () {
    expect(FeedType.parse('roundshot'), FeedType.roundshot);
    // 旧アプリ相当: 未知の値は unknown（再生非対応・誘導表示）になる
    expect(FeedType.parse('no_such_type'), FeedType.unknown);
  });

  test('imageUrlFor: image_url があればそれ、無ければ feed.url', () {
    final repo = newRepo();
    final c = rs('r1');
    expect(repo.imageUrlFor(c), _entry);
    repo.status = StatusFile.fromJson({
      'statuses': {
        'r1': {'state': 'ok', 'image_url': _latest},
      },
    });
    expect(repo.imageUrlFor(c), _latest);
    expect(c.isVideo, isFalse);
    expect(c.isLiveVideo, isFalse);
  });

  testWidgets('詳細画面に静止画として出る（image_url 優先）', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final repo = newRepo();
    repo.status = StatusFile.fromJson({
      'statuses': {
        'r2': {'state': 'ok', 'image_url': _latest},
      },
    });
    final app = AppState(repo);
    await app.favorites.load();
    await tester.pumpWidget(testApp(DetailScreen(camera: rs('r2'), app: app)));
    await tester.pump();
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((n) => n.url)
        .toList();
    expect(urls, contains(_latest));
    expect(find.text('再生非対応'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
