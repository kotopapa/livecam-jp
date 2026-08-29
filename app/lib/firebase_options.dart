import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase接続設定（GoogleService-Info.plist の値を手動転記）。
/// 現状はiOSのみ。Android版を出すときはFirebaseコンソールでAndroidアプリを
/// 追加し、ここに追記する。
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (Platform.isIOS) return ios;
    if (Platform.isAndroid) return android;
    return null; // 未対応プラットフォームでは通知機能を無効化
  }

  /// Android (Firebase コンソール: 全国ライブカメラ地図 (Android)、2026-08-30 登録)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIhg5MtaGbpzrEcCMZBfcJkveCYaV72Lk',
    appId: '1:916091196031:android:cdcd9f54815ca7deeee54a',
    messagingSenderId: '916091196031',
    projectId: 'livecam-jp',
    storageBucket: 'livecam-jp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQvvQmFKYWd_gXyC5ur6oqGmmbq6nel-o',
    appId: '1:916091196031:ios:bb9040e935f9d409eee54a',
    messagingSenderId: '916091196031',
    projectId: 'livecam-jp',
    storageBucket: 'livecam-jp.firebasestorage.app',
    iosBundleId: 'jp.livecam.livecamJp',
  );
}
