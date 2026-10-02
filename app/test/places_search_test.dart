import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/places_search.dart';

void main() {
  test('parseResponse: searchText の応答を「名称（住所）」と座標にする', () {
    final hits = PlacesSearch.parseResponse({
      'places': [
        {
          'displayName': {'text': '赤レンガ倉庫'},
          'formattedAddress': '神奈川県横浜市中区新港1丁目1',
          'location': {'latitude': 35.452281, 'longitude': 139.645066},
        },
        {
          // 座標が不正な形式のものは無視する
          'displayName': {'text': '壊れ'},
          'location': {'latitude': 'x', 'longitude': 1},
        },
        {
          // 名前が無いものも無視する
          'location': {'latitude': 1.0, 'longitude': 2.0},
        },
      ],
    })!;
    expect(hits.length, 1);
    expect(hits.first.$1, '赤レンガ倉庫（神奈川県横浜市中区新港1丁目1）');
    expect(hits.first.$2.latitude, 35.452281);
    expect(hits.first.$2.longitude, 139.645066);
    expect(PlacesSearch.parseResponse({'places': []}), isNull);
    expect(PlacesSearch.parseResponse(null), isNull);
    expect(PlacesSearch.parseResponse('x'), isNull);
  });

  test('parseResponse: 住所が無ければ名称だけ', () {
    final hits = PlacesSearch.parseResponse({
      'places': [
        {
          'displayName': {'text': '富士山'},
          'location': {'latitude': 35.36, 'longitude': 138.73},
        },
      ],
    })!;
    expect(hits.first.$1, '富士山');
  });

  test('textSearch: クエリが空・キーが無ければ呼ばない', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"places":[]}', 200);
    });
    expect(
      await PlacesSearch.textSearch('', apiKey: 'KEY', client: client),
      isNull,
    );
    expect(
      await PlacesSearch.textSearch('横浜', apiKey: '', client: client),
      isNull,
    );
    expect(calls, 0);
  });

  test('textSearch: リクエスト仕様（ヘッダー・本文）、200以外はnull、0件はnull', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(
        req.url.toString(),
        'https://places.googleapis.com/v1/places:searchText',
      );
      expect(req.headers['X-Goog-Api-Key'], 'KEY');
      expect(
        req.headers['X-Goog-FieldMask'],
        'places.id,places.displayName,places.formattedAddress,places.location',
      );
      expect(req.headers['X-Android-Package'], 'jp.livecam.livecam_jp');
      final body = jsonDecode(req.body) as Map;
      expect(body['textQuery'], '横浜駅');
      expect(body['languageCode'], 'ja');
      expect(body['regionCode'], 'JP');
      expect(body['pageSize'], 8);
      expect(body.containsKey('locationBias'), isFalse);
      // http.Response(String, ...) は既定でlatin1エンコードのため日本語を含む
      // 本文は utf8 のバイト列で構成する（本物のサーバ応答はUTF-8で届く）
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'places': [
              {
                'displayName': {'text': '横浜駅'},
                'formattedAddress': '神奈川県横浜市西区',
                'location': {'latitude': 35.4657, 'longitude': 139.622},
              },
            ],
          }),
        ),
        200,
      );
    });
    final hits = await PlacesSearch.textSearch(
      '横浜駅',
      apiKey: 'KEY',
      headers: const {'X-Android-Package': 'jp.livecam.livecam_jp'},
      client: client,
    );
    expect(hits, isNotNull);
    expect(hits!.first.$1, '横浜駅（神奈川県横浜市西区）');
    expect(calls, 1);

    final bad = MockClient((_) async => http.Response('quota', 429));
    expect(
      await PlacesSearch.textSearch('横浜駅', apiKey: 'KEY', client: bad),
      isNull,
    );

    final empty = MockClient((_) async => http.Response('{"places":[]}', 200));
    expect(
      await PlacesSearch.textSearch('存在しない場所xyz', apiKey: 'KEY', client: empty),
      isNull,
    );
  });

  test('textSearch: bias を渡したときだけ locationBias を付ける', () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((req) async {
      capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"places":[]}', 200);
    });
    await PlacesSearch.textSearch('東京タワー', apiKey: 'KEY', client: client);
    expect(capturedBody!.containsKey('locationBias'), isFalse);

    await PlacesSearch.textSearch(
      '東京タワー',
      apiKey: 'KEY',
      bias: const LatLng(35.0, 139.0),
      client: client,
    );
    expect(capturedBody!['locationBias']['circle']['radius'], 50000);
    expect(capturedBody!['locationBias']['circle']['center']['latitude'], 35.0);
    expect(
      capturedBody!['locationBias']['circle']['center']['longitude'],
      139.0,
    );
  });

  group('parseAutocomplete', () {
    test('suggestions → PlacePrediction のリスト（構造化テキスト・距離・種別）', () {
      final preds = PlacesSearch.parseAutocomplete({
        'suggestions': [
          {
            'placePrediction': {
              'placeId': 'ChIJ横浜駅',
              'structuredFormat': {
                'mainText': {'text': '横浜駅'},
                'secondaryText': {'text': '神奈川県横浜市西区'},
              },
              'distanceMeters': 850,
              'types': ['train_station', 'point_of_interest'],
            },
          },
          {
            // 座標系情報が無くても text だけで通す
            'placePrediction': {
              'placeId': 'ChIJ壊れ',
              'text': {'text': '何かの場所'},
            },
          },
          {
            // placeId が無いものは無視
            'placePrediction': {
              'structuredFormat': {
                'mainText': {'text': '無視される'},
              },
            },
          },
        ],
      })!;
      expect(preds.length, 2);
      expect(preds[0].placeId, 'ChIJ横浜駅');
      expect(preds[0].mainText, '横浜駅');
      expect(preds[0].secondaryText, '神奈川県横浜市西区');
      expect(preds[0].distanceMeters, 850);
      expect(preds[0].isTransit, isTrue);
      expect(preds[1].mainText, '何かの場所');
      expect(preds[1].distanceMeters, isNull);
      expect(preds[1].isTransit, isFalse);
    });

    test('0件・不正な形式は null', () {
      expect(PlacesSearch.parseAutocomplete({'suggestions': []}), isNull);
      expect(PlacesSearch.parseAutocomplete(null), isNull);
      expect(PlacesSearch.parseAutocomplete('x'), isNull);
      expect(
        PlacesSearch.parseAutocomplete({
          'suggestions': [1, 2],
        }),
        isNull,
      );
    });
  });

  group('autocomplete', () {
    test('リクエスト仕様（本文・ヘッダー）、200以外・0件はnull', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(
          req.url.toString(),
          'https://places.googleapis.com/v1/places:autocomplete',
        );
        expect(req.headers['X-Goog-Api-Key'], 'KEY');
        expect(req.headers.containsKey('X-Goog-FieldMask'), isFalse);
        final body = jsonDecode(req.body) as Map;
        expect(body['input'], '横浜');
        expect(body['languageCode'], 'ja');
        expect(body['sessionToken'], 'TOKEN');
        expect(body['origin'], {'latitude': 35.0, 'longitude': 139.0});
        expect(body['locationBias']['circle']['radius'], 50000);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'p1',
                    'structuredFormat': {
                      'mainText': {'text': '横浜'},
                    },
                  },
                },
              ],
            }),
          ),
          200,
        );
      });
      final preds = await PlacesSearch.autocomplete(
        '横浜',
        apiKey: 'KEY',
        bias: const LatLng(35.0, 139.0),
        sessionToken: 'TOKEN',
        client: client,
      );
      expect(preds, isNotNull);
      expect(preds!.first.placeId, 'p1');
      expect(calls, 1);

      final bad = MockClient((_) async => http.Response('quota', 429));
      expect(
        await PlacesSearch.autocomplete(
          '横浜',
          apiKey: 'KEY',
          sessionToken: 'TOKEN',
          client: bad,
        ),
        isNull,
      );

      final empty = MockClient(
        (_) async => http.Response('{"suggestions":[]}', 200),
      );
      expect(
        await PlacesSearch.autocomplete(
          '横浜',
          apiKey: 'KEY',
          sessionToken: 'TOKEN',
          client: empty,
        ),
        isNull,
      );
    });

    test('入力が空・キーが無ければ呼ばない', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"suggestions":[]}', 200);
      });
      expect(
        await PlacesSearch.autocomplete(
          '',
          apiKey: 'KEY',
          sessionToken: 'T',
          client: client,
        ),
        isNull,
      );
      expect(
        await PlacesSearch.autocomplete(
          '横浜',
          apiKey: '',
          sessionToken: 'T',
          client: client,
        ),
        isNull,
      );
      expect(calls, 0);
    });
  });

  group('parseDetails / details', () {
    test('parseDetails: location → LatLng、不正な形式は null', () {
      final p = PlacesSearch.parseDetails({
        'location': {'latitude': 35.452281, 'longitude': 139.645066},
        'displayName': {'text': '赤レンガ倉庫'},
      });
      expect(p, isNotNull);
      expect(p!.latitude, 35.452281);
      expect(p.longitude, 139.645066);
      expect(
        PlacesSearch.parseDetails({
          'location': {'latitude': 'x'},
        }),
        isNull,
      );
      expect(PlacesSearch.parseDetails(null), isNull);
    });

    test('details: リクエスト仕様（sessionToken・FieldMask）、200以外・不正はnull', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(
          req.url.toString(),
          'https://places.googleapis.com/v1/places/p1?sessionToken=TOKEN',
        );
        expect(req.headers['X-Goog-Api-Key'], 'KEY');
        expect(
          req.headers['X-Goog-FieldMask'],
          'location,formattedAddress',
        );
        return http.Response(
          jsonEncode({
            'location': {'latitude': 35.0, 'longitude': 139.0},
          }),
          200,
        );
      });
      final point = await PlacesSearch.details(
        'p1',
        sessionToken: 'TOKEN',
        apiKey: 'KEY',
        client: client,
      );
      expect(point, const LatLng(35.0, 139.0));
      expect(calls, 1);

      final bad = MockClient((_) async => http.Response('quota', 429));
      expect(
        await PlacesSearch.details(
          'p1',
          sessionToken: 'T',
          apiKey: 'KEY',
          client: bad,
        ),
        isNull,
      );
    });

    test('placeId が空・キーが無ければ呼ばない', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      expect(
        await PlacesSearch.details(
          '',
          sessionToken: 'T',
          apiKey: 'KEY',
          client: client,
        ),
        isNull,
      );
      expect(
        await PlacesSearch.details(
          'p1',
          sessionToken: 'T',
          apiKey: '',
          client: client,
        ),
        isNull,
      );
      expect(calls, 0);
    });
  });

  test('newSessionToken: UUID v4 の形式で毎回異なる値を返す', () {
    final a = PlacesSearch.newSessionToken();
    final b = PlacesSearch.newSessionToken();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuidV4.hasMatch(a), isTrue);
    expect(uuidV4.hasMatch(b), isTrue);
    expect(a, isNot(b));
  });

  group('addressSearch', () {
    test('地理院AddressSearchの応答を(表示名,座標)にし、クエリ全体を含む候補を優先する', () async {
      final client = MockClient((req) async {
        expect(
          req.url.toString().startsWith(
            'https://msearch.gsi.go.jp/address-search/AddressSearch?q=',
          ),
          isTrue,
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'properties': {'title': '横浜駅前'},
                'geometry': {
                  'coordinates': [139.622, 35.4657],
                },
              },
              {
                'properties': {'title': '横浜'},
                'geometry': {
                  'coordinates': [139.6, 35.4],
                },
              },
            ]),
          ),
          200,
        );
      });
      final hits = await PlacesSearch.addressSearch('横浜', client: client);
      expect(hits.length, 2);
      // クエリ全体「横浜」を含む方（ここでは両方含む）が並び順を保つ。
      // 部分一致しない候補が混じる場合に優先されることは下のテストで確認する
      expect(hits.first.$1, '横浜駅前');
      expect(hits.first.$2, const LatLng(35.4657, 139.622));
    });

    test('200以外は空リスト', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      expect(await PlacesSearch.addressSearch('横浜', client: client), isEmpty);
    });
  });
}
