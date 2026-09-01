/// 防災備蓄チェックリストのローカル通知（期限リマインド・点検日）。
///
/// ## 通知の設計
/// - **ローカル通知**（`flutter_local_notifications`）だけを使う。サーバー(FCM)は
///   使わない。端末内で完結するので通信も購読も要らない。
/// - iOSの通知許可は **この機能をONにしたときに初めて求める**。起動時には
///   求めない（プラグインの初期化では `request*Permission: false` を渡す）。
///   FCM(`NotificationSettings`)の許可要求とは同じ iOS の許可を共有するため、
///   どちらか一方で許可済みなら二重にダイアログは出ない。
/// - 通知IDは [reminderIdBase] 以降の専用レンジを使い、
///   このアプリの他の機能とぶつからないようにしている。
///
/// ## 時刻の扱い（docs/time_audit_2026-09-01.md の方針）
/// 期限は「JSTの壁時計の日付」（時刻を持たない素のDateTime）として保存する。
/// 通知の予約だけは絶対時刻が要るので、`Asia/Tokyo` のタイムゾーンを明示して
/// `TZDateTime` に変換する（壁時計と絶対時刻をコード上で混ぜない）。
library;

import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../util/jst.dart';
import 'stockpile.dart';

/// 通知の種類
enum ReminderKind { expiry, inspection }

/// 期限リマインドの対象1件
class ReminderItem {
  const ReminderItem({this.itemId, this.customTitle, required this.expiry});

  /// 既定品目のID（カスタム項目は null）
  final String? itemId;

  /// カスタム項目の名称（既定品目は null）
  final String? customTitle;

  /// 消費期限（JSTの壁計の日付）
  final DateTime expiry;
}

/// 予約する1件の通知（表示文言は持たない＝UI層でl10n解決する）。
///
/// 期限リマインドは**通知日が同じ品目を1通にまとめる**（[items]）。
/// [itemId] [customTitle] [expiry] は先頭の品目の値（後方互換）
class StockpileReminder {
  const StockpileReminder({
    required this.id,
    required this.kind,
    required this.at,
    this.itemId,
    this.customTitle,
    this.expiry,
    this.items = const [],
  });

  /// 通知ID（[reminderIdBase] 以降）
  final int id;
  final ReminderKind kind;

  /// 通知する日時（**JSTの壁時計**。素のDateTime）
  final DateTime at;

  /// 期限リマインドの対象（既定品目のID。カスタム項目は null）
  final String? itemId;

  /// カスタム項目の名称（既定品目は null）
  final String? customTitle;

  /// 対象の消費期限（JSTの壁時計の日付）
  final DateTime? expiry;

  /// この通知でまとめて知らせる品目（期限リマインドのみ。通知日順・期限順）
  final List<ReminderItem> items;
}

/// 通知IDのレンジ先頭（7100〜7199を使う）
const int reminderIdBase = 7100;

/// 通知する時刻（JSTの壁時計・9時）
const int reminderHour = 9;

/// iOSの保留通知は64件が上限。余裕を見て期限リマインドは40件までにする
const int maxExpiryReminders = 40;

