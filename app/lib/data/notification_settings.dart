import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 災害プッシュ通知の設定（FCMトピック購読の管理）。
///
/// トピック設計（送信側 tools/bosai_notify.py と対応）:
///   quake5    = 震度5弱以上で通知
///   quake5up  = 震度5強以上で通知
///   quake6low = 震度6弱以上で通知
///   special-warning = 特別警報の新規発表で通知
/// 地震はレベルに応じて1トピックだけ購読する。
class NotificationSettings {
  static const _quakeEnabledKey = 'notify_quake_enabled';
  static const _quakeLevelKey = 'notify_quake_level'; // '5-' | '5+' | '6-'
  static const _warningEnabledKey = 'notify_warning_enabled';

  static const quakeLevels = ['5-', '5+', '6-'];
  static const quakeLevelLabels = {
    '5-': '震度5弱以上',
    '5+': '震度5強以上',
    '6-': '震度6弱以上',
  };
  static const _levelTopics = {
    '5-': 'quake5',
    '5+': 'quake5up',
    '6-': 'quake6low',
  };

  bool quakeEnabled = false;
  String quakeLevel = '5-';
  bool warningEnabled = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    quakeEnabled = _prefs!.getBool(_quakeEnabledKey) ?? false;
    quakeLevel = _prefs!.getString(_quakeLevelKey) ?? '5-';
    warningEnabled = _prefs!.getBool(_warningEnabledKey) ?? false;
  }

  Future<bool> _ensurePermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _applyQuakeTopics() async {
    final fm = FirebaseMessaging.instance;
    for (final e in _levelTopics.entries) {
      final want = quakeEnabled && e.key == quakeLevel;
      if (want) {
        await fm.subscribeToTopic(e.value);
      } else {
        await fm.unsubscribeFromTopic(e.value);
      }
    }
  }

  /// 戻り値: 権限が拒否されて有効化できなかったとき false
  Future<bool> setQuakeEnabled(bool value) async {
    if (value && !await _ensurePermission()) return false;
    quakeEnabled = value;
    await _prefs?.setBool(_quakeEnabledKey, value);
    await _applyQuakeTopics();
    return true;
  }

  Future<void> setQuakeLevel(String level) async {
    if (!quakeLevels.contains(level)) return;
    quakeLevel = level;
    await _prefs?.setString(_quakeLevelKey, level);
    await _applyQuakeTopics();
  }

  Future<bool> setWarningEnabled(bool value) async {
    if (value && !await _ensurePermission()) return false;
    warningEnabled = value;
    await _prefs?.setBool(_warningEnabledKey, value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('special-warning');
    } else {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('special-warning');
    }
    return true;
  }
}
