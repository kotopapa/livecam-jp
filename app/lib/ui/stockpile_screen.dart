import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart' show VcMerchant;
import '../data/affiliate.dart';
import '../data/stockpile.dart';
import '../data/stockpile_products.dart';
import '../data/stockpile_reminders.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';

/// 出典リンク（コード内コメントの根拠と同じURL）
const _sourceMaffUrl = 'https://www.maff.go.jp/j/zyukyu/foodstock/';
const _sourceCaoUrl =
    'https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html';

/// 防災の備え（備蓄チェックリスト）。
///
/// - 世帯人数と備蓄日数から必要量を自動計算する（根拠は `data/stockpile.dart`）
/// - 項目ごとにチェック・消費期限を持ち、期限の1か月前と点検日にローカル通知
/// - 品目をタップすると詳細シートが開き、チェック・期限の登録・選び方のポイント・
///   定番の製品・提携ショップの検索・削除を1か所で行える（1.4.1。以前は「探す」
///   ボタンと「⋮」メニューに分かれていて見つけにくかった）。商品は配信JSON
///   `data/stockpile_products.dart`。必ず外部ブラウザで開き、シートと画面下部に
///   アフィリエイトの明示を置く
/// - 広告は HomeShell の下部固定バナー（この画面には置かない）
class StockpileScreen extends StatefulWidget {
  const StockpileScreen({
    super.key,
    required this.app,
    this.productsRepository,
    this.visible,
  });

  final AppState app;

  /// 商品データの取得元（テストで差し替える。省略時は配信JSONを見る）
  final StockpileProductsRepository? productsRepository;

  /// タブとして表示中か（HomeShell が渡す）。表示されたら「開いた日」を記録し、
  /// 点検日のバッジを消す
  final ValueNotifier<bool>? visible;

  @override
  State<StockpileScreen> createState() => _StockpileScreenState();
}

class _StockpileScreenState extends State<StockpileScreen> {
  final _reminders = StockpileReminderService();
  StockpileState? _state;

  /// 配信JSONの「選び方」と定番商品。取得できないうちは null
  /// （アプリ内の検索語にフォールバックするので画面は成立する）
  StockpileProducts? _products;

  @override
  void initState() {
    super.initState();
    StockpileStore.load().then((s) {
      if (!mounted) return;
      setState(() => _state = s);
      _markOpenedIfVisible();
    });
    widget.visible?.addListener(_markOpenedIfVisible);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    var repo = widget.productsRepository;
    if (repo == null) {
      Directory? dir;
      try {
        dir = await getTemporaryDirectory();
      } catch (_) {
        dir = null;
      }
      repo = StockpileProductsRepository(cacheDir: dir);
    }
    final p = await repo.load();
    if (mounted && p != null) setState(() => _products = p);
  }

  @override
  void dispose() {
    widget.visible?.removeListener(_markOpenedIfVisible);
    super.dispose();
  }

  /// 画面が見えたら「開いた日」を今日にして保存する（点検日バッジの解除）
  void _markOpenedIfVisible() {
    final s = _state;
    if (s == null || !(widget.visible?.value ?? true)) return;
    final today = startOfDay(jstNow());
    if (s.lastOpenedAt != null &&
        !startOfDay(s.lastOpenedAt!).isBefore(today)) {
      return;
    }
    s.lastOpenedAt = today;
    _save();
  }

  Future<void> _save() async {
    final s = _state;
    if (s == null) return;
    await StockpileStore.save(s);
  }

  /// 保存＋通知の予約し直し（設定・期限が変わったとき）
  Future<void> _saveAndReschedule() async {
    final s = _state;
    if (s == null) return;
    await _save();
    if (!s.expiryReminderEnabled && !s.inspectionReminderEnabled) {
      await _reminders.cancelAll();
      return;
    }
    if (!mounted) return;
    final l10n = context.l10n;
    await _reminders.reschedule(s, text: (r) => _reminderText(l10n, r));
  }

