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
    await tester.pumpWidget(testApp(FavoritesScreen(app: app)));
    expect(find.textContaining('お気に入りはまだありません'), findsOneWidget);
  });

  testWidgets('カード表示とリスト表示を切り替えられる', (tester) async {
    final app = await buildApp();
    app.repository.cameras = [cam('a', '渋谷カメラ'), cam('b', '雷門カメラ')];
    await app.toggleFavorite(app.repository.cameras.first);

    await tester.pumpWidget(testApp(FavoritesScreen(app: app)));
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

  testWidgets('並べ替え画面でドラッグした順が既定の並びとウィジェットの順になる', (tester) async {
    final app = await buildApp();
    app.repository.cameras = [cam('a', '渋谷カメラ'), cam('b', '雷門カメラ'), cam('c', '横浜カメラ')];
    for (final c in app.repository.cameras) {
      await app.toggleFavorite(c);
    }
    expect(app.favoriteCameras().map((c) => c.id), ['c', 'b', 'a'], reason: '登録が新しい順が初期値');

    await tester.pumpWidget(testApp(FavoritesScreen(app: app)));
    await tester.tap(find.byKey(const Key('favorites_reorder')));
    await tester.pumpAndSettle();
    expect(find.text('お気に入りを並べ替え'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);

    // 先頭（横浜）の取っ手を 2 行分下へ
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(3));
    final rowHeight = tester.getRect(find.byType(ListTile).first).height;
    await tester.timedDrag(handles.first, Offset(0, rowHeight * 2.6),
        const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(app.favorites.ordered, ['b', 'a', 'c']);
    expect(app.favoriteCameras().map((c) => c.id), ['b', 'a', 'c'], reason: 'ウィジェットもこの順');

    await tester.tap(find.byKey(const Key('favorites_reorder_done')));
    await tester.pumpAndSettle();
    expect(find.text('お気に入り（3）'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    final names = tester.widgetList<Text>(find.descendant(
        of: find.byType(ListTile), matching: find.byType(Text)))
        .map((t) => t.data)
        .where((t) => t != null && t.endsWith('カメラ'))
        .toList();
    expect(names, ['雷門カメラ', '渋谷カメラ', '横浜カメラ'], reason: '既定は自分で並べた順');
  });
}
