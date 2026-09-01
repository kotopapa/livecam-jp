import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/config.dart';
import 'package:livecam_jp/data/affiliate.dart';
import 'package:livecam_jp/data/stockpile.dart';
import 'package:livecam_jp/data/stockpile_reminders.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/l10n/l10n.dart';
import 'package:livecam_jp/ui/ad_banner.dart';
import 'package:livecam_jp/ui/stockpile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';

/// 対応する全ロケール（i18n_test.dart と同じ7種）
const _allLocales = [
  Locale('ja'),
  Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('ko'),
  Locale('vi'),
];

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

StockpileItemSpec _spec(String id) =>
    defaultStockpileItems.firstWhere((s) => s.id == id);

void main() {
  group('必要量の計算', () {
    test('水は1人1日3L（内閣府・農水省の目安）', () {
      final water = _spec('water');
      // 大人2人・3日分 → 3L × 2人 × 3日 = 18L
      expect(water.requiredQuantity(adults: 2, children: 0, days: 3), 18);
      // 大人2＋子ども2・7日分 → 3 × 4 × 7 = 84L
      expect(water.requiredQuantity(adults: 2, children: 2, days: 7), 84);
      expect(water.requiredQuantity(adults: 1, children: 0, days: 3), 9);
    });

    test('主食は1人1日3食', () {
      final staple = _spec('stapleFood');
      expect(staple.requiredQuantity(adults: 2, children: 1, days: 3), 27);
      expect(staple.requiredQuantity(adults: 1, children: 0, days: 7), 21);
    });

    test('簡易トイレは1人1日5回（経産省の目安）', () {
      final toilet = _spec('portableToilet');
      // 4人家族×7日 = 5×4×7 = 140回分（内閣府「ぼうさい」111号の例と一致）
      expect(toilet.requiredQuantity(adults: 4, children: 0, days: 7), 140);
      expect(toilet.requiredQuantity(adults: 2, children: 0, days: 3), 30);
    });

    test('1人あたり固定・世帯あたり固定の品目', () {
      // 懐中電灯は1人1個（日数に依存しない）
      final light = _spec('flashlight');
      expect(light.requiredQuantity(adults: 2, children: 1, days: 3), 3);
      expect(light.requiredQuantity(adults: 2, children: 1, days: 7), 3);
      // ラジオは世帯1台（人数にも日数にも依存しない）
      final radio = _spec('radio');
      expect(radio.requiredQuantity(adults: 1, children: 0, days: 3), 1);
      expect(radio.requiredQuantity(adults: 5, children: 3, days: 7), 1);
      // 乾電池は1人4本＋世帯4本
      expect(_spec('batteries').requiredQuantity(adults: 2, children: 0, days: 3),
          12);
    });

    test('子ども専用の品目は子どもが居ないと0（画面にも出さない）', () {
      final milk = _spec('babyFormula');
      expect(milk.requiredQuantity(adults: 2, children: 0, days: 3), 0);
      expect(milk.requiredQuantity(adults: 2, children: 1, days: 3), 9);
      final s = StockpileState(adults: 2, children: 0);
      expect(s.visibleSpecs.map((x) => x.id), isNot(contains('babyFormula')));
      expect(s.visibleSpecs.map((x) => x.id), isNot(contains('diapers')));
      final withKids = StockpileState(adults: 2, children: 1);
      expect(withKids.visibleSpecs.map((x) => x.id), contains('babyFormula'));
    });

    test('端数は切り上げる', () {
      const spec = StockpileItemSpec(
        id: 'x',
        category: StockpileCategory.waterFood,
        unit: StockpileUnit.piece,
        searchKeyword: 'x',
        perPersonPerDay: 0.5,
      );
      expect(spec.requiredQuantity(adults: 1, children: 0, days: 3), 2); // 1.5
    });

    test('サマリー（水のL・食料の食数）', () {
      final s = StockpileState(adults: 2, children: 2, days: 3);
      expect(s.totalWaterLiters, 36); // 3L × 4人 × 3日
      expect(s.totalMeals, 36); // 3食 × 4人 × 3日
    });

    test('削除した品目は必要量の一覧から消え、進捗の母数からも外れる', () {
      final s = StockpileState(adults: 1, children: 0);
      final before = s.progress.$2;
      s.removedItemIds.add('rope');
      expect(s.visibleSpecs.map((x) => x.id), isNot(contains('rope')));
      expect(s.progress.$2, before - 1);
      s.entryOf('water').checked = true;
      expect(s.progress.$1, 1);
    });
  });

  group('期限の判定', () {
    final now = DateTime(2026, 9, 1);

    test('期限なしは none', () {
      expect(expiryStatusOf(null, now), ExpiryStatus.none);
    });

    test('1か月より先は ok、ちょうど1か月前から soon', () {
      // 2026-10-01 の1か月前 = 2026-09-01 → 当日から soon
      expect(expiryStatusOf(DateTime(2026, 10, 1), now), ExpiryStatus.soon);
      // 2026-10-02 の1か月前 = 2026-09-02 → まだ ok
      expect(expiryStatusOf(DateTime(2026, 10, 2), now), ExpiryStatus.ok);
      expect(expiryStatusOf(DateTime(2027, 3, 1), now), ExpiryStatus.ok);
    });

    test('期限当日は soon（まだ切れていない）、翌日から expired', () {
      expect(expiryStatusOf(now, now), ExpiryStatus.soon);
      expect(expiryStatusOf(DateTime(2026, 8, 31), now), ExpiryStatus.expired);
    });

    test('時刻付きの「今」でも日付だけで判定する', () {
      final noon = DateTime(2026, 9, 1, 23, 59);
      expect(expiryStatusOf(DateTime(2026, 9, 1), noon), ExpiryStatus.soon);
      expect(expiryStatusOf(DateTime(2026, 8, 31), noon), ExpiryStatus.expired);
    });

    test('1か月前の日付（月またぎ・年またぎ）', () {
      expect(expiryReminderDate(DateTime(2027, 1, 15)), DateTime(2026, 12, 15));
      expect(expiryReminderDate(DateTime(2026, 3, 31)), DateTime(2026, 3, 3),
          reason: '2月31日は3月3日に正規化される（DateTimeの仕様）');
    });

    test('日付キーの往復', () {
      expect(formatDateKey(DateTime(2027, 3, 1)), '2027-03-01');
      expect(parseDateKey('2027-03-01'), DateTime(2027, 3, 1));
      expect(parseDateKey('2027-02-30'), isNull);
      expect(parseDateKey('2027-13-01'), isNull);
      expect(parseDateKey('bad'), isNull);
      expect(parseDateKey(null), isNull);
    });
  });

  group('リマインドの予約', () {
    test('OFFなら何も予約しない', () {
      final s = StockpileState();
      s.entryOf('water').expiry = DateTime(2027, 1, 1);
      expect(buildReminders(s, now: DateTime(2026, 9, 1)), isEmpty);
    });

    test('点検日は次に来る3/11・9/1の午前9時', () {
      final s = StockpileState(inspectionReminderEnabled: true);
      final r = buildReminders(s, now: DateTime(2026, 9, 1, 12));
      expect(r.length, 2);
      expect(r.every((x) => x.kind == ReminderKind.inspection), isTrue);
      expect(r.map((x) => x.at), [
        DateTime(2027, 3, 11, 9), // 今年の3/11は過ぎている
        DateTime(2027, 9, 1, 9), // 9/1の9時も過ぎている（12時時点）
      ]);
      // 9/1の朝8時なら当日9時に鳴る
      final morning = buildReminders(s, now: DateTime(2026, 9, 1, 8));
      expect(morning.last.at, DateTime(2026, 9, 1, 9));
    });

    test('期限の1か月前・午前9時に予約し、過ぎた分は予約しない', () {
      final s = StockpileState(expiryReminderEnabled: true);
      s.entryOf('water').expiry = DateTime(2027, 1, 20);
      s.entryOf('stapleFood').expiry = DateTime(2026, 9, 10); // 通知日は8/10=過去
      final r = buildReminders(s, now: DateTime(2026, 9, 1));
      expect(r.length, 1);
      expect(r.single.kind, ReminderKind.expiry);
      expect(r.single.itemId, 'water');
      expect(r.single.at, DateTime(2026, 12, 20, 9));
    });

    test('通知IDは専用レンジで重複しない', () {
      final s = StockpileState(
          expiryReminderEnabled: true, inspectionReminderEnabled: true);
      s.entryOf('water').expiry = DateTime(2027, 1, 20);
      s.entryOf('cannedFood').expiry = DateTime(2027, 2, 20);
      final r = buildReminders(s, now: DateTime(2026, 9, 1));
      expect(r.length, 4);
      expect(r.map((x) => x.id).toSet().length, 4);
      expect(r.every((x) => x.id >= reminderIdBase && x.id < reminderIdBase + 100),
          isTrue);
    });

    test('カスタム項目も期限リマインドの対象', () {
      final s = StockpileState(expiryReminderEnabled: true);
      s.customItems.add(StockpileEntry(
        id: 'custom-1',
        customTitle: 'カセットボンベ',
        customCategory: StockpileCategory.waterFood,
        expiry: DateTime(2027, 5, 1),
      ));
      final r = buildReminders(s, now: DateTime(2026, 9, 1));
      expect(r.single.customTitle, 'カセットボンベ');
      expect(r.single.itemId, isNull);
    });

    test('MM-dd が不正なら予約しない', () {
      expect(nextInspectionDate('02-30', DateTime(2026, 1, 1)), isNull);
      expect(nextInspectionDate('13-01', DateTime(2026, 1, 1)), isNull);
      expect(nextInspectionDate('bad', DateTime(2026, 1, 1)), isNull);
    });
  });

  group('アフィリエイトURLの組み立て', () {
    const yahoo = VcMerchant(
      key: 'yahoo',
      name: 'Yahoo!ショッピング',
      pid: '892690203',
      enabled: true,
      searchUrl: _yahoo,
    );
    const rakuten = VcMerchant(
      key: 'rakuten',
      name: '楽天市場',
      pid: '892690205',
      enabled: false,
      searchUrl: _rakuten,
    );

    test('config の広告主は sid/pid が揃っていて Yahoo! だけが有効', () {
      expect(vcSid, '3780235');
      expect(vcPidPrimary, '892690203');
      expect(vcMerchants.map((m) => m.pid).toSet().length, vcMerchants.length,
          reason: 'pidの重複');
      expect(
          {for (final m in vcMerchants) m.key: m.pid},
          {
            'yahoo': '892690203',
            'rakuten': '892690205',
            'amazon': '892690207',
          });
      // 審査中の楽天・Amazon は無効
      expect(AffiliateLinks.enabledMerchants.map((m) => m.key), ['yahoo']);
      expect(AffiliateLinks.needsMerchantPicker, isFalse);
      expect(AffiliateLinks.isAvailable, isTrue);
    });

    test('vc_url は遷移先URL全体をパーセントエンコードする', () {
      final url = AffiliateLinks.searchLink('簡易トイレ 防災', yahoo)!;
      expect(url.toString().startsWith(
          'https://ck.jp.ap.valuecommerce.com/servlet/referral?'
          'sid=3780235&pid=892690203&vc_url='), isTrue);
      // ?・=・:・/ がエンコードされていること（生のまま残さない）
      final raw = url.toString();
      final vcUrl = raw.substring(raw.indexOf('vc_url=') + 'vc_url='.length);
      expect(vcUrl, isNot(contains('?')));
      expect(vcUrl, isNot(contains('/')));
      expect(vcUrl, contains('%3A%2F%2F')); // ://
      // デコードすると Yahoo!ショッピングの検索URLに戻る
      expect(Uri.decodeComponent(vcUrl),
          'https://shopping.yahoo.co.jp/search?p=%E7%B0%A1%E6%98%93%E3%83%88'
          '%E3%82%A4%E3%83%AC+%E9%98%B2%E7%81%BD');
      // 実際に取り出したパラメータでも一致する
      expect(url.queryParameters['vc_url'],
          'https://shopping.yahoo.co.jp/search?p=%E7%B0%A1%E6%98%93%E3%83%88'
          '%E3%82%A4%E3%83%AC+%E9%98%B2%E7%81%BD');
      expect(url.queryParameters['sid'], '3780235');
      expect(url.queryParameters['pid'], '892690203');
    });

    test('楽天は検索語をパスに入れる（承認後に有効化して使う）', () {
      const approved = VcMerchant(
          key: 'rakuten',
          name: '楽天市場',
          pid: '892690205',
          enabled: true,
          searchUrl: _rakuten);
      final url = AffiliateLinks.searchLink('保存水', approved)!;
      expect(url.queryParameters['pid'], '892690205');
      expect(url.queryParameters['vc_url'],
          'https://search.rakuten.co.jp/search/mall/'
          '%E4%BF%9D%E5%AD%98%E6%B0%B4/');
    });

    test('Amazon の検索URL', () {
      const approved = VcMerchant(
          key: 'amazon',
          name: 'Amazon.co.jp',
          pid: '892690207',
          enabled: true,
          searchUrl: _amazon);
      final url = AffiliateLinks.searchLink('防災リュック', approved)!;
      expect(url.queryParameters['vc_url'],
          'https://www.amazon.co.jp/s?k='
          '%E9%98%B2%E7%81%BD%E3%83%AA%E3%83%A5%E3%83%83%E3%82%AF');
    });

    test('未承認の広告主・空の検索語ではリンクを作らない', () {
      expect(AffiliateLinks.searchLink('保存水', rakuten), isNull);
      expect(AffiliateLinks.searchLink('   ', yahoo), isNull);
    });

    test('有効が1つなら直接開き、2つ以上なら店舗選択シートを出す', () {
      const only = [yahoo, rakuten]; // 楽天は審査中
      expect(AffiliateLinks.enabledIn(only).length, 1);
      expect(AffiliateLinks.needsPickerIn(only), isFalse);
      expect(AffiliateLinks.soleSearchLinkIn('保存水', only), isNotNull);

      const all = [
        yahoo,
        VcMerchant(
            key: 'rakuten',
            name: '楽天市場',
            pid: '892690205',
            enabled: true,
            searchUrl: _rakuten),
        VcMerchant(
            key: 'amazon',
            name: 'Amazon.co.jp',
            pid: '892690207',
            enabled: true,
            searchUrl: _amazon),
      ];
      expect(AffiliateLinks.enabledIn(all).length, 3);
      expect(AffiliateLinks.needsPickerIn(all), isTrue);
      expect(AffiliateLinks.soleSearchLinkIn('保存水', all), isNull,
          reason: '複数あるときは直接開かず選択シートに委ねる');
    });

    test('全品目に検索語がある', () {
      for (final s in defaultStockpileItems) {
        expect(s.searchKeyword.trim(), isNotEmpty, reason: s.id);
        expect(AffiliateLinks.searchLink(s.searchKeyword, yahoo), isNotNull);
      }
    });
  });

  group('保存と復元', () {
    test('世帯人数・チェック・期限・カスタム項目・点検日が往復する', () {
      final s = StockpileState(adults: 3, children: 2, days: 7);
      s.entryOf('water').checked = true;
      s.entryOf('water').expiry = DateTime(2027, 3, 1);
      s.removedItemIds.add('rope');
      s.customItems.add(StockpileEntry(
        id: 'custom-1',
        customTitle: 'カセットボンベ',
        customCategory: StockpileCategory.waterFood,
        customQuantity: 6,
        checked: true,
      ));
      s.expiryReminderEnabled = true;
      s.inspectionReminderEnabled = true;

      final restored = StockpileStore.decode(StockpileStore.encode(s));
      expect(restored.adults, 3);
      expect(restored.children, 2);
      expect(restored.days, 7);
      expect(restored.entries['water']!.checked, isTrue);
      expect(restored.entries['water']!.expiry, DateTime(2027, 3, 1));
      expect(restored.removedItemIds, {'rope'});
      expect(restored.customItems.single.customTitle, 'カセットボンベ');
      expect(restored.customItems.single.customQuantity, 6);
      expect(restored.customItems.single.customCategory,
          StockpileCategory.waterFood);
      expect(restored.customItems.single.checked, isTrue);
      expect(restored.expiryReminderEnabled, isTrue);
      expect(restored.inspectionReminderEnabled, isTrue);
      expect(restored.inspectionDays, defaultInspectionDays);
    });

    test('未保存・壊れたJSONは既定値になる（落ちない）', () {
      for (final raw in [null, '', 'not json', '[]', '{"days":999}']) {
        final s = StockpileStore.decode(raw);
        expect(s.adults, 2);
        expect(s.children, 0);
        expect(s.days, defaultStockpileDays);
        expect(s.customItems, isEmpty);
      }
    });

    test('異常な人数・日数は丸める', () {
      final s = StockpileStore.decode(
          jsonEncode({'adults': 999, 'children': -5, 'days': 4}));
      expect(s.adults, 20);
      expect(s.children, 0);
      expect(s.days, defaultStockpileDays);
    });

    test('SharedPreferences に保存して読み戻せる', () async {
      SharedPreferences.setMockInitialValues({});
      final s = StockpileState(adults: 1, children: 3, days: 7);
      s.entryOf('mask').checked = true;
      await StockpileStore.save(s);
      final loaded = await StockpileStore.load();
      expect(loaded.adults, 1);
      expect(loaded.children, 3);
      expect(loaded.days, 7);
      expect(loaded.entries['mask']!.checked, isTrue);

      await StockpileStore.clear();
      final cleared = await StockpileStore.load();
      expect(cleared.adults, 2);
      expect(cleared.entries, isEmpty);
    });

    test('チェックも期限も無い品目はJSONに書かない（容量を無駄にしない）', () {
      final s = StockpileState();
      for (final spec in defaultStockpileItems) {
        s.entryOf(spec.id);
      }
      final json = jsonDecode(StockpileStore.encode(s)) as Map<String, dynamic>;
      expect(json['entries'], isEmpty);
    });
  });

  group('ARB（多言語）', () {
    test('7ロケールすべてに stockpile* のキーがそろっている', () {
      const files = [
        'app_ja.arb',
        'app_ja_Hira.arb',
        'app_en.arb',
        'app_zh.arb',
        'app_zh_Hant.arb',
        'app_ko.arb',
        'app_vi.arb',
      ];
      Set<String> stockpileKeysOf(String name) =>
          (jsonDecode(File('lib/l10n/$name').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => k.startsWith('stockpile'))
              .toSet();
      final ja = stockpileKeysOf('app_ja.arb');
      expect(ja, isNotEmpty);
      for (final f in files.skip(1)) {
        expect(stockpileKeysOf(f), ja, reason: '$f のキーが一致しない');
      }
      // 品目のキーが全品目分ある
      for (final spec in defaultStockpileItems) {
        final key =
            'stockpileItem${spec.id[0].toUpperCase()}${spec.id.substring(1)}';
        expect(ja, contains(key), reason: '${spec.id} のARBキーが無い');
      }
    });

    testWidgets('品目・カテゴリ・単位が全ロケールで解決できる', (tester) async {
      for (final locale in _allLocales) {
        final l10n = await _load(tester, locale);
        for (final spec in defaultStockpileItems) {
          final name = stockpileItemNameOf(l10n, spec.id);
          expect(name, isNotNull, reason: '$locale ${spec.id}');
          expect(name!.trim(), isNotEmpty, reason: '$locale ${spec.id}');
        }
        expect(stockpileItemNameOf(l10n, 'no-such-item'), isNull);
        for (final c in StockpileCategory.values) {
          expect(stockpileCategoryNameOf(l10n, c).trim(), isNotEmpty,
              reason: '$locale $c');
        }
        for (final u in StockpileUnit.values) {
          expect(stockpileUnitNameOf(l10n, u).trim(), isNotEmpty,
              reason: '$locale $u');
        }
        // 画面の主要文言
        expect(l10n.stockpileTitle.trim(), isNotEmpty);
        expect(l10n.stockpileAffiliateNotice.trim(), isNotEmpty);
        expect(l10n.stockpileSummaryWater(18), contains('18'));
        expect(l10n.stockpileProgress(3, 10), contains('3'));
        expect(l10n.stockpileNotifyExpiryBody('水', '2027-03-01'),
            contains('2027-03-01'));
      }
    });

    testWidgets('やさしい日本語は日本語と別の平易な表記になっている', (tester) async {
      final ja = await _load(tester, const Locale('ja'));
      final hira = await _load(
          tester, const Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'));
      expect(hira.stockpileTitle, isNot(ja.stockpileTitle));
      expect(hira.stockpileSearchButton, isNot(ja.stockpileSearchButton));
    });
  });

  group('画面', () {
    AppState makeApp() => AppState(CameraRepository(
          api: ApiClient(
              client: MockClient((_) async => http.Response('nf', 404))),
          cache: CacheStore(Directory(Directory.systemTemp.path)),
        ));

    testWidgets('世帯人数を変えると必要量の表示が変わる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(testApp(StockpileScreen(app: makeApp())));
      await tester.pumpAndSettle();

      expect(find.text('防災の備え'), findsOneWidget);
      // 既定は大人2人・3日分 → 水 3L×2×3 = 18L
      expect(find.text('水 18L'), findsOneWidget);
      expect(find.text('食料 18食'), findsOneWidget);
      // 大人を1人増やす
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pump();
      expect(find.text('水 27L'), findsOneWidget);
      // 7日分に切り替える
      await tester.tap(find.text('7日分'));
      await tester.pump();
      expect(find.text('水 63L'), findsOneWidget);
    });

    testWidgets('アフィリエイトの明示と「探す」ボタンが出ている', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 特別警報の発表中は広告を出さない規則。ここでONにしておくと
      // 広告ウィジェット（テスト環境にプラグインが無い）を組み立てずに
      // 最下部まで確認できる
      final app = makeApp()..specialWarningActive = true;
      await tester.pumpWidget(testApp(StockpileScreen(app: app)));
      await tester.pumpAndSettle();
      expect(find.text('探す'), findsWidgets);
      expect(find.text('保存水'), findsOneWidget);

      // 景表法のステマ規制対応の明示は必須（画面最下部）
      await tester.scrollUntilVisible(
          find.text('※商品リンクにはアフィリエイトプログラムを利用しています'), 400,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('※商品リンクにはアフィリエイトプログラムを利用しています'),
          findsOneWidget);
      // 特別警報の発表中は広告を出さない
      expect(find.byType(AdBannerPlaceholder), findsNothing);
    });

    testWidgets('チェックが保存され、進捗に反映される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(testApp(StockpileScreen(app: makeApp())));
      await tester.pumpAndSettle();
      // 既定は子ども0人なので、子ども専用の2品目を除いた24項目
      expect(find.text('0/24 完了'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('1/24 完了'), findsOneWidget);
      final saved = await StockpileStore.load();
      expect(saved.entries['water']!.checked, isTrue);
    });
  });
}

Uri _yahoo(String k) =>
    Uri.parse('https://shopping.yahoo.co.jp/search?p=${Uri.encodeQueryComponent(k)}');
Uri _rakuten(String k) => Uri.parse(
    'https://search.rakuten.co.jp/search/mall/${Uri.encodeComponent(k)}/');
Uri _amazon(String k) =>
    Uri.parse('https://www.amazon.co.jp/s?k=${Uri.encodeQueryComponent(k)}');
