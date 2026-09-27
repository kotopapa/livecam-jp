/// 地名・施設名の検索: Google Places API (New) の Text Search。
///
/// キーは新設せず、地図表示に使っている Google Maps 用キーを NativeConfig 経由で
/// 流用する。キー未設定・エラー・割り当て超過などで使えないとき、および該当0件の
/// ときはすべて null を返し、呼び出し側は従来の国土地理院 AddressSearch（住所）と
/// 台帳のカメラ名検索にフォールバックする。1回の入力確定＝1リクエスト
/// （オートコンプリートはしない）
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'native_config.dart';

class PlacesSearch {
  PlacesSearch._();

  static const _endpoint = 'https://places.googleapis.com/v1/places:searchText';

  /// テキスト検索。[bias] を渡すと現在の地図中心から50km圏を優先する。
  /// 失敗・キー無し・0件はすべて null
  static Future<List<(String, LatLng)>?> textSearch(
    String query, {
    LatLng? bias,
    String languageCode = 'ja',
    int pageSize = 8,
    http.Client? client,
    String? apiKey,
    Map<String, String>? headers,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final key = apiKey ?? await NativeConfig.instance.getGoogleMapsApiKey();
    if (key == null || key.isEmpty) return null;
    final hdrs = headers ?? await NativeConfig.instance.getAppRestrictionHeaders();
    final c = client ?? http.Client();
    try {
      final body = <String, Object?>{
        'textQuery': q,
        'languageCode': languageCode,
        'regionCode': 'JP',
        'pageSize': pageSize,
        if (bias != null)
          'locationBias': {
            'circle': {
              'center': {
                'latitude': bias.latitude,
                'longitude': bias.longitude,
              },
              'radius': 50000,
            },
          },
      };
      final r = await c
          .post(
            Uri.parse(_endpoint),
            headers: {
              ...hdrs,
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.formattedAddress,places.location',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return parseResponse(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Places API (New) searchText の応答 → (表示名, 座標)。
  /// 表示名は「名称（住所）」。0件・不正な形式は null
  static List<(String, LatLng)>? parseResponse(Object? json) {
    if (json is! Map) return null;
    final places = json['places'];
    if (places is! List || places.isEmpty) return null;
    final out = <(String, LatLng)>[];
    for (final p in places) {
      if (p is! Map) continue;
      final loc = p['location'];
      if (loc is! Map || loc['latitude'] is! num || loc['longitude'] is! num) {
        continue;
      }
      final displayName = p['displayName'];
      final name = displayName is Map ? (displayName['text']?.toString() ?? '') : '';
      if (name.isEmpty) continue;
      final address = p['formattedAddress']?.toString() ?? '';
      final label = address.isEmpty ? name : '$name（$address）';
      out.add((
        label,
        LatLng((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble()),
      ));
    }
    return out.isEmpty ? null : out;
  }
}
