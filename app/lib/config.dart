import 'dart:io' show Platform;

/// 配信エンドポイント（SPEC 8章）。
const String apiBaseUrl = 'https://kotopapa.github.io/livecam-jp/v1/';
const String manifestUrl = '${apiBaseUrl}manifest.json';

/// アプリのバージョン表記（pubspec.yaml の version と一致させる）。
const String appVersion = '1.3.1';

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
const String _admobBannerUnitIdIos = 'ca-app-pub-9639294688594011/6375938678';
const String _admobRectangleUnitIdIos = 'ca-app-pub-9639294688594011/5827278377';

/// Android用ユニットID。AdMobでAndroidアプリを登録してユニットを発行するまでは
/// Google公式テストID（本番配布前に必ず差し替える）
const String _admobBannerUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
const String _admobRectangleUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';

/// AdMob バナー広告ユニットID（映像直下・各タブ下部）
String get admobBannerUnitId =>
    Platform.isAndroid ? _admobBannerUnitIdAndroid : _admobBannerUnitIdIos;

/// AdMob レクタングル広告ユニットID（詳細画面 ミニマップ下・300×250）
String get admobRectangleUnitId =>
    Platform.isAndroid ? _admobRectangleUnitIdAndroid : _admobRectangleUnitIdIos;

/// App Store のアプリID（招待・評価導線用）。manifest の store_url が無い場合の既定
const String appStoreId = '6802841521';
const String appStoreUrl = 'https://apps.apple.com/jp/app/id$appStoreId';
