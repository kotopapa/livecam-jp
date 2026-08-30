import 'dart:ui' show PlatformDispatcher;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
// AppState名がアプリ本体のクラスと衝突するためshowで絞る
import 'package:google_mobile_ads/google_mobile_ads.dart' show MobileAds;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging, RemoteMessage;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'firebase_options.dart';
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'data/api_client.dart';
import 'data/cache_store.dart';
import 'data/camera_repository.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // 画像はカメラ静止画(数MB級)が主体のため、既定100MBでは端末メモリを
  // 圧迫しすぎる。デコード画像のキャッシュ上限を50MBに抑える
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  // ネイティブ起動画面はFlutter初回フレームで即消えるため、最低表示時間を保証する
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // 災害プッシュ通知用（対応プラットフォームのみ・失敗しても起動は続行）
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
      // クラッシュ検知（HANDOFF 2-8-3）。デバッグビルドでは送信しない
      if (!kDebugMode) {
        // Flutterフレームワークの例外（タイル画像の404等、アプリは継続する）は
        // 非致命として記録し、本当の強制終了と区別できるようにする
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    }
  } catch (_) {}
  final dir = await getApplicationSupportDirectory();
  final app = AppState(CameraRepository(
    api: ApiClient(),
    cache: CacheStore(dir),
  ));
  final onboardingDone = await OnboardingScreen.isDone();
  runApp(LiveCamApp(app: app, onboardingDone: onboardingDone));
  _hookNotificationTaps(app);
  app.init(); // キャッシュ復元→バックグラウンド更新（待たずに起動する）
  Future.delayed(
      const Duration(milliseconds: 1600), FlutterNativeSplash.remove);
  _initAds(); // 起動をブロックしない（ATT許可→AdMob初期化）
}

/// 広告の初期化。ATT（トラッキング許可）の回答を待ってからSDKを起動する。
/// 拒否されても広告は表示される（非パーソナライズ配信になるだけ）
Future<void> _initAds() async {
  try {
    // スプラッシュ消滅後に許可ダイアログを出す（起動直後は表示に失敗する）
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    await AppTrackingTransparency.requestTrackingAuthorization();
  } catch (_) {}
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
}

class LiveCamApp extends StatefulWidget {
  const LiveCamApp(
      {super.key, required this.app, required this.onboardingDone});

  final AppState app;
  final bool onboardingDone;

  @override
  State<LiveCamApp> createState() => _LiveCamAppState();
}

class _LiveCamAppState extends State<LiveCamApp>
    with WidgetsBindingObserver {
  late bool _onboardingDone = widget.onboardingDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンド移行時にデコード済み画像を全て解放する。
    // 画面は見えていないため副作用がなく、復帰時の再デコードが
    // 「溜まった分の上に乗る」形にならずメモリの土台を低く保てる
    if (state == AppLifecycleState.paused) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

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

/// プッシュ通知のタップでアプリが開かれたら災害速報タブへ移動する。
/// 送信側(tools/bosai_notify.py)は data.screen/tab を付けるが、無くても災害速報へ
void _hookNotificationTaps(AppState app) {
  String route(RemoteMessage m) {
    final screen = m.data['screen'] as String? ?? 'bosai';
    final tab = m.data['tab'] as String? ?? '';
    return tab.isEmpty ? screen : '$screen/$tab';
  }
  try {
    // 終了状態から通知タップで起動した場合
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) {
        app.navigationRequest.value = null; // 同一値でも通知されるように
        app.navigationRequest.value = route(m);
      }
    }).catchError((_) {});
    // バックグラウンドから通知タップで復帰した場合
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      app.navigationRequest.value = null;
      app.navigationRequest.value = route(m);
    });
  } catch (_) {}
}
