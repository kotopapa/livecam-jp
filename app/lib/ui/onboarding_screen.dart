import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detail_screen.dart' show disclaimerText;

/// 初回起動時のオンボーディング（SPEC 9.2①）。
/// アプリの約束3点 + 最終ページの免責（9.5）。免責はスキップできない
/// （「はじめる」ボタンは免責ページにしかない）。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  static const prefsKey = 'onboarding_done_v1';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      image: 'assets/images/onboarding_map.png',
      title: '地図からすぐに探せる',
      body: '全国1万台以上のライブカメラを地図に表示。河川・道路・海岸などカテゴリ別に色分けされています。',
    ),
    (
      image: 'assets/images/onboarding_monitor.png',
      title: '映らないカメラは自動で非表示',
      body: '定期的に自動確認し、取得できないカメラは地図から外れます。取得時刻を必ず表示します。',
    ),
    (
      image: 'assets/images/onboarding_license.png',
      title: '出典・ライセンスを明示',
      body: 'すべての映像は提供元の明示とともに表示します。映像の権利は各提供元に帰属します。',
    ),
  ];

  bool get _isLast => _page == _pages.length; // 最終=免責ページ

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
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages)
                  _PromisePage(image: p.image, title: p.title, body: p.body),
                const _DisclaimerPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              // ページインジケータ
              for (var i = 0; i <= _pages.length; i++)
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
              if (!_isLast)
                TextButton(
                  // スキップしても免責ページへ飛ぶ（免責は飛ばせない。SPEC 9.2①）
                  onPressed: () => _controller.jumpToPage(_pages.length),
                  child: const Text('スキップ'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLast
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut),
                child: Text(_isLast ? '同意してはじめる' : '次へ'),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset(image, height: 220, fit: BoxFit.contain),
        const SizedBox(height: 32),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ]),
    );
  }
}

class _DisclaimerPage extends StatelessWidget {
  const _DisclaimerPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.warning_amber_rounded,
            size: 56, color: Color(0xFFF29900)),
        const SizedBox(height: 24),
        const Text('ご利用前の大切なお願い',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(disclaimerText,
              style: const TextStyle(fontSize: 13, height: 1.6)),
        ),
      ]),
    );
  }
}
