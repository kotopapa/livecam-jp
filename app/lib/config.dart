/// 配信エンドポイント（SPEC 8章）。
const String apiBaseUrl = 'https://kotopapa.github.io/livecam-jp/v1/';
const String manifestUrl = '${apiBaseUrl}manifest.json';

/// アプリのバージョン表記（pubspec.yaml の version と一致させる）。
const String appVersion = '1.0.0';

/// アクセス制御（SPEC 9.4）。ユーザーが変更できない下限値。
const Duration minRefetchInterval = Duration(seconds: 60);
const int maxConcurrentFetches = 3;

/// 全国ランキング用 Firebase 設定（未設定=空文字なら機能無効）。
/// Firestoreは書き込み専用で使い、ランキングの読み込みは
/// GitHub Pages の静的JSON（/v1/ranking.json）から行う。
const String firebaseProjectId = 'livecam-jp';
const String firebaseApiKey = 'AIzaSyBlNICazXyF_x9A5aLARTW3k2L-K62lae0';
