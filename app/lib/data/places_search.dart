/// 地名・施設名の検索: Google Places API (New)。
///
/// キーは新設せず、地図表示に使っている Google Maps 用キーを NativeConfig 経由で
/// 流用する。キー未設定・エラー・割り当て超過などで使えないとき、および該当0件の
/// ときはすべて null を返し、呼び出し側は従来の国土地理院 AddressSearch（住所）と
/// 台帳のカメラ名検索にフォールバックする。
///
/// - [textSearch]: 1回の入力確定＝1リクエスト（キーボードの検索確定時に使う）
/// - [autocomplete] / [details]: 入力中の候補表示（全画面検索。2026-09-27）。
///   同一セッション（[newSessionToken] で発行）内なら Autocomplete は無料扱いになる
///   仕組みのため、確定した候補の座標取得には必ず同じ sessionToken で [details] を呼ぶ
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'native_config.dart';

/// Autocomplete (New) の1候補。
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.distanceMeters,
    this.types = const [],
  });

  final String placeId;
  final String mainText;
  final String secondaryText;

  /// リクエストの origin からの距離（メートル）。API が返さない場合は null
  final int? distanceMeters;
  final List<String> types;

  static const _transitTypes = {
    'train_station',
    'subway_station',
    'transit_station',
  };

  /// 駅・地下鉄駅など（行アイコンを電車にする判定に使う）
  bool get isTransit => types.any(_transitTypes.contains);
}

class PlacesSearch {
  PlacesSearch._();

  static const _textSearchEndpoint =
      'https://places.googleapis.com/v1/places:searchText';
  static const _autocompleteEndpoint =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const _placesEndpoint = 'https://places.googleapis.com/v1/places';
  static const _addressSearchEndpoint =
      'https://msearch.gsi.go.jp/address-search/AddressSearch';

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
    final hdrs =
        headers ?? await NativeConfig.instance.getAppRestrictionHeaders();
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
            Uri.parse(_textSearchEndpoint),
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
      final name = displayName is Map
          ? (displayName['text']?.toString() ?? '')
          : '';
      if (name.isEmpty) continue;
      final address = p['formattedAddress']?.toString() ?? '';
      final label = address.isEmpty ? name : '$name（$address）';
      out.add((
        label,
        LatLng(
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        ),
      ));
    }
    return out.isEmpty ? null : out;
  }

  /// 入力中のオートコンプリート候補。[sessionToken] は検索画面を開くたびに
  /// [newSessionToken] で新規発行したものを渡す。失敗・キー無し・0件は null
  static Future<List<PlacePrediction>?> autocomplete(
    String input, {
    LatLng? bias,
    String languageCode = 'ja',
    required String sessionToken,
    http.Client? client,
    String? apiKey,
    Map<String, String>? headers,
  }) async {
    final q = input.trim();
    if (q.isEmpty) return null;
    final key = apiKey ?? await NativeConfig.instance.getGoogleMapsApiKey();
    if (key == null || key.isEmpty) return null;
    final hdrs =
        headers ?? await NativeConfig.instance.getAppRestrictionHeaders();
    final c = client ?? http.Client();
    try {
      final body = <String, Object?>{
        'input': q,
        'languageCode': languageCode,
        'sessionToken': sessionToken,
        if (bias != null)
          'origin': {'latitude': bias.latitude, 'longitude': bias.longitude},
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
            Uri.parse(_autocompleteEndpoint),
            headers: {
              ...hdrs,
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return parseAutocomplete(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Autocomplete (New) の応答 → 候補リスト。0件・不正な形式は null
  static List<PlacePrediction>? parseAutocomplete(Object? json) {
    if (json is! Map) return null;
    final suggestions = json['suggestions'];
    if (suggestions is! List || suggestions.isEmpty) return null;
    final out = <PlacePrediction>[];
    for (final s in suggestions) {
      if (s is! Map) continue;
      final pred = s['placePrediction'];
      if (pred is! Map) continue;
      final placeId = pred['placeId']?.toString() ?? '';
      if (placeId.isEmpty) continue;
      var mainText = '';
      var secondaryText = '';
      final structured = pred['structuredFormat'];
      if (structured is Map) {
        final mt = structured['mainText'];
        if (mt is Map) mainText = mt['text']?.toString() ?? '';
        final st = structured['secondaryText'];
        if (st is Map) secondaryText = st['text']?.toString() ?? '';
      }
      if (mainText.isEmpty) {
        final text = pred['text'];
        if (text is Map) mainText = text['text']?.toString() ?? '';
      }
      if (mainText.isEmpty) continue;
      final distance = pred['distanceMeters'];
      final types = pred['types'];
      out.add(
        PlacePrediction(
          placeId: placeId,
          mainText: mainText,
          secondaryText: secondaryText,
          distanceMeters: distance is num ? distance.toInt() : null,
          types: types is List
              ? types.map((e) => e.toString()).toList()
              : const [],
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  /// 候補確定後の座標取得（Place Details (New)）。同一セッションの [sessionToken] を
  /// 渡すことで Autocomplete 分は無料扱いになる。失敗・キー無しは null
  static Future<LatLng?> details(
    String placeId, {
    required String sessionToken,
    http.Client? client,
    String? apiKey,
    Map<String, String>? headers,
  }) async {
    if (placeId.isEmpty) return null;
    final key = apiKey ?? await NativeConfig.instance.getGoogleMapsApiKey();
    if (key == null || key.isEmpty) return null;
    final hdrs =
        headers ?? await NativeConfig.instance.getAppRestrictionHeaders();
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(
        '$_placesEndpoint/$placeId',
      ).replace(queryParameters: {'sessionToken': sessionToken});
      final r = await c
          .get(
            uri,
            headers: {
              ...hdrs,
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': 'location,displayName,formattedAddress',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return parseDetails(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Place Details (New) の応答 → 座標。不正な形式は null
  static LatLng? parseDetails(Object? json) {
    if (json is! Map) return null;
    final loc = json['location'];
    if (loc is! Map) return null;
    final lat = loc['latitude'];
    final lng = loc['longitude'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  /// Autocomplete/Details 用のセッショントークン（UUID v4）。
  /// 検索画面を開くたびに新規発行する（新しい依存を増やさず自前で生成）
  static String newSessionToken() {
    final rnd = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int a, int b) => bytes
        .sublist(a, b)
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// 国土地理院 AddressSearch（無料・キー不要）。Google Places が使えない/該当なしの
  /// ときのフォールバック。失敗・0件は空リスト（旧 map_screen._searchPlace を移設）
  static Future<List<(String, LatLng)>> addressSearch(
    String query, {
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(
        '$_addressSearchEndpoint?q=${Uri.encodeQueryComponent(query)}',
      );
      final resp = await c.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final hits = [
        for (final e in list.cast<Map<String, dynamic>>())
          (
            (e['properties'] as Map<String, dynamic>)['title'] as String? ?? '',
            LatLng(
              ((e['geometry'] as Map<String, dynamic>)['coordinates']
                      as List)[1]
                  as double,
              ((e['geometry'] as Map<String, dynamic>)['coordinates']
                      as List)[0]
                  as double,
            ),
          ),
      ];
      // 地理院APIは部分一致の住所も多く返すため、クエリ全体を含む候補を優先する
      hits.sort((a, b) {
        final am = a.$1.contains(query) ? 0 : 1;
        final bm = b.$1.contains(query) ? 0 : 1;
        return am.compareTo(bm);
      });
      return hits.take(15).toList();
    } catch (_) {
      return const [];
    } finally {
      if (client == null) c.close();
    }
  }
}
