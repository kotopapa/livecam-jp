import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'北海道'**
  String get pref01;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'青森'**
  String get pref02;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'岩手'**
  String get pref03;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'宮城'**
  String get pref04;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'秋田'**
  String get pref05;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'山形'**
  String get pref06;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'福島'**
  String get pref07;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'茨城'**
  String get pref08;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'栃木'**
  String get pref09;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'群馬'**
  String get pref10;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'埼玉'**
  String get pref11;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'千葉'**
  String get pref12;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'東京'**
  String get pref13;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'神奈川'**
  String get pref14;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'新潟'**
  String get pref15;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'富山'**
  String get pref16;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'石川'**
  String get pref17;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'福井'**
  String get pref18;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'山梨'**
  String get pref19;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'長野'**
  String get pref20;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'岐阜'**
  String get pref21;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'静岡'**
  String get pref22;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'愛知'**
  String get pref23;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'三重'**
  String get pref24;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'滋賀'**
  String get pref25;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'京都'**
  String get pref26;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'大阪'**
  String get pref27;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'兵庫'**
  String get pref28;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'奈良'**
  String get pref29;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'和歌山'**
  String get pref30;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'鳥取'**
  String get pref31;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'島根'**
  String get pref32;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'岡山'**
  String get pref33;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'広島'**
  String get pref34;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'山口'**
  String get pref35;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'徳島'**
  String get pref36;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'香川'**
  String get pref37;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'愛媛'**
  String get pref38;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'高知'**
  String get pref39;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'福岡'**
  String get pref40;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'佐賀'**
  String get pref41;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'長崎'**
  String get pref42;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'熊本'**
  String get pref43;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'大分'**
  String get pref44;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'宮崎'**
  String get pref45;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'鹿児島'**
  String get pref46;

  /// 都道府県名。英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの。出典：気象庁
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

  /// No description provided for @settingsFollowX.
  ///
  /// In ja, this message translates to:
  /// **'Xでフォローする'**
  String get settingsFollowX;

  /// No description provided for @settingsFollowXSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'@kotopapa8 — 新しいカメラや機能のお知らせ'**
  String get settingsFollowXSubtitle;

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
  /// **'お気に入り登録数'**
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

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'5弱'**
  String get intensity5Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'5強'**
  String get intensity5Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'6弱'**
  String get intensity6Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'6強'**
  String get intensity6Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'震度5弱以上'**
  String get quakeLevel5Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'震度5強以上'**
  String get quakeLevel5Upper;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'震度6弱以上'**
  String get quakeLevel6Lower;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'暴風雪警報'**
  String get warning02;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雨警報'**
  String get warning03;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'洪水警報'**
  String get warning04;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'暴風警報'**
  String get warning05;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雪警報'**
  String get warning06;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'波浪警報'**
  String get warning07;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'高潮警報'**
  String get warning08;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'土砂災害警報'**
  String get warning09;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'大雨危険警報'**
  String get warning43;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'洪水危険警報'**
  String get warning44;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'高潮危険警報'**
  String get warning48;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'土砂災害危険警報'**
  String get warning49;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'暴風雪特別警報'**
  String get warning32;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雨特別警報'**
  String get warning33;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'洪水特別警報'**
  String get warning34;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'暴風特別警報'**
  String get warning35;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雪特別警報'**
  String get warning36;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'波浪特別警報'**
  String get warning37;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'高潮特別警報'**
  String get warning38;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
  ///
  /// In ja, this message translates to:
  /// **'土砂災害特別警報'**
  String get warning39;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雨注意報'**
  String get advisory10;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'大雪注意報'**
  String get advisory12;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'風雪注意報'**
  String get advisory13;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'雷注意報'**
  String get advisory14;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'強風注意報'**
  String get advisory15;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'波浪注意報'**
  String get advisory16;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'融雪注意報'**
  String get advisory17;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'洪水注意報'**
  String get advisory18;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'高潮注意報'**
  String get advisory19;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'濃霧注意報'**
  String get advisory20;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'乾燥注意報'**
  String get advisory21;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'なだれ注意報'**
  String get advisory22;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'低温注意報'**
  String get advisory23;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'霜注意報'**
  String get advisory24;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'着氷注意報'**
  String get advisory25;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) の公式対訳。出典：気象庁。自由訳しないこと
  ///
  /// In ja, this message translates to:
  /// **'着雪注意報'**
  String get advisory26;

  /// 気象庁「気象情報等に関する多言語辞書」(2026-03-26版) を語順のみ既存訳に合わせて調整。出典：気象庁
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
      <String>['en', 'ja'].contains(locale.languageCode);

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
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
