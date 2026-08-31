import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/quake_intensity.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/bosai_screen.dart';

Camera _cam(String pref, String? muni) => Camera.tryParse({
      'id': 'c$pref$muni', 'name': 'cam', 'category': 'road',
      'prefecture': pref, 'lat': 35.0, 'lng': 139.0, 'municipality': muni,
      'feed': {'type': 'still_image', 'url': 'https://example.com/a.jpg'},
      'source': {'page_url': 'https://example.com', 'license': 'unknown'},
    })!;

void main() {
  // 実例(2026-08-31 福島県会津 / 2026-08-23 茨城県南部)を模した list.json のレコード
  final reports = <Map<String, dynamic>>[
    {
      'eid': 'e1', 'at': '2026-08-31T03:29:00+09:00', 'anm': '福島県会津',
      'maxi': '4', 'ttl': '震源・震度情報', 'ser': '2',
      'int': [
        {
          'code': '07', 'maxi': '4',
          'city': [
            {'code': '0736700', 'maxi': '1'}, // 只見町
            {'code': '0720100', 'maxi': '4'}, // 会津若松市
          ],
        },
        {
          'code': '13', 'maxi': '2',
          'city': [
            {'code': '1311100', 'maxi': '2'}, // 大田区
          ],
        },
      ],
    },
    {
      // 続報。只見町の震度が上がり、札幌市(政令市=7桁は 0110000)が加わる
      'eid': 'e1', 'at': '2026-08-31T03:29:00+09:00', 'anm': '福島県会津',
      'maxi': '4', 'ttl': '震源・震度情報', 'ser': '3',
      'int': [
        {
          'code': '07', 'maxi': '4',
          'city': [
            {'code': '0736700', 'maxi': '3'},
            {'code': '0720100', 'maxi': '2'}, // 下がる報は無視される
          ],
        },
        {
          'code': '01', 'maxi': '1',
          'city': [
            {'code': '0110000', 'maxi': '1'}, // 札幌市
          ],
        },
      ],
    },
    // 震度速報のみ（int が無い）
    {'eid': 'e2', 'at': '2026-08-31T05:00:00+09:00', 'maxi': '3', 'ttl': '震度速報'},
  ];

  group('int配列の解析', () {
    test('7桁コードの先頭5桁を市区町村コードとして取り出す', () {
      final m = parseQuakeIntCities(reports.first['int']);
      expect(m, {'07367': '1', '07201': '4', '13111': '2'});
    });

    test('intが無い/壊れていても落ちない', () {
      expect(parseQuakeIntCities(null), isEmpty);
      expect(parseQuakeIntCities('x'), isEmpty);
      expect(parseQuakeIntCities([]), isEmpty);
      expect(parseQuakeIntCities([{'code': '07'}]), isEmpty); // cityなし
      expect(
          parseQuakeIntCities([
            {'code': '07', 'city': [{'code': '073', 'maxi': '1'}]}, // 桁不足
          ]),
          isEmpty);
      expect(
          parseQuakeIntCities([
            {'code': '07', 'city': [{'code': '0736700', 'maxi': ''}]}, // 震度なし
          ]),
          isEmpty);
    });

    test('5弱/6強などの表記を正規化する', () {
      expect(normalizeIntensity('5弱'), '5-');
      expect(normalizeIntensity('6強'), '6+');
      expect(normalizeIntensity('4'), '4');
      expect(
          parseQuakeIntCities([
            {'code': '07', 'city': [{'code': '0720100', 'maxi': '5弱'}]},
          ]),
          {'07201': '5-'});
    });
  });

  group('複数報の合成', () {
    final byEid = buildQuakeMuniIntensities(reports);

    test('市区町村ごとに最大震度を採る', () {
      expect(byEid['e1'], {
        '07367': '3', // 1 → 3 に上がった
        '07201': '4', // 続報の2では上書きされない
        '13111': '2',
        '01100': '1', // 政令市は 0110000 → 01100
      });
    });

    test('intが無い地震はキーごと作らない（震源周辺へフォールバックする）', () {
      expect(byEid.containsKey('e2'), isFalse);
      expect(byEid.length, 1);
    });

    test('震度の大きい順→コード昇順に並べる', () {
      final sorted = sortMuniIntensities(byEid['e1']!);
      expect(sorted.map((m) => m.code).toList(),
          ['07201', '07367', '13111', '01100']);
      expect(sorted.first.intensity, '4');
      expect(sorted.first.prefecture, '07');
      expect(sortMuniIntensities(const {}), isEmpty);
    });
  });

  group('カメラとの突合', () {
    final cameras = [
      _cam('07', '07201'), // 会津若松市
      _cam('13', '13111'), // 大田区
      _cam('01', '01103'), // 札幌市白石区（政令市の区）
      _cam('14', '14201'), // 横須賀市（無関係）
      _cam('07', null), // 市区町村コードなし
    ];

    test('市区町村コードで台数を数える（政令市は配下の区を含む）', () {
      expect(countCamerasInMunicipality(cameras, '07201'), 1);
      expect(countCamerasInMunicipality(cameras, '01100'), 1); // 札幌市→白石区
      expect(countCamerasInMunicipality(cameras, '07367'), 0); // 只見町はカメラ無し
      expect(countCamerasInMunicipality(cameras, ''), 0);
    });

    test('索引は総当たりと同じ台数を返す（大量件数向けの最適化）', () {
      final index = MuniCameraIndex(cameras);
      for (final muni in ['07201', '01100', '01103', '07367', '13111', '14201']) {
        expect(index.count(muni), countCamerasInMunicipality(cameras, muni),
            reason: muni);
      }
      expect(index.count(''), 0);
      expect(index.hasAny(const [MuniIntensity(code: '07367', intensity: '3')]),
          isFalse);
      expect(index.hasAny(const [MuniIntensity(code: '13111', intensity: '3')]),
          isTrue);
    });

    test('都道府県が食い違うカメラは数えない', () {
      expect(countCamerasInMunicipality([_cam('08', '07201')], '07201'), 0);
    });

    test('1つでも一致すれば市区町村導線を使う', () {
      final munis = sortMuniIntensities(buildQuakeMuniIntensities(reports)['e1']!);
      expect(canUseMuniNavigation(cameras, munis), isTrue);
    });

    test('int無し（震度速報のみ）は距離検索へフォールバック', () {
      expect(canUseMuniNavigation(cameras, const []), isFalse);
    });

    test('コードに一致するカメラが0件なら距離検索へフォールバック', () {
      // 合併等で台帳のコードとずれている想定
      const munis = [
        MuniIntensity(code: '07367', intensity: '3'),
        MuniIntensity(code: '07368', intensity: '2'),
      ];
      expect(canUseMuniNavigation(cameras, munis), isFalse);
      expect(canUseMuniNavigation(const <Camera>[], munis), isFalse);
    });
  });

  group('表示ヘルパ', () {
    test('気象庁の分割区域名を市名に丸める', () {
      expect(jmaCityName('横浜市北部'), '横浜市');
      expect(jmaCityName('大田区'), '大田区');
      expect(jmaCityName('北区'), '北区');
      expect(jmaCityName('会津若松市'), '会津若松市');
    });

    test('明るい震度色は黒文字にする', () {
      expect(intensityTextColor('4'), const Color(0xFF202124));
      expect(intensityTextColor('5-'), const Color(0xFF202124));
      expect(intensityTextColor('6+'), Colors.white);
    });

    test('震度の順位', () {
      expect(quakeIntensityRank('7'), greaterThan(quakeIntensityRank('6+')));
      expect(quakeIntensityRank('5-'), greaterThan(quakeIntensityRank('4')));
      expect(quakeIntensityRank(''), 0);
    });
  });
}
