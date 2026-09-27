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
      ]
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
      ]
    })!;
    expect(hits.first.$1, '富士山');
  });

  test('textSearch: クエリが空・キーが無ければ呼ばない', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"places":[]}', 200);
    });
    expect(await PlacesSearch.textSearch('', apiKey: 'KEY', client: client), isNull);
    expect(await PlacesSearch.textSearch('横浜', apiKey: '', client: client), isNull);
    expect(calls, 0);
  });

  test('textSearch: リクエスト仕様（ヘッダー・本文）、200以外はnull、0件はnull', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.url.toString(), 'https://places.googleapis.com/v1/places:searchText');
      expect(req.headers['X-Goog-Api-Key'], 'KEY');
      expect(req.headers['X-Goog-FieldMask'],
          'places.id,places.displayName,places.formattedAddress,places.location');
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
          utf8.encode(jsonEncode({
            'places': [
              {
                'displayName': {'text': '横浜駅'},
                'formattedAddress': '神奈川県横浜市西区',
                'location': {'latitude': 35.4657, 'longitude': 139.622},
              }
            ]
          })),
          200);
    });
    final hits = await PlacesSearch.textSearch('横浜駅',
        apiKey: 'KEY',
        headers: const {'X-Android-Package': 'jp.livecam.livecam_jp'},
        client: client);
    expect(hits, isNotNull);
    expect(hits!.first.$1, '横浜駅（神奈川県横浜市西区）');
    expect(calls, 1);

    final bad = MockClient((_) async => http.Response('quota', 429));
    expect(await PlacesSearch.textSearch('横浜駅', apiKey: 'KEY', client: bad), isNull);

    final empty = MockClient((_) async => http.Response('{"places":[]}', 200));
    expect(
        await PlacesSearch.textSearch('存在しない場所xyz', apiKey: 'KEY', client: empty), isNull);
  });

  test('textSearch: bias を渡したときだけ locationBias を付ける', () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((req) async {
      capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"places":[]}', 200);
    });
    await PlacesSearch.textSearch('東京タワー', apiKey: 'KEY', client: client);
    expect(capturedBody!.containsKey('locationBias'), isFalse);

    await PlacesSearch.textSearch('東京タワー',
        apiKey: 'KEY', bias: const LatLng(35.0, 139.0), client: client);
    expect(capturedBody!['locationBias']['circle']['radius'], 50000);
    expect(capturedBody!['locationBias']['circle']['center']['latitude'], 35.0);
    expect(capturedBody!['locationBias']['circle']['center']['longitude'], 139.0);
  });
}
