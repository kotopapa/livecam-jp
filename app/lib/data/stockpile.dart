/// 防災備蓄チェックリストのモデル・必要量計算・保存（1.4.0）。
///
/// 表示名は持たない（キーだけを持ち、UI層 `l10n/l10n.dart` で解決する）。
/// 多言語対応の方針は docs/i18n_1.4.0.md 8.6 と同じ。
///
/// ## 必要量の根拠（出典。2026-09-01 に実際にアクセスして確認）
///
/// - 内閣府 防災情報のページ 広報誌「ぼうさい」第83号 特集3「地震に備える」
///   https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html
///   「一日一人3リットルを目安に、3日分を用意」「一人最低3日分」（食料）
///   「南海トラフ地震では、1週間以上の備蓄が望ましい」
/// - 首相官邸「災害が起きる前にできること」
///   https://www.kantei.go.jp/jp/headline/bousai/sonae.html
///   「飲料水 3日分（1人1日3リットルが目安）」「非常食 3日分の食料」
/// - 農林水産省「家庭備蓄ポータル」 https://www.maff.go.jp/j/zyukyu/foodstock/
///   （数値は下位ページ）
///   https://www.maff.go.jp/j/zyukyu/foodstock/imadoki/imadoki02_10.html
///   「一人当たり1日3リットルの水が必要…最低3日分として9リットル」
///   https://nippon-food-shift.maff.go.jp/foodstock/
///   「まずは3日分…目標は1週間分です」「カセットボンベ 1人1日1本程度」
/// - 総務省消防庁 地震防災マニュアル「備蓄品を備える」
///   https://www.fdma.go.jp/relocation/bousai_manual/pre/preparation081.html
///   「目安として最低限3日間程度の水や食料品は備蓄しましょう」
/// - 東京都「東京備蓄ナビ」 https://www.bichiku.metro.tokyo.lg.jp/why/
///   「まずは3日分を目標に…1週間やその先も見据えた備蓄を」
///   パンフレット（令和7年10月版）「1日1人3リットルが目安量です」
///   https://www.bousai.metro.tokyo.lg.jp/_res/common/bichiku/pamph_r7_11.pdf
/// - 簡易トイレの回数は経済産業省が一次出典。内閣府 広報誌「ぼうさい」
///   第111号（出典表記：経済産業省製造産業局生活製品課）
///   https://www.bousai.go.jp/kohou/kouhoubousai/r06/111/news_08.html
///   「成人の1日の平均排泄回数は1人あたり5回」
///   「4人家族の場合、5（1人5回分/日）×4（家族の人数）×7（日分）＝140回分」
///
/// **公的資料に数量の根拠が無い品目**（乾電池の本数・モバイルバッテリー・
/// 救急用品など）は、上記の考え方に沿って「1人1個」「世帯1個」程度の
/// 常識的なめやすを置いている。画面には参考値である旨を明示し
/// （`stockpileDisclaimer`）、ユーザーが項目を追加・削除できるようにしている。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/jst.dart';

/// 備蓄品のカテゴリ（表示順）。表示名は `stockpileCategoryNameOf()`
enum StockpileCategory {
  waterFood,
  lightPower,
  sanitation,
  firstAid,
  evacuation,
  valuables;

  static StockpileCategory? fromKey(String key) =>
      StockpileCategory.values.where((c) => c.name == key).firstOrNull;
}

/// 数量の単位キー。表示名は `stockpileUnitNameOf()`
enum StockpileUnit {
  liter,
  meal,
  piece,
  sheet,
  roll,
  pair,
  pack,
  times,
  days,
  set;

  static StockpileUnit? fromKey(String key) =>
      StockpileUnit.values.where((u) => u.name == key).firstOrNull;
}

/// 1人1日あたりの飲料水（L）。
/// 出典: 内閣府「ぼうさい」83号・首相官邸・農林水産省・東京都いずれも
/// 「1人1日3リットルが目安」（飲用1L＋調理等を含めて3L）。
const double waterLitersPerPersonPerDay = 3.0;

/// 1人1日あたりの食事回数。
/// 公的資料は食料について「最低3日分」とだけ示し、食数までは規定していない
/// （内閣府「ぼうさい」83号・消防庁・農林水産省）。ここでは通常の食生活に
/// 合わせて **1日3食** として日数から食数に換算している。
const double mealsPerPersonPerDay = 3.0;

