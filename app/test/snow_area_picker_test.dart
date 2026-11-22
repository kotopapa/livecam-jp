import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_area.dart';
import 'package:livecam_jp/l10n/gen/app_localizations.dart';
import 'package:livecam_jp/ui/snow_area_picker.dart';

void main() {
  setUp(() {
    JmaAreaNames.parse({
      'class20s': {
        '0110000': {'name': '札幌市', 'enName': 'Sapporo City', 'parent': 'x'},
        '0120200': {'name': '函館市', 'enName': 'Hakodate City', 'parent': 'x'},
        '1522200': {'name': '上越市', 'enName': 'Joetsu City', 'parent': 'y'},
      },
    });
  });
  tearDown(JmaAreaNames.reset);

  Future<Set<String>?> open(WidgetTester tester, Set<String> initial,
      Future<void> Function() act) async {
    Set<String>? result;
    var popped = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.of(context).push<Set<String>>(
              MaterialPageRoute(
                builder: (_) => SnowAreaPickerScreen(initial: initial),
              ),
            );
            popped = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.tap(find.byKey(const ValueKey('snow_area_ok')));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    return result;
  }

  testWidgets('市区町村を選んで返す', (tester) async {
    final result = await open(tester, {}, () async {
      await tester.tap(find.text('北海道'));
      await tester.pumpAndSettle();
      expect(find.text('札幌市'), findsOneWidget);
      await tester.tap(find.text('函館市'));
      await tester.pumpAndSettle();
    });
    expect(result, {'0120200'});
  });

  testWidgets('県全体を選ぶと、その県の市区町村は外れる', (tester) async {
    final result = await open(tester, {'0110000', '1522200'}, () async {
      await tester.tap(find.text('北海道'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snow_area_whole_01')));
      await tester.pumpAndSettle();
    });
    expect(result, {'01', '1522200'});
  });

  testWidgets('全国に戻すと空になる', (tester) async {
    final result = await open(tester, {'01', '1522200'}, () async {
      await tester.tap(find.byKey(const ValueKey('snow_area_reset')));
      await tester.pumpAndSettle();
    });
    expect(result, isEmpty);
  });
}
