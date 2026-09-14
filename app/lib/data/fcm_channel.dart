/// Android の FCM 用通知チャンネル。
///
/// Android 8 以降は通知チャンネルをアプリ側で事前に作る必要がある。
/// AndroidManifest の `default_notification_channel_id` に `bosai` を指定して
/// いるが、チャンネル自体が無いと FCM は予備の「その他」チャンネル（既定の重要度。
/// 画面上部にポップアップしない）に出してしまう。災害通知なので重要度「高」で作る。
/// サーバー側（tools/bosai_notify.py）も `android.notification.channel_id: bosai` を
/// 付けて送る。iOS では何もしない
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmChannel {
  FcmChannel._();

  /// マニフェストの default_notification_channel_id と bosai_notify.py の
  /// channel_id に合わせる
  static const String id = 'bosai';

  /// チャンネル名・説明は端末の「設定 → 通知」に出る。多言語化しない
  /// （BuildContext を持たない起動時に作るため）
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    id,
    '災害通知',
    description: '特別警報・危険警報・震度5弱以上の地震の速報',
    importance: Importance.max,
  );

  /// 起動時に1回呼ぶ。既に存在するチャンネルは重要度など利用者の変更を保ったまま
  /// 上書きされない（Android の仕様）
  static Future<void> ensure() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
    } catch (_) {
      // 作れなくても通知自体は予備チャンネルで届く
    }
  }
}
