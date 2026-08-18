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
    final tmp = await Directory.systemTemp.createTemp('livecam_widget');
    addTearDown(() => tmp.delete(recursive: true));
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
