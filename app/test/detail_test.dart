import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/favorites_store.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/detail_screen.dart';
import 'package:livecam_jp/util/geo.dart';
import 'package:flutter/material.dart';

Camera cam(String id, {double? lat, double? lng, FeedType type = FeedType.mlitRoadinfo}) =>
    Camera(
      id: id, name: '$idカメラ', category: 'road', prefecture: '38',
      feed: Feed(type: type, url: 'https://example.jp/page.html', cameraRef: 'X1'),
      operator: '国土交通省 四国地方整備局',
      attribution: '出典：国土交通省 四国地方整備局',
      sourcePageUrl: 'https://example.jp/page.html',
      lat: lat, lng: lng, coordAccuracy: CoordAccuracy.area,
    );

void main() {
  group('geo', () {
    test('距離計算と10km以内の近傍抽出', () {
      final origin = cam('o', lat: 35.0, lng: 139.0);
      final near = cam('near', lat: 35.05, lng: 139.0);   // 約5.6km
      final far = cam('far', lat: 35.5, lng: 139.0);      // 約55km
      expect(distanceMeters(35.0, 139.0, 35.05, 139.0), closeTo(5560, 100));
      final result = nearbyCameras(origin, [origin, near, far]);
      expect(result.map((r) => r.$1.id), ['near']);
    });
  });

  group('お気に入り', () {
    test('toggleで追加・削除され永続化される', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FavoritesStore();
      await store.load();
      expect(await store.toggle('cam-1'), isTrue);
      expect(store.contains('cam-1'), isTrue);
      expect(await store.toggle('cam-1'), isFalse);
      expect(store.contains('cam-1'), isFalse);
    });
  });

  group('詳細画面', () {
    testWidgets('免責・出典・位置未確定表示と更新ボタンのクールダウン', (tester) async {
      // ListViewの遅延ビルドで下部要素が未描画にならないよう縦長ビューポートにする
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      // testWidgets内の実I/O awaitはハングするためディレクトリ作成はしない
      final tmp = Directory(Directory.systemTemp.path);
      final app = AppState(CameraRepository(
        api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
        cache: CacheStore(tmp),
      ));
      await app.favorites.load();

      // mlit_roadinfo で status に image_url がない → フォールバック表示（ネットワーク不要）
      final camera = cam('c1', lat: 35.4, lng: 138.4);
      await tester.pumpWidget(MaterialApp(home: DetailScreen(camera: camera, app: app)));

      expect(find.textContaining('避難の判断は、水位情報・気象警報'), findsOneWidget);
      expect(find.text('出典'), findsOneWidget);
      expect(find.text('位置は広域の代表点'), findsOneWidget);
      expect(find.text('現在映像を取得できません'), findsOneWidget);

      // 手動更新→60秒クールダウンでボタンが無効化・秒表示になる
      expect(find.text('更新'), findsOneWidget);
      await tester.tap(find.text('更新'));
      await tester.pump();
      expect(find.text('更新'), findsNothing);
      expect(find.textContaining('秒'), findsWidgets);

      // 画面を破棄してクールダウンタイマーを確実に止める（実時計依存のため
      // pumpでは消化できない）
      await tester.pumpWidget(const SizedBox());
    });
  });
}
