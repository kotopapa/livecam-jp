import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 災害プッシュ通知の設定（FCMトピック購読の管理）。
///
/// トピック設計（送信側 tools/bosai_notify.py と対応）:
///   quake5    = 震度5弱以上で通知
///   quake5up  = 震度5強以上で通知
///   quake6low = 震度6弱以上で通知
///   special-warning      = 特別警報の新規発表で通知（全国）
///   special-warning-`<XX>` = 特別警報・都道府県別（XXはJISコード01〜47）
/// 地震はレベルに応じて1トピックだけ、特別警報は全国1つか都道府県別の
/// いずれかを購読する（対象未選択=全国）。
class NotificationSettings {
  static const _quakeEnabledKey = 'notify_quake_enabled';
  static const _quakeLevelKey = 'notify_quake_level'; // '5-' | '5+' | '6-'
  static const _warningEnabledKey = 'notify_warning_enabled';
  static const _warningPrefsKey = 'notify_warning_prefs'; // JISコードのリスト

  static final List<String> allPrefCodes = [
    for (var i = 1; i <= 47; i++) i.toString().padLeft(2, '0')
  ];

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

  /// 特別警報の通知対象の都道府県JISコード。空 = 全国
  Set<String> warningPrefs = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    quakeEnabled = _prefs!.getBool(_quakeEnabledKey) ?? false;
    quakeLevel = _prefs!.getString(_quakeLevelKey) ?? '5-';
    warningEnabled = _prefs!.getBool(_warningEnabledKey) ?? false;
    warningPrefs =
        (_prefs!.getStringList(_warningPrefsKey) ?? const []).toSet();
  }

  Future<bool> _ensurePermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// トピック購読の反映。APNsトークン待ちで長時間かかることがあるため
  /// バックグラウンドで実行する（UIをブロックしない）
  void _applyQuakeTopics() {
    final fm = FirebaseMessaging.instance;
    for (final e in _levelTopics.entries) {
      final want = quakeEnabled && e.key == quakeLevel;
      final f = want
          ? fm.subscribeToTopic(e.value)
          : fm.unsubscribeFromTopic(e.value);
      f.catchError((_) {}); // 失敗時は次回起動/変更時に再適用される
    }
  }

  /// 戻り値: 権限が拒否されて有効化できなかったとき false
  Future<bool> setQuakeEnabled(bool value) async {
    if (value && !await _ensurePermission()) return false;
    quakeEnabled = value;
    await _prefs?.setBool(_quakeEnabledKey, value);
    _applyQuakeTopics();
    return true;
  }

  Future<void> setQuakeLevel(String level) async {
    if (!quakeLevels.contains(level)) return;
    quakeLevel = level;
    await _prefs?.setString(_quakeLevelKey, level);
    _applyQuakeTopics();
  }

  /// 特別警報トピックの購読反映。対象未選択なら全国トピック、
  /// 選択ありなら都道府県別トピックを購読し、それ以外は解除する
  void _applyWarningTopics({bool unsubscribeOthers = true}) {
    final fm = FirebaseMessaging.instance;
    final wantNational = warningEnabled && warningPrefs.isEmpty;
    (wantNational
            ? fm.subscribeToTopic('special-warning')
            : fm.unsubscribeFromTopic('special-warning'))
        .catchError((_) {});
    for (final code in allPrefCodes) {
      final want = warningEnabled && warningPrefs.contains(code);
      if (!want && !unsubscribeOthers) continue;
      (want
              ? fm.subscribeToTopic('special-warning-$code')
              : fm.unsubscribeFromTopic('special-warning-$code'))
          .catchError((_) {});
    }
  }

  Future<bool> setWarningEnabled(bool value) async {
    if (value && !await _ensurePermission()) return false;
    warningEnabled = value;
    await _prefs?.setBool(_warningEnabledKey, value);
    _applyWarningTopics();
    return true;
  }

  Future<void> setWarningPrefs(Set<String> prefs) async {
    warningPrefs = prefs.where(allPrefCodes.contains).toSet();
    await _prefs?.setStringList(
        _warningPrefsKey, warningPrefs.toList()..sort());
    _applyWarningTopics();
  }

  /// 起動時に保存済み設定の購読を再適用する（購読漏れの自己修復）。
  /// 起動のたびに48件の解除を投げないよう、購読side のみ再適用する
  void reapply() {
    if (quakeEnabled) _applyQuakeTopics();
    if (warningEnabled) _applyWarningTopics(unsubscribeOthers: false);
  }
}
