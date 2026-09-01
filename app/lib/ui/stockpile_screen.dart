import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdSize;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../data/affiliate.dart';
import '../data/stockpile.dart';
import '../data/stockpile_products.dart';
import '../data/stockpile_reminders.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';
import 'ad_banner.dart';

/// 出典リンク（コード内コメントの根拠と同じURL）
const _sourceMaffUrl = 'https://www.maff.go.jp/j/zyukyu/foodstock/';
const _sourceCaoUrl =
    'https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html';

/// 防災の備え（備蓄チェックリスト）。
///
/// - 世帯人数と備蓄日数から必要量を自動計算する（根拠は `data/stockpile.dart`）
/// - 項目ごとにチェック・消費期限を持ち、期限の1か月前と点検日にローカル通知
/// - 「探す」から選び方のポイント・定番の製品・提携ショップの検索を折りたたみで開く
///   （商品は配信JSON `data/stockpile_products.dart`。必ず外部ブラウザで開き、
///   シートと画面下部にアフィリエイトの明示を置く）
class StockpileScreen extends StatefulWidget {
  const StockpileScreen({super.key, required this.app, this.productsRepository});

  final AppState app;

  /// 商品データの取得元（テストで差し替える。省略時は配信JSONを見る）
  final StockpileProductsRepository? productsRepository;

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
      if (mounted) setState(() => _state = s);
    });
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
    final name = r.customTitle ??
        (r.itemId == null ? null : stockpileItemNameOf(l10n, r.itemId!)) ??
        l10n.stockpileTitle;
    return (
      title: l10n.stockpileNotifyTitle,
      body: l10n.stockpileNotifyExpiryBody(
          name, r.expiry == null ? '' : formatDateKey(r.expiry!)),
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
          .putIfAbsent(c.customCategory ?? StockpileCategory.valuables, () => [])
          .add(c);
    }
    // 広告はリストの途中（2カテゴリ目の後）に1つだけ。
    // 特別警報の発表中は防災アプリとして出さない（既存の規則に合わせる）
    const adAfter = StockpileCategory.lightPower;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _householdCard(l10n, s),
        _summaryCard(l10n, s),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.stockpileProgress(done, total),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total, minHeight: 6),
            ),
          ]),
        ),
        for (final category in StockpileCategory.values) ...[
          _sectionHeader(stockpileCategoryNameOf(l10n, category)),
          for (final spec in s.visibleSpecs.where((x) => x.category == category))
            _specRow(l10n, s, spec),
          for (final custom in customByCategory[category] ?? const [])
            _customRow(l10n, s, custom),
          if (category == adAfter && !widget.app.specialWarningActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AdBannerPlaceholder(
                  size: AdSize.mediumRectangle, adUnitId: admobRectangleUnitId),
            ),
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
        _sectionHeader(l10n.stockpileSectionReminder),
        SwitchListTile(
          secondary: const Icon(Icons.event_available_outlined),
          title: Text(l10n.stockpileExpiryReminder),
          subtitle: Text(l10n.stockpileExpiryReminderSubtitle),
          value: s.expiryReminderEnabled,
          onChanged: (v) => _setReminder(expiry: v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_none),
          title: Text(l10n.stockpileInspectionReminder),
          subtitle: Text(l10n.stockpileInspectionReminderSubtitle),
          value: s.inspectionReminderEnabled,
          onChanged: (v) => _setReminder(inspection: v),
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.stockpileDisclaimer,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('${l10n.commonSource}:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            _sourceLink(l10n.stockpileSourceCao, _sourceCaoUrl),
            _sourceLink(l10n.stockpileSourceMaff, _sourceMaffUrl),
            const SizedBox(height: 12),
            // 景表法のステマ規制対応。商品リンクのある画面に必須の明示
            Text(l10n.stockpileAffiliateNotice,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ]),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );

  Widget _sourceLink(String label, String url) => InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.blue))),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
          ]),
        ),
      );

  // -------------------------------------------------------------------------
  // 世帯人数・必要量
  // -------------------------------------------------------------------------

  Widget _householdCard(AppLocalizations l10n, StockpileState s) => Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.stockpileHouseholdTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _counterRow(l10n.stockpileAdults, s.adults, 1, 20,
                (v) => setState(() => s.adults = v)),
            _counterRow(l10n.stockpileChildren, s.children, 0, 20,
                (v) => setState(() => s.children = v)),
            const SizedBox(height: 8),
            Text(l10n.stockpileDaysLabel, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              for (final d in stockpileDayOptions)
                ChoiceChip(
                  label: Text(l10n.stockpileDaysValue(d)),
                  selected: s.days == d,
                  onSelected: (_) {
                    setState(() => s.days = d);
                    _save();
                  },
                ),
            ]),
          ]),
        ),
      );

  Widget _counterRow(String label, int value, int min, int max,
          void Function(int) onChanged) =>
      Row(children: [
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
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      ]);

  Widget _summaryCard(AppLocalizations l10n, StockpileState s) => Card(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        color: const Color(0xFFF1F6FF),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.stockpileSummaryTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.water_drop_outlined, size: 20),
              const SizedBox(width: 6),
              Text(l10n.stockpileSummaryWater(s.totalWaterLiters),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const Icon(Icons.restaurant, size: 20),
              const SizedBox(width: 6),
              Text(l10n.stockpileSummaryMeals(s.totalMeals),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Text(l10n.stockpileSummaryNote,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ]),
        ),
      );

  // -------------------------------------------------------------------------
  // 品目の行
  // -------------------------------------------------------------------------

  Widget _specRow(
      AppLocalizations l10n, StockpileState s, StockpileItemSpec spec) {
    final entry = s.entryOf(spec.id);
    final name = stockpileItemNameOf(l10n, spec.id) ?? spec.id;
    return _itemRow(
      l10n: l10n,
      entry: entry,
      name: name,
      requiredLabel: l10n.stockpileRequired(
          '${s.requiredOf(spec)}', stockpileUnitNameOf(l10n, spec.unit)),
      itemId: spec.id,
      searchKeyword: spec.searchKeyword,
      onDelete: () => _deleteSpec(s, spec, name),
    );
  }

  Widget _customRow(
      AppLocalizations l10n, StockpileState s, StockpileEntry custom) {
    final name = custom.customTitle ?? '';
    return _itemRow(
      l10n: l10n,
      entry: custom,
      name: name,
      requiredLabel: custom.customQuantity == null
          ? null
          : l10n.stockpileRequired('${custom.customQuantity}',
              stockpileUnitNameOf(l10n, StockpileUnit.piece)),
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
    required VoidCallback onDelete,
    bool isCustom = false,
  }) {
    final status = expiryStatusOf(entry.expiry, jstNow());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Checkbox(
          value: entry.checked,
          onChanged: (v) {
            setState(() => entry.checked = v ?? false);
            _save();
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    fontSize: 14,
                    decoration:
                        entry.checked ? TextDecoration.lineThrough : null,
                    color: entry.checked ? Colors.grey[600] : null)),
            const SizedBox(height: 2),
            Wrap(spacing: 6, runSpacing: 2, children: [
              if (requiredLabel != null)
                _chip(requiredLabel, const Color(0xFF616E7C)),
              if (entry.expiry != null)
                _chip(
                    switch (status) {
                      ExpiryStatus.expired => l10n.stockpileExpired,
                      ExpiryStatus.soon => l10n.stockpileExpirySoon,
                      _ => l10n.stockpileExpiryOn(formatDateKey(entry.expiry!)),
                    },
                    switch (status) {
                      ExpiryStatus.expired => const Color(0xFFD93025),
                      ExpiryStatus.soon => const Color(0xFFE8710A),
                      _ => const Color(0xFF616E7C),
                    }),
            ]),
            const SizedBox(height: 4),
          ]),
        ),
        if (AffiliateLinks.isAvailable)
          TextButton(
            onPressed: () => _openGuide(itemId, name, searchKeyword),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.search, size: 16),
              const SizedBox(width: 2),
              Text(l10n.stockpileSearchButton,
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) {
            switch (v) {
              case 'expiry':
                _pickExpiry(entry);
              case 'clear':
                setState(() => entry.expiry = null);
                _saveAndReschedule();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'expiry',
                child: Text(entry.expiry == null
                    ? l10n.stockpileExpirySet
                    : l10n.stockpileExpiryOn(formatDateKey(entry.expiry!)))),
            if (entry.expiry != null)
              PopupMenuItem(
                  value: 'clear', child: Text(l10n.stockpileExpiryClear)),
            PopupMenuItem(
                value: 'delete', child: Text(l10n.stockpileDeleteItem)),
          ],
        ),
      ]),
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

  void _deleteSpec(
      StockpileState s, StockpileItemSpec spec, String name) {
    setState(() {
      s.removedItemIds.add(spec.id);
      s.entries.remove(spec.id);
    });
    _saveAndReschedule();
    _showRemoved(context.l10n, name, () {
      setState(() => s.removedItemIds.remove(spec.id));
      _save();
    });
  }

  void _showRemoved(AppLocalizations l10n, String name, VoidCallback undo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.stockpileDeleted(name)),
      action: SnackBarAction(label: l10n.stockpileUndo, onPressed: undo),
    ));
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
    setState(() => entry.expiry = DateTime(picked.year, picked.month, picked.day));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.stockpileNotifyDenied)));
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
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    var category = StockpileCategory.valuables;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.stockpileAddItem),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.stockpileItemNameLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.stockpileItemQuantityLabel),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StockpileCategory>(
              initialValue: category,
              decoration:
                  InputDecoration(labelText: l10n.stockpileItemCategoryLabel),
              items: [
                for (final c in StockpileCategory.values)
                  DropdownMenuItem(
                      value: c,
                      child: Text(stockpileCategoryNameOf(l10n, c))),
              ],
              onChanged: (v) => setLocal(() => category = v ?? category),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.commonOk)),
          ],
        ),
      ),
    );
    final s = _state;
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    final qty = int.tryParse(qtyCtrl.text.trim());
    qtyCtrl.dispose();
    if (added != true || name.isEmpty || s == null) return;
    setState(() {
      s.customItems.add(StockpileEntry(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        customTitle: name,
        customCategory: category,
        customQuantity: (qty == null || qty <= 0) ? null : qty,
      ));
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
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonOk)),
        ],
      ),
    );
    if (ok != true) return;
    await StockpileStore.clear();
    await _reminders.cancelAll();
    if (mounted) setState(() => _state = StockpileState());
  }

  /// 「探す」。有効な提携先が1つだけなら直接開き、複数なら店舗を選ばせる。
  /// アフィリエイト規約への配慮から**必ず外部ブラウザ**で開く
  /// 「探す」を押したとき。配信JSONに解説があればシートを開き、
  /// 無ければ従来どおり直接ショップ検索へ飛ばす（自由入力の項目など）。
  Future<void> _openGuide(
      String? itemId, String name, String fallbackKeyword) async {
    final guide = itemId == null ? null : _products?.guideFor(itemId);
    if (guide == null) {
      await _search(fallbackKeyword);
      return;
    }
    final l10n = context.l10n;
    final products = _products;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (context, controller) => SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(guide.name.isEmpty ? name : guide.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
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
                Text(guide.why,
                    style: TextStyle(fontSize: 13, color: Colors.grey[800])),
              ],
              if (guide.products.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sheetHeader(l10n.stockpileGuideProducts),
                for (final pr in guide.products)
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(pr.url),
                        mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Expanded(
                            child: Text(pr.title,
                                style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new, size: 15),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(l10n.stockpileGuideProductsNote,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
              if (AffiliateLinks.isAvailable) ...[
                const SizedBox(height: 16),
                _sheetHeader(l10n.stockpileGuideSearch),
                for (final m in AffiliateLinks.enabledMerchants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final kw = guide.keywordFor(m.key) ?? fallbackKeyword;
                        final url = AffiliateLinks.searchLink(kw, m);
                        if (url == null) return;
                        Navigator.of(context).pop();
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.stockpileGuideSearchAt(m.name)),
                      ),
                    ),
                  ),
              ],
              if (guide.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sheetHeader(l10n.stockpileGuideSources),
                for (final src in guide.sources) _sourceLink(src.name, src.url),
              ],
              const SizedBox(height: 14),
              if (products != null && products.disclaimer.isNotEmpty)
                Text(products.disclaimer,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              const SizedBox(height: 6),
              Text(
                  products != null && products.notice.isNotEmpty
                      ? products.notice
                      : l10n.stockpileAffiliateNotice,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        border:
            Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF2E7D32)),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)))),
      ]),
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

  Future<void> _search(String keyword) async {
    final sole = AffiliateLinks.soleSearchLink(keyword);
    if (sole != null) {
      await launchUrl(sole, mode: LaunchMode.externalApplication);
      return;
    }
    final merchants = AffiliateLinks.enabledMerchants;
    if (merchants.isEmpty) return;
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<VcMerchant>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(children: [
              Expanded(
                  child: Text(l10n.stockpileChooseShop,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),
          for (final m in merchants)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(m.name),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => Navigator.of(context).pop(m),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(l10n.stockpileAffiliateNotice,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ),
        ]),
      ),
    );
    if (chosen == null) return;
    final url = AffiliateLinks.searchLink(keyword, chosen);
    if (url != null) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
