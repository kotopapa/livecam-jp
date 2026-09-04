import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Hira'),
    Locale('ko'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// アプリ名（画面表示用）
  ///
  /// In ja, this message translates to:
  /// **'全国ライブカメラ地図'**
  String get appTitle;

  /// No description provided for @commonClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get commonOk;

  /// No description provided for @commonNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get commonSkip;

  /// No description provided for @commonCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get commonCopy;

  /// No description provided for @commonShare.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get commonShare;

  /// No description provided for @commonRetry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get commonRetry;

  /// No description provided for @commonOpenInSafari.
  ///
  /// In ja, this message translates to:
  /// **'Safariで開く'**
  String get commonOpenInSafari;

  /// No description provided for @commonSource.
  ///
  /// In ja, this message translates to:
  /// **'出典'**
  String get commonSource;

  /// カメラ台数（単位つき）
  ///
  /// In ja, this message translates to:
  /// **'{count}台'**
  String commonCameraCount(int count);

  /// SPEC 9.5 / 12.2: 免責・規約類は日本語を正文とする旨の明示
  ///
  /// In ja, this message translates to:
  /// **'この日本語版を正文とします。翻訳は参考です。'**
  String get legalJapaneseAuthoritative;

  /// 設定画面の項目名
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get languageLabel;

  /// 設定画面の項目タイトル（常に両言語併記）
  ///
  /// In ja, this message translates to:
  /// **'言語 / Language'**
  String get languageSettingTitle;

  /// 言語名。各言語のARBでも自称表記のままにする
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get languageNameJa;

  /// 言語名
  ///
  /// In ja, this message translates to:
  /// **'やさしい日本語'**
  String get languageNameJaHira;

  /// 言語名
  ///
  /// In ja, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @languageFollowSystem.
  ///
  /// In ja, this message translates to:
  /// **'端末の設定に合わせる'**
  String get languageFollowSystem;

  /// No description provided for @languageChooseTitle.
  ///
  /// In ja, this message translates to:
  /// **'言語を選ぶ'**
  String get languageChooseTitle;

  /// No description provided for @tabMap.
  ///
  /// In ja, this message translates to:
  /// **'地図'**
  String get tabMap;

  /// No description provided for @tabList.
  ///
  /// In ja, this message translates to:
  /// **'一覧'**
  String get tabList;

  /// No description provided for @tabBosai.
  ///
  /// In ja, this message translates to:
  /// **'災害速報'**
  String get tabBosai;

  /// No description provided for @tabFavorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get tabFavorites;

  /// 下部タブ: 防災の備え（備蓄チェックリスト）
  ///
  /// In ja, this message translates to:
  /// **'備え'**
  String get tabStockpile;

  /// No description provided for @tabSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get tabSettings;

  /// No description provided for @onboardingTitle1.
  ///
  /// In ja, this message translates to:
  /// **'地図からすぐに探せる'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In ja, this message translates to:
  /// **'全国1万台以上のライブカメラを地図に表示。河川・道路・海岸などカテゴリ別に色分けされています。'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In ja, this message translates to:
  /// **'映らないカメラは自動で非表示'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In ja, this message translates to:
  /// **'定期的に自動確認し、取得できないカメラは地図から外れます。取得時刻を必ず表示します。'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In ja, this message translates to:
  /// **'出典・ライセンスを明示'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In ja, this message translates to:
  /// **'すべての映像は提供元の明示とともに表示します。映像の権利は各提供元に帰属します。'**
  String get onboardingBody3;

  /// オンボーディング免責ページの災害通知トグル（既定ON）
  ///
  /// In ja, this message translates to:
  /// **'災害通知を受け取る'**
  String get onboardingNotifyOptIn;

  /// 災害通知トグルの説明
  ///
  /// In ja, this message translates to:
  /// **'震度5弱以上の地震と特別警報（全国）をお知らせします。あとから設定で変更できます。'**
  String get onboardingNotifyOptInDetail;

  /// No description provided for @onboardingDisclaimerTitle.
  ///
  /// In ja, this message translates to:
  /// **'ご利用前の大切なお願い'**
  String get onboardingDisclaimerTitle;

  /// No description provided for @onboardingAgreeAndStart.
  ///
  /// In ja, this message translates to:
  /// **'同意してはじめる'**
  String get onboardingAgreeAndStart;

  /// SPEC 9.5 の必須免責文。日本語版を正文とする（legalJapaneseAuthoritative を併記すること）
  ///
  /// In ja, this message translates to:
  /// **'カメラ映像は限られた範囲の状況を示すものです。カメラの性能上、光環境や気象条件により不鮮明になる場合があります。避難の判断は、水位情報・気象警報・自治体の避難情報に従ってください。本アプリは参考情報を提供するものです。'**
  String get disclaimerText;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In ja, this message translates to:
  /// **'アップデートが必要です'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In ja, this message translates to:
  /// **'このバージョンはサポートが終了しました。\nApp Storeから最新版に更新してください。'**
  String get updateRequiredBody;

  /// No description provided for @updateOpenStore.
  ///
  /// In ja, this message translates to:
  /// **'App Storeを開く'**
  String get updateOpenStore;

  /// No description provided for @categoryRiver.
  ///
  /// In ja, this message translates to:
  /// **'河川'**
  String get categoryRiver;

  /// No description provided for @categoryRoad.
  ///
  /// In ja, this message translates to:
  /// **'道路'**
  String get categoryRoad;

  /// No description provided for @categoryVolcano.
  ///
  /// In ja, this message translates to:
  /// **'火山'**
  String get categoryVolcano;

  /// No description provided for @categoryDam.
  ///
  /// In ja, this message translates to:
  /// **'ダム'**
  String get categoryDam;

  /// No description provided for @categoryCoast.
  ///
  /// In ja, this message translates to:
  /// **'海岸'**
  String get categoryCoast;

  /// No description provided for @categoryPort.
  ///
  /// In ja, this message translates to:
  /// **'港湾'**
  String get categoryPort;

  /// No description provided for @categoryScenic.
  ///
  /// In ja, this message translates to:
  /// **'景観'**
  String get categoryScenic;

  /// No description provided for @categoryHealing.
  ///
  /// In ja, this message translates to:
  /// **'癒し'**
  String get categoryHealing;

  /// No description provided for @categoryOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get categoryOther;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'北海道'**
  String get pref01;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'青森'**
  String get pref02;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'岩手'**
  String get pref03;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'宮城'**
  String get pref04;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'秋田'**
  String get pref05;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'山形'**
  String get pref06;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'福島'**
  String get pref07;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'茨城'**
  String get pref08;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'栃木'**
  String get pref09;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'群馬'**
  String get pref10;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'埼玉'**
  String get pref11;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'千葉'**
  String get pref12;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'東京'**
  String get pref13;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'神奈川'**
  String get pref14;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'新潟'**
  String get pref15;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'富山'**
  String get pref16;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'石川'**
  String get pref17;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'福井'**
  String get pref18;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'山梨'**
  String get pref19;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'長野'**
  String get pref20;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'岐阜'**
  String get pref21;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'静岡'**
  String get pref22;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'愛知'**
  String get pref23;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'三重'**
  String get pref24;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'滋賀'**
  String get pref25;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'京都'**
  String get pref26;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'大阪'**
  String get pref27;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'兵庫'**
  String get pref28;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'奈良'**
  String get pref29;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'和歌山'**
  String get pref30;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'鳥取'**
  String get pref31;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'島根'**
  String get pref32;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'岡山'**
  String get pref33;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'広島'**
  String get pref34;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'山口'**
  String get pref35;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'徳島'**
  String get pref36;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'香川'**
  String get pref37;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'愛媛'**
  String get pref38;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'高知'**
  String get pref39;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'福岡'**
  String get pref40;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'佐賀'**
  String get pref41;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'長崎'**
  String get pref42;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'熊本'**
  String get pref43;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'大分'**
  String get pref44;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'宮崎'**
  String get pref45;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'鹿児島'**
  String get pref46;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「都道府県」から接尾辞（県/府/都・현/부/도・Tỉnh）を除去
  ///
  /// In ja, this message translates to:
  /// **'沖縄'**
  String get pref47;

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @settingsSupportTitle.
  ///
  /// In ja, this message translates to:
  /// **'開発者を応援する'**
  String get settingsSupportTitle;

  /// No description provided for @settingsSupportBody.
  ///
  /// In ja, this message translates to:
  /// **'缶コーヒー1本(¥200)から。個人開発の継続を支えてください'**
  String get settingsSupportBody;

  /// No description provided for @settingsSupportButton.
  ///
  /// In ja, this message translates to:
  /// **'応援'**
  String get settingsSupportButton;

  /// No description provided for @settingsSectionNotify.
  ///
  /// In ja, this message translates to:
  /// **'災害通知'**
  String get settingsSectionNotify;

  /// 震度階級は気象庁「多言語辞書」に準拠。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'震度5弱以上の地震'**
  String get settingsQuakeTitle;

  /// No description provided for @settingsQuakeSubtitleOff.
  ///
  /// In ja, this message translates to:
  /// **'大きな地震の発生を通知し、周辺カメラへ誘導します'**
  String get settingsQuakeSubtitleOff;

  /// No description provided for @settingsQuakeSubtitleOn.
  ///
  /// In ja, this message translates to:
  /// **'通知レベル: {level}'**
  String settingsQuakeSubtitleOn(String level);

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'特別警報'**
  String get settingsWarningTitle;

  /// No description provided for @settingsWarningSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'大雨・暴風・高潮などの特別警報の発表を通知します'**
  String get settingsWarningSubtitle;

  /// No description provided for @settingsNotifyArea.
  ///
  /// In ja, this message translates to:
  /// **'通知する地域'**
  String get settingsNotifyArea;

  /// No description provided for @settingsNotifyAreaAll.
  ///
  /// In ja, this message translates to:
  /// **'全国'**
  String get settingsNotifyAreaAll;

  /// No description provided for @settingsNotifyAreaSummary.
  ///
  /// In ja, this message translates to:
  /// **'{first} など{count}件'**
  String settingsNotifyAreaSummary(String first, int count);

  /// No description provided for @settingsNotifyAreaHint.
  ///
  /// In ja, this message translates to:
  /// **'選択した都道府県の特別警報のみ通知します。何も選ばない場合は全国が対象になります'**
  String get settingsNotifyAreaHint;

  /// No description provided for @settingsNotifyAreaResetAll.
  ///
  /// In ja, this message translates to:
  /// **'全国に戻す'**
  String get settingsNotifyAreaResetAll;

  /// No description provided for @settingsNotifyLevel.
  ///
  /// In ja, this message translates to:
  /// **'通知するレベル'**
  String get settingsNotifyLevel;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'特別警報のみ（レベル5）'**
  String get settingsNotifyLevelSpecialOnly;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'危険警報から（レベル4以上）'**
  String get settingsNotifyLevelDangerUp;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'危険警報は大雨・洪水・高潮・土砂災害の警戒レベル4相当の発表です'**
  String get settingsNotifyLevelNote;

  /// No description provided for @settingsNotifyDelayNote.
  ///
  /// In ja, this message translates to:
  /// **'※通知は気象庁の発表から5〜15分程度遅れることがあります。緊急地震速報の代わりにはなりません'**
  String get settingsNotifyDelayNote;

  /// No description provided for @settingsNotifyDenied.
  ///
  /// In ja, this message translates to:
  /// **'通知が許可されていません。iOSの設定アプリから通知を許可してください'**
  String get settingsNotifyDenied;

  /// No description provided for @settingsSectionData.
  ///
  /// In ja, this message translates to:
  /// **'データ取得'**
  String get settingsSectionData;

  /// No description provided for @settingsWifiOnly.
  ///
  /// In ja, this message translates to:
  /// **'Wi-Fi接続時のみ画像を取得'**
  String get settingsWifiOnly;

  /// No description provided for @settingsWifiOnlySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'モバイル通信量を抑えます（地図とカメラ一覧は表示されます）'**
  String get settingsWifiOnlySubtitle;

  /// No description provided for @settingsClearCache.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュを削除'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラ一覧などの保存データを消去して再取得します'**
  String get settingsClearCacheSubtitle;

  /// No description provided for @settingsClearCacheDone.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュを削除して再取得しました'**
  String get settingsClearCacheDone;

  /// No description provided for @settingsSectionFilterDefaults.
  ///
  /// In ja, this message translates to:
  /// **'フィルタの初期設定'**
  String get settingsSectionFilterDefaults;

  /// No description provided for @settingsShowWorld.
  ///
  /// In ja, this message translates to:
  /// **'世界のカメラを表示'**
  String get settingsShowWorld;

  /// No description provided for @settingsVideoOnly.
  ///
  /// In ja, this message translates to:
  /// **'動画カメラのみ'**
  String get settingsVideoOnly;

  /// No description provided for @settingsHideUncertain.
  ///
  /// In ja, this message translates to:
  /// **'位置が曖昧なカメラを非表示'**
  String get settingsHideUncertain;

  /// No description provided for @settingsHideUncertainSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'黄色い縁取りのピン（おおよそ/代表点）を隠します'**
  String get settingsHideUncertainSubtitle;

  /// No description provided for @settingsFilterDefaultsNote.
  ///
  /// In ja, this message translates to:
  /// **'ここで設定した内容は次回起動時の初期状態になります（地図の凡例からも一時的に変更できます）'**
  String get settingsFilterDefaultsNote;

  /// No description provided for @settingsSectionRequest.
  ///
  /// In ja, this message translates to:
  /// **'カメラの追加・削除のご依頼'**
  String get settingsSectionRequest;

  /// No description provided for @settingsRequestForm.
  ///
  /// In ja, this message translates to:
  /// **'ご相談・依頼フォーム'**
  String get settingsRequestForm;

  /// No description provided for @settingsRequestFormSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラの追加要請・掲載削除の依頼はこちらから（ログイン不要）。設置者・運営者の方からの削除のお申し出には速やかに対応します'**
  String get settingsRequestFormSubtitle;

  /// No description provided for @settingsSectionLicense.
  ///
  /// In ja, this message translates to:
  /// **'出典・ライセンス'**
  String get settingsSectionLicense;

  /// No description provided for @settingsAttributionList.
  ///
  /// In ja, this message translates to:
  /// **'出典・ライセンス一覧'**
  String get settingsAttributionList;

  /// No description provided for @settingsAttributionListSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラ映像の提供元の一覧'**
  String get settingsAttributionListSubtitle;

  /// 本文は日本語のみ（Webページ）。日本語を正文とする
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get settingsTerms;

  /// 本文は日本語のみ（Webページ）。日本語を正文とする
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get settingsPrivacy;

  /// No description provided for @settingsLegalJapaneseOnly.
  ///
  /// In ja, this message translates to:
  /// **'利用規約・プライバシーポリシーの本文は日本語のみです（日本語を正文とします）'**
  String get settingsLegalJapaneseOnly;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In ja, this message translates to:
  /// **'このアプリについて'**
  String get settingsSectionAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get settingsVersion;

  /// No description provided for @settingsInvite.
  ///
  /// In ja, this message translates to:
  /// **'友達を招待する'**
  String get settingsInvite;

  /// No description provided for @settingsInviteSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'QRコードまたはリンクでApp Storeのページを共有'**
  String get settingsInviteSubtitle;

  /// No description provided for @settingsInviteDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'QRコードを読み取るか、リンクを送ると\nApp Storeのアプリページが開きます'**
  String get settingsInviteDialogBody;

  /// 共有シートの本文（末尾にURLが付く）
  ///
  /// In ja, this message translates to:
  /// **'全国ライブカメラ地図 - 河川・道路・防災'**
  String get settingsInviteShareText;

  /// No description provided for @settingsLinkCopied.
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピーしました'**
  String get settingsLinkCopied;

  /// No description provided for @settingsReview.
  ///
  /// In ja, this message translates to:
  /// **'アプリを評価する'**
  String get settingsReview;

  /// No description provided for @settingsReviewSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'App Storeでレビューを書く'**
  String get settingsReviewSubtitle;

  /// No description provided for @settingsOtherApps.
  ///
  /// In ja, this message translates to:
  /// **'開発者の他のアプリ'**
  String get settingsOtherApps;

  /// No description provided for @settingsShowMoreApps.
  ///
  /// In ja, this message translates to:
  /// **'その他のアプリを見る'**
  String get settingsShowMoreApps;

  /// No description provided for @settingsSectionDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'免責'**
  String get settingsSectionDisclaimer;

  /// No description provided for @settingsOssLicenses.
  ///
  /// In ja, this message translates to:
  /// **'OSSライセンス'**
  String get settingsOssLicenses;

  /// No description provided for @settingsNotifyDiag.
  ///
  /// In ja, this message translates to:
  /// **'通知診断'**
  String get settingsNotifyDiag;

  /// No description provided for @settingsNotifyDiagSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'通知が届かないときの状態確認'**
  String get settingsNotifyDiagSubtitle;

  /// No description provided for @settingsNotifyDiagUnlocked.
  ///
  /// In ja, this message translates to:
  /// **'通知診断を表示しました（災害通知の項目内）'**
  String get settingsNotifyDiagUnlocked;

  /// No description provided for @settingsNotifyPermission.
  ///
  /// In ja, this message translates to:
  /// **'通知許可: {value}'**
  String settingsNotifyPermission(String value);

  /// No description provided for @settingsNotifyApns.
  ///
  /// In ja, this message translates to:
  /// **'APNsトークン: {value}'**
  String settingsNotifyApns(String value);

  /// No description provided for @settingsNotifyFcm.
  ///
  /// In ja, this message translates to:
  /// **'FCMトークン:'**
  String get settingsNotifyFcm;

  /// No description provided for @settingsCopyToken.
  ///
  /// In ja, this message translates to:
  /// **'トークンをコピー'**
  String get settingsCopyToken;

  /// No description provided for @settingsTokenCopied.
  ///
  /// In ja, this message translates to:
  /// **'FCMトークンをコピーしました'**
  String get settingsTokenCopied;

  /// No description provided for @settingsCrashDiag.
  ///
  /// In ja, this message translates to:
  /// **'クラッシュ診断データ'**
  String get settingsCrashDiag;

  /// No description provided for @settingsCrashDiagSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'強制終了の記録(MetricKit)を表示・コピー'**
  String get settingsCrashDiagSubtitle;

  /// No description provided for @settingsCrashDiagNone.
  ///
  /// In ja, this message translates to:
  /// **'診断データはまだありません'**
  String get settingsCrashDiagNone;

  /// No description provided for @settingsCrashDiagNoneHint.
  ///
  /// In ja, this message translates to:
  /// **'診断データはまだありません。\nクラッシュ後にアプリを起動し直すと記録されます'**
  String get settingsCrashDiagNoneHint;

  /// No description provided for @settingsCopyFullText.
  ///
  /// In ja, this message translates to:
  /// **'全文をコピー'**
  String get settingsCopyFullText;

  /// No description provided for @settingsJsonCopied.
  ///
  /// In ja, this message translates to:
  /// **'診断JSONをコピーしました'**
  String get settingsJsonCopied;

  /// No description provided for @attributionScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'出典・ライセンス一覧'**
  String get attributionScreenTitle;

  /// No description provided for @attributionOpenYoutube.
  ///
  /// In ja, this message translates to:
  /// **'YouTubeで配信元を見る'**
  String get attributionOpenYoutube;

  /// No description provided for @attributionOpenSite.
  ///
  /// In ja, this message translates to:
  /// **'提供元のサイトを開く'**
  String get attributionOpenSite;

  /// No description provided for @listTitle.
  ///
  /// In ja, this message translates to:
  /// **'一覧（{count}）'**
  String listTitle(int count);

  /// No description provided for @listSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'カメラ名・河川名・路線名で検索'**
  String get listSearchHint;

  /// No description provided for @listEmpty.
  ///
  /// In ja, this message translates to:
  /// **'条件に合うカメラがありません'**
  String get listEmpty;

  /// No description provided for @listRanking.
  ///
  /// In ja, this message translates to:
  /// **'ランキング'**
  String get listRanking;

  /// No description provided for @favoritesTitle.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り（{count}）'**
  String favoritesTitle(int count);

  /// No description provided for @favoritesEmpty.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りはまだありません。\n地図でカメラを開いて★を押すと追加されます。'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptyFiltered.
  ///
  /// In ja, this message translates to:
  /// **'絞り込み条件に合うお気に入りがありません'**
  String get favoritesEmptyFiltered;

  /// No description provided for @favoritesSort.
  ///
  /// In ja, this message translates to:
  /// **'並べ替え'**
  String get favoritesSort;

  /// No description provided for @favoritesSortNewest.
  ///
  /// In ja, this message translates to:
  /// **'登録が新しい順'**
  String get favoritesSortNewest;

  /// No description provided for @favoritesSortOldest.
  ///
  /// In ja, this message translates to:
  /// **'登録が古い順'**
  String get favoritesSortOldest;

  /// No description provided for @favoritesSortName.
  ///
  /// In ja, this message translates to:
  /// **'名前順'**
  String get favoritesSortName;

  /// No description provided for @favoritesSortCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ順'**
  String get favoritesSortCategory;

  /// No description provided for @favoritesToggleView.
  ///
  /// In ja, this message translates to:
  /// **'表示切替'**
  String get favoritesToggleView;

  /// No description provided for @favoritesRefreshAll.
  ///
  /// In ja, this message translates to:
  /// **'一括更新（3件ずつ順次取得）'**
  String get favoritesRefreshAll;

  /// No description provided for @favoritesVideoOnly.
  ///
  /// In ja, this message translates to:
  /// **'動画のみ'**
  String get favoritesVideoOnly;

  /// No description provided for @rankingTitle.
  ///
  /// In ja, this message translates to:
  /// **'全国ランキング'**
  String get rankingTitle;

  /// No description provided for @rankingModeNow.
  ///
  /// In ja, this message translates to:
  /// **'いま見られている（24時間 TOP10）'**
  String get rankingModeNow;

  /// No description provided for @rankingModeWeek.
  ///
  /// In ja, this message translates to:
  /// **'よく見られている（7日間 TOP30）'**
  String get rankingModeWeek;

  /// No description provided for @rankingModeFavorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り登録（TOP20）'**
  String get rankingModeFavorites;

  /// No description provided for @rankingNote.
  ///
  /// In ja, this message translates to:
  /// **'全ユーザーの匿名統計に基づくランキングです（毎日更新）'**
  String get rankingNote;

  /// No description provided for @rankingEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ集計データがありません（毎日1回更新されます）'**
  String get rankingEmpty;

  /// No description provided for @rankingPreparing.
  ///
  /// In ja, this message translates to:
  /// **'全国ランキングは準備中です。\n集計は3時間おきに行われます。'**
  String get rankingPreparing;

  /// No description provided for @rankingFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました'**
  String get rankingFetchFailed;

  /// No description provided for @rankingFetchFailedHttp.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました (HTTP {code})'**
  String rankingFetchFailedHttp(int code);

  /// No description provided for @rankingUnitViews.
  ///
  /// In ja, this message translates to:
  /// **'回'**
  String get rankingUnitViews;

  /// No description provided for @rankingUnitFavorites.
  ///
  /// In ja, this message translates to:
  /// **'件'**
  String get rankingUnitFavorites;

  /// No description provided for @detailLive.
  ///
  /// In ja, this message translates to:
  /// **'ライブ配信中'**
  String get detailLive;

  /// No description provided for @detailTimeUnknown.
  ///
  /// In ja, this message translates to:
  /// **'取得時刻不明'**
  String get detailTimeUnknown;

  /// No description provided for @detailRefreshEvery.
  ///
  /// In ja, this message translates to:
  /// **'{sec}秒ごとに更新'**
  String detailRefreshEvery(int sec);

  /// No description provided for @detailRefreshIn.
  ///
  /// In ja, this message translates to:
  /// **'{sec}秒'**
  String detailRefreshIn(int sec);

  /// No description provided for @detailRefreshNow.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get detailRefreshNow;

  /// No description provided for @detailPosRepresentative.
  ///
  /// In ja, this message translates to:
  /// **'位置は広域の代表点'**
  String get detailPosRepresentative;

  /// No description provided for @detailPosApprox.
  ///
  /// In ja, this message translates to:
  /// **'位置はおおよそ'**
  String get detailPosApprox;

  /// No description provided for @detailNotUpdating.
  ///
  /// In ja, this message translates to:
  /// **'画像が更新されていません'**
  String get detailNotUpdating;

  /// No description provided for @detailWorld.
  ///
  /// In ja, this message translates to:
  /// **'海外'**
  String get detailWorld;

  /// No description provided for @detailCategoryAndPlace.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ・位置'**
  String get detailCategoryAndPlace;

  /// No description provided for @detailOpenMap.
  ///
  /// In ja, this message translates to:
  /// **'地図で見る'**
  String get detailOpenMap;

  /// No description provided for @detailHotelsTitle.
  ///
  /// In ja, this message translates to:
  /// **'この付近の宿を探す'**
  String get detailHotelsTitle;

  /// No description provided for @detailOpenSourceSite.
  ///
  /// In ja, this message translates to:
  /// **'出典サイトを見る'**
  String get detailOpenSourceSite;

  /// No description provided for @detailOpenYoutube.
  ///
  /// In ja, this message translates to:
  /// **'YouTubeで見る'**
  String get detailOpenYoutube;

  /// No description provided for @detailOpenChannel.
  ///
  /// In ja, this message translates to:
  /// **'チャンネルページを見る'**
  String get detailOpenChannel;

  /// No description provided for @detailOpenOriginalPage.
  ///
  /// In ja, this message translates to:
  /// **'元ページで見る'**
  String get detailOpenOriginalPage;

  /// No description provided for @detailReportProblem.
  ///
  /// In ja, this message translates to:
  /// **'このカメラの不具合を報告'**
  String get detailReportProblem;

  /// No description provided for @detailNearby.
  ///
  /// In ja, this message translates to:
  /// **'周辺のカメラ'**
  String get detailNearby;

  /// No description provided for @detailDistanceKm.
  ///
  /// In ja, this message translates to:
  /// **'約{km}km'**
  String detailDistanceKm(String km);

  /// No description provided for @detailWifiOnlyBlocked.
  ///
  /// In ja, this message translates to:
  /// **'設定により、画像の取得はWi-Fi接続時のみです'**
  String get detailWifiOnlyBlocked;

  /// No description provided for @detailNoImage.
  ///
  /// In ja, this message translates to:
  /// **'現在映像を取得できません'**
  String get detailNoImage;

  /// No description provided for @detailEmbedBlockedYoutube.
  ///
  /// In ja, this message translates to:
  /// **'提供者の設定により、この映像は\nアプリ内で再生できません'**
  String get detailEmbedBlockedYoutube;

  /// No description provided for @detailEmbedBlockedPage.
  ///
  /// In ja, this message translates to:
  /// **'配信元の利用条件により\nアプリ内では表示できません'**
  String get detailEmbedBlockedPage;

  /// No description provided for @detailIHighwayTitle.
  ///
  /// In ja, this message translates to:
  /// **'NEXCO公式「iHighway」で\nライブカメラを表示'**
  String get detailIHighwayTitle;

  /// No description provided for @detailIHighwayBody.
  ///
  /// In ja, this message translates to:
  /// **'タップするとアプリ内ブラウザで公式サイトを開き、\nこのカメラの位置まで自動で移動します'**
  String get detailIHighwayBody;

  /// No description provided for @detailIHighwayHost.
  ///
  /// In ja, this message translates to:
  /// **'ihighway.jp（NEXCO公式）'**
  String get detailIHighwayHost;

  /// 国土地理院の地図タイルの出典表記。日本語の正式名は変更しない
  ///
  /// In ja, this message translates to:
  /// **'地理院タイル'**
  String get detailMapTileGsi;

  /// No description provided for @elevationLoading.
  ///
  /// In ja, this message translates to:
  /// **'標高 …'**
  String get elevationLoading;

  /// No description provided for @elevationValue.
  ///
  /// In ja, this message translates to:
  /// **'標高 {value}（{source}）'**
  String elevationValue(String value, String source);

  /// No description provided for @timeTakenAt.
  ///
  /// In ja, this message translates to:
  /// **'{time} 取得{relative}'**
  String timeTakenAt(String time, String relative);

  /// No description provided for @timeRelJustNow.
  ///
  /// In ja, this message translates to:
  /// **'（たった今）'**
  String get timeRelJustNow;

  /// No description provided for @timeRelMinutes.
  ///
  /// In ja, this message translates to:
  /// **'（{n}分前）'**
  String timeRelMinutes(int n);

  /// No description provided for @timeRelHours.
  ///
  /// In ja, this message translates to:
  /// **'（{n}時間前）'**
  String timeRelHours(int n);

  /// No description provided for @timeMonthDay.
  ///
  /// In ja, this message translates to:
  /// **'{month}月{day}日'**
  String timeMonthDay(int month, int day);

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「震度５弱」から震度語を除いた短縮形（バッジ表示用）
  ///
  /// In ja, this message translates to:
  /// **'5弱'**
  String get intensity5Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「震度５強」から震度語を除いた短縮形
  ///
  /// In ja, this message translates to:
  /// **'5強'**
  String get intensity5Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「震度６弱」から震度語を除いた短縮形
  ///
  /// In ja, this message translates to:
  /// **'6弱'**
  String get intensity6Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「震度６強」から震度語を除いた短縮形
  ///
  /// In ja, this message translates to:
  /// **'6強'**
  String get intensity6Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「震度５弱以上」
  ///
  /// In ja, this message translates to:
  /// **'震度5弱以上'**
  String get quakeLevel5Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「震度５弱以上」の型に「５強」を当てはめた　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'震度5強以上'**
  String get quakeLevel5Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「震度５弱以上」の型に「６弱」を当てはめた　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'震度6弱以上'**
  String get quakeLevel6Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「暴風雪警報」
  ///
  /// In ja, this message translates to:
  /// **'暴風雪警報'**
  String get warning02;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雨警報（土砂災害）」から括弧を除去
  ///
  /// In ja, this message translates to:
  /// **'大雨警報'**
  String get warning03;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「洪水警報」
  ///
  /// In ja, this message translates to:
  /// **'洪水警報'**
  String get warning04;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「暴風警報」
  ///
  /// In ja, this message translates to:
  /// **'暴風警報'**
  String get warning05;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雪警報」
  ///
  /// In ja, this message translates to:
  /// **'大雪警報'**
  String get warning06;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「波浪警報」
  ///
  /// In ja, this message translates to:
  /// **'波浪警報'**
  String get warning07;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「高潮警報」
  ///
  /// In ja, this message translates to:
  /// **'高潮警報'**
  String get warning08;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「土砂災害」＋「警報」の合成（2026新体系。辞書に単独項目なし）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'土砂災害警報'**
  String get warning09;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 防災気象情報「レベル４大雨危険警報」からレベル表記を除去（JMA_ADAPT）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'大雨危険警報'**
  String get warning43;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「レベル４氾濫危険警報」は氾濫語。本アプリのコード44は洪水危険警報のため「洪水」の訳語に差し替え　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'洪水危険警報'**
  String get warning44;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 防災気象情報「レベル４高潮危険警報」からレベル表記を除去（JMA_ADAPT）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'高潮危険警報'**
  String get warning48;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 防災気象情報「レベル４土砂災害危険警報」からレベル表記を除去（JMA_ADAPT）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'土砂災害危険警報'**
  String get warning49;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「暴風雪特別警報」
  ///
  /// In ja, this message translates to:
  /// **'暴風雪特別警報'**
  String get warning32;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雨特別警報（土砂災害）」から括弧を除去
  ///
  /// In ja, this message translates to:
  /// **'大雨特別警報'**
  String get warning33;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「洪水」＋「特別警報」の合成（2026新体系）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'洪水特別警報'**
  String get warning34;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「暴風特別警報」
  ///
  /// In ja, this message translates to:
  /// **'暴風特別警報'**
  String get warning35;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雪特別警報」
  ///
  /// In ja, this message translates to:
  /// **'大雪特別警報'**
  String get warning36;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「波浪特別警報」
  ///
  /// In ja, this message translates to:
  /// **'波浪特別警報'**
  String get warning37;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「高潮特別警報」
  ///
  /// In ja, this message translates to:
  /// **'高潮特別警報'**
  String get warning38;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「土砂災害」＋「特別警報」の合成（2026新体系）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'土砂災害特別警報'**
  String get warning39;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雨注意報」
  ///
  /// In ja, this message translates to:
  /// **'大雨注意報'**
  String get advisory10;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「大雪注意報」
  ///
  /// In ja, this message translates to:
  /// **'大雪注意報'**
  String get advisory12;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「風雪注意報」
  ///
  /// In ja, this message translates to:
  /// **'風雪注意報'**
  String get advisory13;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「雷注意報」
  ///
  /// In ja, this message translates to:
  /// **'雷注意報'**
  String get advisory14;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「強風注意報」
  ///
  /// In ja, this message translates to:
  /// **'強風注意報'**
  String get advisory15;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「波浪注意報」
  ///
  /// In ja, this message translates to:
  /// **'波浪注意報'**
  String get advisory16;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「融雪注意報」
  ///
  /// In ja, this message translates to:
  /// **'融雪注意報'**
  String get advisory17;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「洪水注意報」
  ///
  /// In ja, this message translates to:
  /// **'洪水注意報'**
  String get advisory18;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「高潮注意報」
  ///
  /// In ja, this message translates to:
  /// **'高潮注意報'**
  String get advisory19;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「濃霧注意報」
  ///
  /// In ja, this message translates to:
  /// **'濃霧注意報'**
  String get advisory20;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「乾燥注意報」
  ///
  /// In ja, this message translates to:
  /// **'乾燥注意報'**
  String get advisory21;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「なだれ注意報」
  ///
  /// In ja, this message translates to:
  /// **'なだれ注意報'**
  String get advisory22;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「低温注意報」
  ///
  /// In ja, this message translates to:
  /// **'低温注意報'**
  String get advisory23;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「霜注意報」
  ///
  /// In ja, this message translates to:
  /// **'霜注意報'**
  String get advisory24;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「着氷注意報」
  ///
  /// In ja, this message translates to:
  /// **'着氷注意報'**
  String get advisory25;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「着雪注意報」
  ///
  /// In ja, this message translates to:
  /// **'着雪注意報'**
  String get advisory26;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「土砂災害」＋「注意報」の合成（2026新体系）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'土砂災害注意報'**
  String get advisory29;

  /// No description provided for @mapLocationDenied.
  ///
  /// In ja, this message translates to:
  /// **'位置情報の利用が許可されていません（設定から変更できます）'**
  String get mapLocationDenied;

  /// No description provided for @mapLocationFailed.
  ///
  /// In ja, this message translates to:
  /// **'現在地を取得できませんでした'**
  String get mapLocationFailed;

  /// No description provided for @mapLegendTitle.
  ///
  /// In ja, this message translates to:
  /// **'凡例・絞り込み'**
  String get mapLegendTitle;

  /// No description provided for @mapLegendSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'カメラ名・運営者・河川/路線名で検索'**
  String get mapLegendSearchHint;

  /// No description provided for @mapFilterFavoritesOnly.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りのみ'**
  String get mapFilterFavoritesOnly;

  /// No description provided for @mapFilterOkOnly.
  ///
  /// In ja, this message translates to:
  /// **'現在映っているもののみ'**
  String get mapFilterOkOnly;

  /// No description provided for @mapLegendLiveDot.
  ///
  /// In ja, this message translates to:
  /// **'赤ドット = 動画（ライブ配信）'**
  String get mapLegendLiveDot;

  /// No description provided for @mapLegendUncertain.
  ///
  /// In ja, this message translates to:
  /// **'黄色の縁 = 位置未確定（おおよそ/代表点）'**
  String get mapLegendUncertain;

  /// No description provided for @mapLegendFrozen.
  ///
  /// In ja, this message translates to:
  /// **'半透明 = 画像が長時間更新されていない'**
  String get mapLegendFrozen;

  /// No description provided for @mapLegendFavorite.
  ///
  /// In ja, this message translates to:
  /// **'金の星 = お気に入り登録済み'**
  String get mapLegendFavorite;

  /// No description provided for @mapLegendCluster.
  ///
  /// In ja, this message translates to:
  /// **'数字の丸 = 周辺カメラのまとまり（タップでズーム）'**
  String get mapLegendCluster;

  /// No description provided for @mapSearchTitle.
  ///
  /// In ja, this message translates to:
  /// **'場所を検索'**
  String get mapSearchTitle;

  /// No description provided for @mapSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'地名・住所（例: 渋谷、金沢市広坂）'**
  String get mapSearchHint;

  /// No description provided for @mapSearchNotFound.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした。地名・住所・カメラ名でお試しください'**
  String get mapSearchNotFound;

  /// No description provided for @mapSearchSectionCameras.
  ///
  /// In ja, this message translates to:
  /// **'カメラ'**
  String get mapSearchSectionCameras;

  /// No description provided for @mapSearchSectionPlaces.
  ///
  /// In ja, this message translates to:
  /// **'場所'**
  String get mapSearchSectionPlaces;

  /// No description provided for @mapPointCameras.
  ///
  /// In ja, this message translates to:
  /// **'この地点のカメラ（{count}台）'**
  String mapPointCameras(int count);

  /// No description provided for @mapFilteredCount.
  ///
  /// In ja, this message translates to:
  /// **'絞り込み中 {count}台'**
  String mapFilteredCount(int count);

  /// No description provided for @mapTotalCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}台'**
  String mapTotalCount(int count);

  /// No description provided for @mapLayersTooltip.
  ///
  /// In ja, this message translates to:
  /// **'地図レイヤー'**
  String get mapLayersTooltip;

  /// No description provided for @bosaiTitle.
  ///
  /// In ja, this message translates to:
  /// **'災害速報'**
  String get bosaiTitle;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'地震・津波'**
  String get bosaiTabQuake;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'気象警報'**
  String get bosaiTabWarning;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'熱中症'**
  String get bosaiTabHeat;

  /// No description provided for @bosaiNoWarnings.
  ///
  /// In ja, this message translates to:
  /// **'現在、発表中の警報・注意報はありません'**
  String get bosaiNoWarnings;

  /// 出典表記（気象庁）はどの言語でも省略しない。SPEC C5
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁。現在、警報・特別警報の発表はありません。注意報のみの地域は下の一覧から確認できます。'**
  String get bosaiWarningNoteNone;

  /// 出典表記（気象庁）はどの言語でも省略しない。SPEC C5
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁 気象警報・注意報。タップするとその都道府県のカメラ一覧を表示します。'**
  String get bosaiWarningNote;

  /// No description provided for @bosaiAdvisoryRegions.
  ///
  /// In ja, this message translates to:
  /// **'注意報が発表中の地域（{count}都道府県）'**
  String bosaiAdvisoryRegions(int count);

  /// No description provided for @bosaiWarningAreasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{pref}の警報発表地域'**
  String bosaiWarningAreasTitle(String pref);

  /// No description provided for @bosaiAdvisoryAreasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{pref}の注意報発表地域'**
  String bosaiAdvisoryAreasTitle(String pref);

  /// 出典表記（気象庁）はどの言語でも省略しない。SPEC C5
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁。タップするとその市区町村のカメラ一覧を表示します'**
  String get bosaiMuniNote;

  /// No description provided for @bosaiMuniFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'発表エリアの詳細を取得できませんでした'**
  String get bosaiMuniFetchFailed;

  /// No description provided for @bosaiMuniNone.
  ///
  /// In ja, this message translates to:
  /// **'現在、発表中の市区町村はありません'**
  String get bosaiMuniNone;

  /// No description provided for @bosaiCameraCount.
  ///
  /// In ja, this message translates to:
  /// **'カメラ{count}台'**
  String bosaiCameraCount(int count);

  /// No description provided for @bosaiNoCamera.
  ///
  /// In ja, this message translates to:
  /// **'カメラなし'**
  String get bosaiNoCamera;

  /// No description provided for @bosaiMuniCamerasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}のカメラ（警報発表中）'**
  String bosaiMuniCamerasTitle(String name);

  /// No description provided for @settingsJmaDictionary.
  ///
  /// In ja, this message translates to:
  /// **'防災用語の翻訳について'**
  String get settingsJmaDictionary;

  /// SPEC C5 / 公共データ利用規約（第1.0版）の出典表示要件。省略しないこと
  ///
  /// In ja, this message translates to:
  /// **'警報名・注意報名・震度などの各言語訳は、気象庁「気象情報等に関する多言語辞書」に準拠しています。出典：気象庁ホームページ'**
  String get settingsJmaDictionaryNote;

  /// No description provided for @hazardFloodTitle.
  ///
  /// In ja, this message translates to:
  /// **'洪水浸水想定区域（想定最大規模）'**
  String get hazardFloodTitle;

  /// No description provided for @hazardLandslideTitle.
  ///
  /// In ja, this message translates to:
  /// **'土砂災害警戒区域'**
  String get hazardLandslideTitle;

  /// No description provided for @hazardTsunamiTitle.
  ///
  /// In ja, this message translates to:
  /// **'津波浸水想定'**
  String get hazardTsunamiTitle;

  /// No description provided for @hazardHightideTitle.
  ///
  /// In ja, this message translates to:
  /// **'高潮浸水想定区域'**
  String get hazardHightideTitle;

  /// No description provided for @hazardLandslideSteepSlope.
  ///
  /// In ja, this message translates to:
  /// **'急傾斜地'**
  String get hazardLandslideSteepSlope;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「土石流」
  ///
  /// In ja, this message translates to:
  /// **'土石流'**
  String get hazardLandslideDebrisFlow;

  /// No description provided for @hazardLandslideSlide.
  ///
  /// In ja, this message translates to:
  /// **'地すべり'**
  String get hazardLandslideSlide;

  /// No description provided for @hazardDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'最新かつ詳細な情報は各市町村のハザードマップをご確認ください。避難判断は自治体の避難情報に従ってください'**
  String get hazardDisclaimer;

  /// No description provided for @facilityKindWater.
  ///
  /// In ja, this message translates to:
  /// **'給水拠点・応急給水施設'**
  String get facilityKindWater;

  /// No description provided for @facilityKindStock.
  ///
  /// In ja, this message translates to:
  /// **'防災備蓄倉庫'**
  String get facilityKindStock;

  /// No description provided for @facilityKindFireWater.
  ///
  /// In ja, this message translates to:
  /// **'消防水利（消火栓・防火水槽）'**
  String get facilityKindFireWater;

  /// No description provided for @facilityKindWaterShort.
  ///
  /// In ja, this message translates to:
  /// **'給水拠点'**
  String get facilityKindWaterShort;

  /// No description provided for @facilityKindStockShort.
  ///
  /// In ja, this message translates to:
  /// **'防災備蓄倉庫'**
  String get facilityKindStockShort;

  /// No description provided for @facilityKindFireWaterShort.
  ///
  /// In ja, this message translates to:
  /// **'消防水利'**
  String get facilityKindFireWaterShort;

  /// No description provided for @facilityDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'公開している自治体のみ。最新の情報は各自治体にご確認ください'**
  String get facilityDisclaimer;

  /// No description provided for @facilityNoData.
  ///
  /// In ja, this message translates to:
  /// **'この地域のデータはまだありません'**
  String get facilityNoData;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「洪水」
  ///
  /// In ja, this message translates to:
  /// **'洪水'**
  String get shelterHazardFlood;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「土砂災害」
  ///
  /// In ja, this message translates to:
  /// **'土砂'**
  String get shelterHazardSediment;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「高潮」（韓国語は辞書の注記<바다의 물이 늘어남>を除去）
  ///
  /// In ja, this message translates to:
  /// **'高潮'**
  String get shelterHazardHightide;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「地震情報」から情報語を除去
  ///
  /// In ja, this message translates to:
  /// **'地震'**
  String get shelterHazardEarthquake;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「津波警報」から警報語を除去
  ///
  /// In ja, this message translates to:
  /// **'津波'**
  String get shelterHazardTsunami;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: 辞書に「火事」なし（一般語のため各言語の通常語）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'火事'**
  String get shelterHazardFire;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: 辞書に「内水」なし。JMA「浸水」(inundation) を基に合成　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'内水'**
  String get shelterHazardInlandFlood;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「火山」
  ///
  /// In ja, this message translates to:
  /// **'火山'**
  String get shelterHazardVolcano;

  /// No description provided for @shelterDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'最新かつ詳細な状況は各市町村にご確認ください'**
  String get shelterDisclaimer;

  /// No description provided for @riskLandTitle.
  ///
  /// In ja, this message translates to:
  /// **'土砂キキクル'**
  String get riskLandTitle;

  /// No description provided for @riskInundTitle.
  ///
  /// In ja, this message translates to:
  /// **'浸水キキクル'**
  String get riskInundTitle;

  /// No description provided for @riskFloodTitle.
  ///
  /// In ja, this message translates to:
  /// **'洪水キキクル'**
  String get riskFloodTitle;

  /// No description provided for @riskLandSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'土砂災害の危険度（1kmメッシュ・10分ごとに更新）'**
  String get riskLandSubtitle;

  /// No description provided for @riskInundSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'浸水害の危険度（1kmメッシュ・10分ごとに更新）'**
  String get riskInundSubtitle;

  /// No description provided for @riskFloodSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'洪水災害の危険度（河川ごと・10分ごとに更新）'**
  String get riskFloodSubtitle;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: 気象庁凡例「今後の情報等に留意」に対応する語（辞書に単独項目なし）　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'留意'**
  String get riskLevelWatch;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「警報の危険度分布・注意」
  ///
  /// In ja, this message translates to:
  /// **'注意'**
  String get riskLevelCaution;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「警報の危険度分布・警戒」
  ///
  /// In ja, this message translates to:
  /// **'警戒'**
  String get riskLevelWarning;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「警報の危険度分布・危険」
  ///
  /// In ja, this message translates to:
  /// **'危険'**
  String get riskLevelDanger;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「警報の危険度分布・災害切迫」
  ///
  /// In ja, this message translates to:
  /// **'切迫'**
  String get riskLevelCritical;

  /// No description provided for @wbgtLevelDanger.
  ///
  /// In ja, this message translates to:
  /// **'危険'**
  String get wbgtLevelDanger;

  /// No description provided for @wbgtLevelSevereWarning.
  ///
  /// In ja, this message translates to:
  /// **'厳重警戒'**
  String get wbgtLevelSevereWarning;

  /// No description provided for @wbgtLevelWarning.
  ///
  /// In ja, this message translates to:
  /// **'警戒'**
  String get wbgtLevelWarning;

  /// No description provided for @wbgtLevelCaution.
  ///
  /// In ja, this message translates to:
  /// **'注意'**
  String get wbgtLevelCaution;

  /// No description provided for @wbgtLevelSafe.
  ///
  /// In ja, this message translates to:
  /// **'ほぼ安全'**
  String get wbgtLevelSafe;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: JMA「熱中症警戒アラート」＋「特別警報」の合成　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'熱中症特別警戒'**
  String get heatAlertSpecial;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: ADAPT: 上記に「判定」段階の注記を付けたもの　※ADAPT（辞書に単独項目が無く、辞書の語彙で合成した語）
  ///
  /// In ja, this message translates to:
  /// **'熱中症特別警戒（判定）'**
  String get heatAlertSpecialPending;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁／**自由訳しないこと**。根拠: JMA 用語「熱中症警戒アラート」
  ///
  /// In ja, this message translates to:
  /// **'熱中症警戒'**
  String get heatAlertWarning;

  /// No description provided for @heatAlertDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'本情報は参考情報です。正式発表は熱中症予防情報サイト等をご確認ください'**
  String get heatAlertDisclaimer;

  /// 言語名。各言語のARBでも自称表記のままにする
  ///
  /// In ja, this message translates to:
  /// **'简体中文'**
  String get languageNameZhHans;

  /// 言語名。各言語のARBでも自称表記のままにする
  ///
  /// In ja, this message translates to:
  /// **'繁體中文'**
  String get languageNameZhHant;

  /// 言語名。各言語のARBでも自称表記のままにする
  ///
  /// In ja, this message translates to:
  /// **'한국어'**
  String get languageNameKo;

  /// 言語名。各言語のARBでも自称表記のままにする
  ///
  /// In ja, this message translates to:
  /// **'Tiếng Việt'**
  String get languageNameVi;

  /// No description provided for @mapLayerPanelSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'地図に1種類だけ重ねて表示します'**
  String get mapLayerPanelSubtitle;

  /// No description provided for @mapLayerNone.
  ///
  /// In ja, this message translates to:
  /// **'表示しない'**
  String get mapLayerNone;

  /// No description provided for @mapLayerSectionWeather.
  ///
  /// In ja, this message translates to:
  /// **'気象'**
  String get mapLayerSectionWeather;

  /// No description provided for @mapLayerRainRadarTitle.
  ///
  /// In ja, this message translates to:
  /// **'雨雲レーダー（現在）'**
  String get mapLayerRainRadarTitle;

  /// No description provided for @mapLayerRainRadarSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'高解像度降水ナウキャスト・5分ごとに更新'**
  String get mapLayerRainRadarSubtitle;

  /// No description provided for @mapLayerQuakesTitle.
  ///
  /// In ja, this message translates to:
  /// **'震源'**
  String get mapLayerQuakesTitle;

  /// No description provided for @mapQuakePeriodDay.
  ///
  /// In ja, this message translates to:
  /// **'24時間'**
  String get mapQuakePeriodDay;

  /// No description provided for @mapQuakePeriodWeek.
  ///
  /// In ja, this message translates to:
  /// **'7日'**
  String get mapQuakePeriodWeek;

  /// No description provided for @mapQuakePeriodMonth.
  ///
  /// In ja, this message translates to:
  /// **'30日'**
  String get mapQuakePeriodMonth;

  /// No description provided for @mapLayerRain24hTitle.
  ///
  /// In ja, this message translates to:
  /// **'24時間降水量'**
  String get mapLayerRain24hTitle;

  /// ADAPT: 「解析雨量」は多言語辞書に無いため気象庁英語ページの Radar/Raingauge-Analyzed Precipitation を用いた
  ///
  /// In ja, this message translates to:
  /// **'気象庁の解析雨量（面）＋拡大でアメダス観測値'**
  String get mapLayerRain24hSubtitle;

  /// No description provided for @mapLayerSectionHazard.
  ///
  /// In ja, this message translates to:
  /// **'ハザードマップ'**
  String get mapLayerSectionHazard;

  /// ADAPT: 警戒区域/特別警戒区域は多言語辞書に無いため hazard area / special hazard area とした
  ///
  /// In ja, this message translates to:
  /// **'急傾斜地・土石流・地すべり（黄=警戒区域 / 赤=特別警戒区域）'**
  String get mapHazardLandslideSubtitle;

  /// No description provided for @mapHazardDepthSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'想定される浸水深を色分け表示'**
  String get mapHazardDepthSubtitle;

  /// ADAPT: 避難場所レイヤーの見出し。名前のない避難場所の代替表示にも使う
  ///
  /// In ja, this message translates to:
  /// **'避難場所'**
  String get mapShelterTitle;

  /// ADAPT: 国土地理院の用語。多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'避難場所（指定緊急避難場所・指定避難所）'**
  String get mapLayerShelterTitle;

  /// No description provided for @mapLayerShelterSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'拡大すると表示。災害種別で絞り込みできます'**
  String get mapLayerShelterSubtitle;

  /// ADAPT: 多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'防災拠点'**
  String get mapFacilityTitle;

  /// ADAPT: 多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'防災拠点（給水拠点・防災備蓄倉庫）'**
  String get mapLayerFacilityTitle;

  /// No description provided for @mapLayerFacilitySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'拡大すると表示。種別で絞り込みできます'**
  String get mapLayerFacilitySubtitle;

  /// No description provided for @mapQuakeNearbyTitle.
  ///
  /// In ja, this message translates to:
  /// **'この付近の地震 {count}件'**
  String mapQuakeNearbyTitle(int count);

  /// No description provided for @mapQuakeUnknownPlace.
  ///
  /// In ja, this message translates to:
  /// **'震源（詳細未発表）'**
  String get mapQuakeUnknownPlace;

  /// No description provided for @mapQuakeMaxIntensity.
  ///
  /// In ja, this message translates to:
  /// **'最大震度{value}'**
  String mapQuakeMaxIntensity(String value);

  /// 震源・避難場所・防災拠点から開く周辺カメラ画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'{name} 周辺のカメラ'**
  String mapNearbyCamerasTitle(String name);

  /// No description provided for @mapQuakeTapHint.
  ///
  /// In ja, this message translates to:
  /// **'タップで周辺のライブカメラ（50km以内）を表示'**
  String get mapQuakeTapHint;

  /// No description provided for @mapShelterNoticeTitle.
  ///
  /// In ja, this message translates to:
  /// **'避難場所レイヤーについて'**
  String get mapShelterNoticeTitle;

  /// ADAPT: 初回ONのときの注意ダイアログ本文。末尾に出典表記（日本語のまま）が続く
  ///
  /// In ja, this message translates to:
  /// **'・「指定緊急避難場所」は災害の危険から命を守るために逃げ込む場所、「指定避難所」は一定期間滞在する施設です（二重枠で表示）\n・指定緊急避難場所は災害種別ごとに指定されており、災害の種類によっては避難できない場合があります\n・市町村から提供された情報のため、最新でない場合や掲載されていない場所があります。正確な情報は当該市町村にご確認ください'**
  String get mapShelterNoticeBody;

  /// No description provided for @mapShelterHazardAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get mapShelterHazardAll;

  /// ADAPT: 多言語辞書に無い。詳細シートのバッジなので短く
  ///
  /// In ja, this message translates to:
  /// **'指定避難所'**
  String get mapShelterDesignated;

  /// No description provided for @mapShelterHazardsLabel.
  ///
  /// In ja, this message translates to:
  /// **'対応する災害種別'**
  String get mapShelterHazardsLabel;

  /// No description provided for @mapOpenRoute.
  ///
  /// In ja, this message translates to:
  /// **'Googleマップで経路を見る'**
  String get mapOpenRoute;

  /// No description provided for @mapNearbyCamerasButton.
  ///
  /// In ja, this message translates to:
  /// **'周辺のライブカメラ'**
  String get mapNearbyCamerasButton;

  /// No description provided for @mapFacilityNoticeTitle.
  ///
  /// In ja, this message translates to:
  /// **'防災拠点レイヤーについて'**
  String get mapFacilityNoticeTitle;

  /// ADAPT: 初回ONのときの注意ダイアログ本文。末尾に出典表記（日本語のまま）が続く
  ///
  /// In ja, this message translates to:
  /// **'・各自治体がオープンデータとして公開している「応急給水施設」「備蓄倉庫」「消防水利施設」の一覧を集めたものです。公開している自治体のみで、全国は網羅していません\n・消火栓・防火水槽は消防活動用の設備で、一般の方が使用するものではありません\n・給水拠点は災害時に開設されるもので、平常時に給水を受けられるとは限りません\n・更新時期は自治体ごとに異なります。正確な情報は各自治体にご確認ください'**
  String get mapFacilityNoticeBody;

  /// No description provided for @mapFacilityOwner.
  ///
  /// In ja, this message translates to:
  /// **'提供：{owner}'**
  String mapFacilityOwner(String owner);

  /// No description provided for @mapFacilityGeocodedNote.
  ///
  /// In ja, this message translates to:
  /// **'住所から推定した位置です（実際の場所とずれる場合があります）'**
  String get mapFacilityGeocodedNote;

  /// No description provided for @mapFacilitySourceDataset.
  ///
  /// In ja, this message translates to:
  /// **'出典（データセット）'**
  String get mapFacilitySourceDataset;

  /// 雨雲スライダーの時間差。mapNowcastAfter / mapNowcastBefore に埋め込む
  ///
  /// In ja, this message translates to:
  /// **'{value}時間'**
  String mapNowcastSpanHours(String value);

  /// No description provided for @mapNowcastSpanMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{value}分'**
  String mapNowcastSpanMinutes(int value);

  /// No description provided for @mapNowcastNow.
  ///
  /// In ja, this message translates to:
  /// **'現在（実況）'**
  String get mapNowcastNow;

  /// No description provided for @mapNowcastForecastHourly.
  ///
  /// In ja, this message translates to:
  /// **'予報・1時間雨量'**
  String get mapNowcastForecastHourly;

  /// No description provided for @mapNowcastForecast.
  ///
  /// In ja, this message translates to:
  /// **'予測'**
  String get mapNowcastForecast;

  /// No description provided for @mapNowcastAfter.
  ///
  /// In ja, this message translates to:
  /// **'{span}後（{kind}）'**
  String mapNowcastAfter(String span, String kind);

  /// No description provided for @mapNowcastBefore.
  ///
  /// In ja, this message translates to:
  /// **'{span}前（実況）'**
  String mapNowcastBefore(String span);

  /// No description provided for @mapNowcastBackToNow.
  ///
  /// In ja, this message translates to:
  /// **'現在へ'**
  String get mapNowcastBackToNow;

  /// No description provided for @mapNowcastNowMarker.
  ///
  /// In ja, this message translates to:
  /// **'▲ 現在'**
  String get mapNowcastNowMarker;

  /// No description provided for @mapNowcastLast.
  ///
  /// In ja, this message translates to:
  /// **'{label}（6時間先）'**
  String mapNowcastLast(String label);

  /// No description provided for @mapLegendRainRadar.
  ///
  /// In ja, this message translates to:
  /// **'雨雲レーダー {label}'**
  String mapLegendRainRadar(String label);

  /// No description provided for @mapLegendRainRadarKind.
  ///
  /// In ja, this message translates to:
  /// **'雨雲レーダー {label}（{kind}）'**
  String mapLegendRainRadarKind(String label, String kind);

  /// No description provided for @mapLegendRainWeak.
  ///
  /// In ja, this message translates to:
  /// **'弱'**
  String get mapLegendRainWeak;

  /// No description provided for @mapLegendQuakes.
  ///
  /// In ja, this message translates to:
  /// **'震源 {period}（{count}件）'**
  String mapLegendQuakes(String period, int count);

  /// No description provided for @mapLegendIntensity.
  ///
  /// In ja, this message translates to:
  /// **'震度{value}'**
  String mapLegendIntensity(String value);

  /// No description provided for @mapLegendIntensity6Up.
  ///
  /// In ja, this message translates to:
  /// **'6弱〜'**
  String get mapLegendIntensity6Up;

  /// No description provided for @mapLegendRain24h.
  ///
  /// In ja, this message translates to:
  /// **'24時間降水量 {label}'**
  String mapLegendRain24h(String label);

  /// No description provided for @mapLegendRain24hZoom.
  ///
  /// In ja, this message translates to:
  /// **'24時間降水量 {label}（拡大で観測値）'**
  String mapLegendRain24hZoom(String label);

  /// ADAPT: 警戒区域/特別警戒区域は多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'{title}（警戒 / 特別警戒）'**
  String mapLegendLandslide(String title);

  /// No description provided for @mapLegendShelterZoomIn.
  ///
  /// In ja, this message translates to:
  /// **'避難場所（拡大すると避難場所を表示）'**
  String get mapLegendShelterZoomIn;

  /// No description provided for @mapLegendShelter.
  ///
  /// In ja, this message translates to:
  /// **'避難場所（{count}件）'**
  String mapLegendShelter(int count);

  /// No description provided for @mapLegendShelterCluster.
  ///
  /// In ja, this message translates to:
  /// **'避難場所（{count}件・まとめ表示）'**
  String mapLegendShelterCluster(int count);

  /// No description provided for @mapLegendShelterHazard.
  ///
  /// In ja, this message translates to:
  /// **'避難場所・{hazard}（{count}件）'**
  String mapLegendShelterHazard(String hazard, int count);

  /// No description provided for @mapLegendShelterHazardCluster.
  ///
  /// In ja, this message translates to:
  /// **'避難場所・{hazard}（{count}件・まとめ表示）'**
  String mapLegendShelterHazardCluster(String hazard, int count);

  /// ADAPT: 国土地理院の用語。多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'指定緊急避難場所'**
  String get mapLegendShelterEmergency;

  /// ADAPT: 国土地理院の用語。多言語辞書に無い
  ///
  /// In ja, this message translates to:
  /// **'二重枠=指定避難所'**
  String get mapLegendShelterDesignated;

  /// No description provided for @mapLegendFacilityZoomIn.
  ///
  /// In ja, this message translates to:
  /// **'防災拠点（拡大すると防災拠点を表示）'**
  String get mapLegendFacilityZoomIn;

  /// {message} には facilityNoData が入る
  ///
  /// In ja, this message translates to:
  /// **'防災拠点（{message}）'**
  String mapLegendFacilityNoData(String message);

  /// No description provided for @mapLegendFacility.
  ///
  /// In ja, this message translates to:
  /// **'防災拠点（{count}件）'**
  String mapLegendFacility(int count);

  /// No description provided for @mapLegendFacilityCluster.
  ///
  /// In ja, this message translates to:
  /// **'防災拠点（{count}件・まとめ表示）'**
  String mapLegendFacilityCluster(int count);

  /// No description provided for @mapLegendFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'取得できません'**
  String get mapLegendFetchFailed;

  /// No description provided for @mapShelterFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'避難場所を取得できませんでした（タップで再試行）'**
  String get mapShelterFetchFailed;

  /// No description provided for @mapFacilityFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'防災拠点を取得できませんでした（タップで再試行）'**
  String get mapFacilityFetchFailed;

  /// No description provided for @mapRainTooltip.
  ///
  /// In ja, this message translates to:
  /// **'{name} 24時間 {mm}mm'**
  String mapRainTooltip(String name, String mm);

  /// No description provided for @bosaiFetchFailedPull.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました（引き下げてやり直せます）'**
  String get bosaiFetchFailedPull;

  /// 気象庁の津波リストに見出し(ttl)が無いときの代替。出典：気象庁 多言語辞書（Tsunami Information）
  ///
  /// In ja, this message translates to:
  /// **'津波情報'**
  String get bosaiTsunamiInfo;

  /// 震源地名が空のときの表示
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get bosaiUnknownPlace;

  /// No description provided for @bosaiFetchFailedDetail.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました（{error}）'**
  String bosaiFetchFailedDetail(String error);

  /// No description provided for @bosaiTimeJustNow.
  ///
  /// In ja, this message translates to:
  /// **'たった今'**
  String get bosaiTimeJustNow;

  /// No description provided for @bosaiTimeMinutesAgo.
  ///
  /// In ja, this message translates to:
  /// **'{n}分前'**
  String bosaiTimeMinutesAgo(int n);

  /// No description provided for @bosaiTimeHoursAgo.
  ///
  /// In ja, this message translates to:
  /// **'{n}時間前'**
  String bosaiTimeHoursAgo(int n);

  /// No description provided for @bosaiTimeMonthDayHour.
  ///
  /// In ja, this message translates to:
  /// **'{month}月{day}日 {hour}時頃'**
  String bosaiTimeMonthDayHour(int month, int day, int hour);

  /// 出典：気象庁 多言語辞書（震度=seismic intensity）
  ///
  /// In ja, this message translates to:
  /// **'{place}の震度'**
  String bosaiQuakeIntensityTitle(String place);

  /// No description provided for @bosaiNearbyCamerasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{place}周辺のカメラ'**
  String bosaiNearbyCamerasTitle(String place);

  /// No description provided for @bosaiQuakeEmpty.
  ///
  /// In ja, this message translates to:
  /// **'直近72時間の地震情報はありません'**
  String get bosaiQuakeEmpty;

  /// bosaiQuakeNote の {at} に差し込む断片。英語は前の語と続けるため先頭に半角空白を入れている
  ///
  /// In ja, this message translates to:
  /// **'（{time}時点・新しい順）'**
  String bosaiQuakeAsOf(String time);

  /// 出典表記（気象庁）はどの言語でも省略しない。SPEC C5。{at} は bosaiQuakeAsOf（無いときは空文字）
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁 地震情報（直近72時間）{at}。タップすると揺れた市区町村のライブカメラ一覧（市区町村別震度が無い場合は震源周辺）を表示します。'**
  String bosaiQuakeNote(String at);

  /// 出典：気象庁 多言語辞書（Tsunami）
  ///
  /// In ja, this message translates to:
  /// **'津波'**
  String get bosaiBadgeTsunami;

  /// ADAPT: 44pxのバッジに2行で入れるため、多言語辞書の seismic intensity を Intensity に短縮した
  ///
  /// In ja, this message translates to:
  /// **'震度\n{value}'**
  String bosaiBadgeIntensity(String value);

  /// No description provided for @bosaiMuniObserved.
  ///
  /// In ja, this message translates to:
  /// **'{count}市区町村で観測'**
  String bosaiMuniObserved(int count);

  /// No description provided for @bosaiWarningStaleAt.
  ///
  /// In ja, this message translates to:
  /// **'最新の情報を取得できませんでした（{time} 時点の情報を表示中）'**
  String bosaiWarningStaleAt(String time);

  /// No description provided for @bosaiWarningAsOf.
  ///
  /// In ja, this message translates to:
  /// **'{time} 時点'**
  String bosaiWarningAsOf(String time);

  /// 出典：気象庁 多言語辞書（熱中症警戒アラート=Heat Stroke Alert）
  ///
  /// In ja, this message translates to:
  /// **'熱中症警戒情報の運用期間外です（毎年4月下旬〜10月下旬に発表されます）'**
  String get bosaiHeatOffSeason;

  /// 出典表記のうしろに続けて置く断片。英語は先頭に半角空白を入れている。hour は0埋め済みの文字列
  ///
  /// In ja, this message translates to:
  /// **'（{month}/{day} {hour}時発表）'**
  String bosaiHeatReportAt(int month, int day, String hour);

  /// No description provided for @bosaiHeatTapHint.
  ///
  /// In ja, this message translates to:
  /// **'タップするとその都道府県のカメラ一覧を表示します。'**
  String get bosaiHeatTapHint;

  /// 出典：気象庁 多言語辞書（Heat Stroke Alert）
  ///
  /// In ja, this message translates to:
  /// **'現在、熱中症警戒情報は発表されていません'**
  String get bosaiHeatNone;

  /// No description provided for @bosaiHeatToday.
  ///
  /// In ja, this message translates to:
  /// **'今日'**
  String get bosaiHeatToday;

  /// No description provided for @bosaiHeatTomorrow.
  ///
  /// In ja, this message translates to:
  /// **'明日'**
  String get bosaiHeatTomorrow;

  /// No description provided for @bosaiHeatPrefCamerasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{pref}のカメラ（熱中症警戒情報）'**
  String bosaiHeatPrefCamerasTitle(String pref);

  /// 出典：気象庁 多言語辞書（暑さ指数=heat index）
  ///
  /// In ja, this message translates to:
  /// **'近くの地点の暑さ指数（WBGT）'**
  String get bosaiWbgtCardTitle;

  /// No description provided for @bosaiWbgtUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'取得できませんでした'**
  String get bosaiWbgtUnavailable;

  /// value は '350m' / '3.2km' のように単位まで含む文字列
  ///
  /// In ja, this message translates to:
  /// **'約{value}'**
  String bosaiApproxDistance(String value);

  /// No description provided for @bosaiWbgtNow.
  ///
  /// In ja, this message translates to:
  /// **'現在'**
  String get bosaiWbgtNow;

  /// No description provided for @bosaiWbgtNoCurrent.
  ///
  /// In ja, this message translates to:
  /// **'実況値なし'**
  String get bosaiWbgtNoCurrent;

  /// No description provided for @bosaiWbgtLevelAt.
  ///
  /// In ja, this message translates to:
  /// **'{level}（{time}）'**
  String bosaiWbgtLevelAt(String level, String time);

  /// No description provided for @bosaiWbgtForecast.
  ///
  /// In ja, this message translates to:
  /// **'予測'**
  String get bosaiWbgtForecast;

  /// No description provided for @bosaiWbgtHour.
  ///
  /// In ja, this message translates to:
  /// **'{hour}時'**
  String bosaiWbgtHour(int hour);

  /// No description provided for @bosaiWbgtNextDayHour.
  ///
  /// In ja, this message translates to:
  /// **'翌{hour}時'**
  String bosaiWbgtNextDayHour(int hour);

  /// No description provided for @bosaiWbgtDateHour.
  ///
  /// In ja, this message translates to:
  /// **'{month}/{day} {hour}時'**
  String bosaiWbgtDateHour(int month, int day, int hour);

  /// 出典表記（気象庁）はどの言語でも省略しない。SPEC C5
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁 地震情報（震度の大きい順）。タップするとその市区町村のカメラ一覧を表示します。カメラがない市区町村は震源周辺のカメラを表示します。'**
  String get bosaiQuakeMuniNote;

  /// 出典：気象庁 多言語辞書（震源=Hypocenter）
  ///
  /// In ja, this message translates to:
  /// **'震源周辺のカメラ（距離順）'**
  String get bosaiEpicenterNearby;

  /// 市区町村名が引けなかったときのコード表記
  ///
  /// In ja, this message translates to:
  /// **'市区町村 {code}'**
  String bosaiMuniCodeFallback(String code);

  /// No description provided for @bosaiPrefEpicenterFallback.
  ///
  /// In ja, this message translates to:
  /// **'{pref}・震源周辺のカメラを表示します'**
  String bosaiPrefEpicenterFallback(String pref);

  /// No description provided for @bosaiMuniIntensityCamerasTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}のカメラ（震度{intensity}）'**
  String bosaiMuniIntensityCamerasTitle(String name, String intensity);

  /// No description provided for @bosaiLiveOnly.
  ///
  /// In ja, this message translates to:
  /// **'LIVEのみ（{count}）'**
  String bosaiLiveOnly(int count);

  /// No description provided for @bosaiMuniFallbackNote.
  ///
  /// In ja, this message translates to:
  /// **'この市区町村に対応するカメラがないため、都道府県内の全カメラを表示しています'**
  String get bosaiMuniFallbackNote;

  /// No description provided for @bosaiPrefNoCameras.
  ///
  /// In ja, this message translates to:
  /// **'この都道府県のカメラがありません'**
  String get bosaiPrefNoCameras;

  /// No description provided for @bosaiNoLiveCameras.
  ///
  /// In ja, this message translates to:
  /// **'LIVE配信のカメラがありません'**
  String get bosaiNoLiveCameras;

  /// No description provided for @bosaiNoCamerasWithin50km.
  ///
  /// In ja, this message translates to:
  /// **'50km以内にカメラがありません'**
  String get bosaiNoCamerasWithin50km;

  /// ADAPT 応援画面のAppBarタイトル
  ///
  /// In ja, this message translates to:
  /// **'開発者を応援'**
  String get tipTitle;

  /// ADAPT 応援画面の説明文
  ///
  /// In ja, this message translates to:
  /// **'このアプリは個人で開発・運営しています。カメラの調査・追加や監視サーバーの維持、気象データの対応など、継続的なアップデートの励みになります。支援は任意で、機能の違いはありません。'**
  String get tipIntro;

  /// ADAPT 投げ銭の段階名（COFFEE）
  ///
  /// In ja, this message translates to:
  /// **'缶コーヒーでひと息'**
  String get tipCoffeeTitle;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'開発の合間に飲む缶コーヒー代をプレゼント'**
  String get tipCoffeeSubtitle;

  /// ADAPT 投げ銭の段階名（SWEETS）
  ///
  /// In ja, this message translates to:
  /// **'スイーツで糖分補給'**
  String get tipSweetsTitle;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'集中コーディング用の甘いお菓子＆カフェ代を支援'**
  String get tipSweetsSubtitle;

  /// ADAPT 投げ銭の段階名（LUNCH）
  ///
  /// In ja, this message translates to:
  /// **'ランチで開発ブースト'**
  String get tipLunchTitle;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'次の新機能開発に向けた栄養満点ランチをごちそう'**
  String get tipLunchSubtitle;

  /// ADAPT 投げ銭の段階名（DEV TOOLS）
  ///
  /// In ja, this message translates to:
  /// **'開発ツール費を応援'**
  String get tipDevToolsTitle;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'カメラ調査やサーバー監視に使うサービス費を支援'**
  String get tipDevToolsSubtitle;

  /// ADAPT アプリ内課金の商品が取得できないとき
  ///
  /// In ja, this message translates to:
  /// **'支援メニューは準備中です。しばらくしてからお試しください。'**
  String get tipPreparing;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'このデバイスではアプリ内課金を利用できません。'**
  String get tipUnavailable;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'購入を開始できませんでした'**
  String get tipPurchaseStartFailed;

  /// ADAPT 購入完了時のメッセージ
  ///
  /// In ja, this message translates to:
  /// **'ご支援ありがとうございます！開発の励みになります。'**
  String get tipThanks;

  /// ADAPT {error} はストアが返すエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'購入を完了できませんでした（{error}）'**
  String tipPurchaseFailed(String error);

  /// ADAPT tipPurchaseFailed の {error} が空のときの代替文言
  ///
  /// In ja, this message translates to:
  /// **'不明なエラー'**
  String get tipUnknownError;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'購入前にご確認ください'**
  String get tipNoticeTitle;

  /// ADAPT
  ///
  /// In ja, this message translates to:
  /// **'支援はApp Storeのアプリ内課金で処理されます（返金はAppleの規定に従います）。'**
  String get tipNoticeBody;

  /// ADAPT Apple標準EULAへのリンクのラベル
  ///
  /// In ja, this message translates to:
  /// **'EULA（Apple標準使用許諾契約）'**
  String get tipEula;

  /// ADAPT クラッシュ診断ダイアログ。{name} は診断JSONのファイル名
  ///
  /// In ja, this message translates to:
  /// **'記録: {count}件\n最新: {name}'**
  String settingsDiagCrashRecords(int count, String name);

  /// ADAPT MetricKit の crashDiagnostics
  ///
  /// In ja, this message translates to:
  /// **'クラッシュ'**
  String get settingsDiagKindCrash;

  /// ADAPT MetricKit の hangDiagnostics
  ///
  /// In ja, this message translates to:
  /// **'ハング'**
  String get settingsDiagKindHang;

  /// ADAPT MetricKit の cpuExceptionDiagnostics
  ///
  /// In ja, this message translates to:
  /// **'CPU異常'**
  String get settingsDiagKindCpu;

  /// ADAPT MetricKit の diskWriteExceptionDiagnostics
  ///
  /// In ja, this message translates to:
  /// **'ディスク書込異常'**
  String get settingsDiagKindDiskWrite;

  /// ADAPT {kinds} は settingsDiagKind* を区切り文字で連結した文字列
  ///
  /// In ja, this message translates to:
  /// **'種別: {kinds}'**
  String settingsDiagCrashKinds(String kinds);

  /// ADAPT 診断ファイルの読み取りに失敗したとき
  ///
  /// In ja, this message translates to:
  /// **'読み取りエラー: {error}'**
  String settingsDiagReadError(String error);

  /// ADAPT 通知診断で通知許可・トークンが取得できなかったとき
  ///
  /// In ja, this message translates to:
  /// **'取得失敗'**
  String get settingsDiagFetchFailed;

  /// ADAPT トークンが null のとき
  ///
  /// In ja, this message translates to:
  /// **'未取得(null)'**
  String get settingsDiagNotAcquired;

  /// ADAPT {prefix} はAPNsトークンの先頭8文字
  ///
  /// In ja, this message translates to:
  /// **'取得済み({prefix}…)'**
  String settingsDiagAcquired(String prefix);

  /// ADAPT 通知診断でトークン取得が例外になったとき
  ///
  /// In ja, this message translates to:
  /// **'エラー: {error}'**
  String settingsDiagError(String error);

  /// 防災備蓄チェックリスト画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'防災の備え'**
  String get stockpileTitle;

  /// 設定画面の入口の項目名
  ///
  /// In ja, this message translates to:
  /// **'防災の備え（備蓄チェックリスト）'**
  String get stockpileEntryTitle;

  /// 設定画面の入口の説明
  ///
  /// In ja, this message translates to:
  /// **'家族の人数から必要量を計算してチェックできます'**
  String get stockpileEntrySubtitle;

  /// 災害速報タブ 気象警報タブ最下部の控えめな導線
  ///
  /// In ja, this message translates to:
  /// **'備蓄は足りていますか？ チェックリストを開く'**
  String get stockpileBosaiLink;

  /// 世帯人数カードの見出し
  ///
  /// In ja, this message translates to:
  /// **'世帯の人数'**
  String get stockpileHouseholdTitle;

  /// 世帯人数（大人）
  ///
  /// In ja, this message translates to:
  /// **'大人'**
  String get stockpileAdults;

  /// 世帯人数（子ども）
  ///
  /// In ja, this message translates to:
  /// **'子ども'**
  String get stockpileChildren;

  /// 備蓄日数の選択
  ///
  /// In ja, this message translates to:
  /// **'備蓄する日数'**
  String get stockpileDaysLabel;

  /// 備蓄日数の選択肢（3日分・7日分）
  ///
  /// In ja, this message translates to:
  /// **'{days}日分'**
  String stockpileDaysValue(int days);

  /// 必要量サマリーの見出し
  ///
  /// In ja, this message translates to:
  /// **'必要量のめやす'**
  String get stockpileSummaryTitle;

  /// 必要な水の量（L）
  ///
  /// In ja, this message translates to:
  /// **'水 {liters}L'**
  String stockpileSummaryWater(int liters);

  /// 必要な食事の回数
  ///
  /// In ja, this message translates to:
  /// **'食料 {meals}食'**
  String stockpileSummaryMeals(int meals);

  /// 必要量の根拠（内閣府・農林水産省の目安）
  ///
  /// In ja, this message translates to:
  /// **'内閣府・農林水産省の目安（1人1日あたり 水3L・3食）にもとづく試算です'**
  String get stockpileSummaryNote;

  /// 出典リンク（農林水産省 家庭備蓄ポータル）
  ///
  /// In ja, this message translates to:
  /// **'農林水産省「家庭備蓄ポータル」'**
  String get stockpileSourceMaff;

  /// 出典リンク（内閣府 防災情報のページ）
  ///
  /// In ja, this message translates to:
  /// **'内閣府「防災情報のページ」'**
  String get stockpileSourceCao;

  /// チェック済み件数
  ///
  /// In ja, this message translates to:
  /// **'{done}/{total} 完了'**
  String stockpileProgress(int done, int total);

  /// 必要量（数量＋単位）
  ///
  /// In ja, this message translates to:
  /// **'必要 {quantity}{unit}'**
  String stockpileRequired(String quantity, String unit);

  /// アフィリエイト検索ボタン
  ///
  /// In ja, this message translates to:
  /// **'探す'**
  String get stockpileSearchButton;

  /// 期限を登録するボタン
  ///
  /// In ja, this message translates to:
  /// **'期限を登録'**
  String get stockpileExpirySet;

  /// 登録済みの期限（日付はYYYY-MM-DD）
  ///
  /// In ja, this message translates to:
  /// **'期限 {date}'**
  String stockpileExpiryOn(String date);

  /// 期限まで1か月以内
  ///
  /// In ja, this message translates to:
  /// **'まもなく期限'**
  String get stockpileExpirySoon;

  /// 期限切れ
  ///
  /// In ja, this message translates to:
  /// **'期限切れ'**
  String get stockpileExpired;

  /// 登録した期限を消す
  ///
  /// In ja, this message translates to:
  /// **'期限を消す'**
  String get stockpileExpiryClear;

  /// 項目の追加
  ///
  /// In ja, this message translates to:
  /// **'項目を追加'**
  String get stockpileAddItem;

  /// 追加ダイアログの品名欄
  ///
  /// In ja, this message translates to:
  /// **'品名'**
  String get stockpileItemNameLabel;

  /// 追加ダイアログの必要数欄
  ///
  /// In ja, this message translates to:
  /// **'必要数'**
  String get stockpileItemQuantityLabel;

  /// 追加ダイアログのカテゴリ欄
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get stockpileItemCategoryLabel;

  /// 項目の削除
  ///
  /// In ja, this message translates to:
  /// **'項目を削除'**
  String get stockpileDeleteItem;

  /// 品目シートのチェック項目（準備できたか）
  ///
  /// In ja, this message translates to:
  /// **'準備できた'**
  String get stockpileMarkPrepared;

  /// 品目シートの期限の見出し
  ///
  /// In ja, this message translates to:
  /// **'消費期限'**
  String get stockpileSectionExpiry;

  /// 一覧の上に出す操作の案内
  ///
  /// In ja, this message translates to:
  /// **'項目をタップすると期限の登録・選び方・購入先を表示します'**
  String get stockpileItemTapHint;

  /// 定番商品のメーカー公式ページへの副リンク
  ///
  /// In ja, this message translates to:
  /// **'公式サイト'**
  String get stockpileOfficialSite;

  /// 世帯人数（乳幼児。ミルク・おむつの計算に使う）
  ///
  /// In ja, this message translates to:
  /// **'乳幼児（ミルク・おむつ）'**
  String get stockpileInfants;

  /// 同じ日に複数の品目の期限が近づいたときの通知本文
  ///
  /// In ja, this message translates to:
  /// **'{names} の期限が近づいています（{date}）'**
  String stockpileNotifyExpiryBodyMany(String names, String date);

  /// 通知本文で品目名を省略したときの「ほかN件」
  ///
  /// In ja, this message translates to:
  /// **'ほか{count}件'**
  String stockpileNotifyMoreItems(int count);

  /// 通知本文で品目名をつなぐ区切り
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get stockpileNotifyNameSeparator;

  /// 削除したときのメッセージ
  ///
  /// In ja, this message translates to:
  /// **'「{item}」を削除しました'**
  String stockpileDeleted(String item);

  /// 削除の取り消し
  ///
  /// In ja, this message translates to:
  /// **'元に戻す'**
  String get stockpileUndo;

  /// チェックリストを初期状態に戻す
  ///
  /// In ja, this message translates to:
  /// **'初期状態に戻す'**
  String get stockpileReset;

  /// 初期化の確認
  ///
  /// In ja, this message translates to:
  /// **'チェック・期限・追加した項目をすべて消して、最初の状態に戻します。よろしいですか？'**
  String get stockpileResetConfirm;

  /// リマインド設定の見出し
  ///
  /// In ja, this message translates to:
  /// **'リマインド'**
  String get stockpileSectionReminder;

  /// 期限リマインドのスイッチ
  ///
  /// In ja, this message translates to:
  /// **'期限の1か月前に知らせる'**
  String get stockpileExpiryReminder;

  /// 期限リマインドの説明
  ///
  /// In ja, this message translates to:
  /// **'登録した期限の1か月前の午前9時に、この端末で通知します'**
  String get stockpileExpiryReminderSubtitle;

  /// 点検日リマインドのスイッチ
  ///
  /// In ja, this message translates to:
  /// **'点検日に知らせる'**
  String get stockpileInspectionReminder;

  /// 点検日リマインドの説明（3/11・9/1）
  ///
  /// In ja, this message translates to:
  /// **'3月11日と9月1日（防災の日）の午前9時に通知します'**
  String get stockpileInspectionReminderSubtitle;

  /// 通知が許可されなかったとき
  ///
  /// In ja, this message translates to:
  /// **'端末の通知が許可されていません。設定アプリから通知を許可してください'**
  String get stockpileNotifyDenied;

  /// ローカル通知のタイトル
  ///
  /// In ja, this message translates to:
  /// **'防災備蓄の点検'**
  String get stockpileNotifyTitle;

  /// 期限リマインドの本文
  ///
  /// In ja, this message translates to:
  /// **'「{item}」の期限が近づいています（{date}）'**
  String stockpileNotifyExpiryBody(String item, String date);

  /// 点検日リマインドの本文
  ///
  /// In ja, this message translates to:
  /// **'備蓄品の期限と数量を点検しましょう'**
  String get stockpileNotifyInspectionBody;

  /// 商品シートの見出し（公的資料にもとづく選び方）
  ///
  /// In ja, this message translates to:
  /// **'選び方のポイント'**
  String get stockpileGuideWhy;

  /// 商品シートの見出し（メーカー公式ページの一覧）
  ///
  /// In ja, this message translates to:
  /// **'参考になる製品'**
  String get stockpileGuideProducts;

  /// 商品リンクの但し書き（価格・在庫は載せていない旨）
  ///
  /// In ja, this message translates to:
  /// **'商品名で提携ショップを検索します（行末の ↗ はメーカー公式ページ）。販売状況・価格は各ショップでご確認ください。'**
  String get stockpileGuideProductsNote;

  /// 商品シートの見出し（提携ショップ検索）
  ///
  /// In ja, this message translates to:
  /// **'商品を探す'**
  String get stockpileGuideSearch;

  /// 提携ショップの検索ボタン。{shop}は店舗名（固有名詞なので翻訳しない）
  ///
  /// In ja, this message translates to:
  /// **'{shop}で探す'**
  String stockpileGuideSearchAt(String shop);

  /// 商品シートの見出し（出典リンク）
  ///
  /// In ja, this message translates to:
  /// **'出典'**
  String get stockpileGuideSources;

  /// 必要量は参考値である旨
  ///
  /// In ja, this message translates to:
  /// **'必要量は公的機関の目安にもとづく参考値です。ご家庭の事情に合わせて調整してください'**
  String get stockpileDisclaimer;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'水・食料'**
  String get stockpileCatWaterFood;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'明かり・電源'**
  String get stockpileCatLightPower;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'衛生'**
  String get stockpileCatSanitation;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'救急・衛生用品'**
  String get stockpileCatFirstAid;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'避難用'**
  String get stockpileCatEvacuation;

  /// カテゴリ名
  ///
  /// In ja, this message translates to:
  /// **'貴重品・情報'**
  String get stockpileCatValuables;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'L'**
  String get stockpileUnitLiter;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'食'**
  String get stockpileUnitMeal;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'個'**
  String get stockpileUnitPiece;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'枚'**
  String get stockpileUnitSheet;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'ロール'**
  String get stockpileUnitRoll;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'双'**
  String get stockpileUnitPair;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'パック'**
  String get stockpileUnitPack;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'回分'**
  String get stockpileUnitTimes;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'日分'**
  String get stockpileUnitDays;

  /// 単位
  ///
  /// In ja, this message translates to:
  /// **'式'**
  String get stockpileUnitSet;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'保存水'**
  String get stockpileItemWater;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'非常食（主食）'**
  String get stockpileItemStapleFood;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'レトルト食品'**
  String get stockpileItemRetortFood;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'缶詰'**
  String get stockpileItemCannedFood;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'粉ミルク・液体ミルク'**
  String get stockpileItemBabyFormula;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'懐中電灯'**
  String get stockpileItemFlashlight;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'乾電池'**
  String get stockpileItemBatteries;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'モバイルバッテリー'**
  String get stockpileItemPowerBank;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'携帯ラジオ'**
  String get stockpileItemRadio;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'簡易トイレ'**
  String get stockpileItemPortableToilet;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'トイレットペーパー'**
  String get stockpileItemToiletPaper;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'ウェットティッシュ'**
  String get stockpileItemWetWipes;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'ゴミ袋'**
  String get stockpileItemGarbageBags;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'おむつ'**
  String get stockpileItemDiapers;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'救急セット'**
  String get stockpileItemFirstAidKit;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'常備薬'**
  String get stockpileItemMedicine;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'マスク'**
  String get stockpileItemMask;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'消毒液'**
  String get stockpileItemDisinfectant;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'防災リュック'**
  String get stockpileItemBackpack;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'アルミブランケット'**
  String get stockpileItemBlanket;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'軍手'**
  String get stockpileItemGloves;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'ロープ'**
  String get stockpileItemRope;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'現金（小銭を含む）'**
  String get stockpileItemCash;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'身分証のコピー'**
  String get stockpileItemIdCopy;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'連絡先メモ'**
  String get stockpileItemContactMemo;

  /// 備蓄品の名称
  ///
  /// In ja, this message translates to:
  /// **'充電ケーブル'**
  String get stockpileItemCable;

  /// 「探す」を押したときの店舗選択シートの見出し
  ///
  /// In ja, this message translates to:
  /// **'店舗を選ぶ'**
  String get stockpileChooseShop;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'ja':
      {
        switch (locale.scriptCode) {
          case 'Hira':
            return AppLocalizationsJaHira();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
