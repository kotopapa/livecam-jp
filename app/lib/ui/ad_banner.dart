import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_state.dart';
import '../config.dart';

/// 詳細画面に置くAdMobバナー（320×50）。
///
/// 読み込み完了までは高さだけ確保して何も描かず、読み込み失敗時は
/// 高さ0に畳む（コンテンツの間なのでプレースホルダを見せない）。
class AdBannerPlaceholder extends StatefulWidget {
  AdBannerPlaceholder({super.key, this.size = AdSize.banner, String? adUnitId}) : adUnitId = adUnitId ?? admobBannerUnitId;

  /// 広告サイズ。既定は320×50。詳細画面の地図下には
  /// [AdSize.mediumRectangle](300×250)を使う
  final AdSize size;

  /// 広告ユニットID（サイズごとに別ユニットを使う）
  final String adUnitId;

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
      adUnitId: widget.adUnitId,
      size: widget.size,
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
        height: widget.size.height.toDouble(),
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


/// 画面下部に固定するアンカー型アダプティブバナー（HomeShell用）。
/// 画面幅に合わせた高さで1回だけ読み込み、タブを切り替えても保持する。
/// 読み込み失敗時は高さ0（空白を見せない）
class AnchoredAdBanner extends StatefulWidget {
  const AnchoredAdBanner({super.key});

  @override
  State<AnchoredAdBanner> createState() => _AnchoredAdBannerState();
}

class _AnchoredAdBannerState extends State<AnchoredAdBanner> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _failed = false;
  bool _loading = false;

  Future<void> _load(BuildContext context) async {
    if (_loading || _ad != null) return;
    _loading = true;
    final width = MediaQuery.of(context).size.width.truncate();
    final orientation = MediaQuery.of(context).orientation;
    // 「Large」版(最大90px)は地図領域を圧迫するため、高さが抑えられる標準版を使う
    final size =
        // ignore: deprecated_member_use
        await AdSize.getAnchoredAdaptiveBannerAdSize(orientation, width);
    if (!mounted || size == null) {
      _loading = false;
      if (mounted) setState(() => _failed = true);
      return;
    }
    _size = size;
    _ad = BannerAd(
      adUnitId: admobBannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
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
    if (_failed) return const SizedBox.shrink();
    if (_ad == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(context));
      return const SizedBox.shrink();
    }
    if (!_loaded || _size == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _size!.width.toDouble(),
        height: _size!.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}


/// push遷移した一覧画面(災害速報→地震/警報の先、ランキング等)の下部に置く
/// アンカーバナー。HomeShellのバナーはタブ配下にしか出ないため、
/// これらの画面では個別に置く。特別警報の発表中は非表示(HomeShellと同じ規則)
class AdFooter extends StatelessWidget {
  const AdFooter({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Offstage(
        offstage: app.specialWarningActive,
        child: const AnchoredAdBanner(),
      ),
    );
  }
}
