/// 配信エンドポイント（SPEC 8章）。
const String apiBaseUrl = 'https://kotopapa.github.io/livecam-jp/v1/';
const String manifestUrl = '${apiBaseUrl}manifest.json';

/// アプリのバージョン表記（pubspec.yaml の version と一致させる）。
const String appVersion = '1.0.1';

/// アクセス制御（SPEC 9.4）。ユーザーが変更できない下限値。
const Duration minRefetchInterval = Duration(seconds: 60);
const int maxConcurrentFetches = 3;

/// 全国ランキング用 Firebase 設定（未設定=空文字なら機能無効）。
/// Firestoreは書き込み専用で使い、ランキングの読み込みは
/// GitHub Pages の静的JSON（/v1/ranking.json）から行う。
const String firebaseProjectId = 'livecam-jp';
const String firebaseApiKey = 'AIzaSyBlNICazXyF_x9A5aLARTW3k2L-K62lae0';

/// AdMob バナー広告ユニットID（詳細画面）。
/// アプリID(Info.plist の GADApplicationIdentifier)とペアで管理する。
/// デバッグ検証にはGoogle公式テストID
/// (ca-app-pub-3940256099942544/2934735716) に一時差し替えて使う。
const String admobBannerUnitId = 'ca-app-pub-9639294688594011/6375938678';
