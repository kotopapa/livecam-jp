import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/jma_area.dart';
import 'package:livecam_jp/data/point_weather.dart';
import 'package:livecam_jp/data/wave_forecast.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/point_weather_card.dart';

import 'l10n_test_app.dart';

Camera cam({double lat = 35.68, double lng = 139.76, String? municipality = '14201'}) => Camera(
      id: 'c1', name: 'カメラ', category: 'city', prefecture: '14',
      municipality: municipality, lat: lat, lng: lng,
      feed: Feed(type: FeedType.stillImage, url: 'https://example.jp/a.jpg'),
      operator: 'x', attribution: 'x', sourcePageUrl: 'https://example.jp/',
      coordAccuracy: CoordAccuracy.exact,
    );

Map<String, dynamic> readJson(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

const times = ['20261101120000', '20261101150000', '20261101180000', '20261101210000'];

/// lat=35.68 lng=139.76 → ブロック 34_138、格子 (33, 28)
Map<String, dynamic> block({List<Map<String, dynamic>>? points}) => {
      'basetime': '20261101080000',
      'validtimes': times,
      'lat0': 34,
      'lng0': 138,
      'points': points ??
          [
            {'i': 33, 'j': 28, 't': [14, 12, null, 10], 'w': [2, 3, 4, 5], 'r': [0, 1, 5, 0], 's': [0, 0, 0, 2]},
          ],
    };

List<dynamic> forecast() => [
      {
        'timeSeries': [
          {
            'timeDefines': ['2026-11-01T17:00:00+09:00'],
            'areas': [{'area': {'name': '東部', 'code': '140010'}, 'weatherCodes': ['200']}],
          },
          {
            'timeDefines': ['2026-11-01T18:00:00+09:00', '2026-11-02T00:00:00+09:00', '2026-11-02T06:00:00+09:00'],
            'areas': [{'area': {'name': '東部', 'code': '140010'}, 'pops': ['10', '20', '70']}],
          },
          {
            'timeDefines': ['2026-11-02T00:00:00+09:00', '2026-11-02T09:00:00+09:00'],
            'areas': [{'area': {'name': '横浜', 'code': '46106'}, 'temps': ['13', '21']}],
          },
        ],
      },
      {
        'timeSeries': [
          {
            'timeDefines': ['2026-11-02T00:00:00+09:00', '2026-11-03T00:00:00+09:00', '2026-11-04T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '神奈川県', 'code': '140000'},
               'weatherCodes': ['212', '101', '999'], 'pops': ['', '20', '40']}
            ],
          },
          {
            'timeDefines': ['2026-11-02T00:00:00+09:00', '2026-11-03T00:00:00+09:00', '2026-11-04T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '横浜', 'code': '46106'},
               'tempsMin': ['', '13', '12'], 'tempsMax': ['', '20', '19']}
            ],
          },
        ],
      },
    ];

Map<String, dynamic> vpfd() => {
      'reportDateTime': '2026-11-01T17:00:00+09:00',
      'areaTimeSeries': {
        'timeDefines': [
          {'dateTime': '2026-11-01T21:00:00+09:00', 'duration': 'PT3H'},
          {'dateTime': '2026-11-02T00:00:00+09:00', 'duration': 'PT3H'},
        ],
        'weather': ['くもり', '雨または雪'],
        'wind': [
          {'direction': '南', 'speed': 2, 'range': '3 5'},
          {'direction': '静穏', 'speed': 0, 'range': ''},
        ],
      },
      'pointTimeSeries': {
        'pointNameJP': '横浜',
        'pointNameEN': 'Yokohama',
        'timeDefines': [
          {'dateTime': '2026-11-01T21:00:00+09:00'},
          {'dateTime': '2026-11-02T00:00:00+09:00'},
        ],
        'temperature': [18, 17],
      },
    };

