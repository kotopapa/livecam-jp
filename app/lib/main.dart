import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'data/api_client.dart';
import 'data/cache_store.dart';
import 'data/camera_repository.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final app = AppState(CameraRepository(
    api: ApiClient(),
    cache: CacheStore(dir),
  ));
  runApp(LiveCamApp(app: app));
  app.init(); // キャッシュ復元→バックグラウンド更新（待たずに起動する）
}

class LiveCamApp extends StatelessWidget {
  const LiveCamApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '全国ライブカメラ地図',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E6FD9)),
      home: HomeShell(app: app),
    );
  }
}
