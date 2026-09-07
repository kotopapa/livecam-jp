/// 利用状況の集計（Firebase Analytics / Google Analytics for Firebase）。
///
/// 目的は利用者数（DAU/MAU）・画面ごとの表示数・どの県やカテゴリのカメラが
/// 見られているかの把握。**個人を識別する情報・位置情報は送らない**
/// （プライバシーポリシー 3-4）。
///
/// - 画面遷移は名前付きルートを使っていないため自動計測が効かない。
///   各画面の initState から [screen] を明示的に呼ぶ
/// - デバッグビルドでは収集しない（Crashlytics と同じ方針）
/// - Firebase が初期化されていない環境（テスト・未対応プラットフォーム）では
///   すべて no-op になる
library;

import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/camera.dart';

class Analytics {
  Analytics._();

  static FirebaseAnalytics? _fa;

  /// Firebase.initializeApp の後に1回呼ぶ。[enabled] が false なら収集を止める
  static Future<void> init({required bool enabled}) async {
    try {
      final fa = FirebaseAnalytics.instance;
      await fa.setAnalyticsCollectionEnabled(enabled);
      _fa = enabled ? fa : null;
    } catch (_) {
      _fa = null;
    }
  }

  static bool get enabled => _fa != null;

  /// 画面表示（画面名は英小文字とアンダースコア）
  static void screen(String name) {
    final fa = _fa;
    if (fa == null) return;
    fa.logScreenView(screenName: name).catchError((_) {});
  }

  /// 任意イベント。値は Firebase の制約（名前40文字・値100文字）に収める
  static void event(String name, {Map<String, Object>? params}) {
    final fa = _fa;
    if (fa == null) return;
    fa.logEvent(name: name, parameters: params).catchError((_) {});
  }

  /// カメラ詳細を開いた。ID・カテゴリ・都道府県・配信形式だけを送る
  static void cameraView(Camera c) => event('camera_view', params: {
        'camera_id': c.id,
        'category': c.category,
        'prefecture': c.isWorld
            ? 'world'
            : (c.prefecture.isEmpty ? 'unknown' : c.prefecture),
        'feed_type': c.feed.type.name,
      });
}
