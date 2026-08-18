import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'data/api_client.dart';
import 'data/cache_store.dart';
import 'data/camera_repository.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final app = AppState(CameraRepository(
    api: ApiClient(),
    cache: CacheStore(dir),
  ));
  final onboardingDone = await OnboardingScreen.isDone();
  runApp(LiveCamApp(app: app, onboardingDone: onboardingDone));
  app.init(); // キャッシュ復元→バックグラウンド更新（待たずに起動する）
}

class LiveCamApp extends StatefulWidget {
  const LiveCamApp(
      {super.key, required this.app, required this.onboardingDone});

  final AppState app;
  final bool onboardingDone;

  @override
  State<LiveCamApp> createState() => _LiveCamAppState();
}

class _LiveCamAppState extends State<LiveCamApp> {
  late bool _onboardingDone = widget.onboardingDone;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '全国ライブカメラ地図',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E6FD9)),
      home: _onboardingDone
          ? HomeShell(app: widget.app)
          : OnboardingScreen(
              onDone: () => setState(() => _onboardingDone = true)),
    );
  }
}