void main() {
  setUp(() {
    JmaAreaNames.reset();
    JmaAreaNames.parse(readJson('area_wave.json'));
    WaveForecasts.resetCache();
    PointWeathers.resetCache();
  });

  group('格子', () {
    test('ブロック名と格子番号', () {
      expect(PointWeathers.blockName(35.68, 139.76), '34_138');
      expect(PointWeathers.gridIndex(35.68, 139.76, 34, 138), (33, 28));
      expect(PointWeathers.blockName(43.06, 141.35), '42_140');
    });

    test('本体 → 8近傍 → 無し', () {
      final p = PointWeathers.findPoint(block(), 35.68, 139.76);
      expect(p!['i'], 33);
      final near = block(points: [
        {'i': 34, 'j': 27, 't': [1]},
        {'i': 33, 'j': 29, 't': [2]},
        {'i': 40, 'j': 40, 't': [3]},
      ]);
      final q = PointWeathers.findPoint(near, 35.68, 139.76)!;
      expect((q['i'] as int) * 100 + (q['j'] as int), isIn([3427, 3329]));
      expect(PointWeathers.findPoint(block(points: [{'i': 40, 'j': 40}]), 35.68, 139.76), isNull);
    });

    test('点の予報の解析', () {
      final s = PointWeathers.parsePoint(block(), 35.68, 139.76);
      expect(s.length, 4);
      expect(s.first.validUtc, DateTime.utc(2026, 11, 1, 12));
      expect(s[2].temp, isNull);
      expect(s[3].snow, 2);
      expect(s[1].weather, 3);
    });
  });

  group('風・週間・降水確率', () {
    test('風向と範囲', () {
      expect(PointWeathers.dirFromName('南西'), 10);
      expect(PointWeathers.dirFromName('北'), 16);
      expect(PointWeathers.dirFromName('静穏'), 0);
      expect(PointWeathers.dirFromName(''), isNull);
      expect(PointWeathers.parseRange('3 5'), (3, 5));
      expect(PointWeathers.parseRange('4'), (4, 4));
      expect(PointWeathers.parseRange(''), isNull);
    });

    test('VPFD: 時刻は instant・天気文字列はコードへ', () {
      final w = PointWeathers.parseVpfd(vpfd(), areaName: '東部', areaEnName: 'Eastern')!;
      expect(w.steps.first.validUtc, DateTime.utc(2026, 11, 1, 12));
      expect(w.steps.first.dir, 8);
      expect((w.steps.first.minMs, w.steps.first.maxMs), (3, 5));
      expect(w.steps[1].dir, 0);
      expect(w.steps[1].weatherCode, '313');
      expect(w.repName, '横浜');
      expect(w.repTemps[DateTime.utc(2026, 11, 1, 15)], 17);
    });

    test('週間: 初日の気温が空なら今日明日の最高・最低で補う', () {
      final w = PointWeathers.parseWeek(forecast(), '140010', DateTime(2026, 11, 1, 21))!;
      expect(w.areaName, '神奈川県');
      expect(w.stationName, '横浜');
      expect(w.days.length, 3);
      expect(w.days[0].day, DateTime(2026, 11, 2));
      expect((w.days[0].tempMax, w.days[0].tempMin), (21, 13));
      expect(w.days[0].pop, isNull);
      expect((w.days[1].tempMax, w.days[1].tempMin, w.days[1].pop), (20, 13, 20));
    });

    test('週間: 過ぎた日は出さない', () {
      final w = PointWeathers.parseWeek(forecast(), '140010', DateTime(2026, 11, 3, 9))!;
      expect(w.days.first.day, DateTime(2026, 11, 3));
    });

    test('降水確率は枠の開始 instant で引ける', () {
      final p = PointWeathers.parsePops(forecast(), '140010');
      expect(p[DateTime.utc(2026, 11, 1, 9)], 10);
      expect(p[DateTime.utc(2026, 11, 1, 21)], 70);
    });

    test('天気マーク: 無いコードは近いものへ・文字列対応', () {
      expect(weatherIconBase('100'), '100');
      expect(weatherIconBase('203'), '202');
      expect(weatherIconBase('999'), '');
      expect(weatherCodeOfText('くもり　時々　晴れ'), '200');
      expect(weatherCodeOfText('雨'), '300');
      expect(weatherCodeOfText('雨または雪'), '313');
      expect(weatherCodeOfText(''), isNull);
      expect(weatherCodeOfW(1), '100');
      expect(weatherCodeOfW(0), isNull);
    });
  });

  group('列', () {
    test('過ぎた枠は出さず、風と突き合わせる', () {
      final pw = PointWeather(
        steps: PointWeathers.parsePoint(block(), 35.68, 139.76),
        wind: PointWeathers.parseVpfd(vpfd(), areaName: '東部', areaEnName: ''),
        pops: PointWeathers.parsePops(forecast(), '140010'),
      );
      // 12:00Z の枠は [12,15) なので 14:00Z でも出る
      var cols = pw.columns(DateTime.utc(2026, 11, 1, 14));
      expect(cols.length, 4);
      expect(cols.first.wind!.dir, 8);
      expect(cols.first.weatherCode, '200');
      expect(cols[3].pop, 70);
      // 15:00Z ちょうどなら最初の枠は終わっている
      cols = pw.columns(DateTime.utc(2026, 11, 1, 15));
      expect(cols.length, 3);
      expect(cols.first.validUtc, DateTime.utc(2026, 11, 1, 15));
    });

    test('点の予報が無ければ区域の風と代表地点の気温で並べる', () {
      final pw = PointWeather(
          wind: PointWeathers.parseVpfd(vpfd(), areaName: '東部', areaEnName: ''));
      expect(pw.tempIsRepresentative, isTrue);
      final cols = pw.columns(DateTime.utc(2026, 11, 1, 12));
      expect(cols.map((c) => c.temp), [18, 17]);
      expect(cols.first.weatherCode, '200');
    });
  });

  group('アメダス', () {
    final stations = [
      const AmedasStation('1', '近い雨量計', 35.681, 139.761),
      const AmedasStation('2', '東京', 35.69, 139.75),
      const AmedasStation('3', '遠い', 36.5, 140.5),
    ];
    final at = DateTime(2026, 11, 2, 3, 40);

    test('気温のある最寄りを選び、品質フラグ0だけ使う', () {
      final map = {
        '1': {'precipitation1h': [0.0, 0]},
        '2': {
          'temp': [14.9, 0],
          'humidity': [77, 0],
          'wind': [1.8, 0],
          'windDirection': [2, 0],
          'precipitation1h': [0.5, 1],
        },
      };
      final a = PointWeathers.nearestAmedas(map, stations, 35.68, 139.76, at)!;
      expect(a.name, '東京');
      expect(a.temp, 14.9);
      expect(a.windDir, 2);
      expect(a.precip1h, isNull);
      expect(a.distanceKm, closeTo(1.2, 0.3));
    });

    test('気温が無ければ取れる最寄り・30km 超は対象外', () {
      final map = {
        '1': {'precipitation1h': [0.0, 0]},
        '3': {'temp': [10.0, 0]},
      };
      expect(PointWeathers.nearestAmedas(map, stations, 35.68, 139.76, at)!.name, '近い雨量計');
      expect(PointWeathers.nearestAmedas({'3': {'temp': [10.0, 0]}}, stations, 35.68, 139.76, at), isNull);
    });
  });

  group('取得', () {
    http.Client client({bool noBlock = false, bool noWdist = false}) => MockClient((req) async {
          final u = req.url.toString();
          http.Response j(Object o) => http.Response.bytes(utf8.encode(jsonEncode(o)), 200);
          if (u.endsWith('/wdist/index.json')) {
            return noWdist
                ? http.Response('', 404)
                : j({'basetime': '20261101080000', 'validtimes': times, 'blocks': ['34_138']});
          }
          if (u.endsWith('/wdist/34_138.json')) return noBlock ? http.Response('', 404) : j(block());
          if (u.contains('/VPFD/140010.json')) return j(vpfd());
          if (u.endsWith('/forecast/140000.json')) return j(forecast());
          if (u.endsWith('latest_time.txt')) return http.Response('2026-11-02T03:40:00+09:00', 200);
          if (u.contains('/amedas/data/map/20261102034000.json')) {
            return j({'2': {'temp': [14.9, 0]}});
          }
          return http.Response('', 404);
        });

    setUp(() => PointWeathers.setStations([const AmedasStation('2', '東京', 35.69, 139.75)]));

    test('3情報源がそろう', () async {
      final pw = (await PointWeathers.fetch(cam(), client: client()))!;
      expect(pw.hasPoint, isTrue);
      expect(pw.wind!.steps, isNotEmpty);
      expect(pw.amedas!.name, '東京');
      expect(pw.week!.days, isNotEmpty);
      expect(pw.baseUtc, DateTime.utc(2026, 11, 1, 8));
    });

    test('点の予報が 404 でも他で出す', () async {
      final pw = (await PointWeathers.fetch(cam(), client: client(noBlock: true)))!;
      expect(pw.hasPoint, isFalse);
      expect(pw.wind, isNotNull);
    });

    test('海外・座標外は null', () async {
      expect(await PointWeathers.fetch(cam(lat: 51, lng: 0), client: client()), isNull);
    });
  });

  group('カード', () {
    final now = DateTime.utc(2026, 11, 1, 12);

    PointWeather full() => PointWeather(
          steps: [
            for (var k = 0; k < 16; k++)
              PointStep(
                  validUtc: DateTime.utc(2026, 11, 1, 12).add(Duration(hours: 3 * k)),
                  temp: 10 + (k % 8),
                  weather: 1 + k % 5,
                  rain: k % 6,
                  snow: k % 4),
          ],
          wind: PointWeathers.parseVpfd(vpfd(), areaName: '東京地方', areaEnName: 'Tokyo'),
          amedas: AmedasNow(
              name: '東京', distanceKm: 3.2, at: DateTime(2026, 11, 2, 3, 40),
              temp: 14.9, humidity: 77, windMs: 1.8, windDir: 2, precip1h: 0.0),
          baseUtc: DateTime.utc(2026, 11, 1, 8),
          week: PointWeathers.parseWeek(forecast(), '140010', DateTime(2026, 11, 1, 21)),
          pops: PointWeathers.parsePops(forecast(), '140010'),
        );

    Future<void> pump(WidgetTester tester, PointWeather? pw, {Locale locale = const Locale('ja')}) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(
          SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PointWeatherCard(camera: cam(), loader: (_) async => pw, now: now))),
          locale: locale));
      await tester.pumpAndSettle();
    }

    testWidgets('3情報源そろえば全部の部品が出る', (tester) async {
      await pump(tester, full());
      expect(find.text('この地点の天気'), findsOneWidget);
      expect(find.text('14.9℃'), findsOneWidget);
      expect(find.textContaining('最寄りの観測点 東京（3.2km）'), findsOneWidget);
      expect(find.textContaining('湿度 77%'), findsOneWidget);
      expect(find.byType(TempChartPainter, skipOffstage: false), findsNothing); // Painter は Widget ではない
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TempChartPainter),
          findsOneWidget);
      expect(find.byType(WeatherIcon, skipOffstage: false), findsWidgets);
      expect(find.byIcon(Icons.navigation, skipOffstage: false), findsWidgets);
      expect(find.text('月'), findsOneWidget);
      expect(find.text('日'), findsNothing); // 11/2 は月曜 〜 11/4 は水曜
      expect(find.textContaining('週間は 神奈川県 の予報・気温は 横浜'), findsOneWidget);
      expect(find.textContaining('出典：気象庁ホームページ'), findsOneWidget);
      expect(find.textContaining('11/1 17:00 発表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点の予報が無くても区域の風と代表地点の気温で出る', (tester) async {
      final pw = PointWeather(
        wind: PointWeathers.parseVpfd(vpfd(), areaName: '東京地方', areaEnName: 'Tokyo'),
        amedas: AmedasNow(name: '東京', distanceKm: 3.2, at: DateTime(2026, 11, 2, 3, 40), temp: 14.9),
      );
      await pump(tester, pw);
      expect(find.textContaining('代表地点 横浜'), findsOneWidget);
      expect(find.textContaining('風は 東京地方 の予報'), findsOneWidget);
      expect(find.text('14.9℃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('実況だけでも出る', (tester) async {
      await pump(tester, PointWeather(
          amedas: AmedasNow(name: '東京', distanceKm: 3.2, at: DateTime(2026, 11, 2, 3, 40), temp: 14.9)));
      expect(find.text('14.9℃'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TempChartPainter),
          findsNothing);
    });

    testWidgets('全部無ければ何も出ない（区切り線も）', (tester) async {
      await pump(tester, null);
      expect(find.text('この地点の天気'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    for (final loc in const [
      Locale('ja'), Locale('en'), Locale('ko'), Locale('vi'), Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
    ]) {
      testWidgets('390px 幅で崩れない: $loc', (tester) async {
        await pump(tester, full(), locale: loc);
        expect(tester.takeException(), isNull);
        expect(find.byType(WeatherIcon, skipOffstage: false), findsWidgets);
      });
    }

    testWidgets('復帰の合図で取り直す', (tester) async {
      final tick = ValueNotifier(0);
      var n = 0;
      await tester.pumpWidget(testApp(PointWeatherCard(
          camera: cam(), resumeTick: tick, now: now, loader: (_) async { n++; return full(); })));
      await tester.pumpAndSettle();
      tick.value++;
      await tester.pumpAndSettle();
      expect(n, 2);
    });
  });
}
