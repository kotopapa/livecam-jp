import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/locale_controller.dart';
import '../l10n/l10n.dart';
import 'detail_screen.dart' show disclaimerTextOf;
import 'language_switcher.dart';

/// 初回起動時のオンボーディング（SPEC 9.2①）。
/// アプリの約束3点 + 最終ページの免責（9.5）。免責はスキップできない
/// （「はじめる」ボタンは免責ページにしかない）。
///
/// 1.4.0: 画面上部に言語切替ボタンを常設する（日本語 / やさしい日本語 /
/// English）。強制の言語選択画面は出さず、初回は端末の言語設定から自動選択する。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen(
      {super.key, required this.onDone, required this.localeController});

  static const prefsKey = 'onboarding_done_v1';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  final VoidCallback onDone;
  final LocaleController localeController;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// 約束ページ1枚分の中身（文言は表示時に l10n から解決する）
typedef _PromiseContent = ({String image, String title, String body});

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  List<_PromiseContent> _pages(AppLocalizations l10n) => [
        (
          image: 'assets/images/onboarding_map.png',
          title: l10n.onboardingTitle1,
          body: l10n.onboardingBody1,
        ),
        (
          image: 'assets/images/onboarding_monitor.png',
          title: l10n.onboardingTitle2,
          body: l10n.onboardingBody2,
        ),
        (
          image: 'assets/images/onboarding_license.png',
          title: l10n.onboardingTitle3,
          body: l10n.onboardingBody3,
        ),
      ];

  bool get _isLast => _page == _pageCount; // 最終=免責ページ

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKey, true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // 言語切替は常設。押すとその場で切り替わる
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LanguageSwitcher(controller: widget.localeController),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages(l10n))
                  _PromisePage(image: p.image, title: p.title, body: p.body),
                const _DisclaimerPage(),
              ],
            ),
          ),
          Padding(
            // 320px幅でベトナム語のボタン（Đồng ý và bắt đầu）が入るよう左右は16
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Row(children: [
              // ページインジケータ
              for (var i = 0; i <= _pageCount; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                  ),
                ),
              const Spacer(),
              // 長い言語（ベトナム語・韓国語）でも横にあふれないよう縮められるようにする
              if (!_isLast)
                Flexible(
                  child: TextButton(
                    // スキップしても免責ページへ飛ぶ（免責は飛ばせない。SPEC 9.2①）
                    onPressed: () => _controller.jumpToPage(_pageCount),
                    child: Text(l10n.commonSkip,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: FilledButton(
                  onPressed: _isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut),
                  child: Text(
                      _isLast ? l10n.onboardingAgreeAndStart : l10n.commonNext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PromisePage extends StatelessWidget {
  const _PromisePage(
      {required this.image, required this.title, required this.body});

  final String image;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // 多言語対応で本文が長くなる言語（やさしい日本語・ベトナム語・韓国語）があるため、
    // 画像の高さを画面に応じて縮め、それでも入らなければスクロールさせる
    // （固定220pxのままだと iPhone SE 相当の 320x568 で縦にあふれる）
    return LayoutBuilder(builder: (context, c) {
      final imageHeight = c.maxHeight * 0.42 < 220.0 ? c.maxHeight * 0.42 : 220.0;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: c.maxHeight - 64 > 0 ? c.maxHeight - 64 : 0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset(image, height: imageHeight, fit: BoxFit.contain),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ]),
        ),
      );
    });
  }
}

class _DisclaimerPage extends StatelessWidget {
  const _DisclaimerPage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.warning_amber_rounded,
              size: 56, color: Color(0xFFF29900)),
          const SizedBox(height: 24),
          Text(l10n.onboardingDisclaimerTitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(disclaimerTextOf(l10n),
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
          // 翻訳は参考。日本語を正文とする（SPEC 12.2）
          if (Localizations.localeOf(context).languageCode != 'ja' ||
              Localizations.localeOf(context).scriptCode == 'Hira') ...[
            const SizedBox(height: 8),
            Text(l10n.legalJapaneseAuthoritative,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ]),
      ),
    );
  }
}
