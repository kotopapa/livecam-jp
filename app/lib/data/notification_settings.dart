import 'dart:async';

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
///   danger-warning(-XX)  = 危険警報（警戒レベル4相当・2026新体系）。
///                          「レベル4から通知」を選んだ場合のみ追加購読する
/// 地震はレベルに応じて1トピックだけ、特別警報は全国1つか都道府県別の
/// いずれかを購読する（対象未選択=全国）。
class NotificationSettings {
  static const _quakeEnabledKey = 'notify_quake_enabled';
  static const _quakeLevelKey = 'notify_quake_level'; // '5-' | '5+' | '6-'
  static const _warningEnabledKey = 'notify_warning_enabled';
  static const _warningPrefsKey = 'notify_warning_prefs'; // JISコードのリスト
  static const _warningLevelKey = 'notify_warning_level'; // '5' | '4'

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

  /// '5' = 特別警報のみ（既定） / '4' = 危険警報（レベル4相当）から通知
  String warningLevel = '5';

  /// 特別警報の通知対象の都道府県JISコード。空 = 全国
  Set<String> warningPrefs = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    quakeEnabled = _prefs!.getBool(_quakeEnabledKey) ?? false;
    quakeLevel = _prefs!.getString(_quakeLevelKey) ?? '5-';
    warningEnabled = _prefs!.getBool(_warningEnabledKey) ?? false;
    warningLevel = _prefs!.getString(_warningLevelKey) ?? '5';
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

  static const _appliedTopicsKey = 'notify_applied_warning_topics';

  /// いま購読すべき警報トピックの集合
  Set<String> _desiredWarningTopics() {
    if (!warningEnabled) return {};
    final danger = warningLevel == '4';
    if (warningPrefs.isEmpty) {
      return {'special-warning', if (danger) 'danger-warning'};
    }
    return {
      for (final code in warningPrefs) ...{
        'special-warning-$code',
        if (danger) 'danger-warning-$code',
      }
    };
  }

  /// 特別警報トピックの購読反映。
  /// 全トピックへ一斉に購読/解除を投げるとFCMのレート制限に弾かれて
  /// 静かに失敗するため（実機で発生）、前回適用済みの集合を保存し、
  /// 差分のみを1件ずつ順番に適用する。購読側は自己修復のため毎回実行する
  Future<void> _applyWarningTopics() async {
    final fm = FirebaseMessaging.instance;
    final desired = _desiredWarningTopics();
    final applied =
        (_prefs?.getStringList(_appliedTopicsKey) ?? const []).toSet();
    final result = applied.toSet();
    for (final topic in applied.difference(desired)) {
      try {
        await fm.unsubscribeFromTopic(topic);
        result.remove(topic);
      } catch (_) {} // 失敗分は次回の差分適用で再試行される
    }
    for (final topic in desired) {
      try {
        await fm.subscribeToTopic(topic);
        result.add(topic);
      } catch (_) {}
    }
    await _prefs?.setStringList(_appliedTopicsKey, result.toList()..sort());
  }

  Future<void> setWarningLevel(String level) async {
    if (level != '5' && level != '4') return;
    warningLevel = level;
    await _prefs?.setString(_warningLevelKey, level);
    unawaited(_applyWarningTopics());
  }

  Future<bool> setWarningEnabled(bool value) async {
    if (value && !await _ensurePermission()) return false;
    warningEnabled = value;
    await _prefs?.setBool(_warningEnabledKey, value);
    unawaited(_applyWarningTopics());
    return true;
  }

  Future<void> setWarningPrefs(Set<String> prefs) async {
    warningPrefs = prefs.where(allPrefCodes.contains).toSet();
    await _prefs?.setStringList(
        _warningPrefsKey, warningPrefs.toList()..sort());
    unawaited(_applyWarningTopics());
  }

  /// 起動時に保存済み設定の購読を再適用する（購読漏れの自己修復）。
  /// 起動のたびに48件の解除を投げないよう、購読side のみ再適用する
  void reapply() {
    if (quakeEnabled) _applyQuakeTopics();
    if (warningEnabled) unawaited(_applyWarningTopics());
  }
}
