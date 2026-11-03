import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/jma_area.dart';
import 'package:livecam_jp/data/muni_warnings.dart';
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

/// 11時発表（神奈川。週間は翌日から・今日の最低は 09 時の後ろに最高と同じ値で入る）
List<dynamic> forecast11() => [
      {
        'timeSeries': [
          {
            'timeDefines': ['2026-11-03T11:00:00+09:00', '2026-11-04T00:00:00+09:00', '2026-11-05T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '東部', 'code': '140010'}, 'weatherCodes': ['101', '212', '302']},
              {'area': {'name': '西部', 'code': '140020'}, 'weatherCodes': ['111', '212', '302']},
            ],
          },
          {
            'timeDefines': ['2026-11-03T12:00:00+09:00', '2026-11-03T18:00:00+09:00', '2026-11-04T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '東部', 'code': '140010'}, 'pops': ['0', '0', '10']},
              {'area': {'name': '西部', 'code': '140020'}, 'pops': ['0', '10', '10']},
            ],
          },
          {
            'timeDefines': ['2026-11-03T09:00:00+09:00', '2026-11-03T00:00:00+09:00',
              '2026-11-04T00:00:00+09:00', '2026-11-04T09:00:00+09:00'],
            'areas': [
              {'area': {'name': '横浜', 'code': '46106'}, 'temps': ['19', '19', '13', '18']},
              {'area': {'name': '小田原', 'code': '46166'}, 'temps': ['20', '20', '11', '18']},
            ],
          },
        ],
      },
      {
        'timeSeries': [
          {
            'timeDefines': ['2026-11-04T00:00:00+09:00', '2026-11-05T00:00:00+09:00', '2026-11-06T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '神奈川県', 'code': '140000'},
               'weatherCodes': ['212', '302', '201'], 'pops': ['', '90', '30']}
            ],
          },
          {
            'timeDefines': ['2026-11-04T00:00:00+09:00', '2026-11-05T00:00:00+09:00', '2026-11-06T00:00:00+09:00'],
            'areas': [
              {'area': {'name': '横浜', 'code': '46106'},
               'tempsMin': ['', '16', '12'], 'tempsMax': ['', '24', '20']}
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
  _popAtTests();
  _rainTextTests();
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
      expect(w.steps[1].weatherCode, '303');
      expect(w.repName, '横浜');
      expect(w.repTemps[DateTime.utc(2026, 11, 1, 15)], 17);
    });

    test('週間: 今日は [0] の列を足し、初日の気温が空なら今日明日の最高・最低で補う', () {
      final w = PointWeathers.parseWeek(forecast(), '140010', DateTime(2026, 11, 1, 21))!;
      expect(w.areaName, '神奈川県');
      expect(w.stationName, '横浜');
      expect(w.nearStationName, isNull);
      expect(w.days.length, 4);
      // 今日（11/1）は週間に無い → [0] の日別天気と 6 時間確率（18 時枠）。気温は無い
      expect(w.days[0].day, DateTime(2026, 11, 1));
      expect((w.days[0].code, w.days[0].pop, w.days[0].tempMax, w.days[0].tempMin), ('200', 10, null, null));
      expect(w.days[1].day, DateTime(2026, 11, 2));
      expect((w.days[1].tempMax, w.days[1].tempMin), (21, 13));
      expect(w.days[1].pop, 70); // 週間の初日は空 → [0] の6時間確率のその日の最大
      expect((w.days[2].tempMax, w.days[2].tempMin, w.days[2].pop), (20, 13, 20));
    });

    test('週間: 11時発表は今日の列を [0] から作り、気温はカメラに最も近い地点', () {
      final coords = {'46106': (35.4383, 139.6517), '46166': (35.2767, 139.155)};
      // 小田原城のカメラ → 今日明日は小田原、3日目からは横浜
      final w = PointWeathers.parseWeek(forecast11(), '140020', DateTime(2026, 11, 3, 12),
          lat: 35.2506, lng: 139.1536, coords: coords)!;
      expect((w.stationName, w.nearStationName), ('横浜', '小田原'));
      expect(w.days.map((d) => d.day.day).toList(), [3, 4, 5, 6]);
      // 今日: 天気は [0]、確率は 12 時・18 時枠の最大、最高は 09 時の値、最低は出さない
      expect((w.days[0].code, w.days[0].pop, w.days[0].tempMax, w.days[0].tempMin), ('111', 10, 20, null));
      // 明日: 天気は週間、確率は週間の初日が空なので [0] の 00 時枠、気温は小田原
      expect((w.days[1].code, w.days[1].pop, w.days[1].tempMax, w.days[1].tempMin), ('212', 10, 18, 11));
      // 3日目から: 週間の横浜
      expect((w.days[2].pop, w.days[2].tempMax, w.days[2].tempMin), (90, 24, 16));
      // 横浜に近いカメラなら横浜だけ
      final y = PointWeathers.parseWeek(forecast11(), '140010', DateTime(2026, 11, 3, 12),
          lat: 35.45, lng: 139.64, coords: coords)!;
      expect((y.stationName, y.nearStationName), ('横浜', null));
      expect((y.days[0].tempMax, y.days[1].tempMax, y.days[1].tempMin), (19, 18, 13));
      // 座標が無ければ従来どおり週間の地点の名前で [0] を引く
      final n = PointWeathers.parseWeek(forecast11(), '140020', DateTime(2026, 11, 3, 12))!;
      expect((n.nearStationName, n.days[0].tempMax), (null, 19));
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
      expect(weatherIconSpec('100'), (main: 'clear-day', then: null));
      expect(weatherIconSpec('203'), (main: 'overcast-rain', then: null));
      expect(weatherIconSpec('212'), (main: 'overcast', then: 'rain')); // のち
      expect(weatherIconSpec('414'), (main: 'snow', then: 'rain'));
      expect(weatherIconSpec('999'), isNull);
      expect(weatherCodeOfText('くもり　時々　晴れ'), '200');
      expect(weatherCodeOfText('雨'), '300');
      expect(weatherCodeOfText('雨または雪'), '303');
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

    test('現在の時刻を含む列の気温はアメダスの実況に置き換える', () {
      final steps = PointWeathers.parsePoint(block(), 35.68, 139.76);
      // 2026-11-01 14:00Z = JST 23:00。観測 JST 22:50（13:50Z）
      final pw = PointWeather(
          steps: steps,
          amedas: AmedasNow(
              name: '東京', distanceKm: 3.2, at: DateTime(2026, 11, 1, 22, 50), temp: 17.1));
      final now = DateTime.utc(2026, 11, 1, 14);
      final cols = pw.columns(now);
      expect(cols.first.validUtc, DateTime.utc(2026, 11, 1, 12));
      expect(cols.first.temp, 17);
      expect(cols.first.tempObserved, isTrue);
      // 次の列は予報のまま
      expect(cols[1].temp, PointWeather(steps: steps).columns(now)[1].temp);
      expect(cols[1].tempObserved, isFalse);
      // 観測が古ければ置き換えない
      final stale = PointWeather(
          steps: steps,
          amedas: AmedasNow(
              name: '東京', distanceKm: 3.2, at: DateTime(2026, 11, 1, 18, 0), temp: 17.1));
      expect(stale.columns(now).first.tempObserved, isFalse);
      expect(stale.columns(now).first.temp, PointWeather(steps: steps).columns(now).first.temp);
      // 最初の列がまだ先（now が枠の前）なら置き換えない
      final early = pw.columns(DateTime.utc(2026, 11, 1, 11, 30));
      expect(early.first.validUtc, DateTime.utc(2026, 11, 1, 12));
      expect(early.first.tempObserved, isFalse);
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
      expect(find.byIcon(Icons.navigation, skipOffstage: false), findsNothing); // 3時間予報に風は出さない
      expect(find.text('月'), findsOneWidget);
      expect(find.text('日'), findsOneWidget); // 今日 11/1（日曜）の列も出る 〜 11/4 は水曜
      expect(find.textContaining('週間は 神奈川県 の予報・気温は 横浜'), findsOneWidget);
      expect(find.textContaining('出典：気象庁ホームページ'), findsOneWidget);
      expect(find.textContaining('Meteocons（Bas Milius, MIT）'), findsOneWidget);
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
      expect(find.textContaining('風は'), findsNothing);
      expect(find.text('14.9℃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('警報あり → 最上位のバッジが出てタップでシート', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = false;
      await tester.pumpWidget(testApp(Scaffold(body: SingleChildScrollView(
          child: PointWeatherCard(
              camera: cam(),
              loader: (_) async => full(),
              now: now,
              onOpenWarningTab: () => opened = true,
              warningLoader: (_) async => MuniWarnings(
                  codes: const ['49', '14'],
                  cityName: '横浜市北部',
                  issuedAt: DateTime.utc(2026, 11, 1, 2)))))));
      await tester.pumpAndSettle();
      expect(find.text('危険警報 (Lv.4)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('point_weather_warning_badge')));
      await tester.pumpAndSettle();
      expect(find.text('横浜市 の警報・注意報'), findsOneWidget);
      // 警報も注意報も名前で出す（注意報 14 が '14' のまま出ていた。2026-11-02 神戸の濃霧注意報）
      expect(find.text('土砂災害危険警報'), findsOneWidget);
      expect(find.text('雷注意報'), findsOneWidget);
      expect(find.text('14'), findsNothing);
      expect(find.text('防災タブで見る'), findsOneWidget);
      await tester.tap(find.text('防災タブで見る'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('警報なし・取得失敗 → バッジは出ず他は出る', (tester) async {
      await pump(tester, full());
      expect(find.byKey(const Key('point_weather_warning_badge')), findsNothing);
      expect(find.text('14.9℃'), findsOneWidget);
      await tester.pumpWidget(testApp(Scaffold(body: PointWeatherCard(
          camera: cam(),
          loader: (_) async => full(),
          now: now,
          warningLoader: (_) async => throw Exception('x')))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('point_weather_warning_badge')), findsNothing);
      expect(find.text('14.9℃'), findsOneWidget);
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

    testWidgets('今日＋週間7日の 8 列でも 390px 幅で崩れない', (tester) async {
      final week = WeekForecast(areaName: '神奈川県', stationName: '横浜', nearStationName: '小田原', days: [
        for (var i = 0; i < 8; i++)
          WeekDay(day: DateTime(2026, 11, 1 + i), code: '302', pop: 100, tempMax: -10 + i, tempMin: -15 + i),
      ]);
      for (final loc in const [
        Locale('ja'),
        Locale('en'),
        Locale('vi'),
        Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
      ]) {
        await pump(tester, PointWeather(steps: const [], week: week), locale: loc);
        expect(find.byType(WeatherIcon, skipOffstage: false), findsNWidgets(8));
        expect(tester.takeException(), isNull);
        if (loc == const Locale('ja')) {
          expect(find.textContaining('気温は今日明日が 小田原、それ以降は 横浜'), findsOneWidget);
        }
      }
    });

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

void _popAtTests() {
  test('降水確率は 6 時間枠の 2 列に同じ値', () {
    final t0 = DateTime.utc(2026, 11, 1, 21); // JST 11/2 06:00 の枠
    final pops = {t0: 30, t0.add(const Duration(hours: 6)): 80};
    expect(PointWeather.popAt(pops, t0), 30);
    expect(PointWeather.popAt(pops, t0.add(const Duration(hours: 3))), 30);
    expect(PointWeather.popAt(pops, t0.add(const Duration(hours: 6))), 80);
    expect(PointWeather.popAt(pops, t0.add(const Duration(hours: 9))), 80);
    expect(PointWeather.popAt(pops, t0.add(const Duration(hours: 12))), isNull);
    expect(PointWeather.popAt(pops, t0.subtract(const Duration(hours: 1))), isNull);
  });
}

void _rainTextTests() {
  test('降るマークの列は 1mm 未満でも 1mm と出す', () {
    expect(rainText(0), '0mm');
    expect(rainText(0, weatherCode: '200'), '0mm');
    expect(rainText(0, weatherCode: '300'), '1mm');
    expect(rainText(0, weatherCode: '400'), '1mm');
    expect(rainText(1, weatherCode: '400'), '3mm');
  });
}
