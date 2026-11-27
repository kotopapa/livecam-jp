import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/muni_warnings.dart';
import 'package:livecam_jp/data/viewer_area.dart';
import 'package:livecam_jp/ui/here_warning_card.dart';

import 'l10n_test_app.dart';

Map<String, dynamic> rep(String type, String dt, List<Map<String, dynamic>> areas) => {
      'dataTypeCode': type,
      'reportDatetime': dt,
      'warning': {'class20Items': areas},
    };

Map<String, dynamic> area(String code, List<List<String>> kinds) => {
      'areaCode': code,
      'kinds': [for (final k in kinds) {'code': k[0], 'status': k[1]}],
    };

void main() {
  // 気象庁 area.json の class20 のキー（実物から抜粋）
  const keys = {
    '1310100', // 千代田区
    '0110000', // 札幌市（市単位）
    '1410011', '1410012', // 横浜市北部・南部
    '1413000', // 川崎市
    '0920601', '0920602', // 日光市今市・日光
    '0920100', // 宇都宮市
  };

  group('areaCodesOf', () {
    test('そのままのコードがあればそれだけ', () {
      expect(MuniWarnings.areaCodesOf('13101', keys), {'1310100'});
    });
    test('政令市の区は、市単位のコードへ寄せる', () {
      expect(MuniWarnings.areaCodesOf('01101', keys), {'0110000'});
    });
    test('政令市の区は、市を分割した区域をすべて拾う（隣の川崎市は拾わない）', () {
      expect(MuniWarnings.areaCodesOf('14101', keys), {'1410011', '1410012'});
    });
    test('分割された市町村は全区域を拾う', () {
      expect(MuniWarnings.areaCodesOf('09206', keys), {'0920601', '0920602'});
    });
    test('無ければ空', () {
      expect(MuniWarnings.areaCodesOf('47999', keys), isEmpty);
    });
  });

  test('parse は areaCodes の区域だけを合算する', () {
    final reports = <dynamic>[
      rep('VPWW55', '2026-11-28T05:00:00+09:00', [
        area('1410011', [['03', '発表']]),
        area('1410012', [['14', '継続'], ['10', '解除']]),
        area('1413000', [['33', '発表']]),
      ]),
      rep('VPWW56', '2026-11-28T05:30:00+09:00', [
        area('1410012', [['49', '発表']]),
      ]),
    ];
    final w = MuniWarnings.parse(reports, '14101',
        areaCodes: MuniWarnings.areaCodesOf('14101', keys));
    expect(w.codes, ['49', '03', '14']);
    expect(w.topLevel, 4);
  });

  test('逆ジオコーダの応答から市区町村コードを取り出す', () {
    expect(
        ViewerArea.parseMunicipality(
            '{"results":{"muniCd":"14101","lv01Nm":"鶴見中央一丁目"}}'),
        '14101');
    expect(ViewerArea.parseMunicipality('{}'), isNull);
    expect(ViewerArea.parseMunicipality('not json'), isNull);
  });

  group('HereWarningCard', () {
    Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
        testApp(Scaffold(body: SingleChildScrollView(child: card))));

    testWidgets('発表中は最上位の段階と全種類を出し、タップできる', (tester) async {
      var tapped = 0;
      await pump(
          tester,
          HereWarningCard(
            status: HereWarningStatus.ready,
            warnings: MuniWarnings(
                codes: const ['49', '03', '14'],
                cityName: '横浜市',
                issuedAt: DateTime.parse('2026-11-28T05:30:00+09:00')),
            placeName: '横浜市鶴見区',
            onTap: () => tapped++,
          ));
      expect(find.text('現在地の警報・注意報'), findsOneWidget);
      expect(find.text('横浜市鶴見区'), findsOneWidget);
      expect(find.text('危険警報 (Lv.4)'), findsOneWidget);
      expect(find.text('11/28 05:30 発表'), findsOneWidget);
      // 種類のチップは 3 つ
      final top = find.byKey(const Key('here_warning_top'));
      expect(top, findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
      expect(tester.widget<Wrap>(find.byType(Wrap)).children.length, 3);
      await tester.tap(find.byKey(const Key('here_warning_card')));
      expect(tapped, 1);
    });

    testWidgets('発表が無ければその旨を出す', (tester) async {
      await pump(
          tester,
          const HereWarningCard(
              status: HereWarningStatus.ready,
              warnings: MuniWarnings(codes: [], cityName: '千代田区'),
              placeName: '千代田区'));
      expect(find.text('発表中の警報・注意報はありません'), findsOneWidget);
      expect(find.byKey(const Key('here_warning_top')), findsNothing);
    });

    testWidgets('位置が使えないとき・取得できないとき', (tester) async {
      await pump(tester,
          const HereWarningCard(status: HereWarningStatus.noLocation));
      expect(find.text('現在地を取得できませんでした'), findsOneWidget);
      await pump(tester,
          const HereWarningCard(status: HereWarningStatus.unavailable));
      expect(find.text('現在地の警報・注意報を取得できませんでした'), findsOneWidget);
    });
  });
}