/// 1人1日あたりのトイレ回数（簡易トイレの必要個数のもと）。
/// 出典: 経済産業省（内閣府 広報誌「ぼうさい」111号が引用）
/// 「成人の1日の平均排泄回数は1人あたり5回」。
const double toiletTimesPerPersonPerDay = 5.0;

/// 備蓄する日数の選択肢。
/// 出典: 内閣府・消防庁・農林水産省・東京都いずれも
/// 「最低3日分、できれば1週間分」。
const List<int> stockpileDayOptions = [3, 7];

/// 既定の備蓄日数
const int defaultStockpileDays = 3;

/// 点検日の既定候補（MM-dd）。3月11日（東日本大震災）と9月1日（防災の日）
const List<String> defaultInspectionDays = ['03-11', '09-01'];

/// 期限リマインドを出す「何か月前」か
const int expiryReminderMonths = 1;

/// 備蓄品1品目の定義（数量ルールを持つ不変データ）。
class StockpileItemSpec {
  const StockpileItemSpec({
    required this.id,
    required this.category,
    required this.unit,
    required this.searchKeyword,
    this.perPersonPerDay = 0,
    this.perPerson = 0,
    this.perHousehold = 0,
    this.infantsOnly = false,
    this.expiryRelevant = false,
  });

  /// 安定キー（ARBのキー・保存JSONのキーに使う）
  final String id;
  final StockpileCategory category;
  final StockpileUnit unit;

  /// アフィリエイト検索に使う語（日本語。Amazon.co.jp を検索する）。
  /// **空なら購入導線を出さない**（現金・書類の写し・連絡先メモ・常備薬のように
  /// 「買って備える」ものではない品目。以前は小銭入れ・防水ケースなど周辺用品の
  /// 検索語を入れていたが、品目と噛み合わず不自然だった）
  final String searchKeyword;

  /// ショップ検索の導線を出してよい品目か
  bool get purchasable => searchKeyword.trim().isNotEmpty;

  /// 1人1日あたりの必要量
  final double perPersonPerDay;

  /// 1人あたりの必要量（日数に依存しない）
  final double perPerson;

  /// 世帯あたりの必要量（人数にも日数にも依存しない）
  final double perHousehold;

  /// 乳幼児（ミルク・おむつが要る年齢）の人数だけで数える品目。
  /// 「子ども」全員分を計上するとミルクを飲まない子にも積まれてしまう
  final bool infantsOnly;

  /// 消費期限の管理が要る品目か（UIで期限欄を勧める）
  final bool expiryRelevant;

  /// 必要量（切り上げ・最低1）。
  /// [adults] [children] [infants] は人数、[days] は備蓄日数。
  /// 乳幼児は水・食料などの一般品目でも1人として数える（安全側）
  int requiredQuantity({
    required int adults,
    required int children,
    int infants = 0,
    required int days,
  }) {
    final people = infantsOnly ? infants : adults + children + infants;
    if (infantsOnly && infants <= 0) return 0;
    final total =
        perPersonPerDay * people * days + perPerson * people + perHousehold;
    if (total <= 0) return 0;
    return total.ceil();
  }
}

