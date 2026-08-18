import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/ui/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('スキップしても免責ページに行き、同意ボタンで完了する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var done = false;
    await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(onDone: () => done = true)));

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
}
