import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/muni_warnings.dart';

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
  final reports = <dynamic>[
    // 古い気象警報（無視される）
    rep('VPWW55', '2026-11-01T05:00:00+09:00', [
      area('1410100', [['03', '発表']]),
    ]),
    rep('VPWW55', '2026-11-01T11:00:00+09:00', [
      area('1410100', [['14', '継続'], ['10', '解除'], ['18', 'なし']]),
      area('1410200', [['03', '発表']]),
    ]),
    // 別報の土砂災害（合算される）
    rep('VPWW56', '2026-11-01T11:30:00+09:00', [
      area('1410100', [['49', '発表']]),
    ]),
  ];

  test('報種別を合算し、解除・なしと古い報を除き、段階順に並べる', () {
    final w = MuniWarnings.parse(reports, '14101', cityName: '横浜市');
    expect(w.codes, ['49', '14']);
    expect(w.topLevel, 4);
    expect(w.issuedAt, DateTime.parse('2026-11-01T11:30:00+09:00'));
  });

  test('区コードはその区だけ', () {
    final w = MuniWarnings.parse(reports, '14102');
    expect(w.codes, ['03']);
    expect(w.topLevel, 3);
  });

  test('市コード（区域が無い）は同じ市の区を合算する', () {
    final w = MuniWarnings.parse(reports, '14100');
    expect(w.codes, ['49', '03', '14']);
  });

  test('特別警報が最上位', () {
    final w = MuniWarnings.parse([
      rep('VPWW55', '2026-11-01T11:00:00+09:00', [
        area('1420100', [['03', '発表'], ['33', '発表']]),
      ]),
    ], '14201');
    expect(w.topLevel, 5);
    expect(w.codes.first, '33');
  });

  test('発表中が無ければ空', () {
    final w = MuniWarnings.parse(reports, '14999');
    expect(w.codes, isEmpty);
    expect(w.topLevel, 0);
  });
}