/// 既定の品目一覧（この順に表示する）。
///
/// 数量は上記の出典にもとづく「めやす」。ご家庭の事情で増減できるよう
/// ユーザーが項目を追加・削除できる作りにしている。
const List<StockpileItemSpec> defaultStockpileItems = [
  // --- 水・食料 ---------------------------------------------------------
  StockpileItemSpec(
    id: 'water',
    category: StockpileCategory.waterFood,
    unit: StockpileUnit.liter,
    searchKeyword: '長期保存水 5年',
    perPersonPerDay: waterLitersPerPersonPerDay,
    expiryRelevant: true,
  ),
  // 主食（アルファ米・パンの缶詰・乾麺）で1日3食分
  StockpileItemSpec(
    id: 'stapleFood',
    category: StockpileCategory.waterFood,
    unit: StockpileUnit.meal,
    searchKeyword: '非常食 アルファ米 5年保存',
    perPersonPerDay: mealsPerPersonPerDay,
    expiryRelevant: true,
  ),
  // 主菜・副菜（レトルト2食＋缶詰1食＝1日3食分）
  StockpileItemSpec(
    id: 'retortFood',
    category: StockpileCategory.waterFood,
    unit: StockpileUnit.meal,
    searchKeyword: 'レトルト食品 常温 長期保存',
    perPersonPerDay: 2,
    expiryRelevant: true,
  ),
  StockpileItemSpec(
    id: 'cannedFood',
    category: StockpileCategory.waterFood,
    unit: StockpileUnit.piece,
    searchKeyword: '缶詰 セット 保存食',
    perPersonPerDay: 1,
    expiryRelevant: true,
  ),
  StockpileItemSpec(
    id: 'babyFormula',
    category: StockpileCategory.waterFood,
    unit: StockpileUnit.times,
    searchKeyword: '液体ミルク 備蓄',
    perPersonPerDay: 3,
    infantsOnly: true,
    expiryRelevant: true,
  ),
  // --- 明かり・電源 -----------------------------------------------------
  StockpileItemSpec(
    id: 'flashlight',
    category: StockpileCategory.lightPower,
    unit: StockpileUnit.piece,
    searchKeyword: '懐中電灯 LED 防災',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'batteries',
    category: StockpileCategory.lightPower,
    unit: StockpileUnit.piece,
    searchKeyword: '乾電池 単3 まとめ買い',
    perPerson: 4,
    perHousehold: 4,
    expiryRelevant: true,
  ),
  StockpileItemSpec(
    id: 'powerBank',
    category: StockpileCategory.lightPower,
    unit: StockpileUnit.piece,
    searchKeyword: 'モバイルバッテリー 大容量 防災',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'radio',
    category: StockpileCategory.lightPower,
    unit: StockpileUnit.piece,
    searchKeyword: '防災ラジオ 手回し 充電',
    perHousehold: 1,
  ),
  // --- 衛生 -------------------------------------------------------------
  StockpileItemSpec(
    id: 'portableToilet',
    category: StockpileCategory.sanitation,
    unit: StockpileUnit.times,
    searchKeyword: '簡易トイレ 携帯トイレ 防災',
    perPersonPerDay: toiletTimesPerPersonPerDay,
    expiryRelevant: true,
  ),
  StockpileItemSpec(
    id: 'toiletPaper',
    category: StockpileCategory.sanitation,
    unit: StockpileUnit.roll,
    searchKeyword: 'トイレットペーパー 備蓄',
    perPerson: 2,
  ),
  StockpileItemSpec(
    id: 'wetWipes',
    category: StockpileCategory.sanitation,
    unit: StockpileUnit.pack,
    searchKeyword: 'ウェットティッシュ 大容量 防災',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'garbageBags',
    category: StockpileCategory.sanitation,
    unit: StockpileUnit.sheet,
    searchKeyword: 'ゴミ袋 45L 防災',
    perPersonPerDay: 1,
  ),
  StockpileItemSpec(
    id: 'diapers',
    category: StockpileCategory.sanitation,
    unit: StockpileUnit.sheet,
    searchKeyword: '紙おむつ 備蓄',
    perPersonPerDay: 6,
    infantsOnly: true,
  ),
  // --- 救急・衛生用品 ---------------------------------------------------
  StockpileItemSpec(
    id: 'firstAidKit',
    category: StockpileCategory.firstAid,
    unit: StockpileUnit.set,
    searchKeyword: '救急セット 防災',
    perHousehold: 1,
  ),
  StockpileItemSpec(
    id: 'medicine',
    category: StockpileCategory.firstAid,
    unit: StockpileUnit.days,
    searchKeyword: '',
    perPersonPerDay: 1,
    expiryRelevant: true,
  ),
  StockpileItemSpec(
    id: 'mask',
    category: StockpileCategory.firstAid,
    unit: StockpileUnit.sheet,
    searchKeyword: 'マスク 不織布 箱',
    perPersonPerDay: 1,
  ),
  StockpileItemSpec(
    id: 'disinfectant',
    category: StockpileCategory.firstAid,
    unit: StockpileUnit.piece,
    searchKeyword: '消毒液 アルコール 携帯',
    perHousehold: 1,
    expiryRelevant: true,
  ),
  // --- 避難用 -----------------------------------------------------------
  StockpileItemSpec(
    id: 'backpack',
    category: StockpileCategory.evacuation,
    unit: StockpileUnit.piece,
    searchKeyword: '防災リュック 非常用持ち出し袋',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'blanket',
    category: StockpileCategory.evacuation,
    unit: StockpileUnit.piece,
    searchKeyword: 'アルミブランケット 防災',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'gloves',
    category: StockpileCategory.evacuation,
    unit: StockpileUnit.pair,
    searchKeyword: '軍手 作業用 防災',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'rope',
    category: StockpileCategory.evacuation,
    unit: StockpileUnit.piece,
    searchKeyword: 'ロープ 防災 多用途',
    perHousehold: 1,
  ),
  // --- 貴重品・情報 -----------------------------------------------------
  StockpileItemSpec(
    id: 'cash',
    category: StockpileCategory.valuables,
    unit: StockpileUnit.set,
    searchKeyword: '',
    perHousehold: 1,
  ),
  StockpileItemSpec(
    id: 'idCopy',
    category: StockpileCategory.valuables,
    unit: StockpileUnit.piece,
    searchKeyword: '',
    perPerson: 1,
  ),
  StockpileItemSpec(
    id: 'contactMemo',
    category: StockpileCategory.valuables,
    unit: StockpileUnit.piece,
    searchKeyword: '',
    perHousehold: 1,
  ),
  StockpileItemSpec(
    id: 'cable',
    category: StockpileCategory.valuables,
    unit: StockpileUnit.piece,
    searchKeyword: '充電ケーブル 3in1',
    perPerson: 1,
  ),
];