  /// 通知の文言（予約時の表示言語で作る。言語を変えたら次に開いたときに直る）
  ReminderText _reminderText(AppLocalizations l10n, StockpileReminder r) {
    if (r.kind == ReminderKind.inspection) {
      return (
        title: l10n.stockpileNotifyTitle,
        body: l10n.stockpileNotifyInspectionBody,
      );
    }
    String nameOf(ReminderItem it) =>
        it.customTitle ??
        (it.itemId == null ? null : stockpileItemNameOf(l10n, it.itemId!)) ??
        l10n.stockpileTitle;
    final date = r.expiry == null ? '' : formatDateKey(r.expiry!);
    // 同じ日に複数の品目 → 1通に列挙（4件目以降は「ほかN件」）
    if (r.items.length > 1) {
      const shown = 3;
      final names = r.items.take(shown).map(nameOf).toList();
      if (r.items.length > shown) {
        names.add(l10n.stockpileNotifyMoreItems(r.items.length - shown));
      }
      return (
        title: l10n.stockpileNotifyTitle,
        body: l10n.stockpileNotifyExpiryBodyMany(
          names.join(l10n.stockpileNotifyNameSeparator),
          date,
        ),
      );
    }
    final name = r.items.isNotEmpty
        ? nameOf(r.items.first)
        : nameOf(
            ReminderItem(
              itemId: r.itemId,
              customTitle: r.customTitle,
              expiry: r.expiry ?? DateTime(2000),
            ),
          );
    return (
      title: l10n.stockpileNotifyTitle,
      body: l10n.stockpileNotifyExpiryBody(name, date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _state;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockpileTitle),
        actions: [
          if (s != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reset') _confirmReset();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'reset', child: Text(l10n.stockpileReset)),
              ],
            ),
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: widget.app,
              builder: (context, _) => _buildList(l10n, s),
            ),
    );
  }

  Widget _buildList(AppLocalizations l10n, StockpileState s) {
    final (done, total) = s.progress;
    final customByCategory = <StockpileCategory, List<StockpileEntry>>{};
    for (final c in s.customItems) {
      customByCategory
          .putIfAbsent(
            c.customCategory ?? StockpileCategory.valuables,
            () => [],
          )
          .add(c);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _householdCard(l10n, s),
        _summaryCard(l10n, s),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.stockpileProgress(done, total),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.stockpileItemTapHint,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _reminderCard(l10n, s),
        for (final category in StockpileCategory.values) ...[
          _sectionHeader(stockpileCategoryNameOf(l10n, category)),
          for (final spec in s.visibleSpecs.where(
            (x) => x.category == category,
          ))
            _specRow(l10n, s, spec),
          for (final custom in customByCategory[category] ?? const [])
            _customRow(l10n, s, custom),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: Text(l10n.stockpileAddItem),
          ),
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.stockpileDisclaimer,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.commonSource}:',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _sourceLink(l10n.stockpileSourceCao, _sourceCaoUrl),
              _sourceLink(l10n.stockpileSourceMaff, _sourceMaffUrl),
              const SizedBox(height: 12),
              // 景表法のステマ規制対応。商品リンクのある画面に必須の明示
              Text(
                l10n.stockpileAffiliateNotice,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _sourceLink(String label, String url) => InkWell(
    onTap: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
        ],
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // 世帯人数・必要量
  // -------------------------------------------------------------------------

  Widget _householdCard(AppLocalizations l10n, StockpileState s) => Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stockpileHouseholdTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _counterRow(
            l10n.stockpileAdults,
            s.adults,
            1,
            20,
            (v) => setState(() => s.adults = v),
          ),
          _counterRow(
            l10n.stockpileChildren,
            s.children,
            0,
            20,
            (v) => setState(() => s.children = v),
          ),
          _counterRow(
            l10n.stockpileInfants,
            s.infants,
            0,
            20,
            (v) => setState(() => s.infants = v),
          ),
          const SizedBox(height: 8),
          Text(l10n.stockpileDaysLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final d in stockpileDayOptions)
                ChoiceChip(
                  label: Text(l10n.stockpileDaysValue(d)),
                  selected: s.days == d,
                  onSelected: (_) {
                    setState(() => s.days = d);
                    _save();
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );

  /// 通知の設定。一覧の最下部にあると気づかれないため上に置き、
  /// チェックリストを押し下げないようチップ2つのコンパクトなカードにする
  Widget _reminderCard(AppLocalizations l10n, StockpileState s) => Card(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.stockpileSectionReminder,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                avatar: const Icon(Icons.event_available_outlined, size: 16),
                label: Text(
                  l10n.stockpileExpiryReminder,
                  style: const TextStyle(fontSize: 12),
                ),
                tooltip: l10n.stockpileExpiryReminderSubtitle,
                selected: s.expiryReminderEnabled,
                onSelected: (v) => _setReminder(expiry: v),
              ),
              FilterChip(
                avatar: const Icon(Icons.fact_check_outlined, size: 16),
                label: Text(
                  l10n.stockpileInspectionReminder,
                  style: const TextStyle(fontSize: 12),
                ),
                tooltip: l10n.stockpileInspectionReminderSubtitle,
                selected: s.inspectionReminderEnabled,
                onSelected: (v) => _setReminder(inspection: v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.expiryReminderEnabled
                ? l10n.stockpileExpiryReminderSubtitle
                : l10n.stockpileInspectionReminderSubtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    ),
  );

  Widget _counterRow(
    String label,
    int value,
    int min,
    int max,
    void Function(int) onChanged,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: value <= min
            ? null
            : () {
                onChanged(value - 1);
                _save();
              },
      ),
      SizedBox(
        width: 32,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: value >= max
            ? null
            : () {
                onChanged(value + 1);
                _save();
              },
      ),
    ],
  );

  Widget _summaryCard(AppLocalizations l10n, StockpileState s) => Card(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    color: const Color(0xFFF1F6FF),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stockpileSummaryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, size: 20),
              const SizedBox(width: 6),
              Text(
                l10n.stockpileSummaryWater(s.totalWaterLiters),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.restaurant, size: 20),
              const SizedBox(width: 6),
              Text(
                l10n.stockpileSummaryMeals(s.totalMeals),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.stockpileSummaryNote,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // 品目の行
  // -------------------------------------------------------------------------

  Widget _specRow(
    AppLocalizations l10n,
    StockpileState s,
    StockpileItemSpec spec,
  ) {
    final entry = s.entryOf(spec.id);
    final name = stockpileItemNameOf(l10n, spec.id) ?? spec.id;
    return _itemRow(
      l10n: l10n,
      entry: entry,
      name: name,
      requiredLabel: l10n.stockpileRequired(
        '${s.requiredOf(spec)}',
        stockpileUnitNameOf(l10n, spec.unit),
      ),
      itemId: spec.id,
      searchKeyword: spec.searchKeyword,
      purchasable: spec.purchasable,
      // 既定の品目は削除できない（削除はカスタム項目だけ。2026-09-01 ユーザー決定）
      onDelete: null,
    );
  }

  Widget _customRow(
    AppLocalizations l10n,
    StockpileState s,
    StockpileEntry custom,
  ) {
    final name = custom.customTitle ?? '';
    return _itemRow(
      l10n: l10n,
      entry: custom,
      name: name,
      requiredLabel: custom.customQuantity == null
          ? null
          : l10n.stockpileRequired(
              '${custom.customQuantity}',
              stockpileUnitNameOf(l10n, StockpileUnit.piece),
            ),
      itemId: null,
      searchKeyword: name,
      isCustom: true,
      onDelete: () {
        setState(() => s.customItems.remove(custom));
        _saveAndReschedule();
        _showRemoved(l10n, name, () {
          setState(() => s.customItems.add(custom));
          _saveAndReschedule();
        });
      },
    );
  }

  Widget _itemRow({
    required AppLocalizations l10n,
    required StockpileEntry entry,
    required String name,
    required String? requiredLabel,
    required String? itemId,
    required String searchKeyword,
    required VoidCallback? onDelete,
    bool isCustom = false,
    bool purchasable = true,
  }) {
    final status = expiryStatusOf(entry.expiry, jstNow());
    // 行のどこを押しても詳細シート（期限・選び方・購入先・削除）が開く
    return InkWell(
      onTap: () => _openItemSheet(
        entry: entry,
        name: name,
        requiredLabel: requiredLabel,
        itemId: itemId,
        searchKeyword: searchKeyword,
        purchasable: purchasable,
        onDelete: onDelete,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: entry.checked,
              onChanged: (v) {
                setState(() => entry.checked = v ?? false);
                _save();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: entry.checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: entry.checked ? Colors.grey[600] : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      if (requiredLabel != null)
                        _chip(requiredLabel, const Color(0xFF616E7C)),
                      if (entry.expiry != null)
                        _chip(
                          switch (status) {
                            ExpiryStatus.expired => l10n.stockpileExpired,
                            ExpiryStatus.soon => l10n.stockpileExpirySoon,
                            _ => l10n.stockpileExpiryOn(
                              formatDateKey(entry.expiry!),
                            ),
                          },
                          switch (status) {
                            ExpiryStatus.expired => const Color(0xFFD93025),
                            ExpiryStatus.soon => const Color(0xFFE8710A),
                            _ => const Color(0xFF616E7C),
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[500]),
            // 提携ショップのロゴ。押すとその店の検索結果へ直接飛ぶ（外部ブラウザ）。
            // 承認済みの店舗だけ並ぶ（config.dart の vcMerchants）
            if (purchasable && AffiliateLinks.isAvailable)
              for (final m in AffiliateLinks.enabledMerchants)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _MerchantLogoButton(
                    merchant: m,
                    tooltip: l10n.stockpileGuideSearchAt(m.name),
                    onTap: () => _searchAt(m, itemId, searchKeyword),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );

  // -------------------------------------------------------------------------
  // 操作
  // -------------------------------------------------------------------------

  void _showRemoved(AppLocalizations l10n, String name, VoidCallback undo) {
    if (!mounted) return;
    const duration = Duration(seconds: 5);
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.stockpileDeleted(name)),
        duration: duration,
        action: SnackBarAction(label: l10n.stockpileUndo, onPressed: undo),
      ),
    );
    // 操作ボタン付きの SnackBar は端末のアクセシビリティ操作が有効だと
    // 自動で閉じない（Flutter の仕様）。設定に関係なく数秒で必ず閉じる
    Future<void>.delayed(duration, controller.close);
  }

  Future<void> _pickExpiry(StockpileEntry entry) async {
    // 期限は「JSTの壁時計の日付」。端末TZに関係なく日本時間の日付で扱う
    final today = startOfDay(jstNow());
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.expiry ?? addDays(today, 180),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 30),
    );
    if (picked == null || !mounted) return;
    setState(
      () => entry.expiry = DateTime(picked.year, picked.month, picked.day),
    );
    await _saveAndReschedule();
  }

  Future<void> _setReminder({bool? expiry, bool? inspection}) async {
    final s = _state;
    if (s == null) return;
    final turningOn = (expiry ?? false) || (inspection ?? false);
    if (turningOn) {
      // この機能を使うときに初めて通知許可を求める（起動時には求めない）
      final ok = await _reminders.requestPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.stockpileNotifyDenied)),
          );
        }
        return;
      }
    }
    setState(() {
      if (expiry != null) s.expiryReminderEnabled = expiry;
      if (inspection != null) s.inspectionReminderEnabled = inspection;
    });
    await _saveAndReschedule();
  }

  Future<void> _addItem() async {
    final result = await showDialog<_NewItem>(
      context: context,
      builder: (context) => const _AddItemDialog(),
    );
    final s = _state;
    if (result == null || s == null) return;
    setState(() {
      s.customItems.add(
        StockpileEntry(
          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
          customTitle: result.name,
          customCategory: result.category,
          customQuantity: result.quantity,
        ),
      );
    });
    await _save();
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stockpileReset),
        content: Text(l10n.stockpileResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StockpileStore.clear();
    await _reminders.cancelAll();
    if (mounted) setState(() => _state = StockpileState());
  }

  /// [merchant] で品目を検索する（配信JSONの店舗別検索語を優先）
  Future<void> _searchAt(
    VcMerchant merchant,
    String? itemId,
    String fallbackKeyword,
  ) async {
    final guide = itemId == null ? null : _products?.guideFor(itemId);
    final kw = guide?.keywordFor(merchant.key) ?? fallbackKeyword;
    final url = AffiliateLinks.searchLink(kw, merchant);
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// 品目の詳細シート。チェック・消費期限・選び方・定番の製品・提携ショップの
  /// 検索・削除を1か所に集める。アフィリエイトのリンクは規約への配慮から
  /// **必ず外部ブラウザ**で開く
  Future<void> _openItemSheet({
    required StockpileEntry entry,
    required String name,
    required String? requiredLabel,
    required String? itemId,
    required String searchKeyword,
    required VoidCallback? onDelete,
    bool purchasable = true,
  }) async {
    final l10n = context.l10n;
    final guide = itemId == null ? null : _products?.guideFor(itemId);
    final products = _products;
    // 現金・書類の写しなど「買うものではない」品目にはショップ検索を出さない
    final merchants = purchasable && AffiliateLinks.isAvailable
        ? AffiliateLinks.enabledMerchants
        : const <VcMerchant>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocal) {
          // シート内の表示と背後の一覧を両方更新する
          void refresh() {
            setLocal(() {});
            if (mounted) setState(() {});
          }

          final status = expiryStatusOf(entry.expiry, jstNow());
          final expiryColor = switch (status) {
            ExpiryStatus.expired => const Color(0xFFD93025),
            ExpiryStatus.soon => const Color(0xFFE8710A),
            _ => null,
          };
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  guide != null && guide.name.isNotEmpty ? guide.name : name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (requiredLabel != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _chip(requiredLabel, const Color(0xFF616E7C)),
                  ),
                ],
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: entry.checked,
                  title: Text(l10n.stockpileMarkPrepared),
                  onChanged: (v) {
                    entry.checked = v ?? false;
                    _save();
                    refresh();
                  },
                ),
                _sheetHeader(l10n.stockpileSectionExpiry),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_outlined, color: expiryColor),
                  title: Text(
                    entry.expiry == null
                        ? l10n.stockpileExpirySet
                        : l10n.stockpileExpiryOn(formatDateKey(entry.expiry!)),
                    style: TextStyle(color: expiryColor),
                  ),
                  subtitle: switch (status) {
                    ExpiryStatus.expired => Text(
                      l10n.stockpileExpired,
                      style: TextStyle(color: expiryColor),
                    ),
                    ExpiryStatus.soon => Text(
                      l10n.stockpileExpirySoon,
                      style: TextStyle(color: expiryColor),
                    ),
                    _ => null,
                  },
                  trailing: entry.expiry == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.stockpileExpiryClear,
                          onPressed: () {
                            entry.expiry = null;
                            _saveAndReschedule();
                            refresh();
                          },
                        ),
                  onTap: () async {
                    await _pickExpiry(entry);
                    refresh();
                  },
                ),
                if (guide != null) ...[
                  if (guide.cert case final cert?) ...[
                    const SizedBox(height: 8),
                    _certBadge(cert),
                  ],
                  if (guide.spec.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(guide.spec, style: const TextStyle(fontSize: 13)),
                  ],
                  if (guide.why.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sheetHeader(l10n.stockpileGuideWhy),
                    Text(
                      guide.why,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                  if (guide.products.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sheetHeader(l10n.stockpileGuideProducts),
                    for (final pr in guide.products) _productRow(l10n, pr),
                    const SizedBox(height: 4),
                    Text(
                      l10n.stockpileGuideProductsNote,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ],
                if (merchants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sheetHeader(l10n.stockpileGuideSearch),
                  for (final m in merchants)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _searchAt(m, itemId, searchKeyword),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                        ),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l10n.stockpileGuideSearchAt(m.name)),
                        ),
                      ),
                    ),
                ],
                if (guide != null && guide.sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sheetHeader(l10n.stockpileGuideSources),
                  for (final src in guide.sources)
                    _sourceLink(src.name, src.url),
                ],
                const SizedBox(height: 14),
                if (products != null && products.disclaimer.isNotEmpty)
                  Text(
                    products.disclaimer,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                if (merchants.isNotEmpty ||
                    (guide?.products.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  // 景表法のステマ規制対応。商品リンクのある画面に必須の明示
                  Text(
                    products != null && products.notice.isNotEmpty
                        ? products.notice
                        : l10n.stockpileAffiliateNotice,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
                // 削除はカスタム項目だけ（既定の品目には出さない）
                if (onDelete != null) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onDelete();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD93025),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(l10n.stockpileDeleteItem),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// 定番商品の1行。タイトルと店舗ロゴは提携ショップでの商品検索（アフィリエイト）へ、
  /// 公式ページは行末の小さなリンクで残す。提携先が無ければ従来どおり公式ページへ
  Widget _productRow(AppLocalizations l10n, ProductRef pr) {
    final merchants = AffiliateLinks.isAvailable
        ? AffiliateLinks.productMerchants(pr)
        : const <VcMerchant>[];
    Future<void> open(Uri? url) async {
      if (url == null) return;
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    final official = Uri.tryParse(pr.url);
    return InkWell(
      onTap: () => open(
        merchants.isEmpty
            ? official
            : AffiliateLinks.productLink(pr, merchants.first),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(pr.title, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 6),
            for (final m in merchants)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _MerchantLogoButton(
                  merchant: m,
                  tooltip: l10n.stockpileGuideSearchAt(m.name),
                  onTap: () => open(AffiliateLinks.productLink(pr, m)),
                ),
              ),
            if (official != null && pr.shop == 'official')
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 16),
                tooltip: l10n.stockpileOfficialSite,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => open(official),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );

  /// 認証・規格のバッジ。URLがあれば公式ページへ飛ばす
  Widget _certBadge(ProductCert cert) {
    final no = cert.no;
    final label = no == null || no.isEmpty ? cert.name : '${cert.name}（$no）';
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 14,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
    final url = cert.url;
    if (url == null || url.isEmpty) {
      return Align(alignment: Alignment.centerLeft, child: badge);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: badge,
      ),
    );
  }
}

/// 提携ショップのロゴ風ボタン（行末に並べる小さな正方形）。
///
/// 公式ロゴ画像は同梱していないため、各社のブランド色を使ったワードマークで描く。
/// 店舗が増えても config.dart の `key` で色と表記を引く（未知のキーは頭文字）
class _MerchantLogoButton extends StatelessWidget {
  const _MerchantLogoButton({
    required this.merchant,
    required this.tooltip,
    required this.onTap,
  });

  final VcMerchant merchant;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text, size) = switch (merchant.key) {
      'amazon' => (const Color(0xFF232F3E), const Color(0xFFFF9900), 'a', 15.0),
      'rakuten' => (const Color(0xFFBF0000), Colors.white, 'R', 15.0),
      'yahoo' => (const Color(0xFFFF0033), Colors.white, 'Y!', 12.0),
      _ => (
        Theme.of(context).colorScheme.primary,
        Colors.white,
        merchant.name.isEmpty ? '?' : merchant.name[0],
        13.0,
      ),
    };
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「項目を追加」ダイアログの入力結果
typedef _NewItem = ({String name, int? quantity, StockpileCategory category});

/// 「項目を追加」ダイアログ。
///
/// TextEditingController はこのウィジェットが所有して dispose する。
/// 以前は呼び出し側が pop 直後に dispose していたため、閉じるアニメーション中の
/// TextField が破棄済みコントローラを参照して assertion が出ていた
class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  StockpileCategory _category = StockpileCategory.valuables;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim());
    Navigator.of(context).pop((
      name: name,
      quantity: (qty == null || qty <= 0) ? null : qty,
      category: _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.stockpileAddItem),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.stockpileItemNameLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.stockpileItemQuantityLabel,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<StockpileCategory>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: l10n.stockpileItemCategoryLabel,
            ),
            items: [
              for (final c in StockpileCategory.values)
                DropdownMenuItem(
                  value: c,
                  child: Text(stockpileCategoryNameOf(l10n, c)),
                ),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonOk)),
      ],
    );
  }
}
