import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/jma_flood.dart';
import 'package:livecam_jp/data/jma_layers.dart';
import 'package:livecam_jp/data/situation.dart';

void main() {
  test('r8 map.json から特別警報・危険警報の県を集める（官署×報種別で最新報）', () {
    final reports = [
      {
        'publishingOffice': '気象庁', 'dataTypeCode': 'VPWW55',
        'reportDatetime': '2026-09-15T10:00:00+09:00',
        'warning': {
          'class10Items': [
            {'areaCode': '130010', 'kinds': [{'code': '33', 'status': '発表'}]},
            {'areaCode': '110010', 'kinds': [{'code': '43', 'status': '継続'}]},
            {'areaCode': '140010', 'kinds': [{'code': '03', 'status': '発表'}]},
          ]
        },
      },
      {
        'publishingOffice': '気象庁', 'dataTypeCode': 'VPWW56',
        'reportDatetime': '2026-09-15T10:00:00+09:00',
        'warning': {
          'class10Items': [
            {'areaCode': '120010', 'kinds': [{'code': '49', 'status': '発表'}]},
          ]
        },
      },
      // 古い報（同じ官署×報種別）は無視される
      {
        'publishingOffice': '気象庁', 'dataTypeCode': 'VPWW55',
        'reportDatetime': '2026-09-15T09:00:00+09:00',
        'warning': {
          'class10Items': [
            {'areaCode': '270010', 'kinds': [{'code': '33', 'status': '発表'}]},
          ]
        },
      },
      // 解除は数えない
      {
        'publishingOffice': '沖縄気象台', 'dataTypeCode': 'VPWW55',
        'reportDatetime': '2026-09-15T10:00:00+09:00',
        'warning': {
          'class10Items': [
            {'areaCode': '471010', 'kinds': [{'code': '32', 'status': '解除'}]},
          ]
        },
      },
    ];
    final w = WarningPrefs.parse(reports);
    expect(w.special, {'13'});
    expect(w.danger, {'11', '12'});
  });

  test('isNotable と signature、震度4以上の判定', () {
    expect(Situation.empty.isNotable, isFalse);
    expect(Situation.intensityAtLeast4('3'), isFalse);
    expect(Situation.intensityAtLeast4('4'), isTrue);
    expect(Situation.intensityAtLeast4('5-'), isTrue);
    expect(Situation.intensityAtLeast4('7'), isTrue);
    final q = QuakePoint(
      at: DateTime.utc(2026, 9, 15, 3),
      place: '千葉県北西部',
      magnitude: '5.0',
      maxIntensity: '4',
      pos: const LatLng(35.7, 140.1),
    );
    final f = FloodForecast(
      riverCode: 'R1',
      riverName: '荒川',
      level: FloodLevel.danger,
      kindName: '氾濫危険情報',
      reportAt: DateTime.utc(2026, 9, 15, 1),
    );
    final s = Situation(
      warnings: const WarningPrefs(danger: {'11'}),
      typhoons: const [],
      floods: [f],
      quakes: [q],
      loadedAt: DateTime.utc(2026, 9, 15, 4),
    );
    expect(s.isNotable, isTrue);
    expect(s.signature, 's:|d:11|t:|f:R1/4|q:2026-09-15T03:00:00.000Z/4|u:');
    // 内容が同じなら signature も同じ（閉じた状態を保つ判定に使う）
    final s2 = Situation(
      warnings: const WarningPrefs(danger: {'11'}),
      typhoons: const [],
      floods: [f],
      quakes: [q],
      loadedAt: DateTime.utc(2026, 9, 15, 5),
    );
    expect(s2.signature, s.signature);
  });
}
