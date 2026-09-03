/// 利用者が「いま居る都道府県」を求める（1.4.1）。
///
/// 特別警報（レベル5）の発表中に広告と宿の導線を伏せる判定は、**カメラの場所ではなく
/// 利用者の現在地**で行う（2026-09-03 ユーザー決定）。県外の人が警報エリアのカメラを
/// 見るのはごく普通で、復旧期にはむしろ宿を出した方が支援につながるため。
///
/// - 位置情報は**新たに許可を求めない**。既に許可済みなら端末が最後に知っている位置
///   （`getLastKnownPosition`）を使う。取れなければ null（呼び出し側は「分からない
///   人には無条件で出す」扱い）
/// - 座標→都道府県は国土地理院の逆ジオコーダ（`mreversegeocoder.gsi.go.jp`）。
///   返る `muniCd`（JIS 5桁）の先頭2桁が都道府県。海上・国外は `{}` が返る
/// - 呼ぶのは特別警報が出ているときだけ（`AppState.checkSpecialWarnings`）なので
///   平時のAPI呼び出しは無い
library;

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ViewerArea {
  ViewerArea({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String endpoint =
      'https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress';
  static const Map<String, String> _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)',
  };

  /// 座標の都道府県コード（JIS 2桁）。海上・国外・失敗は null
  Future<String?> prefectureOf(double lat, double lng) async {
    try {
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        'lat': lat.toStringAsFixed(5),
        'lon': lng.toStringAsFixed(5),
      });
      final r = await _client
          .get(uri, headers: _ua)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return parsePrefecture(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// `{"results":{"muniCd":"19430","lv01Nm":"船津"}}` → "19"
  static String? parsePrefecture(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final results = j['results'];
      if (results is! Map) return null;
      final muni = results['muniCd'];
      if (muni is! String || muni.length < 2) return null;
      final pref = muni.substring(0, 2);
      final n = int.tryParse(pref);
      if (n == null || n < 1 || n > 47) return null;
      return pref;
    } catch (_) {
      return null;
    }
  }

  /// 端末の最後の既知位置（許可済みのときだけ。ダイアログは出さない）
  static Future<Position?> lastKnownPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// 現在地の都道府県。位置が取れなければ null
  Future<String?> currentPrefecture() async {
    final pos = await lastKnownPosition();
    if (pos == null) return null;
    return prefectureOf(pos.latitude, pos.longitude);
  }
}
