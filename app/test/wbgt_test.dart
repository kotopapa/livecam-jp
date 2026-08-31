import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/wbgt.dart';

/// 地点マスタの実物（2026-08-31取得 wbgt_point_master-20260515.csv）の抜粋。
/// BOM付き・区切りは「, 」。福島(36126)は終了日 2021-03-18 の廃止地点
const _master = '﻿地方, 振興局, 地点番号, 観測所名, よみがな, ローマ字表記, 所在地, '
    'Latitude, Latitude_3, Longitude, Longitude_4, Start Year-Start Month-Start Day, '
    'End Year-End Month-End Day, Old Station Number, 実測開始日, 実測終了日, '
    '特別警戒情報判定除外開始日, 特別警戒情報判定除外終了日\n'
    '北海道, 宗谷, 11001, 宗谷岬, そうやみさき, SOYAMISAKI, 稚内市宗谷岬, 45, 31.2, 141, 56.1, 2010-05-01, 9999-99-99, 11001, , , , \n'
    '関東, 東京, 44132, 東京, とうきょう, TOKYO, 千代田区北の丸公園　東京管区気象台, 35, 41.5, 139, 45.0, 2010-05-01, 9999-99-99, 44132, 2010-05-01, 9999-99-99, , \n'
    '東北, 福島, 36126, 福島, ふくしま, FUKUSHIMA, 福島市松木町　福島地方気象台, 37, 45.5, 140, 28.2, 2010-05-01, 2021-03-18, 36126, , , , \n'
    '関東, 東京, 44136, 練馬, ねりま, NERIMA, 練馬区石神井台, 35, 44.1, 139, 35.6, 2010-05-01, 9999-99-99, 44136, , , , \n';

/// 予測CSVの実物（東京 44132、2026-08-31 21:25作成）
const _forecast = ',,2026083124,2026090103,2026090106,2026090109,2026090112,'
    '2026090115,2026090118,2026090121,2026090124,2026090203,2026090206,'
    '2026090209,2026090212,2026090215,2026090218,2026090221,2026090224\n'
    '44132,2026/08/31 21:25, 220, 220, 230, 260, 290, 270, 240, 240, 240, 240, '
    '240, 280, 300, 290, 250, 260, 260\n';

/// 実況CSVの実物（末尾のみ。22時以降は未来で空欄）
const _actual = 'Date,Time,44132\n'
    '2026/8/31,19:00,22.4\n'
    '2026/8/31,20:00,22.4\n'
    '2026/8/31,21:00,22.1\n'
    '2026/8/31,22:00,\n'
    '2026/8/31,23:00,\n'
    '2026/8/31,24:00,\n';