/// 品目の状態（チェック・期限）。カスタム項目は名称と必要数も持つ。
class StockpileEntry {
  StockpileEntry({
    required this.id,
    this.checked = false,
    this.expiry,
    this.customTitle,
    this.customCategory,
    this.customQuantity,
  });

  final String id;
  bool checked;

  /// 消費期限（**JSTの壁時計の日付**。時刻は持たない素のDateTime）
  DateTime? expiry;

  /// カスタム項目の名称（既定品目は null）
  final String? customTitle;
  final StockpileCategory? customCategory;
  final int? customQuantity;

  bool get isCustom => customTitle != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'checked': checked,
    if (expiry != null) 'expiry': formatDateKey(expiry!),
    if (customTitle != null) 'title': customTitle,
    if (customCategory != null) 'category': customCategory!.name,
    if (customQuantity != null) 'quantity': customQuantity,
  };

  static StockpileEntry? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    return StockpileEntry(
      id: id,
      checked: j['checked'] == true,
      expiry: parseDateKey(j['expiry'] as String?),
      customTitle: j['title'] as String?,
      customCategory: StockpileCategory.fromKey(j['category'] as String? ?? ''),
      customQuantity: (j['quantity'] as num?)?.toInt(),
    );
  }
}

/// `yyyy-MM-dd`（JSTの壁時計の日付。時刻を混ぜない）
String formatDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `yyyy-MM-dd` → 素のDateTime（時刻 00:00）。不正な値は null
DateTime? parseDateKey(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final v = DateTime(y, mo, d);
  if (v.month != mo || v.day != d) return null; // 2月30日などを弾く
  return v;
}

/// 期限の状態
enum ExpiryStatus { none, ok, soon, expired }

/// [expiry] が [now]（JSTの壁時計）から見てどの状態か。
/// 「1か月前」はカレンダー上の1か月（`DateTime(y, m - 1, d)`）で判定する。
ExpiryStatus expiryStatusOf(DateTime? expiry, DateTime now) {
  if (expiry == null) return ExpiryStatus.none;
  final today = startOfDay(asWallClock(now));
  final due = startOfDay(expiry);
  if (due.isBefore(today)) return ExpiryStatus.expired;
  final noticeFrom = DateTime(
    due.year,
    due.month - expiryReminderMonths,
    due.day,
  );
  return today.isBefore(noticeFrom) ? ExpiryStatus.ok : ExpiryStatus.soon;
}

/// 期限リマインドを出す日（期限の1か月前・JSTの壁時計の日付）
DateTime expiryReminderDate(DateTime expiry) =>
    DateTime(expiry.year, expiry.month - expiryReminderMonths, expiry.day);

