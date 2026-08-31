import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/heat_alert.dart';
import 'package:livecam_jp/util/prefectures.dart';

/// 環境省CSVの実物（2026-08-31 05:00発表）を縮めたもの。
/// メタ行→ヘッダ行→区域行の並びとフラグ列の位置は実データのまま
const _csv = '''Title,熱中症特別警戒情報・熱中症警戒情報,,,,,,,,,
Encoding,UTF-8,,,,,,,,,
TimeZone,+09:00,,,,,,,,,
CreateDate,2026/08/31,,,,,,,,,
CreateTime,04:30:02,,,,,,,,,
PublishingOffice,環境省,,,,,,,,,
ReportDate,2026/08/31,,,,,,,,,
ReportTime,05:00:00,,,,,,,,,
TargetDate1,2026/08/31,,,,,,,,,
TargetTime1,05:00:00,,,,,,,,,
DurationTime1,19:00:00,,,,,,,,,
TargetDate2,2026/09/01,,,,,,,,,
TargetTime2,00:00:00,,,,,,,,,
DurationTime2,24:00:00,,,,,,,,,
BriefComment1,自分と自分の周りの人の命を守ってください,,,,,,,,,
BriefComment2,暑さから、自分の身を守りましょう,,,,,,,,,
KeyMessage1,熱中症特別警戒情報発表対象地域の皆様へ：○広域的に…,,,,,,,,,
KeyMessage2,熱中症警戒情報対象地域の皆様へ：○熱中症警戒アラートが…,,,,,,,,,
KeyMessage3,,,,,,,,,,
FlagExplanation,発表無し:0、熱中症警戒情報発表:1、熱中症特別警戒情報判定:2、熱中症特別警戒情報発表:3、発表時間外:9,,,,,,,,,
Status,通常,,,,,,,,,
InternalFlag,0000000000,,,,,,,,,
府県予報区,都府県・振興局表示番号,都府県・振興局表示番号サブ,府県予報区等コード,都道府県名,都道府県コード,TargetDate1フラグ,TargetDate2フラグ,日最高WBGT（10:00）,日最高WBGT（17:00）,日最高WBGT（5:00）
宗谷地方,11,0,011000,北海道,01,0,0,宗谷岬:17/稚内:18,宗谷岬:18/稚内:18,宗谷岬:17/稚内:17
上川・留萌地方,12,0,012000,北海道,01,1,0,旭川:20,旭川:19,旭川:20
石狩・空知・後志地方,14,0,016000,北海道,01,0,1,札幌:22,札幌:22,札幌:22
東京都,44,0,130000,東京,13,0,9,東京:31,東京:31,東京:31
大阪府,62,0,270000,大阪,27,1,1,大阪:32,大阪:32,大阪:32
沖縄本島地方,91,0,471000,沖縄,47,3,2,那覇:33,那覇:33,那覇:33
''';

