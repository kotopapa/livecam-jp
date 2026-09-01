import 'dart:io' show Platform;

/// 配信エンドポイント（SPEC 8章）。
const String apiBaseUrl = 'https://kotopapa.github.io/livecam-jp/v1/';
const String manifestUrl = '${apiBaseUrl}manifest.json';

/// アプリのバージョン表記（pubspec.yaml の version と一致させる）。
const String appVersion = '1.4.0';

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

// ---------------------------------------------------------------------------
// アフィリエイト（バリューコマース）
// ---------------------------------------------------------------------------

/// バリューコマースのサイトID（アフィリエイター＝このアプリ側の固定値）。
const String vcSid = '3780235';

/// バリューコマースのリファラル（クリック計測）エンドポイント。
const String vcReferralEndpoint =
    'https://ck.jp.ap.valuecommerce.com/servlet/referral';

/// 提携先（広告主）1件の定義。
///
/// 新しい広告主を足すときは [vcMerchants] に1行足すだけでよい。
/// 提携が**承認されるまでは [enabled] を false** にしておくこと
/// （未承認のpidでリンクを出すと成果が計上されず、規約上も好ましくない）。
class VcMerchant {
  const VcMerchant({
    required this.key,
    required this.name,
    required this.pid,
    required this.enabled,
    required this.searchUrl,
  });

  /// 内部キー（保存・テスト用の安定した識別子）
  final String key;

  /// 画面に出す店舗名（固有名詞なので翻訳しない）
  final String name;

  /// バリューコマースの広告主プログラムID
  final String pid;

  /// 提携が承認済みか。false の店舗は画面に出さない
  final bool enabled;

  /// 検索語 → 店舗の検索結果ページURL
  final Uri Function(String keyword) searchUrl;
}

Uri _yahooSearchUrl(String keyword) => Uri.parse(
    'https://shopping.yahoo.co.jp/search?p=${Uri.encodeQueryComponent(keyword)}');

Uri _rakutenSearchUrl(String keyword) => Uri.parse(
    'https://search.rakuten.co.jp/search/mall/${Uri.encodeComponent(keyword)}/');

Uri _amazonSearchUrl(String keyword) => Uri.parse(
    'https://www.amazon.co.jp/s?k=${Uri.encodeQueryComponent(keyword)}');

/// 提携先の一覧（表示順）。
///
/// 2026-09-01 時点の状態:
/// - Yahoo!ショッピング … 提携済み（**唯一有効**）
/// - 楽天市場 … バリューコマースで審査中 → 承認されたら `enabled: true` にする
/// - Amazon.co.jp … 審査中 → 承認されたら `enabled: true` にする
///
/// 手順は docs/stockpile_1.4.0.md「広告主を増やす／有効にする手順」を参照。
const List<VcMerchant> vcMerchants = <VcMerchant>[
  VcMerchant(
    key: 'yahoo',
    name: 'Yahoo!ショッピング',
    pid: '892690203',
    enabled: true,
    searchUrl: _yahooSearchUrl,
  ),
  VcMerchant(
    key: 'rakuten',
    name: '楽天市場',
    pid: '892690205',
    enabled: false, // 審査中。承認されたら true にするだけで画面に出る
    searchUrl: _rakutenSearchUrl,
  ),
  VcMerchant(
    key: 'amazon',
    name: 'Amazon.co.jp',
    pid: '892690207',
    enabled: false, // 審査中。承認されたら true にするだけで画面に出る
    searchUrl: _amazonSearchUrl,
  ),
];

/// 既定（先頭）の広告主プログラムID。いまは Yahoo!ショッピング。
const String vcPidPrimary = '892690203';
