import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/x_accounts.dart';

Map<String, dynamic> _sample() => {
      'generated': '2026-09-07T00:00:00Z',
      'prefectures': [
        {
          'area_code': '13',
          'area_name': '東京都',
          'handle': 'tokyo_bousai',
          'display_name': '東京都防災',
          'type': 'official',
          'operator': '東京都 総務局総合防災部',
        },
        {
          'area_code': '11',
          'area_name': '埼玉県',
          'handle': 'saitama_kasen',
          'display_name': '埼玉県川の防災情報メール',
          'type': 'official',
        },
        {
          'area_code': '05',
          'area_name': '秋田県',
          'handle': 'pref_akita',
          'display_name': '秋田県庁',
          'type': 'official',
          'dedicated': false,
        },
        // 不正なハンドル・名前なしは捨てる
        {'area_code': '99', 'handle': 'bad handle!', 'display_name': 'x'},
        {'area_code': '98', 'handle': 'ok_handle'},
      ],
      'municipalities': [
        {
          'area_code': '11',
          'area_name': '川口市',
          'handle': 'kawaguchi_bosai',
          'display_name': '川口市防災',
          'type': 'official',
        },
      ],
      'national_offices': [
        {
          'area_codes': ['11', '12', '13'],
          'area_name': '江戸川',
          'handle': 'mlit_edogawa',
          'display_name': '国土交通省 江戸川河川事務所',
          'type': 'national',
        },
      ],
    };

void main() {
  setUp(XAccountsRepository.resetMemory);

  test('parse: 不正な項目を捨て、都道府県はコード順に並ぶ', () {
    final x = XAccounts.fromJson(_sample())!;
    expect(x.prefectures.map((a) => a.areaCodes.single).toList(),
        ['05', '11', '13']);
    expect(x.prefectures.last.type, XAccountType.official);
    expect(x.prefectures.first.dedicated, isFalse);
    expect(x.nationalOffices.single.type, XAccountType.national);
    expect(x.nationalOffices.single.areaCodes, ['11', '12', '13']);
    expect(x.municipalities.single.url.toString(),
        'https://x.com/kawaguchi_bosai');
  });

  test('forPrefecture: 県 → 国の機関 → 市区町村の順', () {
    final x = XAccounts.fromJson(_sample())!;
    expect(x.forPrefecture('11').map((a) => a.handle).toList(),
        ['saitama_kasen', 'mlit_edogawa', 'kawaguchi_bosai']);
    expect(x.forPrefecture('12').map((a) => a.handle).toList(),
        ['mlit_edogawa']);
    expect(x.forPrefecture('47'), isEmpty);
  });

  test('未知の種別は unknown、空データは null', () {
    expect(XAccountType.fromKey('something'), XAccountType.unknown);
    expect(XAccounts.fromJson({'prefectures': []}), isNull);
  });

  test('repository: 取得成功でメモリに控え、失敗時はそれを返す', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (calls == 1) {
        return http.Response(jsonEncode(_sample()), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('', 500);
    });
    final repo = XAccountsRepository(client: client);
    final first = await repo.load();
    expect(first, isNotNull);
    expect(calls, 1);
    // TTL内は再取得しない
    final second = await repo.load();
    expect(identical(first, second), isTrue);
    expect(calls, 1);
  });

  test('repository: 取得失敗かつ控えなしは null', () async {
    final client = MockClient((_) async => http.Response('', 500));
    expect(await XAccountsRepository(client: client).load(), isNull);
  });
}