/// 予約すべき通知の一覧を作る（純関数。テスト対象）。
///
/// [now] は **JSTの壁時計**。過ぎた日時は予約しない。
List<StockpileReminder> buildReminders(
  StockpileState state, {
  required DateTime now,
}) {
  final wallNow = asWallClock(now);
  final out = <StockpileReminder>[];

  if (state.inspectionReminderEnabled) {
    var id = reminderIdBase;
    for (final md in state.inspectionDays) {
      final at = nextInspectionDate(md, wallNow);
      if (at == null) continue;
      out.add(
        StockpileReminder(id: id++, kind: ReminderKind.inspection, at: at),
      );
    }
  }

  if (state.expiryReminderEnabled) {
    final dated = [for (final e in state.datedEntries) e]
      ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
    // 通知日（期限の1か月前）が同じ品目は1通にまとめる
    final byDay = <DateTime, List<ReminderItem>>{};
    for (final e in dated) {
      final noticeDay = expiryReminderDate(e.expiry!);
      final at = DateTime(
        noticeDay.year,
        noticeDay.month,
        noticeDay.day,
        reminderHour,
      );
      if (!at.isAfter(wallNow)) continue; // 過ぎている分は予約しない
      byDay
          .putIfAbsent(at, () => [])
          .add(
            ReminderItem(
              itemId: e.isCustom ? null : e.id,
              customTitle: e.customTitle,
              expiry: e.expiry!,
            ),
          );
    }
    var id = reminderIdBase + 10;
    var count = 0;
    for (final day in byDay.keys.toList()..sort()) {
      final items = byDay[day]!;
      out.add(
        StockpileReminder(
          id: id++,
          kind: ReminderKind.expiry,
          at: day,
          itemId: items.first.itemId,
          customTitle: items.first.customTitle,
          expiry: items.first.expiry,
          items: items,
        ),
      );
      if (++count >= maxExpiryReminders) break;
    }
  }
  return out;
}

/// `MM-dd` の次の到来日（[reminderHour] 時・JSTの壁時計）。不正な値は null
DateTime? nextInspectionDate(String monthDay, DateTime now) {
  final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(monthDay);
  if (m == null) return null;
  final mo = int.parse(m.group(1)!);
  final d = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final wallNow = asWallClock(now);
  var at = DateTime(wallNow.year, mo, d, reminderHour);
  if (at.month != mo || at.day != d) return null; // 2月30日など
  if (!at.isAfter(wallNow)) {
    at = DateTime(wallNow.year + 1, mo, d, reminderHour);
  }
  return at;
}

/// 通知の文言（UI層でl10nから作って渡す）
typedef ReminderText = ({String title, String body});

/// `flutter_local_notifications` への薄いラッパ。
///
/// テスト（プラグイン無し）でも `import` できるよう、プラグイン呼び出しは
/// すべてこのクラスの内部に閉じ込め、失敗しても例外を投げない。
class StockpileReminderService {
  StockpileReminderService();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Androidの通知チャンネル（防災の緊急通知とは別チャンネルにする）
  static const _androidChannelId = 'stockpile_reminder';
  static const _androidChannelName = 'Stockpile reminders';

  /// プラグインの初期化。**許可は求めない**（起動時にダイアログを出さない）。
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // 期限は「日本時間の日付」で登録される値なので、予約も日本時間で行う
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // ここでは絶対に許可を求めない（FCMの許可要求とも競合させない）
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// この機能をONにしたときだけ呼ぶ通知許可の要求。
  /// 戻り値 false = 許可されなかった（画面側で案内を出す）。
  Future<bool> requestPermission() async {
    await ensureInitialized();
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// 予約をすべて作り直す（このアプリの備蓄用IDレンジだけを消す）。
  ///
  /// [text] は通知の種類ごとの文言を返すコールバック（UI層でl10n解決する）。
  Future<void> reschedule(
    StockpileState state, {
    required ReminderText Function(StockpileReminder) text,
    DateTime? now,
  }) async {
    try {
      await ensureInitialized();
      for (var id = reminderIdBase; id < reminderIdBase + 100; id++) {
        await _plugin.cancel(id: id);
      }
      final reminders = buildReminders(state, now: now ?? jstNow());
      for (final r in reminders) {
        final t = text(r);
        await _plugin.zonedSchedule(
          id: r.id,
          title: t.title,
          body: t.body,
          scheduledDate: tz.TZDateTime(
            tz.local,
            r.at.year,
            r.at.month,
            r.at.day,
            r.at.hour,
          ),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // 通知が使えない端末・権限拒否でも画面は動き続ける
    }
  }

  /// 予約をすべて取り消す（機能をOFFにしたとき）
  Future<void> cancelAll() async {
    try {
      await ensureInitialized();
      for (var id = reminderIdBase; id < reminderIdBase + 100; id++) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {}
  }
}
