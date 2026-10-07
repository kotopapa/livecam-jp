import 'dart:convert';
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
import 'package:livecam_jp/data/data_saver.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/models/manifest.dart';
import 'package:livecam_jp/models/status.dart';
import 'package:livecam_jp/ui/ad_banner.dart';
import 'package:livecam_jp/ui/detail_screen.dart';
import 'package:livecam_jp/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fake_google_maps_platform.dart';
import 'l10n_test_app.dart';

Camera cam(String id, {FeedType type = FeedType.mlitRoadinfo, String url = 'https://example.jp/p.html'}) =>
    Camera(
      id: id, name: '$idカメラ', category: 'road', prefecture: '38',
      feed: Feed(type: type, url: url, cameraRef: 'X1'),
      operator: '国土交通省', attribution: '出典：国土交通省',
      sourcePageUrl: 'https://example.jp/page.html',
      lat: 35.4, lng: 138.4, coordAccuracy: CoordAccuracy.exact,
    );

AppState newApp({MockClient? client}) => AppState(CameraRepository(
      api: ApiClient(
          client: client ?? MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));

void main() {
  setUpAll(() => adDisposeDelay = Duration.zero);
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  setUp(() {
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
  });

  group('resolveDataSaver', () {
    test('on/off は端末・警報にかかわらず固定', () {
      for (final low in [true, false]) {
        for (final warn in [true, false]) {
          expect(
              resolveDataSaver(
                  mode: DataSaverMode.on,
                  deviceLowData: low,
                  inSpecialWarningArea: warn),
              isTrue);
          expect(
              resolveDataSaver(
                  mode: DataSaverMode.off,
                  deviceLowData: low,
                  inSpecialWarningArea: warn),
              isFalse);
        }
      }
    });

    test('auto は端末の省データ設定か特別警報エリアのどちらかで入る', () {
      bool auto(bool low, bool warn) => resolveDataSaver(
          mode: DataSaverMode.auto,
          deviceLowData: low,
          inSpecialWarningArea: warn);
      expect(auto(false, false), isFalse);
      expect(auto(true, false), isTrue);
      expect(auto(false, true), isTrue);
      expect(auto(true, true), isTrue);
    });

    test('設定値の読み取りと間隔', () {
      expect(DataSaverMode.parse(null), DataSaverMode.auto);
      expect(DataSaverMode.parse('on'), DataSaverMode.on);
      expect(DataSaverMode.parse('???'), DataSaverMode.auto);
      expect(situationInterval(false), const Duration(minutes: 10));
      expect(situationInterval(true), const Duration(minutes: 30));
      expect(youtubeThumbnailUrl('abc'), 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
      expect(youtubeThumbnailUrl(null), isNull);
      expect(youtubeThumbnailUrl(''), isNull);
    });

    test('AppState.dataSaverActive: 特別警報エリアで auto が入る', () {
      final app = newApp();
      expect(app.dataSaverActive, isFalse);
      app.specialWarningActive = true;
      app.specialWarningPrefectures = const {'13'};
      app.viewerPrefecture = '13';
      expect(app.dataSaverActive, isTrue);
      app.dataSaverMode = DataSaverMode.off;
      expect(app.dataSaverActive, isFalse);
      app.dataSaverMode = DataSaverMode.auto;
      app.viewerPrefecture = '27'; // 県外
      expect(app.dataSaverActive, isFalse);
      app.deviceLowData = true;
      expect(app.dataSaverActive, isTrue);
    });
  });

  group('status_lite', () {
    test('default_state を持つ応答では、載っていないカメラは ok 扱い', () {
      final st = StatusFile.fromJson(jsonDecode('''
{"generated_at":"2026-10-07T00:00:00Z","default_state":"ok",
 "statuses":{"a":{"state":"error"},"b":{"state":"ok","image_url":"https://x/b.jpg"}}}
''') as Map<String, dynamic>);
      expect(st['a']!.state, CameraState.error);
      expect(st['b']!.imageUrl, 'https://x/b.jpg');
      expect(st['zzz']!.state, CameraState.ok);
      expect(st.statusOf('zzz')!.imageUrl, isNull);
    });

    test('従来の status.json（default_state なし）は載っていなければ null', () {
      final st = StatusFile.fromJson(
          jsonDecode('{"statuses":{"a":{"state":"ok"}}}') as Map<String, dynamic>);
      expect(st['zzz'], isNull);
    });

    test('manifest の status_lite を読み、無ければ null', () {
      final m = Manifest.fromJson({
        'status': {'url': '/v1/status.json'},
        'status_lite': {'version': 'v', 'url': '/v1/status_lite.json'},
      });
      expect(m.statusLiteUrl, '/v1/status_lite.json');
      expect(Manifest.fromJson({}).statusLiteUrl, isNull);
    });

    test('refresh は status_lite を取り（status.json は取らない）、cameras だけ先に反映できる', () async {
      final paths = <String>[];
      final client = MockClient((req) async {
        paths.add(req.url.path);
        String body;
        if (req.url.path.endsWith('manifest.json')) {
          body = '{"schema_version":1,"cameras":{"version":"v1","url":"/v1/cameras.json","count":1},'
              '"status":{"url":"/v1/status.json"},'
              '"status_lite":{"version":"v1","url":"/v1/status_lite.json"}}';
        } else if (req.url.path.endsWith('cameras.json')) {
          body = '{"version":"v1","cameras":[{"id":"k1","name":"k","lat":35.0,"lng":139.0,'
              '"coord_accuracy":"exact","category":"river","prefecture":"13",'
              '"feed":{"type":"still_image","url":"https://e.jp/1.jpg"},'
              '"operator":"x","source":{"attribution":"x"}}]}';
        } else if (req.url.path.endsWith('status_lite.json')) {
          body = '{"generated_at":"t","default_state":"ok","statuses":{}}';
        } else {
          return http.Response('no', 404);
        }
        return http.Response.bytes(utf8.encode(body), 200);
      });
      final tmp = await Directory.systemTemp.createTemp('saver_test');
      addTearDown(() => tmp.delete(recursive: true));
      final repo = CameraRepository(
          api: ApiClient(client: client, baseUri: Uri.parse('https://h.example/v1/')),
          cache: CacheStore(tmp));
      await repo.refreshCatalog();
      expect(repo.cameras.length, 1, reason: 'status を待たずに cameras が使える');
      expect(paths.any((p) => p.contains('status')), isFalse);
      await repo.refreshStatus();
      expect(paths.where((p) => p.endsWith('status_lite.json')).length, 1);
      expect(paths.any((p) => p.endsWith('/status.json')), isFalse);
      // lite に載っていないカメラも正常として地図に出る
      expect(repo.status['k1']!.state, CameraState.ok);
      expect(repo.displayableCameras().map((c) => c.id), ['k1']);
    });

    test('通信節約中は status を15分まで再取得しない', () async {
      var fetches = 0;
      final client = MockClient((req) async {
        String body;
        if (req.url.path.endsWith('manifest.json')) {
          body = '{"cameras":{"version":"v1","url":"/v1/cameras.json"},"status":{"url":"/v1/status.json"}}';
        } else if (req.url.path.endsWith('cameras.json')) {
          body = '{"version":"v1","cameras":[]}';
        } else {
          fetches++;
          body = '{"statuses":{}}';
        }
        return http.Response.bytes(utf8.encode(body), 200);
      });
      final tmp = await Directory.systemTemp.createTemp('saver_test2');
      addTearDown(() => tmp.delete(recursive: true));
      var t = DateTime.utc(2026, 10, 7, 1);
      final repo = CameraRepository(
          api: ApiClient(client: client, baseUri: Uri.parse('https://h.example/v1/')),
          cache: CacheStore(tmp, now: () => t),
          now: () => t);
      await repo.refresh(dataSaver: true);
      expect(fetches, 1);
      t = t.add(const Duration(minutes: 10));
      await repo.refresh(dataSaver: true);
      expect(fetches, 1, reason: '10分後は節約中なので取らない');
      await repo.refresh();
      expect(fetches, 2, reason: '通常なら5分で取る');
      t = t.add(const Duration(minutes: 16));
      await repo.refresh(dataSaver: true);
      expect(fetches, 3);
    });
  });

  group('画面', () {
    testWidgets('節約モードの詳細画面: チップが出て、時間が経っても自動更新しない', (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = newApp()..dataSaverMode = DataSaverMode.on;
      await app.favorites.load();
      await tester.pumpWidget(testApp(DetailScreen(camera: cam('c1'), app: app)));
      expect(find.text('通信節約中（自動更新オフ）'), findsOneWidget);
      // 手動更新は通常どおり使える
      expect(find.text('更新'), findsOneWidget);
      // 自動更新タイマーが無い: 長時間進めても保留中のタイマーは生じない
      await tester.pump(const Duration(minutes: 30));
      expect(tester.binding.transientCallbackCount, 0);

      // オフにするとチップが消える（画面は app の変更に追従する）
      await app.setDataSaverMode(DataSaverMode.off);
      await tester.pump();
      expect(find.text('通信節約中（自動更新オフ）'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('節約モードの YouTube は自動で開かず、タップ待ちの枠を出す', (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = newApp()..dataSaverMode = DataSaverMode.on;
      await app.favorites.load();
      final yt = cam('y1', type: FeedType.youtubeVideo, url: 'abcdefghijk');
      await tester.pumpWidget(testApp(DetailScreen(camera: yt, app: app)));
      expect(find.byKey(const ValueKey('youtube_tap_to_play')), findsOneWidget);
      expect(find.text('タップして再生'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('設定画面に通信節約モードの3択があり、選ぶと保存される', (tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = newApp();
      await tester.pumpWidget(testApp(SettingsScreen(
          app: app, localeController: LocaleController())));
      await tester.pump();
      expect(find.text('通信節約モード'), findsOneWidget);
      expect(find.textContaining('端末の省データ設定が有効なとき'), findsOneWidget);
      expect(find.text('自動'), findsOneWidget);
      expect(find.text('常にオン'), findsOneWidget);
      expect(find.text('常にオフ'), findsOneWidget);
      await tester.tap(find.text('常にオン'));
      await tester.pump();
      expect(app.dataSaverMode, DataSaverMode.on);
      expect(app.dataSaverActive, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