void main() {
  setUp(Wbgt.clearCacheForTest);

  group('dmToDeg', () {
    test('度と分（小数）を度に変換する', () {
      expect(Wbgt.dmToDeg('45', '31.2'), closeTo(45.52, 1e-9));
      expect(Wbgt.dmToDeg('139', '45.0'), closeTo(139.75, 1e-9));
      expect(Wbgt.dmToDeg(' 35', ' 41.5'), closeTo(35.6916666, 1e-6));
    });

    test('数値でなければ null', () {
      expect(Wbgt.dmToDeg('', '31.2'), isNull);
      expect(Wbgt.dmToDeg('45', 'x'), isNull);
    });
  });

  group('parseMaster', () {
    test('BOM・「, 」区切り・度分の座標を読み、廃止地点を除く', () {
      final pts = Wbgt.parseMaster(_master, asOf: DateTime(2026, 8, 31));
      expect(pts.map((p) => p.id), ['11001', '44132', '44136']);
      final tokyo = pts[1];
      expect(tokyo.name, '東京');
      expect(tokyo.kana, 'とうきょう');
      expect(tokyo.address, '千代田区北の丸公園　東京管区気象台');
      expect(tokyo.lat, closeTo(35.691666, 1e-5));
      expect(tokyo.lng, closeTo(139.75, 1e-9));
      expect(pts[0].lat, closeTo(45.52, 1e-9));
      expect(pts[0].lng, closeTo(141.935, 1e-9));
    });

    test('終了日より前の日付なら廃止地点も含む', () {
      final pts = Wbgt.parseMaster(_master, asOf: DateTime(2020, 8, 1));
      expect(pts.map((p) => p.id), contains('36126'));
    });

    test('空・ヘッダのみは空リスト', () {
      expect(Wbgt.parseMaster(''), isEmpty);
      expect(Wbgt.parseMaster(_master.split('\n').first), isEmpty);
    });
  });

  group('parseForecast', () {
    test('時刻列と値列を対応させ、値は10で割る。HH=24は翌日0時', () {
      final f = Wbgt.parseForecast(_forecast);
      expect(f.length, 17);
      expect(f.first.at, DateTime(2026, 9, 1, 0));
      expect(f.first.value, 22.0);
      expect(f[3].at, DateTime(2026, 9, 1, 9));
      expect(f[3].value, 26.0);
      expect(f[12].at, DateTime(2026, 9, 2, 12));
      expect(f[12].value, 30.0);
      expect(f.last.at, DateTime(2026, 9, 3, 0));
    });

    test('値が欠けたコマは捨てる', () {
      final f = Wbgt.parseForecast(',,2026090103,2026090106\n44132,2026/08/31 21:25, , 230\n');
      expect(f.length, 1);
      expect(f.single.at, DateTime(2026, 9, 1, 6));
      expect(f.single.value, 23.0);
    });

    test('1行しかなければ空', () {
      expect(Wbgt.parseForecast(',,2026090103\n'), isEmpty);
      expect(Wbgt.parseForecast(''), isEmpty);
    });
  });

  group('latestActual', () {
    test('最新の非空欄の値を返す（値は℃そのまま）', () {
      final v = Wbgt.latestActual(_actual);
      expect(v, isNotNull);
      expect(v!.at, DateTime(2026, 8, 31, 21));
      expect(v.value, 22.1);
    });

    test('24:00 は翌日0時に正規化される', () {
      final v = Wbgt.latestActual('Date,Time,44132\n2026/8/31,23:00,22.0\n2026/8/31,24:00,21.5\n');
      expect(v!.at, DateTime(2026, 9, 1, 0));
      expect(v.value, 21.5);
    });

    test('全て空欄なら null', () {
      expect(Wbgt.latestActual('Date,Time,44132\n2026/9/1,1:00,\n2026/9/1,2:00,\n'), isNull);
      expect(Wbgt.latestActual(''), isNull);
    });
  });

  group('wbgtLevelOf（環境省の5段階）', () {
    test('閾値 31 / 28 / 25 / 21', () {
      expect(wbgtLevelOf(31.0), WbgtLevel.danger);
      expect(wbgtLevelOf(35.2), WbgtLevel.danger);
      expect(wbgtLevelOf(30.9), WbgtLevel.severeWarning);
      expect(wbgtLevelOf(28.0), WbgtLevel.severeWarning);
      expect(wbgtLevelOf(27.9), WbgtLevel.warning);
      expect(wbgtLevelOf(25.0), WbgtLevel.warning);
      expect(wbgtLevelOf(24.9), WbgtLevel.caution);
      expect(wbgtLevelOf(21.0), WbgtLevel.caution);
      expect(wbgtLevelOf(20.9), WbgtLevel.safe);
      expect(wbgtLevelOf(-3.0), WbgtLevel.safe);
    });

    // 表示名は 1.4.0 で ARB へ移動した（`wbgtLevelLabelOf()` / i18n_test.dart）
    test('色（color_theme.css）', () {
      expect(WbgtLevel.danger.color.toARGB32(), 0xFFFF2800);
      expect(WbgtLevel.severeWarning.color.toARGB32(), 0xFFFF9600);
      expect(WbgtLevel.warning.color.toARGB32(), 0xFFFAF500);
      expect(WbgtLevel.caution.color.toARGB32(), 0xFFA0D2FF);
      expect(WbgtLevel.safe.color.toARGB32(), 0xFF218CFF);
    });
  });

  group('nearest', () {
    final pts = Wbgt.parseMaster(_master, asOf: DateTime(2026, 8, 31));

    test('距離順に3件（皇居付近 → 東京・練馬・宗谷岬）', () {
      final n = Wbgt.nearest(pts, 35.685, 139.7528);
      expect(n.map((e) => e.$1.id), ['44132', '44136', '11001']);
      expect(n[0].$2, lessThan(1000));
      expect(n[1].$2, greaterThan(n[0].$2));
      expect(n[2].$2, greaterThan(1000 * 1000));
    });

    test('limit と空リスト', () {
      expect(Wbgt.nearest(pts, 35.685, 139.7528, limit: 1).length, 1);
      expect(Wbgt.nearest(const [], 35.0, 139.0), isEmpty);
    });
  });

  group('upcoming', () {
    test('現在より後〜翌日24時まで', () {
      final f = Wbgt.parseForecast(_forecast);
      final up = Wbgt.upcoming(f, DateTime(2026, 8, 31, 21, 30));
      // 8/31時点では翌日(9/1)の24時=9/2 0時まで（9コマ）。9/2以降は含めない
      expect(up.length, 9);
      expect(up.first.at, DateTime(2026, 9, 1, 0));
      expect(up.last.at, DateTime(2026, 9, 2, 0));
      final up2 = Wbgt.upcoming(f, DateTime(2026, 9, 1, 8, 5));
      expect(up2.first.at, DateTime(2026, 9, 1, 9));
      expect(up2.last.at, DateTime(2026, 9, 3, 0));
      final up3 = Wbgt.upcoming(f, DateTime(2026, 9, 2, 22));
      expect(up3.map((e) => e.at), [DateTime(2026, 9, 3, 0)]);
    });

    test('ちょうど現在時刻のコマは含めない', () {
      final f = Wbgt.parseForecast(_forecast);
      final up = Wbgt.upcoming(f, DateTime(2026, 9, 1, 9));
      expect(up.first.at, DateTime(2026, 9, 1, 12));
    });
  });

  test('hourKey / formatDistance / URL', () {
    expect(Wbgt.hourKey(DateTime(2026, 8, 31, 21, 59)), '2026083121');
    expect(Wbgt.formatDistance(820.4), '820m');
    expect(Wbgt.formatDistance(3250), '3.3km');
    expect(Wbgt.forecastUrl('44132').toString(),
        'https://www.wbgt.env.go.jp/prev15WG/dl/yohou_44132.csv');
    expect(Wbgt.actualUrl('44132', DateTime(2026, 8, 31)).toString(),
        'https://www.wbgt.env.go.jp/est15WG/dl/wbgt_44132_202608.csv');
    expect(Wbgt.masterUrls.first.toString(),
        'https://www.wbgt.env.go.jp/man15NH/wbgt_point_master-20260515.csv');
  });

  group('fetchPoint', () {
    const tokyo = WbgtPoint(
        id: '44132', name: '東京', kana: 'とうきょう', address: '千代田区',
        lat: 35.69, lng: 139.75);

    test('実況と予測を取り、同じ正時内は再取得しない', () async {
      final hits = <String>[];
      final client = MockClient((req) async {
        hits.add(req.url.path);
        if (req.url.path.contains('yohou_')) return http.Response(_forecast, 200);
        if (req.url.path.contains('wbgt_44132_202608')) return http.Response(_actual, 200);
        return http.Response('', 404);
      });
      final now = DateTime(2026, 8, 31, 21, 40);
      final d = await Wbgt.fetchPoint(tokyo, now: now, client: client);
      expect(d.failed, isFalse);
      expect(d.current!.value, 22.1);
      expect(d.forecast.length, 17);
      expect(hits.length, 2);

      final d2 = await Wbgt.fetchPoint(tokyo,
          now: DateTime(2026, 8, 31, 21, 59), client: client);
      expect(identical(d, d2), isTrue);
      expect(hits.length, 2);

      await Wbgt.fetchPoint(tokyo, now: DateTime(2026, 8, 31, 22, 0), client: client);
      expect(hits.length, 4);
    });

    test('月初で当月ファイルに値が無ければ前月を見る', () async {
      final hits = <String>[];
      final client = MockClient((req) async {
        hits.add(req.url.path);
        if (req.url.path.contains('yohou_')) return http.Response('', 404);
        if (req.url.path.contains('_202609')) return http.Response('Date,Time,44132\n2026/9/1,1:00,\n', 200);
        if (req.url.path.contains('_202608')) return http.Response(_actual, 200);
        return http.Response('', 404);
      });
      final d = await Wbgt.fetchPoint(tokyo,
          now: DateTime(2026, 9, 1, 0, 30), client: client);
      expect(d.current!.value, 22.1);
      expect(d.forecast, isEmpty);
      expect(d.failed, isFalse);
      expect(hits.where((p) => p.contains('_202608')).length, 1);
    });

    test('両方失敗なら failed（キャッシュしない）', () async {
      var n = 0;
      final client = MockClient((_) async {
        n++;
        return http.Response('', 404);
      });
      final now = DateTime(2026, 8, 31, 21, 40);
      final d = await Wbgt.fetchPoint(tokyo, now: now, client: client);
      expect(d.failed, isTrue);
      await Wbgt.fetchPoint(tokyo, now: now, client: client);
      expect(n, 4); // 再試行される
    });
  });
}
