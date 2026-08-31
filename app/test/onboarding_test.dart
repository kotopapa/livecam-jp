import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/l10n/l10n.dart';
import 'package:livecam_jp/ui/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('スキップしても免責ページに行き、同意ボタンで完了する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var done = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: OnboardingScreen(
          onDone: () => done = true,
          localeController: LocaleController(initial: AppLanguage.ja)),
    ));

    // 1ページ目に「はじめる」はない（免責は飛ばせない）
    expect(find.text('同意してはじめる'), findsNothing);
    expect(find.text('地図からすぐに探せる'), findsOneWidget);

    // スキップ → 免責ページへ
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();
    expect(find.text('ご利用前の大切なお願い'), findsOneWidget);
    expect(find.textContaining('避難の判断'), findsOneWidget);

    // 同意して完了 → フラグが立つ
    await tester.tap(find.text('同意してはじめる'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(await OnboardingScreen.isDone(), isTrue);
  });

  testWidgets('オンボーディング1画面目の言語ボタンでその場で切り替わる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = LocaleController(initial: AppLanguage.ja);
    await tester.pumpWidget(_OnboardingHost(controller: controller));

    expect(find.text('地図からすぐに探せる'), findsOneWidget);

    // English に切り替える → その場で反映される
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Find cameras on the map'), findsOneWidget);
    expect(controller.language, AppLanguage.en);

    // やさしい日本語へ
    await tester.tap(find.text('やさしい日本語'));
    await tester.pumpAndSettle();
    expect(find.text('ちずから すぐに さがせます'), findsOneWidget);
    expect(controller.language, AppLanguage.jaHira);
  });
}

/// 言語切替で MaterialApp ごと作り直す本体（main.dart）と同じ構造のホスト
class _OnboardingHost extends StatelessWidget {
  const _OnboardingHost({required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(onDone: () {}, localeController: controller),
        ),
      );
}
