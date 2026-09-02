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
    await tester.pumpWidget(
      MaterialApp(
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
          localeController: LocaleController(initial: AppLanguage.ja),
        ),
      ),
    );

    // 1ページ目に「はじめる」はない（免責は飛ばせない）
    expect(find.text('同意してはじめる'), findsNothing);
    expect(find.text('地図からすぐに探せる'), findsOneWidget);

    // スキップ → 免責ページへ
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();
    expect(find.text('ご利用前の大切なお願い'), findsOneWidget);
    expect(find.textContaining('避難の判断'), findsOneWidget);

    // 災害通知のトグルが既定ONで表示されている（OFFにもできる）
    expect(find.text('災害通知を受け取る'), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isTrue);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

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

    // 言語ボタン → 一覧シートから English を選ぶ → その場で反映される
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    expect(find.text('Tiếng Việt'), findsOneWidget); // 全言語が並ぶ
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Find cameras on the map'), findsOneWidget);
    expect(controller.language, AppLanguage.en);

    // やさしい日本語へ（ボタンの表示も切り替わっている）
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('やさしい日本語'));
    await tester.pumpAndSettle();
    expect(find.text('ちずから すぐに さがせます'), findsOneWidget);
    expect(controller.language, AppLanguage.jaHira);
  });

  testWidgets('幅320pxのベトナム語でも最終ページのボタンがあふれず省略もされない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = LocaleController(initial: AppLanguage.vi);
    await tester.pumpWidget(_OnboardingHost(controller: controller));

    await tester.tap(find.byType(TextButton)); // スキップ
    await tester.pumpAndSettle();
    // レイアウトの overflow はテストでは例外になるので、ここまで来れば収まっている
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, 'Đồng ý và bắt đầu');
    final size = tester.getSize(find.byType(FilledButton));
    // ボタンが文字幅ぶん確保できている（半分に制限されると省略される）
    expect(size.width, greaterThan(150));
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
