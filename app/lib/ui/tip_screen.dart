import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// 開発者を応援する（投げ銭）。消耗型のアプリ内課金4段階。
///
/// App Store Connect に同じ商品IDの「消耗型」商品を登録しておくこと
/// （未登録・審査前は商品が取得できず「準備中」表示になる）。
class TipScreen extends StatefulWidget {
  const TipScreen({super.key});

  /// 商品ID（App Store Connect / Google Play で同じIDを登録する）
  static const productIds = <String>{
    'jp.livecam.tip.coffee',
    'jp.livecam.tip.sweets',
    'jp.livecam.tip.lunch',
    'jp.livecam.tip.devtools',
  };

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _Tier {
  const _Tier(this.id, this.badge, this.icon, this.color);
  final String id;
  final String badge;
  final IconData icon;
  final Color color;

  String title(AppLocalizations l10n) => switch (id) {
        'jp.livecam.tip.coffee' => l10n.tipCoffeeTitle,
        'jp.livecam.tip.sweets' => l10n.tipSweetsTitle,
        'jp.livecam.tip.lunch' => l10n.tipLunchTitle,
        _ => l10n.tipDevToolsTitle,
      };

  String subtitle(AppLocalizations l10n) => switch (id) {
        'jp.livecam.tip.coffee' => l10n.tipCoffeeSubtitle,
        'jp.livecam.tip.sweets' => l10n.tipSweetsSubtitle,
        'jp.livecam.tip.lunch' => l10n.tipLunchSubtitle,
        _ => l10n.tipDevToolsSubtitle,
      };
}

const _tiers = <_Tier>[
  _Tier('jp.livecam.tip.coffee', 'COFFEE', Icons.coffee, Color(0xFF7A5C46)),
  _Tier('jp.livecam.tip.sweets', 'SWEETS', Icons.cake, Color(0xFFB0574A)),
  _Tier('jp.livecam.tip.lunch', 'LUNCH', Icons.restaurant, Color(0xFF4E7A5A)),
  _Tier('jp.livecam.tip.devtools', 'DEV TOOLS', Icons.auto_awesome,
      Color(0xFF6B4E9B)),
];

class _TipScreenState extends State<TipScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Map<String, ProductDetails> _products = {};
  bool _loading = true;
  bool _available = true;
  String? _busyId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _available = await _iap.isAvailable();
      if (_available) {
        final r = await _iap.queryProductDetails(TipScreen.productIds);
        _products = {for (final p in r.productDetails) p.id: p};
      }
    } catch (_) {
      _available = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(_Tier t) async {
    final p = _products[t.id];
    if (p == null || _busyId != null) return;
    setState(() {
      _busyId = t.id;
      _message = null;
    });
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      if (mounted) {
        final l10n = context.l10n;
        setState(() {
          _busyId = null;
          _message = l10n.tipPurchaseStartFailed;
        });
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final pd in purchases) {
      switch (pd.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
          if (mounted) {
            final l10n = context.l10n;
            setState(() {
              _busyId = null;
              _message = l10n.tipThanks;
            });
          }
        case PurchaseStatus.error:
          if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
          if (mounted) {
            final l10n = context.l10n;
            setState(() {
              _busyId = null;
              _message = l10n.tipPurchaseFailed(
                  pd.error?.message ?? l10n.tipUnknownError);
            });
          }
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _busyId = null);
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 4),
        const Center(
          child: CircleAvatar(
            radius: 36,
            child: Icon(Icons.videocam, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.settingsSupportTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          l10n.tipIntro,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_available || _products.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _available ? l10n.tipPreparing : l10n.tipUnavailable,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final t in _tiers)
            if (_products[t.id] != null) _tierCard(t, _products[t.id]!, l10n),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!, textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.tipNoticeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(l10n.tipNoticeBody,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 4),
              _link(l10n.tipEula,
                  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
              _link(l10n.settingsTerms, 'https://kotopapa.github.io/livecam-jp/terms.html'),
              _link(l10n.settingsPrivacy, 'https://kotopapa.github.io/livecam-jp/privacy.html'),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _link(String label, String url) => InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label)),
            const Icon(Icons.open_in_new, size: 16),
          ]),
        ),
      );

  Widget _tierCard(_Tier t, ProductDetails p, AppLocalizations l10n) {
    final busy = _busyId == t.id;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.color.withValues(alpha: 0.5))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : () => _buy(t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(t.icon, color: t.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: t.color, letterSpacing: 1)),
                Text(t.title(l10n), style: TextStyle(fontWeight: FontWeight.bold, color: t.color)),
                Text(t.subtitle(l10n), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ]),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(20)),
                    child: Text(p.price,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ]),
        ),
      ),
    );
  }
}
