import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/favorites_screen.dart';

Camera cam(String id, String name) => Camera(
      id: id, name: name, category: 'scenic', prefecture: '13',
      // imageUrl未解決の経路（mlit_roadinfo+status無し）でネットワーク画像を避ける
      feed: const Feed(type: FeedType.mlitRoadinfo, url: 'u', cameraRef: 'r'),
      operator: 'テスト運営者', attribution: 'x',
      lat: 35.0, lng: 139.0, coordAccuracy: CoordAccuracy.exact,
    );

Future<AppState> buildApp() async {
  SharedPreferences.setMockInitialValues({});
  final app = AppState(CameraRepository(
    api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
    cache: CacheStore(Directory(Directory.systemTemp.path)),
  ));
  await app.favorites.load();
  return app;
}

void main() {
  testWidgets('空のときは案内文を表示する', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(MaterialApp(home: FavoritesScreen(app: app)));
    expect(find.textContaining('お気に入りはまだありません'), findsOneWidget);
  });

  testWidgets('カード表示とリスト表示を切り替えられる', (tester) async {
    final app = await buildApp();
    app.repository.cameras = [cam('a', '渋谷カメラ'), cam('b', '雷門カメラ')];
    await app.toggleFavorite(app.repository.cameras.first);

    await tester.pumpWidget(MaterialApp(home: FavoritesScreen(app: app)));
    expect(find.text('お気に入り（1）'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget, reason: '初期はカード表示');
    expect(find.text('渋谷カメラ'), findsOneWidget);
    expect(find.text('雷門カメラ'), findsNothing, reason: 'お気に入り以外は出ない');

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    // フィルタチップの横ListViewが常設のため、縦リスト切替でListViewは2つになる
    expect(find.byType(ListView), findsNWidgets(2), reason: 'リスト表示へ切替');
    expect(find.text('渋谷カメラ'), findsOneWidget);

    // リストの★で解除できる
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();
    expect(find.textContaining('お気に入りはまだありません'), findsOneWidget);
  });
}
