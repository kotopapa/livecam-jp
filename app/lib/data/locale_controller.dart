import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリの表示言語（1.4.0）。
///
/// - `ja`      … 日本語
/// - `ja-Hira` … やさしい日本語（BCP47 の ja-Hira。漢字を減らした平易な日本語）
/// - `en`      … English
/// - `zh-Hans` … 简体中文（中国語 簡体字。`Locale` は基底ロケールの `zh`）
/// - `zh-Hant` … 繁體中文（中国語 繁体字）
/// - `ko`      … 한국어
/// - `vi`      … Tiếng Việt
///
/// 「やさしい日本語」は独立した1言語として日本語・英語と並列に扱う（ユーザー決定
/// 事項。SPEC/docs/research_2026-09-01/i18n_languages.md 5章）。
///
/// 追加4言語の選定根拠は同調査の 4.3（在留＋訪日の合成カバー率で上位）。
/// 簡体字／繁体字は訪日客ではほぼ同数のため両方持つ（同 4.4）。
enum AppLanguage {
  ja('ja'),
  jaHira('ja-Hira'),
  en('en'),
  zhHans('zh-Hans'),
  zhHant('zh-Hant'),
  ko('ko'),
  vi('vi');

  const AppLanguage(this.tag);

  /// SharedPreferences に保存する識別子（BCP47 タグ）
  final String tag;

  Locale get locale => switch (this) {
        AppLanguage.ja => const Locale('ja'),
        AppLanguage.jaHira =>
          const Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
        AppLanguage.en => const Locale('en'),
        // 簡体字は **素の `zh`** を基底ロケールとして使う。gen-l10n は
        // script 付きロケールだけだと基底 ARB を要求するため（`app_zh.arb`）。
        // 端末が `zh-Hans` / `zh-CN` を要求してもここへ解決される
        AppLanguage.zhHans => const Locale('zh'),
        AppLanguage.zhHant =>
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        AppLanguage.ko => const Locale('ko'),
        AppLanguage.vi => const Locale('vi'),
      };

  static AppLanguage? fromTag(String? tag) {
    for (final l in AppLanguage.values) {
      if (l.tag == tag) return l;
    }
    return null;
  }

  /// 繁体字を使う地域（台湾・香港・マカオ）。script が無い `zh-TW` 等の判別に使う
  static const _hantRegions = {'TW', 'HK', 'MO'};

  /// 中国語ロケールを簡体字／繁体字に振り分ける。
  /// `zh-Hant` / `zh-TW` / `zh-HK` / `zh-MO` は繁体字、それ以外（`zh` 単独を含む）は簡体字
  static AppLanguage chineseVariantOf(Locale locale) =>
      locale.scriptCode == 'Hant' ||
              _hantRegions.contains(locale.countryCode?.toUpperCase())
          ? AppLanguage.zhHant
          : AppLanguage.zhHans;

  /// Locale から言語を引く（ja-Hira / zh-Hans / zh-Hant は scriptCode で判別する）
  static AppLanguage? fromLocale(Locale? locale) {
    if (locale == null) return null;
    switch (locale.languageCode) {
      case 'ja':
        return locale.scriptCode == 'Hira' ? AppLanguage.jaHira : AppLanguage.ja;
      case 'zh':
        return chineseVariantOf(locale);
      case 'ko':
        return AppLanguage.ko;
      case 'vi':
        return AppLanguage.vi;
    }
    return AppLanguage.en;
  }

  /// 端末の言語設定からの自動判定（初回起動時。強制の言語選択画面は出さない）。
  /// 日本語→ja、中国語→簡体字/繁体字、韓国語→ko、ベトナム語→vi、それ以外→en。
  /// やさしい日本語は自動選択しない（本人が選ぶもの）
  static AppLanguage fromDeviceLocales(List<Locale> locales) {
    for (final l in locales) {
      switch (l.languageCode) {
        case 'ja':
          return AppLanguage.ja;
        case 'zh':
          return chineseVariantOf(l);
        case 'ko':
          return AppLanguage.ko;
        case 'vi':
          return AppLanguage.vi;
      }
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