/// チェックリスト全体の状態（SharedPreferences に JSON で保存する）。
class StockpileState {
  StockpileState({
    this.adults = 2,
    this.children = 0,
    this.infants = 0,
    this.days = defaultStockpileDays,
    Map<String, StockpileEntry>? entries,
    List<StockpileEntry>? customItems,
    Set<String>? removedItemIds,
    this.expiryReminderEnabled = false,
    this.inspectionReminderEnabled = false,
    List<String>? inspectionDays,
    this.lastOpenedAt,
  }) : entries = entries ?? <String, StockpileEntry>{},
       customItems = customItems ?? <StockpileEntry>[],
       removedItemIds = removedItemIds ?? <String>{},
       inspectionDays = inspectionDays ?? List.of(defaultInspectionDays);

  int adults;
  int children;

  /// 乳幼児（ミルク・おむつの対象）。[children] とは別に数える
  int infants;
  int days;

  /// 既定品目のID → 状態
  final Map<String, StockpileEntry> entries;

  /// ユーザーが追加した項目
  final List<StockpileEntry> customItems;

  /// ユーザーが削除した既定品目のID
  final Set<String> removedItemIds;

  bool expiryReminderEnabled;
  bool inspectionReminderEnabled;

  /// 点検日（`MM-dd`）
  final List<String> inspectionDays;

  /// 最後に「備え」画面を開いた日（JSTの壁時計の日付）。
  /// 点検日を過ぎてから開いていなければタブにバッジを出す
  DateTime? lastOpenedAt;

  /// チェックリストを使い始めているか（チェック・期限・カスタム項目のいずれかがある）
  bool get isInUse =>
      customItems.isNotEmpty ||
      entries.values.any((e) => e.checked || e.expiry != null);

  /// 表示する既定品目（削除済みと、乳幼児がいないときの乳幼児専用品目を除く）
  List<StockpileItemSpec> get visibleSpecs => [
    for (final s in defaultStockpileItems)
      if (!removedItemIds.contains(s.id) && !(s.infantsOnly && infants <= 0)) s,
  ];

  /// [spec] の状態（無ければ作って登録する）
  StockpileEntry entryOf(String id) =>
      entries.putIfAbsent(id, () => StockpileEntry(id: id));

  int requiredOf(StockpileItemSpec spec) => spec.requiredQuantity(
    adults: adults,
    children: children,
    infants: infants,
    days: days,
  );

  /// 必要量のめやす（サマリーカード用）
  int get totalWaterLiters =>
      (waterLitersPerPersonPerDay * (adults + children + infants) * days)
          .ceil();

  int get totalMeals =>
      (mealsPerPersonPerDay * (adults + children + infants) * days).ceil();

  /// 進捗（チェック済み / 全項目）
  (int done, int total) get progress {
    var done = 0;
    var total = 0;
    for (final s in visibleSpecs) {
      total++;
      if (entries[s.id]?.checked == true) done++;
    }
    for (final c in customItems) {
      total++;
      if (c.checked) done++;
    }
    return (done, total);
  }

  /// 期限が登録されている全項目（既定＋カスタム）
  List<StockpileEntry> get datedEntries => [
    for (final s in visibleSpecs)
      if (entries[s.id]?.expiry != null) entries[s.id]!,
    for (final c in customItems)
      if (c.expiry != null) c,
  ];

  Map<String, dynamic> toJson() => {
    'version': 1,
    'adults': adults,
    'children': children,
    'infants': infants,
    'days': days,
    'entries': [
      for (final e in entries.values)
        if (e.checked || e.expiry != null) e.toJson(),
    ],
    'custom': [for (final c in customItems) c.toJson()],
    'removed': removedItemIds.toList()..sort(),
    'expiryReminder': expiryReminderEnabled,
    'inspectionReminder': inspectionReminderEnabled,
    'inspectionDays': inspectionDays,
    if (lastOpenedAt != null) 'lastOpened': formatDateKey(lastOpenedAt!),
  };

