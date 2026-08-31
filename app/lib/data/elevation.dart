import 'dart:convert';

import 'package:http/http.dart' as http;

/// 国土地理院の標高API（無料・認証不要。SPEC C2）。
///
/// `https://cyberjapandata2.gsi.go.jp/general/dem/scripts/getelevation.php`
/// `?lon=&lt;lon&gt;&lat=&lt;lat&gt;&outtype=JSON`
/// → `{"elevation":3.6,"hsrc":"1m（レーザ）"}`
///
/// **データが無い地点（海上・国外）でも HTTP 200 を返し、
/// `{"elevation":"-----","hsrc":"-----"}` になる**（2026-08-31実測）。
/// 必ず数値かどうかで判定すること。
///
/// 1画面につき1リクエストのみ。結果は座標をキーにメモリキャッシュし、
/// 同じ地点では再取得しない。表示する画面には出所（国土地理院）を添える。
class Elevation {
  static const attribution = '国土地理院';
  static const endpoint =
      'https://cyberjapandata2.gsi.go.jp/general/dem/scripts/getelevation.php';

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// 座標キー → 標高[m]。null は「データ無し」（再取得しない）。
  /// 通信エラーは記録せず、次に開いたときに取り直す
  static final Map<String, double?> _cache = {};

  /// キャッシュのキー。約1m相当（小数5桁）に丸めて同一地点をまとめる
  static String cacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  static Uri uriFor(double lat, double lng) => Uri.parse(
      '$endpoint?lon=${lng.toStringAsFixed(6)}&lat=${lat.toStringAsFixed(6)}'
      '&outtype=JSON');

  /// レスポンス本文から標高[m]を取り出す。数値でなければ（"-----" 等）null
  static double? parse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final v = j['elevation'];
      if (v is num) return v.isFinite ? v.toDouble() : null;
      if (v is String) {
        final d = double.tryParse(v.trim());
        return (d != null && d.isFinite) ? d : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 取得済みか（キャッシュに確定値があるか）
  static bool isCached(double lat, double lng) =>
      _cache.containsKey(cacheKey(lat, lng));

  /// キャッシュ済みの標高（未取得・データ無しはどちらも null）
  static double? cached(double lat, double lng) => _cache[cacheKey(lat, lng)];

  /// 標高[m]。データ無し・取得失敗はいずれも null（表示しない）。
  /// 同じ地点は一度取得したら再取得しない
  static Future<double?> fetch(double lat, double lng,
      {http.Client? client}) async {
    final key = cacheKey(lat, lng);
    if (_cache.containsKey(key)) return _cache[key];
    final uri = uriFor(lat, lng);
    try {
      final r = client == null
          ? await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10))
          : await client.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null; // 一時的な失敗はキャッシュしない
      final v = parse(utf8.decode(r.bodyBytes));
      _cache[key] = v; // データ無し(null)も確定値として覚える
      return v;
    } catch (_) {
      return null;
    }
  }

  /// 表示用（小数1桁。1000m以上は整数）
  static String format(double m) =>
      m.abs() >= 1000 ? '${m.round()}m' : '${m.toStringAsFixed(1)}m';

  /// テスト用。キャッシュを空にする
  static void clearCacheForTest() => _cache.clear();
}
