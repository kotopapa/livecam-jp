/// ネイティブ（iOS/Android）から Google Maps 用の API キーとアプリ制限ヘッダーを取得する。
///
/// ルート検索(Google Routes API)・地名検索(Google Places API (New)) 用に新しい
/// API キーは発行せず、地図表示に既に使っている Google Maps 用キーを流用する
/// （iOS: Info.plist の GMSApiKey、Android: AndroidManifest の meta-data
/// com.google.android.geo.API_KEY）。このキーはバンドルID／パッケージ名で制限され
/// ているため、REST 呼び出しには同じ制限を満たすヘッダーを付ける必要がある
/// （iOS: X-Ios-Bundle-Identifier、Android: X-Android-Package / X-Android-Cert）。
/// ネイティブ側の実装: ios/Runner/AppDelegate.swift・
/// android/app/src/main/kotlin/jp/livecam/livecam_jp/MainActivity.kt
library;

import 'package:flutter/services.dart';

class NativeConfig {
  NativeConfig._();

  static final NativeConfig instance = NativeConfig._();

  static const MethodChannel _channel = MethodChannel('livecam/native_config');

  String? _apiKey;
  bool _apiKeyLoaded = false;
  Map<String, String>? _headers;
  bool _headersLoaded = false;

  /// Google Maps 用 API キー。一度取得したらキャッシュする。
  /// チャンネル未実装・取得失敗・値が空のときは null（呼び出し側は Google を
  /// 使わず従来の手段にフォールバックする）
  Future<String?> getGoogleMapsApiKey() async {
    if (_apiKeyLoaded) return _apiKey;
    try {
      final v = await _channel.invokeMethod<String>('getGoogleMapsApiKey');
      _apiKey = (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      _apiKey = null;
    }
    _apiKeyLoaded = true;
    return _apiKey;
  }

  /// アプリ制限ヘッダー（バンドルID／パッケージ名・署名証明書のSHA-1）。
  /// 取得できないときは空のMapを返す（ヘッダー無しでリクエストして
  /// キー制限に引っかかった場合はサーバ側が失敗を返すので呼び出し側で拾える）
  Future<Map<String, String>> getAppRestrictionHeaders() async {
    if (_headersLoaded) return _headers ?? const {};
    try {
      final v = await _channel
          .invokeMethod<Map<Object?, Object?>>('getAppRestrictionHeaders');
      _headers = v == null
          ? const {}
          : {for (final e in v.entries) e.key.toString(): e.value?.toString() ?? ''};
    } catch (_) {
      _headers = const {};
    }
    _headersLoaded = true;
    return _headers ?? const {};
  }

  /// テスト用: キャッシュを消す
  void resetForTest() {
    _apiKeyLoaded = false;
    _apiKey = null;
    _headersLoaded = false;
    _headers = null;
  }
}