  static StockpileState fromJson(Map<String, dynamic> j) {
    final entries = <String, StockpileEntry>{};
    for (final raw in (j['entries'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final e = StockpileEntry.fromJson(raw.cast<String, dynamic>());
      if (e != null) entries[e.id] = e;
    }
    final custom = <StockpileEntry>[];
    for (final raw in (j['custom'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final e = StockpileEntry.fromJson(raw.cast<String, dynamic>());
      if (e != null && e.isCustom) custom.add(e);
    }
    final days = (j['days'] as num?)?.toInt() ?? defaultStockpileDays;
    return StockpileState(
      adults: ((j['adults'] as num?)?.toInt() ?? 2).clamp(1, 20),
      children: ((j['children'] as num?)?.toInt() ?? 0).clamp(0, 20),
      infants: ((j['infants'] as num?)?.toInt() ?? 0).clamp(0, 20),
      days: stockpileDayOptions.contains(days) ? days : defaultStockpileDays,
      entries: entries,
      customItems: custom,
      removedItemIds: {
        for (final r in (j['removed'] as List? ?? const []))
          if (r is String) r,
      },
      expiryReminderEnabled: j['expiryReminder'] == true,
      inspectionReminderEnabled: j['inspectionReminder'] == true,
      inspectionDays:
          [
            for (final d in (j['inspectionDays'] as List? ?? const []))
              if (d is String && RegExp(r'^\d{2}-\d{2}$').hasMatch(d)) d,
          ].isEmpty
          ? List.of(defaultInspectionDays)
          : [
              for (final d in (j['inspectionDays'] as List))
                if (d is String && RegExp(r'^\d{2}-\d{2}$').hasMatch(d)) d,
            ],
      lastOpenedAt: parseDateKey(j['lastOpened'] as String?),
    );
  }
}

/// SharedPreferences への保存・復元。
/// 「備え」タブのバッジに使う注意の内訳
class StockpileAlerts {
  const StockpileAlerts({required this.expiring, required this.inspectionDue});

  /// 期限まで1か月以内・期限切れの品目数
  final int expiring;

  /// 点検日を過ぎてから画面を開いていない
  final bool inspectionDue;

  int get count => expiring + (inspectionDue ? 1 : 0);
}

/// `MM-dd` の一覧のうち、[now]（JSTの壁時計）以前で最も新しい到来日
DateTime? lastInspectionDate(List<String> inspectionDays, DateTime now) {
  final today = startOfDay(asWallClock(now));
  DateTime? latest;
  for (final md in inspectionDays) {
    final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(md);
    if (m == null) continue;
    final mo = int.parse(m.group(1)!);
    final d = int.parse(m.group(2)!);
    for (final year in [today.year, today.year - 1]) {
      final at = DateTime(year, mo, d);
      if (at.month != mo || at.day != d) continue;
      if (at.isAfter(today)) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
      break;
    }
  }
  return latest;
}

/// タブのバッジに出す注意を数える（純関数）。
/// - 期限: 1か月以内・期限切れの品目（期限を更新するまで残る）
/// - 点検日: 使い始めている（または点検通知ON）世帯で、直近の点検日より後に
///   画面を開いていない場合（開けば消える）
StockpileAlerts computeStockpileAlerts(StockpileState s, DateTime now) {
  var expiring = 0;
  for (final e in s.datedEntries) {
    final st = expiryStatusOf(e.expiry, now);
    if (st == ExpiryStatus.soon || st == ExpiryStatus.expired) expiring++;
  }
  var inspectionDue = false;
  if (s.inspectionReminderEnabled || s.isInUse) {
    final last = lastInspectionDate(s.inspectionDays, now);
    if (last != null) {
      final opened = s.lastOpenedAt;
      inspectionDue = opened == null || startOfDay(opened).isBefore(last);
    }
  }
  return StockpileAlerts(expiring: expiring, inspectionDue: inspectionDue);
}

class _StockpileChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}

class StockpileStore {
  static const prefsKey = 'stockpile_v1';

  /// 保存・消去のたびに通知する（HomeShell がタブのバッジを更新するため）
  static final _StockpileChanges _changes = _StockpileChanges();
  static Listenable get changes => _changes;

  /// 保存済みの状態を読む（未保存・壊れていれば既定値）
  static Future<StockpileState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(prefsKey));
  }

  static Future<void> save(StockpileState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(state.toJson()));
    _changes.notify();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    _changes.notify();
  }

  /// JSON文字列 → 状態（テストしやすいように分離）
  static StockpileState decode(String? raw) {
    if (raw == null || raw.isEmpty) return StockpileState();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return StockpileState();
      return StockpileState.fromJson(j.cast<String, dynamic>());
    } catch (_) {
      return StockpileState();
    }
  }

  static String encode(StockpileState state) => jsonEncode(state.toJson());
}
