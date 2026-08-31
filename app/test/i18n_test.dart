import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/data/facility_layers.dart';
import 'package:livecam_jp/data/heat_alert.dart';
import 'package:livecam_jp/data/shelter_layers.dart';
import 'package:livecam_jp/data/wbgt.dart';
import 'package:livecam_jp/l10n/l10n.dart';
import 'package:livecam_jp/main.dart' show resolveAppLocale;
import 'package:livecam_jp/util/prefectures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';

const _jaHira = Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira');
const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// 端末から来る「簡体字の要求」（アプリ側は基底ロケール `zh` へ解決する）
const _zhHansRequest =
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

/// 簡体字の実ロケール。gen-l10n が script 付きだけの言語に基底ARBを要求するため、
/// 簡体字は素の `zh`（`app_zh.arb`）を基底ロケールとして使っている
const _zhHans = Locale('zh');

/// 対応する全ロケール（テストの網羅用）
const _allLocales = [
  Locale('ja'),
  _jaHira,
  Locale('en'),
  _zhHans,
  _zhHant,
  Locale('ko'),
  Locale('vi'),
];

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
      expect(AppLanguage.fromTag('zh-Hans'), AppLanguage.zhHans);
      expect(AppLanguage.fromTag('zh-Hant'), AppLanguage.zhHant);
      expect(AppLanguage.fromTag('ko'), AppLanguage.ko);
      expect(AppLanguage.fromTag('vi'), AppLanguage.vi);
      expect(AppLanguage.fromTag('fr'), isNull);
      expect(AppLanguage.fromTag(null), isNull);
    });

    test('7言語すべてが一意のタグと Locale を持つ', () {
      expect(AppLanguage.values.length, 7);
      expect(AppLanguage.values.map((l) => l.tag).toSet().length, 7);
      expect(AppLanguage.values.map((l) => l.locale).toSet().length, 7);
      // 選べる7言語と gen-l10n の supportedLocales は一致する
      expect(AppLanguage.values.map((l) => l.locale).toSet(),
          AppLocalizations.supportedLocales.toSet());
      expect(_allLocales.toSet(), AppLocalizations.supportedLocales.toSet());
    });

    test('Locale との対応（やさしい日本語・中国語は scriptCode で判別）', () {
      expect(AppLanguage.jaHira.locale, _jaHira);
      expect(AppLanguage.fromLocale(_jaHira), AppLanguage.jaHira);
      expect(AppLanguage.fromLocale(const Locale('ja')), AppLanguage.ja);
      expect(AppLanguage.fromLocale(_zhHansRequest), AppLanguage.zhHans);
      expect(AppLanguage.fromLocale(_zhHans), AppLanguage.zhHans);
      expect(AppLanguage.fromLocale(_zhHant), AppLanguage.zhHant);
      expect(AppLanguage.fromLocale(const Locale('ko')), AppLanguage.ko);
      expect(AppLanguage.fromLocale(const Locale('vi')), AppLanguage.vi);
      expect(AppLanguage.fromLocale(const Locale('pt', 'BR')), AppLanguage.en);
      expect(AppLanguage.fromLocale(null), isNull);
    });

    test('中国語は script が無くても地域で簡体字/繁体字を振り分ける', () {
      expect(AppLanguage.fromLocale(const Locale('zh')), AppLanguage.zhHans,
          reason: 'zh 単独は簡体字');
      expect(AppLanguage.fromLocale(const Locale('zh', 'CN')),
          AppLanguage.zhHans);
      expect(AppLanguage.fromLocale(const Locale('zh', 'SG')),
          AppLanguage.zhHans);
      for (final region in ['TW', 'HK', 'MO']) {
        expect(AppLanguage.fromLocale(Locale('zh', region)),
            AppLanguage.zhHant,
            reason: 'zh-$region は繁体字');
      }
    });

    test('端末言語からの自動判定: ja/zh/ko/vi はその言語、それ以外→en', () {
      expect(AppLanguage.fromDeviceLocales([const Locale('ja', 'JP')]),
          AppLanguage.ja);
      expect(AppLanguage.fromDeviceLocales([const Locale('vi')]),
          AppLanguage.vi);
      expect(AppLanguage.fromDeviceLocales([const Locale('ko', 'KR')]),
          AppLanguage.ko);
      expect(AppLanguage.fromDeviceLocales([const Locale('zh', 'CN')]),
          AppLanguage.zhHans);
      expect(AppLanguage.fromDeviceLocales([const Locale('zh', 'TW')]),
          AppLanguage.zhHant);
      expect(AppLanguage.fromDeviceLocales([const Locale('th')]),
          AppLanguage.en,
          reason: '未対応言語は英語に寄せる');
      expect(
          AppLanguage.fromDeviceLocales(
              [const Locale('zh', 'CN'), const Locale('ja')]),
          AppLanguage.zhHans,
          reason: '先頭の希望言語を優先する');
      expect(AppLanguage.fromDeviceLocales(const []), AppLanguage.ja);
    });

    test('やさしい日本語は自動選択しない（本人が選ぶもの）', () {
      expect(AppLanguage.fromDeviceLocales([_jaHira]), AppLanguage.ja);
    });
  });

  group('localeResolutionCallback', () {
    test('ja/ja-Hira/zh-Hans/zh-Hant/ko/vi はそれぞれに、それ以外は英語', () {
      final supported = AppLocalizations.supportedLocales;
      expect(resolveAppLocale(const Locale('ja', 'JP'), supported),
          const Locale('ja'));
      expect(resolveAppLocale(_jaHira, supported), _jaHira);
      expect(resolveAppLocale(const Locale('zh', 'CN'), supported), _zhHans);
      expect(resolveAppLocale(const Locale('zh', 'TW'), supported), _zhHant);
      expect(resolveAppLocale(_zhHant, supported), _zhHant);
      expect(resolveAppLocale(const Locale('ko'), supported),
          const Locale('ko'));
      expect(resolveAppLocale(const Locale('vi'), supported),
          const Locale('vi'));
      expect(resolveAppLocale(const Locale('pt', 'BR'), supported),
          const Locale('en'));
      expect(resolveAppLocale(null, supported), const Locale('ja'));
      // 解決結果は必ず対応ロケールのいずれか
      for (final l in [
        const Locale('ja'),
        const Locale('th'),
        const Locale('zh', 'HK'),
        const Locale('ko', 'KR'),
      ]) {
        expect(supported, contains(resolveAppLocale(l, supported)));
      }
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

    /// 全ロケールのARBファイル名（テンプレートの ja を先頭に）
    const files = [
      'app_ja.arb',
      'app_ja_Hira.arb',
      'app_en.arb',
      'app_zh.arb',
      'app_zh_Hant.arb',
      'app_ko.arb',
      'app_vi.arb',
    ];

    Map<String, dynamic> read(String name) =>
        jsonDecode(File('${dir.path}/$name').readAsStringSync())
            as Map<String, dynamic>;
    bool isKey(String k) => !k.startsWith('@');
    Set<String> keysOf(String name) => read(name).keys.where(isKey).toSet();

    test('ARBファイルが7ロケール分そろっている', () {
      expect(files.length, AppLanguage.values.length);
      for (final f in files) {
        expect(File('${dir.path}/$f').existsSync(), isTrue, reason: '$f が無い');
      }
    });

    test('全ロケールでキーの欠落・余剰が無い', () {
      final jaKeys = keysOf('app_ja.arb');
      expect(jaKeys, isNotEmpty);
      for (final f in files.skip(1)) {
        final keys = keysOf(f);
        expect(jaKeys.difference(keys), isEmpty, reason: '$f に未翻訳のキーがある');
        expect(keys.difference(jaKeys), isEmpty,
            reason: '$f にテンプレートに無いキーがある');
      }
    });

    test('空文字の訳が無い', () {
      for (final name in files) {
        final arb = read(name);
        for (final e in arb.entries) {
          if (!isKey(e.key)) continue;
          expect((e.value as String).trim(), isNotEmpty,
              reason: '$name の ${e.key} が空');
        }
      }
    });

    test('プレースホルダがどのロケールでも欠けていない', () {
      final ja = read('app_ja.arb');
      final placeholder = RegExp(r'\{(\w+)\}');
      Set<String> phOf(String v) =>
          placeholder.allMatches(v).map((m) => m.group(1)!).toSet();
      for (final name in files.skip(1)) {
        final arb = read(name);
        for (final e in ja.entries) {
          if (!isKey(e.key)) continue;
          final want = phOf(e.value as String);
          if (want.isEmpty) continue;
          expect(phOf(arb[e.key] as String), want,
              reason: '$name の ${e.key} でプレースホルダが欠落/追加されている');
        }
      }
    });

    test('翻訳言語のARBには @description を持たせない（テンプレートに集約する）', () {
      for (final name in files.skip(1)) {
        expect(read(name).keys.where((k) => k.startsWith('@') && k != '@@locale'),
            isEmpty,
            reason: '$name に @description がある');
      }
    });

    test('@@locale がファイル名と一致する', () {
      const expected = {
        'app_ja.arb': 'ja',
        'app_ja_Hira.arb': 'ja_Hira',
        'app_en.arb': 'en',
        'app_zh.arb': 'zh',
        'app_zh_Hant.arb': 'zh_Hant',
        'app_ko.arb': 'ko',
        'app_vi.arb': 'vi',
      };
      for (final f in files) {
        expect(read(f)['@@locale'], expected[f], reason: f);
      }
    });
  });

  group('表示名の解決', () {
    testWidgets('都道府県47件が全ロケールで解決できる', (tester) async {
      for (final locale in _allLocales) {
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

    testWidgets('警報・注意報・震度・カテゴリが全ロケールで解決できる', (tester) async {
      const warningCodes = [
        '02', '03', '04', '05', '06', '07', '08', '09',
        '43', '44', '48', '49',
        '32', '33', '34', '35', '36', '37', '38', '39',
      ];
      const advisoryCodes = [
        '10', '12', '13', '14', '15', '16', '17', '18', '19',
        '20', '21', '22', '23', '24', '25', '26', '29',
      ];
      const categories = [
        'river', 'road', 'volcano', 'dam', 'coast', 'port', 'scenic',
        'healing', 'other',
      ];
      for (final locale in _allLocales) {
        final l10n = await _load(tester, locale);
        for (final c in warningCodes) {
          expect(warningNameOf(l10n, c)?.trim(), isNotEmpty, reason: '$locale $c');
        }
        for (final c in advisoryCodes) {
          expect(advisoryNameOf(l10n, c)?.trim(), isNotEmpty, reason: '$locale $c');
        }
        expect(warningNameOf(l10n, '99'), isNull);
        expect(advisoryNameOf(l10n, '99'), isNull);
        for (final c in ['5-', '5+', '6-', '6+']) {
          expect(intensityLabelOf(l10n, c), isNot(c), reason: '$locale $c');
        }
        for (final c in categories) {
          expect(categoryLabelOf(l10n, c).trim(), isNotEmpty);
        }
      }
    });

    testWidgets('地図レイヤー・避難場所・熱中症の表示名が全ロケールで解決できる',
        (tester) async {
      for (final locale in _allLocales) {
        final l10n = await _load(tester, locale);
        for (final k in ['flood', 'landslide', 'tsunami', 'hightide']) {
          expect(hazardLayerTitleOf(l10n, k).trim(), isNotEmpty,
              reason: '$locale $k');
        }
        for (final k in ['steepSlope', 'debrisFlow', 'landslide']) {
          expect(landslideKindOf(l10n, k), isNot(k), reason: '$locale $k');
        }
        for (final k in ['land', 'inund', 'flood']) {
          expect(riskLayerTitleOf(l10n, k).trim(), isNotEmpty);
          expect(riskLayerSubtitleOf(l10n, k).trim(), isNotEmpty);
        }
        for (final k in ['watch', 'caution', 'warning', 'danger', 'critical']) {
          expect(riskLevelLabelOf(l10n, k), isNot(k), reason: '$locale $k');
        }
        for (final h in ShelterLayers.defaultHazards) {
          expect(shelterHazardLabelOf(l10n, h).trim(), isNotEmpty);
        }
        for (final k in FacilityLayers.kindKeys) {
          expect(facilityKindLabelOf(l10n, k), isNot(k), reason: '$locale $k');
          expect(facilityKindShortOf(l10n, k), isNot(k), reason: '$locale $k');
        }
        for (final v in WbgtLevel.values) {
          expect(wbgtLevelLabelOf(l10n, v).trim(), isNotEmpty);
        }
        for (final v in [
          HeatAlertLevel.special,
          HeatAlertLevel.specialPending,
          HeatAlertLevel.warning,
        ]) {
          expect(heatAlertLabelOf(l10n, v).trim(), isNotEmpty);
        }
        expect(heatAlertLabelOf(l10n, HeatAlertLevel.none), isEmpty);
      }
    });

    testWidgets('気象庁 多言語辞書の対訳がそのまま使われている', (tester) async {
      // 出典：気象庁「気象情報等に関する多言語辞書」(2026-03-26版)。自由訳しないこと
      final en = await _load(tester, const Locale('en'));
      expect(warningNameOf(en, '04'), 'Flood Warning');
      expect(warningNameOf(en, '33'), 'Heavy Rain Emergency Warning');
      expect(advisoryNameOf(en, '14'), 'Thunderstorm Advisory');

      final zhHans = await _load(tester, _zhHans);
      expect(warningNameOf(zhHans, '04'), '洪水警报');
      expect(warningNameOf(zhHans, '06'), '大雪警报');
      expect(advisoryNameOf(zhHans, '14'), '闪电注意报');
      expect(prefectureNameOf(zhHans, '13'), '东京');

      final zhHant = await _load(tester, _zhHant);
      expect(warningNameOf(zhHant, '04'), '洪水警報');
      expect(warningNameOf(zhHant, '07'), '海浪警報');
      expect(prefectureNameOf(zhHant, '13'), '東京');

      final ko = await _load(tester, const Locale('ko'));
      expect(warningNameOf(ko, '04'), '홍수 경보');
      expect(advisoryNameOf(ko, '10'), '호우 주의보');
      expect(prefectureNameOf(ko, '13'), '도쿄');

      final vi = await _load(tester, const Locale('vi'));
      expect(warningNameOf(vi, '04'), 'Cảnh báo lũ lụt');
      expect(advisoryNameOf(vi, '10'), 'Thông tin lưu ý mưa to');
      expect(prefectureNameOf(vi, '13'), 'Tokyo');
    });

    testWidgets('チップ・タブに使う短い文言が長くなりすぎていない', (tester) async {
      // ベトナム語・韓国語は長くなりやすい。折り返しでレイアウトが崩れないよう
      // タブ名は16文字、カテゴリ・都道府県のチップは24文字を上限にする
      for (final locale in _allLocales) {
        final l10n = await _load(tester, locale);
        for (final s in [
          l10n.tabMap,
          l10n.tabList,
          l10n.tabBosai,
          l10n.tabFavorites,
          l10n.tabSettings,
        ]) {
          expect(s.length, lessThanOrEqualTo(16), reason: '$locale のタブ名 "$s"');
          expect(s, isNot(contains('\n')));
        }
        for (final c in [
          'river', 'road', 'volcano', 'dam', 'coast', 'port', 'scenic',
          'healing', 'other',
        ]) {
          final s = categoryLabelOf(l10n, c);
          expect(s.length, lessThanOrEqualTo(24),
              reason: '$locale のカテゴリ "$s"');
        }
        for (final code in prefectureNames.keys) {
          final s = prefectureNameOf(l10n, code);
          expect(s.length, lessThanOrEqualTo(24),
              reason: '$locale の都道府県 "$s"');
        }
      }
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
