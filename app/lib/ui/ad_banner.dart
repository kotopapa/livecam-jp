import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

/// 詳細画面に置くAdMobバナー（320×50）。
///
/// 読み込み完了までは高さだけ確保して何も描かず、読み込み失敗時は
/// 高さ0に畳む（コンテンツの間なのでプレースホルダを見せない）。
class AdBannerPlaceholder extends StatefulWidget {
  const AdBannerPlaceholder({super.key});

  static const double bannerHeight = 50;

  @override
  State<AdBannerPlaceholder> createState() => _AdBannerPlaceholderState();
}

class _AdBannerPlaceholderState extends State<AdBannerPlaceholder> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: admobBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 失敗時は区切り線ごと消す（前後のDividerが二重にならないように
    // 下側の区切り線はこのウィジェットが持つ）
    if (_failed) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: AdBannerPlaceholder.bannerHeight,
        child: _loaded && _ad != null
            ? Center(
                child: SizedBox(
                  width: _ad!.size.width.toDouble(),
                  height: _ad!.size.height.toDouble(),
                  child: AdWidget(ad: _ad!),
                ),
              )
            : const SizedBox.shrink(),
      ),
      const Divider(height: 24),
    ]);
  }
}
