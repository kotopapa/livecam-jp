import 'dart:convert';

import 'package:http/http.dart' as http;

/// 条件付きGET（If-None-Match）対応の軽量APIクライアント。
///
/// SPEC C3/9.4: ETagを必ず使い、304なら再ダウンロードしない。
class ApiClient {
  ApiClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _base = baseUri ?? Uri.parse('https://kotopapa.github.io/livecam-jp/v1/');

  final http.Client _client;
  final Uri _base;

  /// manifest内のURLを解決する。
  ///
  /// manifestは「/v1/cameras.json」形式（サイトルート基準）でURLを持つが、
  /// GitHub Pagesのプロジェクトサイトでは /livecam-jp/ 配下に配信されるため、
  /// そのままオリジン解決すると404になる。「/v1/」以降をベース（…/v1/）からの
  /// 相対として解決することで、ルート配信・サブパス配信の両方に対応する。
  Uri resolve(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    if (url.startsWith('/')) {
      final idx = url.indexOf('/v1/');
      if (idx >= 0) return _base.resolve(url.substring(idx + 4));
      return _base.resolve(url.substring(1));
    }
    return _base.resolve(url);
  }

  Future<ApiResponse> getJson(String url, {String? etag}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'If-None-Match': ?etag,
    };
    try {
      final resp = await _client
          .get(resolve(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 304) {
        return const ApiResponse.notModified();
      }
      if (resp.statusCode != 200) {
        return ApiResponse.failure('HTTP ${resp.statusCode}');
      }
      final body = utf8.decode(resp.bodyBytes);
      jsonDecode(body); // 不正JSONの早期検出（キャッシュを汚さない）
      return ApiResponse.success(body, etag: resp.headers['etag']);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  void close() => _client.close();
}

enum ApiResult { success, notModified, failure }

class ApiResponse {
  const ApiResponse.success(this.body, {this.etag})
      : result = ApiResult.success,
        error = null;
  const ApiResponse.notModified()
      : result = ApiResult.notModified,
        body = null,
        etag = null,
        error = null;
  const ApiResponse.failure(this.error)
      : result = ApiResult.failure,
        body = null,
        etag = null;

  final ApiResult result;
  final String? body;
  final String? etag;
  final String? error;

  Map<String, dynamic> get json => jsonDecode(body!) as Map<String, dynamic>;
}