void main() {
  group('parseCsv', () {
    final r = HeatAlerts.parseCsv(_csv);

    test('メタ行から発表日時と対象日を読む', () {
      expect(r.reportAt, DateTime(2026, 8, 31, 5, 0));
      expect(r.date1, DateTime(2026, 8, 31));
      expect(r.date2, DateTime(2026, 9, 1));
    });

    test('区域行だけを読み、メタ行は混ざらない', () {
      expect(r.areas.length, 6);
      expect(r.areas.first.areaName, '宗谷地方');
      // 府県予報区等コードは気象庁 area.json と同じ6桁
      expect(r.areas.first.areaCode, '011000');
      expect(r.areas.first.prefCode, '01');
      expect(r.areas[3].areaCode, '130000');
    });

    test('フラグをレベルに変換する', () {
      expect(r.areas[0].day1, HeatAlertLevel.none);
      expect(r.areas[1].day1, HeatAlertLevel.warning);
      expect(r.areas[3].day2, HeatAlertLevel.unknown); // 9=発表時間外
      expect(r.areas[5].day1, HeatAlertLevel.special);
      expect(r.areas[5].day2, HeatAlertLevel.specialPending);
    });

    test('対象日でない日付を渡すと unknown', () {
      expect(r.levelOn(r.areas[1], DateTime(2026, 8, 31)),
          HeatAlertLevel.warning);
      expect(r.levelOn(r.areas[2], DateTime(2026, 9, 1)),
          HeatAlertLevel.warning);
      expect(r.levelOn(r.areas[1], DateTime(2026, 9, 2)),
          HeatAlertLevel.unknown);
    });

    test('壊れた本文でも例外にならない', () {
      expect(HeatAlerts.parseCsv('').areas, isEmpty);
      expect(HeatAlerts.parseCsv('<html>404</html>').areas, isEmpty);
      expect(HeatAlerts.parseCsv('府県予報区,a,b\nゴミ,1,2').areas, isEmpty);
    });
  });

  group('heatLevelFromFlag', () {
    test('0/1/2/3/9 と未知の値', () {
      expect(heatLevelFromFlag('0'), HeatAlertLevel.none);
      expect(heatLevelFromFlag('1'), HeatAlertLevel.warning);
      expect(heatLevelFromFlag('2'), HeatAlertLevel.specialPending);
      expect(heatLevelFromFlag('3'), HeatAlertLevel.special);
      expect(heatLevelFromFlag('9'), HeatAlertLevel.unknown);
      expect(heatLevelFromFlag(''), HeatAlertLevel.unknown);
      expect(heatLevelFromFlag('x'), HeatAlertLevel.unknown);
    });

    test('発表無し・発表時間外は一覧に載せない', () {
      expect(HeatAlertLevel.none.isAlert, isFalse);
      expect(HeatAlertLevel.unknown.isAlert, isFalse);
      expect(HeatAlertLevel.warning.isAlert, isTrue);
      expect(HeatAlertLevel.special.isAlert, isTrue);
      expect(HeatAlertLevel.special.rank < HeatAlertLevel.warning.rank, isTrue);
    });
  });

  group('byPrefecture', () {
    final r = HeatAlerts.parseCsv(_csv);
    final list = HeatAlerts.byPrefecture(r,
        today: DateTime(2026, 8, 31), prefNames: prefectureNames);

    test('発表のある都道府県だけを重い順に並べる', () {
      expect(list.map((e) => e.prefCode).toList(), ['47', '01', '27']);
      // 東京は当日0・翌日9なので載らない
      expect(list.any((e) => e.prefCode == '13'), isFalse);
    });

    test('都道府県名は共通のJISコード表から引く', () {
      expect(list.first.prefName, '沖縄');
    });

    test('複数区域の都道府県は重い方に丸め、区域名を添える', () {
      final hokkaido = list.firstWhere((e) => e.prefCode == '01');
      expect(hokkaido.today, HeatAlertLevel.warning); // 上川・留萌
      expect(hokkaido.tomorrow, HeatAlertLevel.warning); // 石狩・空知・後志
      expect(hokkaido.areas, ['上川・留萌地方', '石狩・空知・後志地方']);
    });

    test('区域が1つだけの都道府県は区域名を出さない', () {
      final osaka = list.firstWhere((e) => e.prefCode == '27');
      expect(osaka.areas, isEmpty);
      expect(osaka.top, HeatAlertLevel.warning);
    });
  });

  group('運用期間', () {
    test('4/22〜10/21のみ', () {
      expect(HeatAlerts.isInSeason(DateTime(2026, 4, 21)), isFalse);
      expect(HeatAlerts.isInSeason(DateTime(2026, 4, 22)), isTrue);
      expect(HeatAlerts.isInSeason(DateTime(2026, 8, 31)), isTrue);
      expect(HeatAlerts.isInSeason(DateTime(2026, 10, 21)), isTrue);
      expect(HeatAlerts.isInSeason(DateTime(2026, 10, 22)), isFalse);
      expect(HeatAlerts.isInSeason(DateTime(2026, 1, 15)), isFalse);
    });
  });

  group('candidateUrls', () {
    test('発表済みの回を新しい順に試す', () {
      final u = HeatAlerts.candidateUrls(DateTime(2026, 8, 31, 13, 11));
      expect(u.first.toString(),
          'https://www.wbgt.env.go.jp/alert/dl/2026/alert_20260831_10.csv');
      expect(u[1].toString(),
          'https://www.wbgt.env.go.jp/alert/dl/2026/alert_20260831_05.csv');
      expect(u.last.toString(),
          'https://www.wbgt.env.go.jp/alert/dl/2026/alert_20260830_17.csv');
    });

    test('未明はその日の発表がまだ無いので前日17時にさかのぼる', () {
      final u = HeatAlerts.candidateUrls(DateTime(2026, 8, 31, 3, 0));
      expect(u.length, 1);
      expect(u.single.toString(),
          'https://www.wbgt.env.go.jp/alert/dl/2026/alert_20260830_17.csv');
    });

    test('リクエストが増えすぎないよう候補は打ち切る', () {
      final u = HeatAlerts.candidateUrls(DateTime(2026, 8, 31, 23, 0));
      expect(u.length, HeatAlerts.maxCandidates);
    });

    test('運用期間外は候補が空（＝取得しない）', () {
      expect(HeatAlerts.candidateUrls(DateTime(2026, 1, 15, 12)), isEmpty);
      // 期間初日の未明は前日(4/21)が期間外なので候補なし
      expect(HeatAlerts.candidateUrls(DateTime(2026, 4, 22, 3)), isEmpty);
    });
  });

  group('fetch', () {
    test('最新の回が404なら次に新しい回を使う', () async {
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.toString());
        if (req.url.toString().endsWith('_10.csv')) {
          return http.Response('Not Found', 404);
        }
        return http.Response.bytes(utf8.encode(_csv), 200);
      });
      final r = await HeatAlerts.fetch(
          now: DateTime(2026, 8, 31, 13, 11), client: client);
      expect(r, isNotNull);
      expect(r!.areas.length, 6);
      expect(asked.length, 2);
      expect(asked.first.endsWith('_10.csv'), isTrue);
      expect(asked.last.endsWith('_05.csv'), isTrue);
    });

    test('運用期間外は1度もリクエストせず null', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 404);
      });
      final r =
          await HeatAlerts.fetch(now: DateTime(2026, 12, 1, 12), client: client);
      expect(r, isNull);
      expect(calls, 0);
    });

    test('全滅・通信エラーは null（正常系として扱う）', () async {
      final client = MockClient((_) async => throw Exception('boom'));
      final r =
          await HeatAlerts.fetch(now: DateTime(2026, 8, 31, 13), client: client);
      expect(r, isNull);
    });
  });
}
