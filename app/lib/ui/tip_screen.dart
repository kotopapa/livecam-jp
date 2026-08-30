import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const _Tier(this.id, this.badge, this.title, this.subtitle, this.icon, this.color);
  final String id;
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _tiers = <_Tier>[
  _Tier('jp.livecam.tip.coffee', 'COFFEE', '缶コーヒーでひと息',
      '開発の合間に飲む缶コーヒー代をプレゼント', Icons.coffee, Color(0xFF7A5C46)),
  _Tier('jp.livecam.tip.sweets', 'SWEETS', 'スイーツで糖分補給',
      '集中コーディング用の甘いお菓子＆カフェ代を支援', Icons.cake, Color(0xFFB0574A)),
  _Tier('jp.livecam.tip.lunch', 'LUNCH', 'ランチで開発ブースト',
      '次の新機能開発に向けた栄養満点ランチをごちそう', Icons.restaurant, Color(0xFF4E7A5A)),
  _Tier('jp.livecam.tip.devtools', 'DEV TOOLS', '開発ツール費を応援',
      'カメラ調査やサーバー監視に使うサービス費を支援', Icons.auto_awesome, Color(0xFF6B4E9B)),
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
        setState(() {
          _busyId = null;
          _message = '購入を開始できませんでした';
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
            setState(() {
              _busyId = null;
              _message = 'ご支援ありがとうございます！開発の励みになります。';
            });
          }
        case PurchaseStatus.error:
          if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
          if (mounted) {
            setState(() {
              _busyId = null;
              _message = '購入を完了できませんでした（${pd.error?.message ?? '不明なエラー'}）';
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
    return Scaffold(
      appBar: AppBar(title: const Text('開発者を応援')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 4),
        const Center(
          child: CircleAvatar(
            radius: 36,
            child: Icon(Icons.videocam, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text('開発者を応援する',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'このアプリは個人で開発・運営しています。カメラの調査・追加や監視サーバーの維持、'
          '気象データの対応など、継続的なアップデートの励みになります。'
          '支援は任意で、機能の違いはありません。',
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
                _available
                    ? '支援メニューは準備中です。しばらくしてからお試しください。'
                    : 'このデバイスではアプリ内課金を利用できません。',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final t in _tiers)
            if (_products[t.id] != null) _tierCard(t, _products[t.id]!),
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
              const Text('購入前にご確認ください', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('支援はApp Storeのアプリ内課金で処理されます（返金はAppleの規定に従います）。',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 4),
              _link('EULA（Apple標準使用許諾契約）',
                  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
              _link('利用規約', 'https://kotopapa.github.io/livecam-jp/terms.html'),
              _link('プライバシーポリシー', 'https://kotopapa.github.io/livecam-jp/privacy.html'),
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

  Widget _tierCard(_Tier t, ProductDetails p) {
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
                Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: t.color)),
                Text(t.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
