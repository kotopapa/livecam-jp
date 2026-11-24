import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/catalog_load_banner.dart';

AppState buildApp() {
  SharedPreferences.setMockInitialValues({});
  return AppState(CameraRepository(
    api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
    cache: CacheStore(Directory(Directory.systemTemp.path)),
  ));
}

void main() {
  test('台帳が空で、起動時の復元が済んでいるときだけ出す', () {
    final app = buildApp();
    expect(CatalogLoadBanner.shouldShow(app), isFalse); // 復元前
    app.initialized = true;
    expect(CatalogLoadBanner.shouldShow(app), isTrue);
    app.repository.cameras = [
      Camera(
        id: 'a', name: 'a', category: 'scenic', prefecture: '13',
        feed: const Feed(type: FeedType.mlitRoadinfo, url: 'u', cameraRef: 'r'),
        operator: 'o', attribution: 'x',
        lat: 35.0, lng: 139.0, coordAccuracy: CoordAccuracy.exact,
      ),
    ];
    expect(CatalogLoadBanner.shouldShow(app), isFalse);
  });

  testWidgets('取得中は読み込みの案内、失敗後は再試行ボタンを出す', (tester) async {
    final app = buildApp()..initialized = true;
    app.refreshing = true;
    await tester.pumpWidget(testApp(
      Scaffold(body: CatalogLoadBanner(app: app)),
    ));
    expect(find.text('カメラの情報を読み込んでいます…'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog_load_retry')), findsNothing);

    app.refreshing = false;
    await tester.pumpWidget(testApp(
      Scaffold(body: CatalogLoadBanner(app: app, key: UniqueKey())),
    ));
    expect(find.byKey(const ValueKey('catalog_load_retry')), findsOneWidget);
    expect(find.textContaining('読み込めませんでした'), findsOneWidget);
  });
}
