import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/main.dart';

void main() {
  testWidgets('アプリが起動して4タブのシェルが表示される', (tester) async {
    // testWidgets(fake async)内で実I/Oをawaitするとハングするため、
    // ディレクトリは作成せず既存パスを渡す（このテストではキャッシュ未使用）
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(CameraRepository(
      api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404))),
      cache: CacheStore(tmp),
    ));
    await tester.pumpWidget(LiveCamApp(app: app));
    await tester.pump();
    expect(find.text('地図'), findsOneWidget);
    expect(find.text('一覧'), findsOneWidget);
    expect(find.text('お気に入り'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });
}
