import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/l10n/l10n.dart';
import 'package:livecam_jp/main.dart' show resolveAppLocale;
import 'package:livecam_jp/util/prefectures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';

const _jaHira = Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira');

/// テスト中に AppLocalizations を1つ取り出す
Future<AppLocalizations> _load(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(testApp(
      Builder(builder: (context) {
        l10n = context.l10n;
        return const SizedBox.shrink();
      }),
      locale: locale));
  return l10n;
}

void main() {
  group('AppLanguage', () {
    test('タグとの相互変換', () {
      expect(AppLanguage.fromTag('ja'), AppLanguage.ja);
      expect(AppLanguage.fromTag('ja-Hira'), AppLanguage.jaHira);
      expect(AppLanguage.fromTag('en'), AppLanguage.en);
      expect(AppLanguage.fromTag('fr'), isNull);
      expect(AppLanguage.fromTag(null), isNull);
    });

    test('Locale との対応（やさしい日本語は scriptCode=Hira）', () {
      expect(AppLanguage.jaHira.locale, _jaHira);
      expect(AppLanguage.fromLocale(_jaHira), AppLanguage.jaHira);
      expect(AppLanguage.fromLocale(const Locale('ja')), AppLanguage.ja);
      expect(AppLanguage.fromLocale(const Locale('ko')), AppLanguage.en);
    });

    test('端末言語からの自動判定: 日本語→ja / それ以外→en', () {
      expect(AppLanguage.fromDeviceLocales([const Locale('ja', 'JP')]),
          AppLanguage.ja);
      expect(AppLanguage.fromDeviceLocales([const Locale('vi')]),
          AppLanguage.en);
      expect(
          AppLanguage.fromDeviceLocales(
              [const Locale('zh', 'CN'), const Locale('ja')]),
          AppLanguage.en,
          reason: '先頭の希望言語を優先する');
      expect(AppLanguage.fromDeviceLocales(const []), AppLanguage.ja);
    });

    test('やさしい日本語は自動選択しない（本人が選ぶもの）', () {
      expect(AppLanguage.fromDeviceLocales([_jaHira]), AppLanguage.ja);
    });
  });

  group('localeResolutionCallback', () {
    test('ja系は日本語、ja-Hira はやさしい日本語、それ以外は英語', () {
      final supported = AppLocalizations.supportedLocales;
      expect(resolveAppLocale(const Locale('ja', 'JP'), supported),
          const Locale('ja'));
      expect(resolveAppLocale(_jaHira, supported), _jaHira);
      expect(resolveAppLocale(const Locale('pt', 'BR'), supported),
          const Locale('en'));
      expect(resolveAppLocale(null, supported), const Locale('ja'));
    });
  });

  group('LocaleController', () {
    test('保存されていなければ端末言語から自動判定（isExplicit=false）', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await LocaleController.load();
      expect(c.isExplicit, isFalse);
    });

    test('選択は保存され、次回起動で復元される', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await LocaleController.load();
      var notified = 0;
      c.addListener(() => notified++);
      await c.setLanguage(AppLanguage.jaHira);
      expect(notified, 1);
      expect(c.language, AppLanguage.jaHira);
      expect(c.locale, _jaHira);
      expect(c.isExplicit, isTrue);

      final restored = await LocaleController.load();
      expect(restored.language, AppLanguage.jaHira);
      expect(restored.isExplicit, isTrue);
    });

    test('followSystem で保存を消して端末言語に戻る', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await LocaleController.load();
      await c.setLanguage(AppLanguage.en);
      await c.followSystem();
      expect(c.isExplicit, isFalse);
      final restored = await LocaleController.load();
      expect(restored.isExplicit, isFalse);
    });
  });

  group('ARB', () {
    final dir = Directory('lib/l10n');
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('${dir.path}/$name').readAsStringSync())
            as Map<String, dynamic>;

    test('3ロケールでキーの欠落が無い', () {
      final ja = read('app_ja.arb');
      final hira = read('app_ja_Hira.arb');
      final en = read('app_en.arb');
      bool isKey(String k) => !k.startsWith('@');
      final jaKeys = ja.keys.where(isKey).toSet();
      expect(jaKeys, isNotEmpty);
      expect(jaKeys.difference(hira.keys.where(isKey).toSet()), isEmpty,
          reason: 'やさしい日本語に未翻訳のキーがある');
      expect(jaKeys.difference(en.keys.where(isKey).toSet()), isEmpty,
          reason: '英語に未翻訳のキーがある');
      expect(hira.keys.where(isKey).toSet().difference(jaKeys), isEmpty);
      expect(en.keys.where(isKey).toSet().difference(jaKeys), isEmpty);
    });

    test('空文字の訳が無い', () {
      for (final name in ['app_ja.arb', 'app_ja_Hira.arb', 'app_en.arb']) {
        final arb = read(name);
        for (final e in arb.entries) {
          if (e.key.startsWith('@')) continue;
          expect((e.value as String).trim(), isNotEmpty,
              reason: '$name の ${e.key} が空');
        }
      }
    });
  });

  group('表示名の解決', () {
    testWidgets('都道府県47件が3ロケールすべてで解決できる', (tester) async {
      for (final locale in [const Locale('ja'), _jaHira, const Locale('en')]) {
        final l10n = await _load(tester, locale);
        for (final code in prefectureNames.keys) {
          final name = prefectureNameOf(l10n, code);
          expect(name, isNotEmpty);
          expect(name, isNot(code), reason: '$locale の $code が未定義');
        }
      }
    });

    testWidgets('カテゴリ9種が英語で翻訳されている', (tester) async {
      final l10n = await _load(tester, const Locale('en'));
      expect(categoryLabelOf(l10n, 'river'), 'Rivers');
      expect(categoryLabelOf(l10n, 'road'), 'Roads');
      expect(categoryLabelOf(l10n, 'unknown-key'), 'Other');
    });

    testWidgets('警報・注意報名は気象庁 多言語辞書の対訳を使う', (tester) async {
      final l10n = await _load(tester, const Locale('en'));
      expect(warningNameOf(l10n, '04'), 'Flood Warning');
      expect(warningNameOf(l10n, '33'), 'Heavy Rain Emergency Warning');
      expect(warningNameOf(l10n, '49'), 'Landslide Urgent Warning');
      expect(warningNameOf(l10n, '99'), isNull);
      expect(advisoryNameOf(l10n, '14'), 'Thunderstorm Advisory');
      expect(advisoryNameOf(l10n, '99'), isNull);
      expect(intensityLabelOf(l10n, '5-'), '5-lower');
      expect(intensityLabelOf(l10n, '6強'), '6-upper');
    });

    testWidgets('やさしい日本語は未翻訳キーがあれば日本語へフォールバックする',
        (tester) async {
      final ja = await _load(tester, const Locale('ja'));
      final hira = await _load(tester, _jaHira);
      // ja_Hira は AppLocalizationsJa を継承するため、辞書に無い語も落ちない
      expect(hira.localeName, 'ja_Hira');
      expect(hira, isA<AppLocalizations>());
      // 固有名詞（都道府県）は日本語と同じ表記を保つ
      expect(prefectureNameOf(hira, '13'), prefectureNameOf(ja, '13'));
      // 平易化された文言は日本語と異なる
      expect(hira.tabBosai, isNot(ja.tabBosai));
    });

    testWidgets('言語ごとに免責文が切り替わる（日本語が正文である旨も出せる）',
        (tester) async {
      final ja = await _load(tester, const Locale('ja'));
      final en = await _load(tester, const Locale('en'));
      expect(ja.disclaimerText, contains('避難の判断'));
      expect(en.disclaimerText, contains('evacuate'));
      expect(en.legalJapaneseAuthoritative, contains('Japanese'));
    });
  });
}
