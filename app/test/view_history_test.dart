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
import 'package:livecam_jp/data/view_history_store.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/view_history_screen.dart';

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
  await app.viewHistory.load();
  app.repository.cameras = [
    cam('a', '渋谷カメラ'),
    cam('b', '雷門カメラ'),
    cam('c', '見ていないカメラ'),
  ];
  return app;
}

void main() {
  test('ストア: 新しい順・1台削除・全削除が保存される', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ViewHistoryStore();
    await s.load();
    await s.record('a', at: DateTime(2026, 11, 20, 9));
    await s.record('b', at: DateTime(2026, 11, 21, 9));
    await s.record('a', at: DateTime(2026, 11, 22, 9));
    expect(s.recentIds, ['a', 'b']);
    expect(s.lastViewedAt('a'), DateTime(2026, 11, 22, 9));
    expect(s.totalCount('a'), 2);
    expect(s.lastViewedAt('zzz'), isNull);

    await s.remove('a');
    final reloaded = ViewHistoryStore();
    await reloaded.load();
    expect(reloaded.recentIds, ['b']);

    await reloaded.clear();
    final empty = ViewHistoryStore();
    await empty.load();
    expect(empty.recentIds, isEmpty);
    expect(empty.totalEvents, 0);
  });

  testWidgets('空のときは案内文', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(testApp(ViewHistoryScreen(app: app)));
    expect(find.textContaining('閲覧履歴はまだありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('view_history_clear')), findsNothing);
  });

  testWidgets('最後に見た順に並び、見ていないカメラは出ない', (tester) async {
    final app = await buildApp();
    await app.viewHistory.record('a', at: DateTime(2026, 11, 20, 9));
    await app.viewHistory.record('b', at: DateTime(2026, 11, 21, 9));
    await app.viewHistory.record('gone', at: DateTime(2026, 11, 22, 9));
    await tester.pumpWidget(testApp(ViewHistoryScreen(app: app)));
    expect(find.text('見ていないカメラ'), findsNothing);
    final yb = tester.getTopLeft(find.text('雷門カメラ')).dy;
    final ya = tester.getTopLeft(find.text('渋谷カメラ')).dy;
    expect(yb < ya, isTrue, reason: '新しく見たほうが上');
    expect(find.textContaining('1 回'), findsNWidgets(2));
  });

  testWidgets('横に払うと1台分を消す', (tester) async {
    final app = await buildApp();
    await app.viewHistory.record('a');
    await app.viewHistory.record('b');
    await tester.pumpWidget(testApp(ViewHistoryScreen(app: app)));
    await tester.drag(find.text('渋谷カメラ'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('渋谷カメラ'), findsNothing);
    expect(find.text('雷門カメラ'), findsOneWidget);
    expect(app.viewHistory.recentIds, ['b']);
  });

  testWidgets('すべて削除は確認してから消す', (tester) async {
    final app = await buildApp();
    await app.viewHistory.record('a');
    await tester.pumpWidget(testApp(ViewHistoryScreen(app: app)));
    await tester.tap(find.byKey(const ValueKey('view_history_clear')));
    await tester.pumpAndSettle();
    expect(find.text('閲覧履歴をすべて削除しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('view_history_clear_ok')));
    await tester.pumpAndSettle();
    expect(app.viewHistory.recentIds, isEmpty);
    expect(find.textContaining('閲覧履歴はまだありません'), findsOneWidget);
  });
}
