import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリの表示言語（1.4.0）。
///
/// - `ja`      … 日本語
/// - `ja-Hira` … やさしい日本語（BCP47 の ja-Hira。漢字を減らした平易な日本語）
/// - `en`      … English
///
/// 「やさしい日本語」は独立した1言語として日本語・英語と並列に扱う（ユーザー決定
/// 事項。SPEC/docs/research_2026-09-01/i18n_languages.md 5章）。
enum AppLanguage {
  ja('ja'),
  jaHira('ja-Hira'),
  en('en');

  const AppLanguage(this.tag);

  /// SharedPreferences に保存する識別子（BCP47 タグ）
  final String tag;

  Locale get locale => switch (this) {
        AppLanguage.ja => const Locale('ja'),
        AppLanguage.jaHira =>
          const Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
        AppLanguage.en => const Locale('en'),
      };

  static AppLanguage? fromTag(String? tag) {
    for (final l in AppLanguage.values) {
      if (l.tag == tag) return l;
    }
    return null;
  }

  /// Locale から言語を引く（ja-Hira は scriptCode で判別する）
  static AppLanguage? fromLocale(Locale? locale) {
    if (locale == null) return null;
    if (locale.languageCode == 'ja') {
      return locale.scriptCode == 'Hira' ? AppLanguage.jaHira : AppLanguage.ja;
    }
    return AppLanguage.en;
  }

  /// 端末の言語設定からの自動判定（初回起動時。強制の言語選択画面は出さない）。
  /// 日本語→ja、それ以外→en。やさしい日本語は自動選択しない（本人が選ぶもの）
  static AppLanguage fromDeviceLocales(List<Locale> locales) {
    for (final l in locales) {
      if (l.languageCode == 'ja') return AppLanguage.ja;
      if (l.languageCode.isNotEmpty) return AppLanguage.en;
    }
    return AppLanguage.ja;
  }
}

/// 表示言語の保持と永続化。MaterialApp の `locale` に流す。
class LocaleController extends ChangeNotifier {
  LocaleController({AppLanguage? initial, this.isExplicit = false})
      : _language = initial ?? _detectFromDevice();

  static const prefsKey = 'app_language_v1';

  AppLanguage _language;

  /// ユーザーが明示的に選んだか（false = 端末の言語設定から自動判定した状態）
  bool isExplicit;

  /// 現在の表示言語
  AppLanguage get language => _language;

  /// MaterialApp に渡す Locale
  Locale get locale => _language.locale;

  static AppLanguage _detectFromDevice() =>
      AppLanguage.fromDeviceLocales(PlatformDispatcher.instance.locales);

  /// 起動時の復元。保存が無ければ端末の言語設定から自動判定する
  static Future<LocaleController> load() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(prefsKey);
    } catch (_) {
      // テスト環境等で読めない場合は端末言語にフォールバックする
    }
    final lang = AppLanguage.fromTag(saved);
    return LocaleController(
        initial: lang ?? _detectFromDevice(), isExplicit: lang != null);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language && isExplicit) return;
    _language = language;
    isExplicit = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, language.tag);
    } catch (_) {
      // 保存に失敗しても当該セッションの表示は切り替わっている
    }
  }

  /// 保存を消して端末の言語設定に戻す（設定画面の「端末の設定に合わせる」）
  Future<void> followSystem() async {
    _language = _detectFromDevice();
    isExplicit = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (_) {}
  }
}
