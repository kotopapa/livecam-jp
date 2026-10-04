import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/water_level.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/water_level_card.dart';

import 'l10n_test_app.dart';

Map<String, dynamic> currentJson() => {
      'dspFlg': 1,
      'obsValue': {'stg': 0.81, 'obsTime': '2026/10/04 22:00', 'stgCcd': 0},
      'predstgValues': [
        {'stg': 0.9, 'obsTime': '2026/10/04 23:00'},
      ],
      'min10Values': [
        {'stg': null, 'obsTime': '2026/10/04 22:30'},
        {'stg': 0.81, 'obsTime': '2026/10/04 22:20'},
        {'stg': 0.80, 'obsTime': '2026/10/04 22:10'},
        {'stg': 0.79, 'obsTime': '2026/10/04 14:30'},
      ],
    };

Map<String, dynamic> pastJson() => {
      'pastValues': [
        {'stg': 0.67, 'obsTime': '2026/09/27 00:00'},
        {'stg': 0.70, 'obsTime': '2026/10/03 00:00'},
        {'stg': 0.75, 'obsTime': '2026/10/04 14:00'},
        {'stg': 0.99, 'obsTime': '2026/10/04 15:00'}, // 10分値の範囲に入るので捨てる
      ],
    };

void main() {
  final now = DateTime(2026, 10, 4, 22, 46);

  setUp(() {
    WaterLevel.resetCache();
    WaterStations.resetCache();
  });

  test('時刻は JST 壁時計の素の DateTime として読む', () {
    final t = WaterLevel.parseTime('2026/10/04 22:30');
    expect(t, DateTime(2026, 10, 4, 22, 30));
    expect(t!.isUtc, isFalse);
    expect(WaterLevel.parseTime('bad'), isNull);
  });

  test('現況は欠測を捨てて昇順、過去の時間値は10分値より前だけを結合し48時間に絞る', () {
    final cur = WaterLevel.parseCurrent(currentJson());
    expect(cur.latest!.stage, 0.81);
    expect(cur.points.map((p) => p.stage), [0.79, 0.80, 0.81]);
    expect(cur.forecast.length, 1);
    final merged = WaterLevel.merge(WaterLevel.parsePast(pastJson()), cur.points, now);
    expect(merged.map((p) => p.stage), [0.70, 0.75, 0.79, 0.80, 0.81]);
  });

  test('最新スロットが無ければさかのぼり、過去ファイルと結合する', () async {
    final requested = <String>[];
    final client = MockClient((req) async {
      requested.add(req.url.path);
      if (req.url.path.endsWith('/2240/0230500400006.json')) {
        return http.Response('not found', 404);
      }
      if (req.url.path.contains('/tmlist/stg/')) {
        return http.Response(jsonEncode(currentJson()), 200);
      }
      if (req.url.path.contains('/tmlist/past/stg/20261004/')) {
        return http.Response(jsonEncode(pastJson()), 200);
      }
      return http.Response('not found', 404);
    });
    final s = await WaterLevel.fetch('0230500400006', client: client, nowJst: now);
    expect(requested.first, endsWith('/tmlist/stg/20261004/2240/0230500400006.json'));
    expect(requested[1], endsWith('/tmlist/stg/20261004/2230/0230500400006.json'));
    expect(s!.latest!.stage, 0.81);
    expect(s.points.length, 5);
    // 5分はメモリ控えを返す（再取得しない）
    final n = requested.length;
    await WaterLevel.fetch('0230500400006', client: client, nowJst: now);
    expect(requested.length, n);
  });

  test('観測所の配信ファイルを読む', () {
    final st = WaterStations.parse({
      'stations': {
        '0230500400006': {
          'name': '東橋', 'lat': 36.55, 'lon': 139.88, 'rvr': '田川', 'ofc': 2305, 'obs': 6,
          'levels': {'rsrv': 1.4, 'warn': 2, 'dng': 3.7, 'fld': 4.6},
        },
        'bad': {'name': 'x'},
      },
    });
    expect(st.keys, ['0230500400006']);
    expect(st['0230500400006']!.levels['warn'], 2.0);
    expect(st['0230500400006']!.siteUrl.toString(), contains('ofcCd=2305&obsCd=6'));
  });

  test('グラフの縦軸は観測値の上にある最初の基準水位まで含める', () {
    final painter = WaterLevelChartPainter(
      points: [WaterLevelPoint(now, 0.5), WaterLevelPoint(now.subtract(const Duration(hours: 1)), 0.4)],
      levels: const {'rsrv': 1.4, 'warn': 2.0, 'dng': 3.7},
      nowJst: now,
      textColor: Colors.black,
      gridColor: Colors.grey,
    );
    final (lo, hi) = painter.yRange();
    expect(hi, greaterThanOrEqualTo(1.4));
    expect(hi, lessThan(2.0));
    expect(lo, lessThan(0.4));
  });

  testWidgets('カードは最新値・凡例・出典を出す', (tester) async {
    final cam = Camera.tryParse({
      'id': 'kawabou-1', 'name': '東橋カメラ', 'category': 'river', 'prefecture': '09',
      'lat': 36.55, 'lng': 139.88, 'coord_accuracy': 'exact',
      'feed': {'type': 'still_image', 'url': 'https://cam.river.go.jp/cam/now/1.jpg'},
      'operator': '栃木県', 'source': {'attribution': '出典：栃木県'},
      'water_level': {'obs': '0230500400006', 'dist_m': 30},
    })!;
    expect(cam.waterLevel!.obs, '0230500400006');
    final station = WaterStation(
        obs: '0230500400006', name: '東橋', lat: 36.55, lon: 139.88, ofc: 2305, obsCd: 6,
        levels: const {'warn': 2.0, 'dng': 3.7});
    final series = WaterLevelSeries(
      points: [WaterLevelPoint(now.subtract(const Duration(hours: 2)), 0.5), WaterLevelPoint(now, 0.81)],
      latest: WaterLevelPoint(DateTime(2026, 10, 4, 22, 0), 0.81),
    );
    await tester.pumpWidget(testApp(SingleChildScrollView(
      child: WaterLevelCard(camera: cam, loader: (_) async => (station, series)),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.81 m'), findsOneWidget);
    expect(find.textContaining('東橋'), findsWidgets);
    expect(find.textContaining('氾濫危険水位'), findsOneWidget);
    expect(find.textContaining('川の防災情報'), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
