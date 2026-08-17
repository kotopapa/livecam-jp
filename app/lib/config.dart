/// 配信エンドポイント（SPEC 8章）。
const String apiBaseUrl = 'https://kotopapa.github.io/livecam-jp/v1/';
const String manifestUrl = '${apiBaseUrl}manifest.json';

/// アクセス制御（SPEC 9.4）。ユーザーが変更できない下限値。
const Duration minRefetchInterval = Duration(seconds: 60);
const int maxConcurrentFetches = 3;
