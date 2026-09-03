// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '全国ライブカメラ地図';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonOk => '決定';

  @override
  String get commonNext => '次へ';

  @override
  String get commonSkip => 'スキップ';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonShare => '共有';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonOpenInSafari => 'Safariで開く';

  @override
  String get commonSource => '出典';

  @override
  String commonCameraCount(int count) {
    return '$count台';
  }

  @override
  String get legalJapaneseAuthoritative => 'この日本語版を正文とします。翻訳は参考です。';

  @override
  String get languageLabel => '言語';

  @override
  String get languageSettingTitle => '言語 / Language';

  @override
  String get languageNameJa => '日本語';

  @override
  String get languageNameJaHira => 'やさしい日本語';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => '端末の設定に合わせる';

  @override
  String get languageChooseTitle => '言語を選ぶ';

  @override
  String get tabMap => '地図';

  @override
  String get tabList => '一覧';

  @override
  String get tabBosai => '災害速報';

  @override
  String get tabFavorites => 'お気に入り';

  @override
  String get tabStockpile => '備え';

  @override
  String get tabSettings => '設定';

  @override
  String get onboardingTitle1 => '地図からすぐに探せる';

  @override
  String get onboardingBody1 =>
      '全国1万台以上のライブカメラを地図に表示。河川・道路・海岸などカテゴリ別に色分けされています。';

  @override
  String get onboardingTitle2 => '映らないカメラは自動で非表示';

  @override
  String get onboardingBody2 => '定期的に自動確認し、取得できないカメラは地図から外れます。取得時刻を必ず表示します。';

  @override
  String get onboardingTitle3 => '出典・ライセンスを明示';

  @override
  String get onboardingBody3 => 'すべての映像は提供元の明示とともに表示します。映像の権利は各提供元に帰属します。';

  @override
  String get onboardingNotifyOptIn => '災害通知を受け取る';

  @override
  String get onboardingNotifyOptInDetail =>
      '震度5弱以上の地震と特別警報（全国）をお知らせします。あとから設定で変更できます。';

  @override
  String get onboardingDisclaimerTitle => 'ご利用前の大切なお願い';

  @override
  String get onboardingAgreeAndStart => '同意してはじめる';

  @override
  String get disclaimerText =>
      'カメラ映像は限られた範囲の状況を示すものです。カメラの性能上、光環境や気象条件により不鮮明になる場合があります。避難の判断は、水位情報・気象警報・自治体の避難情報に従ってください。本アプリは参考情報を提供するものです。';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String get updateRequiredBody =>
      'このバージョンはサポートが終了しました。\nApp Storeから最新版に更新してください。';

  @override
  String get updateOpenStore => 'App Storeを開く';

  @override
  String get categoryRiver => '河川';

  @override
  String get categoryRoad => '道路';

  @override
  String get categoryVolcano => '火山';

  @override
  String get categoryDam => 'ダム';

  @override
  String get categoryCoast => '海岸';

  @override
  String get categoryPort => '港湾';

  @override
  String get categoryScenic => '景観';

  @override
  String get categoryHealing => '癒し';

  @override
  String get categoryOther => 'その他';

  @override
  String get pref01 => '北海道';

  @override
  String get pref02 => '青森';

  @override
  String get pref03 => '岩手';

  @override
  String get pref04 => '宮城';

  @override
  String get pref05 => '秋田';

  @override
  String get pref06 => '山形';

  @override
  String get pref07 => '福島';

  @override
  String get pref08 => '茨城';

  @override
  String get pref09 => '栃木';

  @override
  String get pref10 => '群馬';

  @override
  String get pref11 => '埼玉';

  @override
  String get pref12 => '千葉';

  @override
  String get pref13 => '東京';

  @override
  String get pref14 => '神奈川';

  @override
  String get pref15 => '新潟';

  @override
  String get pref16 => '富山';

  @override
  String get pref17 => '石川';

  @override
  String get pref18 => '福井';

  @override
  String get pref19 => '山梨';

  @override
  String get pref20 => '長野';

  @override
  String get pref21 => '岐阜';

  @override
  String get pref22 => '静岡';

  @override
  String get pref23 => '愛知';

  @override
  String get pref24 => '三重';

  @override
  String get pref25 => '滋賀';

  @override
  String get pref26 => '京都';

  @override
  String get pref27 => '大阪';

  @override
  String get pref28 => '兵庫';

  @override
  String get pref29 => '奈良';

  @override
  String get pref30 => '和歌山';

  @override
  String get pref31 => '鳥取';

  @override
  String get pref32 => '島根';

  @override
  String get pref33 => '岡山';

  @override
  String get pref34 => '広島';

  @override
  String get pref35 => '山口';

  @override
  String get pref36 => '徳島';

  @override
  String get pref37 => '香川';

  @override
  String get pref38 => '愛媛';

  @override
  String get pref39 => '高知';

  @override
  String get pref40 => '福岡';

  @override
  String get pref41 => '佐賀';

  @override
  String get pref42 => '長崎';

  @override
  String get pref43 => '熊本';

  @override
  String get pref44 => '大分';

  @override
  String get pref45 => '宮崎';

  @override
  String get pref46 => '鹿児島';

  @override
  String get pref47 => '沖縄';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSupportTitle => '開発者を応援する';

  @override
  String get settingsSupportBody => '缶コーヒー1本(¥200)から。個人開発の継続を支えてください';

  @override
  String get settingsSupportButton => '応援';

  @override
  String get settingsSectionNotify => '災害通知';

  @override
  String get settingsQuakeTitle => '震度5弱以上の地震';

  @override
  String get settingsQuakeSubtitleOff => '大きな地震の発生を通知し、周辺カメラへ誘導します';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return '通知レベル: $level';
  }

  @override
  String get settingsWarningTitle => '特別警報';

  @override
  String get settingsWarningSubtitle => '大雨・暴風・高潮などの特別警報の発表を通知します';

  @override
  String get settingsNotifyArea => '通知する地域';

  @override
  String get settingsNotifyAreaAll => '全国';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first など$count件';
  }

  @override
  String get settingsNotifyAreaHint =>
      '選択した都道府県の特別警報のみ通知します。何も選ばない場合は全国が対象になります';

  @override
  String get settingsNotifyAreaResetAll => '全国に戻す';

  @override
  String get settingsNotifyLevel => '通知するレベル';

  @override
  String get settingsNotifyLevelSpecialOnly => '特別警報のみ（レベル5）';

  @override
  String get settingsNotifyLevelDangerUp => '危険警報から（レベル4以上）';

  @override
  String get settingsNotifyLevelNote => '危険警報は大雨・洪水・高潮・土砂災害の警戒レベル4相当の発表です';

  @override
  String get settingsNotifyDelayNote =>
      '※通知は気象庁の発表から5〜15分程度遅れることがあります。緊急地震速報の代わりにはなりません';

  @override
  String get settingsNotifyDenied => '通知が許可されていません。iOSの設定アプリから通知を許可してください';

  @override
  String get settingsSectionData => 'データ取得';

  @override
  String get settingsWifiOnly => 'Wi-Fi接続時のみ画像を取得';

  @override
  String get settingsWifiOnlySubtitle => 'モバイル通信量を抑えます（地図とカメラ一覧は表示されます）';

  @override
  String get settingsClearCache => 'キャッシュを削除';

  @override
  String get settingsClearCacheSubtitle => 'カメラ一覧などの保存データを消去して再取得します';

  @override
  String get settingsClearCacheDone => 'キャッシュを削除して再取得しました';

  @override
  String get settingsSectionFilterDefaults => 'フィルタの初期設定';

  @override
  String get settingsShowWorld => '世界のカメラを表示';

  @override
  String get settingsVideoOnly => '動画カメラのみ';

  @override
  String get settingsHideUncertain => '位置が曖昧なカメラを非表示';

  @override
  String get settingsHideUncertainSubtitle => '黄色い縁取りのピン（おおよそ/代表点）を隠します';

  @override
  String get settingsFilterDefaultsNote =>
      'ここで設定した内容は次回起動時の初期状態になります（地図の凡例からも一時的に変更できます）';

  @override
  String get settingsSectionRequest => 'カメラの追加・削除のご依頼';

  @override
  String get settingsRequestForm => 'ご相談・依頼フォーム';

  @override
  String get settingsRequestFormSubtitle =>
      'カメラの追加要請・掲載削除の依頼はこちらから（ログイン不要）。設置者・運営者の方からの削除のお申し出には速やかに対応します';

  @override
  String get settingsSectionLicense => '出典・ライセンス';

  @override
  String get settingsAttributionList => '出典・ライセンス一覧';

  @override
  String get settingsAttributionListSubtitle => 'カメラ映像の提供元の一覧';

  @override
  String get settingsTerms => '利用規約';

  @override
  String get settingsPrivacy => 'プライバシーポリシー';

  @override
  String get settingsLegalJapaneseOnly =>
      '利用規約・プライバシーポリシーの本文は日本語のみです（日本語を正文とします）';

  @override
  String get settingsSectionAbout => 'このアプリについて';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsInvite => '友達を招待する';

  @override
  String get settingsInviteSubtitle => 'QRコードまたはリンクでApp Storeのページを共有';

  @override
  String get settingsInviteDialogBody =>
      'QRコードを読み取るか、リンクを送ると\nApp Storeのアプリページが開きます';

  @override
  String get settingsInviteShareText => '全国ライブカメラ地図 - 河川・道路・防災';

  @override
  String get settingsLinkCopied => 'リンクをコピーしました';

  @override
  String get settingsReview => 'アプリを評価する';

  @override
  String get settingsReviewSubtitle => 'App Storeでレビューを書く';

  @override
  String get settingsFollowX => 'Xでフォローする';

  @override
  String get settingsFollowXSubtitle => '@kotopapa8 — 新しいカメラや機能のお知らせ';

  @override
  String get settingsOtherApps => '開発者の他のアプリ';

  @override
  String get settingsShowMoreApps => 'その他のアプリを見る';

  @override
  String get settingsSectionDisclaimer => '免責';

  @override
  String get settingsOssLicenses => 'OSSライセンス';

  @override
  String get settingsNotifyDiag => '通知診断';

  @override
  String get settingsNotifyDiagSubtitle => '通知が届かないときの状態確認';

  @override
  String get settingsNotifyDiagUnlocked => '通知診断を表示しました（災害通知の項目内）';

  @override
  String settingsNotifyPermission(String value) {
    return '通知許可: $value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'APNsトークン: $value';
  }

  @override
  String get settingsNotifyFcm => 'FCMトークン:';

  @override
  String get settingsCopyToken => 'トークンをコピー';

  @override
  String get settingsTokenCopied => 'FCMトークンをコピーしました';

  @override
  String get settingsCrashDiag => 'クラッシュ診断データ';

  @override
  String get settingsCrashDiagSubtitle => '強制終了の記録(MetricKit)を表示・コピー';

  @override
  String get settingsCrashDiagNone => '診断データはまだありません';

  @override
  String get settingsCrashDiagNoneHint =>
      '診断データはまだありません。\nクラッシュ後にアプリを起動し直すと記録されます';

  @override
  String get settingsCopyFullText => '全文をコピー';

  @override
  String get settingsJsonCopied => '診断JSONをコピーしました';

  @override
  String get attributionScreenTitle => '出典・ライセンス一覧';

  @override
  String get attributionOpenYoutube => 'YouTubeで配信元を見る';

  @override
  String get attributionOpenSite => '提供元のサイトを開く';

  @override
  String listTitle(int count) {
    return '一覧（$count）';
  }

  @override
  String get listSearchHint => 'カメラ名・河川名・路線名で検索';

  @override
  String get listEmpty => '条件に合うカメラがありません';

  @override
  String get listRanking => 'ランキング';

  @override
  String favoritesTitle(int count) {
    return 'お気に入り（$count）';
  }

  @override
  String get favoritesEmpty => 'お気に入りはまだありません。\n地図でカメラを開いて★を押すと追加されます。';

  @override
  String get favoritesEmptyFiltered => '絞り込み条件に合うお気に入りがありません';

  @override
  String get favoritesSort => '並べ替え';

  @override
  String get favoritesSortNewest => '登録が新しい順';

  @override
  String get favoritesSortOldest => '登録が古い順';

  @override
  String get favoritesSortName => '名前順';

  @override
  String get favoritesSortCategory => 'カテゴリ順';

  @override
  String get favoritesToggleView => '表示切替';

  @override
  String get favoritesRefreshAll => '一括更新（3件ずつ順次取得）';

  @override
  String get favoritesVideoOnly => '動画のみ';

  @override
  String get rankingTitle => '全国ランキング';

  @override
  String get rankingModeNow => 'いま見られている（24時間 TOP10）';

  @override
  String get rankingModeWeek => 'よく見られている（7日間 TOP30）';

  @override
  String get rankingModeFavorites => 'お気に入り登録（TOP20）';

  @override
  String get rankingNote => '全ユーザーの匿名統計に基づくランキングです（毎日更新）';

  @override
  String get rankingEmpty => 'まだ集計データがありません（毎日1回更新されます）';

  @override
  String get rankingPreparing => '全国ランキングは準備中です。\n集計は3時間おきに行われます。';

  @override
  String get rankingFetchFailed => '取得に失敗しました';

  @override
  String rankingFetchFailedHttp(int code) {
    return '取得に失敗しました (HTTP $code)';
  }

  @override
  String get rankingUnitViews => '回';

  @override
  String get rankingUnitFavorites => '件';

  @override
  String get detailLive => 'ライブ配信中';

  @override
  String get detailTimeUnknown => '取得時刻不明';

  @override
  String detailRefreshEvery(int sec) {
    return '$sec秒ごとに更新';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$sec秒';
  }

  @override
  String get detailRefreshNow => '更新';

  @override
  String get detailPosRepresentative => '位置は広域の代表点';

  @override
  String get detailPosApprox => '位置はおおよそ';

  @override
  String get detailNotUpdating => '画像が更新されていません';

  @override
  String get detailWorld => '海外';

  @override
  String get detailCategoryAndPlace => 'カテゴリ・位置';

  @override
  String get detailOpenMap => '地図で見る';

  @override
  String get detailHotelsTitle => 'この付近の宿を探す';

  @override
  String get detailOpenSourceSite => '出典サイトを見る';

  @override
  String get detailOpenYoutube => 'YouTubeで見る';

  @override
  String get detailOpenChannel => 'チャンネルページを見る';

  @override
  String get detailOpenOriginalPage => '元ページで見る';

  @override
  String get detailReportProblem => 'このカメラの不具合を報告';

  @override
  String get detailNearby => '周辺のカメラ';

  @override
  String detailDistanceKm(String km) {
    return '約${km}km';
  }

  @override
  String get detailWifiOnlyBlocked => '設定により、画像の取得はWi-Fi接続時のみです';

  @override
  String get detailNoImage => '現在映像を取得できません';

  @override
  String get detailEmbedBlockedYoutube => '提供者の設定により、この映像は\nアプリ内で再生できません';

  @override
  String get detailEmbedBlockedPage => '配信元の利用条件により\nアプリ内では表示できません';

  @override
  String get detailIHighwayTitle => 'NEXCO公式「iHighway」で\nライブカメラを表示';

  @override
  String get detailIHighwayBody =>
      'タップするとアプリ内ブラウザで公式サイトを開き、\nこのカメラの位置まで自動で移動します';

  @override
  String get detailIHighwayHost => 'ihighway.jp（NEXCO公式）';

  @override
  String get detailMapTileGsi => '地理院タイル';

  @override
  String get elevationLoading => '標高 …';

  @override
  String elevationValue(String value, String source) {
    return '標高 $value（$source）';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return '$time 取得$relative';
  }

  @override
  String get timeRelJustNow => '（たった今）';

  @override
  String timeRelMinutes(int n) {
    return '（$n分前）';
  }

  @override
  String timeRelHours(int n) {
    return '（$n時間前）';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get intensity5Lower => '5弱';

  @override
  String get intensity5Upper => '5強';

  @override
  String get intensity6Lower => '6弱';

  @override
  String get intensity6Upper => '6強';

  @override
  String get quakeLevel5Lower => '震度5弱以上';

  @override
  String get quakeLevel5Upper => '震度5強以上';

  @override
  String get quakeLevel6Lower => '震度6弱以上';

  @override
  String get warning02 => '暴風雪警報';

  @override
  String get warning03 => '大雨警報';

  @override
  String get warning04 => '洪水警報';

  @override
  String get warning05 => '暴風警報';

  @override
  String get warning06 => '大雪警報';

  @override
  String get warning07 => '波浪警報';

  @override
  String get warning08 => '高潮警報';

  @override
  String get warning09 => '土砂災害警報';

  @override
  String get warning43 => '大雨危険警報';

  @override
  String get warning44 => '洪水危険警報';

  @override
  String get warning48 => '高潮危険警報';

  @override
  String get warning49 => '土砂災害危険警報';

  @override
  String get warning32 => '暴風雪特別警報';

  @override
  String get warning33 => '大雨特別警報';

  @override
  String get warning34 => '洪水特別警報';

  @override
  String get warning35 => '暴風特別警報';

  @override
  String get warning36 => '大雪特別警報';

  @override
  String get warning37 => '波浪特別警報';

  @override
  String get warning38 => '高潮特別警報';

  @override
  String get warning39 => '土砂災害特別警報';

  @override
  String get advisory10 => '大雨注意報';

  @override
  String get advisory12 => '大雪注意報';

  @override
  String get advisory13 => '風雪注意報';

  @override
  String get advisory14 => '雷注意報';

  @override
  String get advisory15 => '強風注意報';

  @override
  String get advisory16 => '波浪注意報';

  @override
  String get advisory17 => '融雪注意報';

  @override
  String get advisory18 => '洪水注意報';

  @override
  String get advisory19 => '高潮注意報';

  @override
  String get advisory20 => '濃霧注意報';

  @override
  String get advisory21 => '乾燥注意報';

  @override
  String get advisory22 => 'なだれ注意報';

  @override
  String get advisory23 => '低温注意報';

  @override
  String get advisory24 => '霜注意報';

  @override
  String get advisory25 => '着氷注意報';

  @override
  String get advisory26 => '着雪注意報';

  @override
  String get advisory29 => '土砂災害注意報';

  @override
  String get mapLocationDenied => '位置情報の利用が許可されていません（設定から変更できます）';

  @override
  String get mapLocationFailed => '現在地を取得できませんでした';

  @override
  String get mapLegendTitle => '凡例・絞り込み';

  @override
  String get mapLegendSearchHint => 'カメラ名・運営者・河川/路線名で検索';

  @override
  String get mapFilterFavoritesOnly => 'お気に入りのみ';

  @override
  String get mapFilterOkOnly => '現在映っているもののみ';

  @override
  String get mapLegendLiveDot => '赤ドット = 動画（ライブ配信）';

  @override
  String get mapLegendUncertain => '黄色の縁 = 位置未確定（おおよそ/代表点）';

  @override
  String get mapLegendFrozen => '半透明 = 画像が長時間更新されていない';

  @override
  String get mapLegendFavorite => '金の星 = お気に入り登録済み';

  @override
  String get mapLegendCluster => '数字の丸 = 周辺カメラのまとまり（タップでズーム）';

  @override
  String get mapSearchTitle => '場所を検索';

  @override
  String get mapSearchHint => '地名・住所（例: 渋谷、金沢市広坂）';

  @override
  String get mapSearchNotFound => '見つかりませんでした。地名・住所・カメラ名でお試しください';

  @override
  String get mapSearchSectionCameras => 'カメラ';

  @override
  String get mapSearchSectionPlaces => '場所';

  @override
  String mapPointCameras(int count) {
    return 'この地点のカメラ（$count台）';
  }

  @override
  String mapFilteredCount(int count) {
    return '絞り込み中 $count台';
  }

  @override
  String mapTotalCount(int count) {
    return '$count台';
  }

  @override
  String get mapLayersTooltip => '地図レイヤー';

  @override
  String get bosaiTitle => '災害速報';

  @override
  String get bosaiTabQuake => '地震・津波';

  @override
  String get bosaiTabWarning => '気象警報';

  @override
  String get bosaiTabHeat => '熱中症';

  @override
  String get bosaiNoWarnings => '現在、発表中の警報・注意報はありません';

  @override
  String get bosaiWarningNoteNone =>
      '出典：気象庁。現在、警報・特別警報の発表はありません。注意報のみの地域は下の一覧から確認できます。';

  @override
  String get bosaiWarningNote => '出典：気象庁 気象警報・注意報。タップするとその都道府県のカメラ一覧を表示します。';

  @override
  String bosaiAdvisoryRegions(int count) {
    return '注意報が発表中の地域（$count都道府県）';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return '$prefの警報発表地域';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return '$prefの注意報発表地域';
  }

  @override
  String get bosaiMuniNote => '出典：気象庁。タップするとその市区町村のカメラ一覧を表示します';

  @override
  String get bosaiMuniFetchFailed => '発表エリアの詳細を取得できませんでした';

  @override
  String get bosaiMuniNone => '現在、発表中の市区町村はありません';

  @override
  String bosaiCameraCount(int count) {
    return 'カメラ$count台';
  }

  @override
  String get bosaiNoCamera => 'カメラなし';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return '$nameのカメラ（警報発表中）';
  }

  @override
  String get settingsJmaDictionary => '防災用語の翻訳について';

  @override
  String get settingsJmaDictionaryNote =>
      '警報名・注意報名・震度などの各言語訳は、気象庁「気象情報等に関する多言語辞書」に準拠しています。出典：気象庁ホームページ';

  @override
  String get hazardFloodTitle => '洪水浸水想定区域（想定最大規模）';

  @override
  String get hazardLandslideTitle => '土砂災害警戒区域';

  @override
  String get hazardTsunamiTitle => '津波浸水想定';

  @override
  String get hazardHightideTitle => '高潮浸水想定区域';

  @override
  String get hazardLandslideSteepSlope => '急傾斜地';

  @override
  String get hazardLandslideDebrisFlow => '土石流';

  @override
  String get hazardLandslideSlide => '地すべり';

  @override
  String get hazardDisclaimer =>
      '最新かつ詳細な情報は各市町村のハザードマップをご確認ください。避難判断は自治体の避難情報に従ってください';

  @override
  String get facilityKindWater => '給水拠点・応急給水施設';

  @override
  String get facilityKindStock => '防災備蓄倉庫';

  @override
  String get facilityKindFireWater => '消防水利（消火栓・防火水槽）';

  @override
  String get facilityKindWaterShort => '給水拠点';

  @override
  String get facilityKindStockShort => '防災備蓄倉庫';

  @override
  String get facilityKindFireWaterShort => '消防水利';

  @override
  String get facilityDisclaimer => '公開している自治体のみ。最新の情報は各自治体にご確認ください';

  @override
  String get facilityNoData => 'この地域のデータはまだありません';

  @override
  String get shelterHazardFlood => '洪水';

  @override
  String get shelterHazardSediment => '土砂';

  @override
  String get shelterHazardHightide => '高潮';

  @override
  String get shelterHazardEarthquake => '地震';

  @override
  String get shelterHazardTsunami => '津波';

  @override
  String get shelterHazardFire => '火事';

  @override
  String get shelterHazardInlandFlood => '内水';

  @override
  String get shelterHazardVolcano => '火山';

  @override
  String get shelterDisclaimer => '最新かつ詳細な状況は各市町村にご確認ください';

  @override
  String get riskLandTitle => '土砂キキクル';

  @override
  String get riskInundTitle => '浸水キキクル';

  @override
  String get riskFloodTitle => '洪水キキクル';

  @override
  String get riskLandSubtitle => '土砂災害の危険度（1kmメッシュ・10分ごとに更新）';

  @override
  String get riskInundSubtitle => '浸水害の危険度（1kmメッシュ・10分ごとに更新）';

  @override
  String get riskFloodSubtitle => '洪水災害の危険度（河川ごと・10分ごとに更新）';

  @override
  String get riskLevelWatch => '留意';

  @override
  String get riskLevelCaution => '注意';

  @override
  String get riskLevelWarning => '警戒';

  @override
  String get riskLevelDanger => '危険';

  @override
  String get riskLevelCritical => '切迫';

  @override
  String get wbgtLevelDanger => '危険';

  @override
  String get wbgtLevelSevereWarning => '厳重警戒';

  @override
  String get wbgtLevelWarning => '警戒';

  @override
  String get wbgtLevelCaution => '注意';

  @override
  String get wbgtLevelSafe => 'ほぼ安全';

  @override
  String get heatAlertSpecial => '熱中症特別警戒';

  @override
  String get heatAlertSpecialPending => '熱中症特別警戒（判定）';

  @override
  String get heatAlertWarning => '熱中症警戒';

  @override
  String get heatAlertDisclaimer => '本情報は参考情報です。正式発表は熱中症予防情報サイト等をご確認ください';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어';

  @override
  String get languageNameVi => 'Tiếng Việt';

  @override
  String get mapLayerPanelSubtitle => '地図に1種類だけ重ねて表示します';

  @override
  String get mapLayerNone => '表示しない';

  @override
  String get mapLayerSectionWeather => '気象';

  @override
  String get mapLayerRainRadarTitle => '雨雲レーダー（現在）';

  @override
  String get mapLayerRainRadarSubtitle => '高解像度降水ナウキャスト・5分ごとに更新';

  @override
  String get mapLayerQuakesTitle => '震源';

  @override
  String get mapQuakePeriodDay => '24時間';

  @override
  String get mapQuakePeriodWeek => '7日';

  @override
  String get mapQuakePeriodMonth => '30日';

  @override
  String get mapLayerRain24hTitle => '24時間降水量';

  @override
  String get mapLayerRain24hSubtitle => '気象庁の解析雨量（面）＋拡大でアメダス観測値';

  @override
  String get mapLayerSectionHazard => 'ハザードマップ';

  @override
  String get mapHazardLandslideSubtitle => '急傾斜地・土石流・地すべり（黄=警戒区域 / 赤=特別警戒区域）';

  @override
  String get mapHazardDepthSubtitle => '想定される浸水深を色分け表示';

  @override
  String get mapShelterTitle => '避難場所';

  @override
  String get mapLayerShelterTitle => '避難場所（指定緊急避難場所・指定避難所）';

  @override
  String get mapLayerShelterSubtitle => '拡大すると表示。災害種別で絞り込みできます';

  @override
  String get mapFacilityTitle => '防災拠点';

  @override
  String get mapLayerFacilityTitle => '防災拠点（給水拠点・防災備蓄倉庫）';

  @override
  String get mapLayerFacilitySubtitle => '拡大すると表示。種別で絞り込みできます';

  @override
  String mapQuakeNearbyTitle(int count) {
    return 'この付近の地震 $count件';
  }

  @override
  String get mapQuakeUnknownPlace => '震源（詳細未発表）';

  @override
  String mapQuakeMaxIntensity(String value) {
    return '最大震度$value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return '$name 周辺のカメラ';
  }

  @override
  String get mapQuakeTapHint => 'タップで周辺のライブカメラ（50km以内）を表示';

  @override
  String get mapShelterNoticeTitle => '避難場所レイヤーについて';

  @override
  String get mapShelterNoticeBody =>
      '・「指定緊急避難場所」は災害の危険から命を守るために逃げ込む場所、「指定避難所」は一定期間滞在する施設です（二重枠で表示）\n・指定緊急避難場所は災害種別ごとに指定されており、災害の種類によっては避難できない場合があります\n・市町村から提供された情報のため、最新でない場合や掲載されていない場所があります。正確な情報は当該市町村にご確認ください';

  @override
  String get mapShelterHazardAll => 'すべて';

  @override
  String get mapShelterDesignated => '指定避難所';

  @override
  String get mapShelterHazardsLabel => '対応する災害種別';

  @override
  String get mapOpenRoute => 'Googleマップで経路を見る';

  @override
  String get mapNearbyCamerasButton => '周辺のライブカメラ';

  @override
  String get mapFacilityNoticeTitle => '防災拠点レイヤーについて';

  @override
  String get mapFacilityNoticeBody =>
      '・各自治体がオープンデータとして公開している「応急給水施設」「備蓄倉庫」「消防水利施設」の一覧を集めたものです。公開している自治体のみで、全国は網羅していません\n・消火栓・防火水槽は消防活動用の設備で、一般の方が使用するものではありません\n・給水拠点は災害時に開設されるもので、平常時に給水を受けられるとは限りません\n・更新時期は自治体ごとに異なります。正確な情報は各自治体にご確認ください';

  @override
  String mapFacilityOwner(String owner) {
    return '提供：$owner';
  }

  @override
  String get mapFacilityGeocodedNote => '住所から推定した位置です（実際の場所とずれる場合があります）';

  @override
  String get mapFacilitySourceDataset => '出典（データセット）';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value時間';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value分';
  }

  @override
  String get mapNowcastNow => '現在（実況）';

  @override
  String get mapNowcastForecastHourly => '予報・1時間雨量';

  @override
  String get mapNowcastForecast => '予測';

  @override
  String mapNowcastAfter(String span, String kind) {
    return '$span後（$kind）';
  }

  @override
  String mapNowcastBefore(String span) {
    return '$span前（実況）';
  }

  @override
  String get mapNowcastBackToNow => '現在へ';

  @override
  String get mapNowcastNowMarker => '▲ 現在';

  @override
  String mapNowcastLast(String label) {
    return '$label（6時間先）';
  }

  @override
  String mapLegendRainRadar(String label) {
    return '雨雲レーダー $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return '雨雲レーダー $label（$kind）';
  }

  @override
  String get mapLegendRainWeak => '弱';

  @override
  String mapLegendQuakes(String period, int count) {
    return '震源 $period（$count件）';
  }

  @override
  String mapLegendIntensity(String value) {
    return '震度$value';
  }

  @override
  String get mapLegendIntensity6Up => '6弱〜';

  @override
  String mapLegendRain24h(String label) {
    return '24時間降水量 $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return '24時間降水量 $label（拡大で観測値）';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title（警戒 / 特別警戒）';
  }

  @override
  String get mapLegendShelterZoomIn => '避難場所（拡大すると避難場所を表示）';

  @override
  String mapLegendShelter(int count) {
    return '避難場所（$count件）';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return '避難場所（$count件・まとめ表示）';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return '避難場所・$hazard（$count件）';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return '避難場所・$hazard（$count件・まとめ表示）';
  }

  @override
  String get mapLegendShelterEmergency => '指定緊急避難場所';

  @override
  String get mapLegendShelterDesignated => '二重枠=指定避難所';

  @override
  String get mapLegendFacilityZoomIn => '防災拠点（拡大すると防災拠点を表示）';

  @override
  String mapLegendFacilityNoData(String message) {
    return '防災拠点（$message）';
  }

  @override
  String mapLegendFacility(int count) {
    return '防災拠点（$count件）';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return '防災拠点（$count件・まとめ表示）';
  }

  @override
  String get mapLegendFetchFailed => '取得できません';

  @override
  String get mapShelterFetchFailed => '避難場所を取得できませんでした（タップで再試行）';

  @override
  String get mapFacilityFetchFailed => '防災拠点を取得できませんでした（タップで再試行）';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24時間 ${mm}mm';
  }

  @override
  String get bosaiFetchFailedPull => '取得に失敗しました（引き下げてやり直せます）';

  @override
  String get bosaiTsunamiInfo => '津波情報';

  @override
  String get bosaiUnknownPlace => '不明';

  @override
  String bosaiFetchFailedDetail(String error) {
    return '取得に失敗しました（$error）';
  }

  @override
  String get bosaiTimeJustNow => 'たった今';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$n分前';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$n時間前';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return '$month月$day日 $hour時頃';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return '$placeの震度';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return '$place周辺のカメラ';
  }

  @override
  String get bosaiQuakeEmpty => '直近72時間の地震情報はありません';

  @override
  String bosaiQuakeAsOf(String time) {
    return '（$time時点・新しい順）';
  }

  @override
  String bosaiQuakeNote(String at) {
    return '出典：気象庁 地震情報（直近72時間）$at。タップすると揺れた市区町村のライブカメラ一覧（市区町村別震度が無い場合は震源周辺）を表示します。';
  }

  @override
  String get bosaiBadgeTsunami => '津波';

  @override
  String bosaiBadgeIntensity(String value) {
    return '震度\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return '$count市区町村で観測';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return '最新の情報を取得できませんでした（$time 時点の情報を表示中）';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return '$time 時点';
  }

  @override
  String get bosaiHeatOffSeason => '熱中症警戒情報の運用期間外です（毎年4月下旬〜10月下旬に発表されます）';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return '（$month/$day $hour時発表）';
  }

  @override
  String get bosaiHeatTapHint => 'タップするとその都道府県のカメラ一覧を表示します。';

  @override
  String get bosaiHeatNone => '現在、熱中症警戒情報は発表されていません';

  @override
  String get bosaiHeatToday => '今日';

  @override
  String get bosaiHeatTomorrow => '明日';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return '$prefのカメラ（熱中症警戒情報）';
  }

  @override
  String get bosaiWbgtCardTitle => '近くの地点の暑さ指数（WBGT）';

  @override
  String get bosaiWbgtUnavailable => '取得できませんでした';

  @override
  String bosaiApproxDistance(String value) {
    return '約$value';
  }

  @override
  String get bosaiWbgtNow => '現在';

  @override
  String get bosaiWbgtNoCurrent => '実況値なし';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level（$time）';
  }

  @override
  String get bosaiWbgtForecast => '予測';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hour時';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return '翌$hour時';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$month/$day $hour時';
  }

  @override
  String get bosaiQuakeMuniNote =>
      '出典：気象庁 地震情報（震度の大きい順）。タップするとその市区町村のカメラ一覧を表示します。カメラがない市区町村は震源周辺のカメラを表示します。';

  @override
  String get bosaiEpicenterNearby => '震源周辺のカメラ（距離順）';

  @override
  String bosaiMuniCodeFallback(String code) {
    return '市区町村 $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref・震源周辺のカメラを表示します';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return '$nameのカメラ（震度$intensity）';
  }

  @override
  String bosaiLiveOnly(int count) {
    return 'LIVEのみ（$count）';
  }

  @override
  String get bosaiMuniFallbackNote => 'この市区町村に対応するカメラがないため、都道府県内の全カメラを表示しています';

  @override
  String get bosaiPrefNoCameras => 'この都道府県のカメラがありません';

  @override
  String get bosaiNoLiveCameras => 'LIVE配信のカメラがありません';

  @override
  String get bosaiNoCamerasWithin50km => '50km以内にカメラがありません';

  @override
  String get tipTitle => '開発者を応援';

  @override
  String get tipIntro =>
      'このアプリは個人で開発・運営しています。カメラの調査・追加や監視サーバーの維持、気象データの対応など、継続的なアップデートの励みになります。支援は任意で、機能の違いはありません。';

  @override
  String get tipCoffeeTitle => '缶コーヒーでひと息';

  @override
  String get tipCoffeeSubtitle => '開発の合間に飲む缶コーヒー代をプレゼント';

  @override
  String get tipSweetsTitle => 'スイーツで糖分補給';

  @override
  String get tipSweetsSubtitle => '集中コーディング用の甘いお菓子＆カフェ代を支援';

  @override
  String get tipLunchTitle => 'ランチで開発ブースト';

  @override
  String get tipLunchSubtitle => '次の新機能開発に向けた栄養満点ランチをごちそう';

  @override
  String get tipDevToolsTitle => '開発ツール費を応援';

  @override
  String get tipDevToolsSubtitle => 'カメラ調査やサーバー監視に使うサービス費を支援';

  @override
  String get tipPreparing => '支援メニューは準備中です。しばらくしてからお試しください。';

  @override
  String get tipUnavailable => 'このデバイスではアプリ内課金を利用できません。';

  @override
  String get tipPurchaseStartFailed => '購入を開始できませんでした';

  @override
  String get tipThanks => 'ご支援ありがとうございます！開発の励みになります。';

  @override
  String tipPurchaseFailed(String error) {
    return '購入を完了できませんでした（$error）';
  }

  @override
  String get tipUnknownError => '不明なエラー';

  @override
  String get tipNoticeTitle => '購入前にご確認ください';

  @override
  String get tipNoticeBody => '支援はApp Storeのアプリ内課金で処理されます（返金はAppleの規定に従います）。';

  @override
  String get tipEula => 'EULA（Apple標準使用許諾契約）';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return '記録: $count件\n最新: $name';
  }

  @override
  String get settingsDiagKindCrash => 'クラッシュ';

  @override
  String get settingsDiagKindHang => 'ハング';

  @override
  String get settingsDiagKindCpu => 'CPU異常';

  @override
  String get settingsDiagKindDiskWrite => 'ディスク書込異常';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return '種別: $kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return '読み取りエラー: $error';
  }

  @override
  String get settingsDiagFetchFailed => '取得失敗';

  @override
  String get settingsDiagNotAcquired => '未取得(null)';

  @override
  String settingsDiagAcquired(String prefix) {
    return '取得済み($prefix…)';
  }

  @override
  String settingsDiagError(String error) {
    return 'エラー: $error';
  }

  @override
  String get stockpileTitle => '防災の備え';

  @override
  String get stockpileEntryTitle => '防災の備え（備蓄チェックリスト）';

  @override
  String get stockpileEntrySubtitle => '家族の人数から必要量を計算してチェックできます';

  @override
  String get stockpileBosaiLink => '備蓄は足りていますか？ チェックリストを開く';

  @override
  String get stockpileHouseholdTitle => '世帯の人数';

  @override
  String get stockpileAdults => '大人';

  @override
  String get stockpileChildren => '子ども';

  @override
  String get stockpileDaysLabel => '備蓄する日数';

  @override
  String stockpileDaysValue(int days) {
    return '$days日分';
  }

  @override
  String get stockpileSummaryTitle => '必要量のめやす';

  @override
  String stockpileSummaryWater(int liters) {
    return '水 ${liters}L';
  }

  @override
  String stockpileSummaryMeals(int meals) {
    return '食料 $meals食';
  }

  @override
  String get stockpileSummaryNote => '内閣府・農林水産省の目安（1人1日あたり 水3L・3食）にもとづく試算です';

  @override
  String get stockpileSourceMaff => '農林水産省「家庭備蓄ポータル」';

  @override
  String get stockpileSourceCao => '内閣府「防災情報のページ」';

  @override
  String stockpileProgress(int done, int total) {
    return '$done/$total 完了';
  }

  @override
  String stockpileRequired(String quantity, String unit) {
    return '必要 $quantity$unit';
  }

  @override
  String get stockpileSearchButton => '探す';

  @override
  String get stockpileExpirySet => '期限を登録';

  @override
  String stockpileExpiryOn(String date) {
    return '期限 $date';
  }

  @override
  String get stockpileExpirySoon => 'まもなく期限';

  @override
  String get stockpileExpired => '期限切れ';

  @override
  String get stockpileExpiryClear => '期限を消す';

  @override
  String get stockpileAddItem => '項目を追加';

  @override
  String get stockpileItemNameLabel => '品名';

  @override
  String get stockpileItemQuantityLabel => '必要数';

  @override
  String get stockpileItemCategoryLabel => 'カテゴリ';

  @override
  String get stockpileDeleteItem => '項目を削除';

  @override
  String get stockpileMarkPrepared => '準備できた';

  @override
  String get stockpileSectionExpiry => '消費期限';

  @override
  String get stockpileItemTapHint => '項目をタップすると期限の登録・選び方・購入先を表示します';

  @override
  String get stockpileOfficialSite => '公式サイト';

  @override
  String get stockpileInfants => '乳幼児（ミルク・おむつ）';

  @override
  String stockpileNotifyExpiryBodyMany(String names, String date) {
    return '$names の期限が近づいています（$date）';
  }

  @override
  String stockpileNotifyMoreItems(int count) {
    return 'ほか$count件';
  }

  @override
  String get stockpileNotifyNameSeparator => '・';

  @override
  String stockpileDeleted(String item) {
    return '「$item」を削除しました';
  }

  @override
  String get stockpileUndo => '元に戻す';

  @override
  String get stockpileReset => '初期状態に戻す';

  @override
  String get stockpileResetConfirm =>
      'チェック・期限・追加した項目をすべて消して、最初の状態に戻します。よろしいですか？';

  @override
  String get stockpileSectionReminder => 'リマインド';

  @override
  String get stockpileExpiryReminder => '期限の1か月前に知らせる';

  @override
  String get stockpileExpiryReminderSubtitle => '登録した期限の1か月前の午前9時に、この端末で通知します';

  @override
  String get stockpileInspectionReminder => '点検日に知らせる';

  @override
  String get stockpileInspectionReminderSubtitle =>
      '3月11日と9月1日（防災の日）の午前9時に通知します';

  @override
  String get stockpileNotifyDenied => '端末の通知が許可されていません。設定アプリから通知を許可してください';

  @override
  String get stockpileNotifyTitle => '防災備蓄の点検';

  @override
  String stockpileNotifyExpiryBody(String item, String date) {
    return '「$item」の期限が近づいています（$date）';
  }

  @override
  String get stockpileNotifyInspectionBody => '備蓄品の期限と数量を点検しましょう';

  @override
  String get stockpileGuideWhy => '選び方のポイント';

  @override
  String get stockpileGuideProducts => '参考になる製品';

  @override
  String get stockpileGuideProductsNote =>
      '商品名で提携ショップを検索します（行末の ↗ はメーカー公式ページ）。販売状況・価格は各ショップでご確認ください。';

  @override
  String get stockpileGuideSearch => '商品を探す';

  @override
  String stockpileGuideSearchAt(String shop) {
    return '$shopで探す';
  }

  @override
  String get stockpileGuideSources => '出典';

  @override
  String get stockpileDisclaimer => '必要量は公的機関の目安にもとづく参考値です。ご家庭の事情に合わせて調整してください';

  @override
  String get stockpileCatWaterFood => '水・食料';

  @override
  String get stockpileCatLightPower => '明かり・電源';

  @override
  String get stockpileCatSanitation => '衛生';

  @override
  String get stockpileCatFirstAid => '救急・衛生用品';

  @override
  String get stockpileCatEvacuation => '避難用';

  @override
  String get stockpileCatValuables => '貴重品・情報';

  @override
  String get stockpileUnitLiter => 'L';

  @override
  String get stockpileUnitMeal => '食';

  @override
  String get stockpileUnitPiece => '個';

  @override
  String get stockpileUnitSheet => '枚';

  @override
  String get stockpileUnitRoll => 'ロール';

  @override
  String get stockpileUnitPair => '双';

  @override
  String get stockpileUnitPack => 'パック';

  @override
  String get stockpileUnitTimes => '回分';

  @override
  String get stockpileUnitDays => '日分';

  @override
  String get stockpileUnitSet => '式';

  @override
  String get stockpileItemWater => '保存水';

  @override
  String get stockpileItemStapleFood => '非常食（主食）';

  @override
  String get stockpileItemRetortFood => 'レトルト食品';

  @override
  String get stockpileItemCannedFood => '缶詰';

  @override
  String get stockpileItemBabyFormula => '粉ミルク・液体ミルク';

  @override
  String get stockpileItemFlashlight => '懐中電灯';

  @override
  String get stockpileItemBatteries => '乾電池';

  @override
  String get stockpileItemPowerBank => 'モバイルバッテリー';

  @override
  String get stockpileItemRadio => '携帯ラジオ';

  @override
  String get stockpileItemPortableToilet => '簡易トイレ';

  @override
  String get stockpileItemToiletPaper => 'トイレットペーパー';

  @override
  String get stockpileItemWetWipes => 'ウェットティッシュ';

  @override
  String get stockpileItemGarbageBags => 'ゴミ袋';

  @override
  String get stockpileItemDiapers => 'おむつ';

  @override
  String get stockpileItemFirstAidKit => '救急セット';

  @override
  String get stockpileItemMedicine => '常備薬';

  @override
  String get stockpileItemMask => 'マスク';

  @override
  String get stockpileItemDisinfectant => '消毒液';

  @override
  String get stockpileItemBackpack => '防災リュック';

  @override
  String get stockpileItemBlanket => 'アルミブランケット';

  @override
  String get stockpileItemGloves => '軍手';

  @override
  String get stockpileItemRope => 'ロープ';

  @override
  String get stockpileItemCash => '現金（小銭を含む）';

  @override
  String get stockpileItemIdCopy => '身分証のコピー';

  @override
  String get stockpileItemContactMemo => '連絡先メモ';

  @override
  String get stockpileItemCable => '充電ケーブル';

  @override
  String get stockpileChooseShop => '店舗を選ぶ';
}

/// The translations for Japanese, using the Hiragana script (`ja_Hira`).
class AppLocalizationsJaHira extends AppLocalizationsJa {
  AppLocalizationsJaHira() : super('ja_Hira');

  @override
  String get appTitle => '全国ライブカメラ地図';

  @override
  String get commonClose => 'とじる';

  @override
  String get commonCancel => 'やめる';

  @override
  String get commonOk => 'けってい';

  @override
  String get commonNext => 'つぎへ';

  @override
  String get commonSkip => 'とばす';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonShare => 'ほかの人に おくる';

  @override
  String get commonRetry => 'もう一回 やる';

  @override
  String get commonOpenInSafari => 'Safariで ひらく';

  @override
  String get commonSource => 'じょうほうの もとになった ところ（出典）';

  @override
  String commonCameraCount(int count) {
    return '$countだい';
  }

  @override
  String get legalJapaneseAuthoritative =>
      'この 日本語（にほんご）の 文（ぶん）が 正式（せいしき）です。ほかの ことばは さんこうです。';

  @override
  String get languageLabel => 'ことば';

  @override
  String get languageSettingTitle => 'ことば / Language';

  @override
  String get languageNameJa => '日本語';

  @override
  String get languageNameJaHira => 'やさしい日本語';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => 'スマホの せっていに あわせる';

  @override
  String get languageChooseTitle => 'ことばを えらぶ';

  @override
  String get tabMap => 'ちず';

  @override
  String get tabList => 'いちらん';

  @override
  String get tabBosai => 'さいがいの おしらせ';

  @override
  String get tabFavorites => 'おきにいり';

  @override
  String get tabStockpile => 'そなえ';

  @override
  String get tabSettings => 'せってい';

  @override
  String get onboardingTitle1 => 'ちずから すぐに さがせます';

  @override
  String get onboardingBody1 =>
      '日本ぜんこくの ライブカメラを ちずに ならべます。かわ・どうろ・うみ など しゅるいごとに いろが ちがいます。';

  @override
  String get onboardingTitle2 => 'うつらない カメラは じどうで きえます';

  @override
  String get onboardingBody2 =>
      'アプリが ときどき じどうで しらべます。うつらない カメラは ちずから きえます。えいぞうを とった 時間（じかん）は かならず みせます。';

  @override
  String get onboardingTitle3 => 'だれが だしている えいぞうか わかります';

  @override
  String get onboardingBody3 =>
      'えいぞうは かならず 「だれが だしているか」と いっしょに みせます。えいぞうの けんりは だした ひとの ものです。';

  @override
  String get onboardingNotifyOptIn => 'さいがいの おしらせを うけとる';

  @override
  String get onboardingNotifyOptInDetail =>
      'しんど 5弱（じゃく）いじょうの じしんと とくべつ けいほうを おしらせします。あとで せっていで かえられます。';

  @override
  String get onboardingDisclaimerTitle => 'つかう まえに よんでください';

  @override
  String get onboardingAgreeAndStart => 'わかりました。はじめる';

  @override
  String get disclaimerText =>
      'カメラの えいぞうは せまい ばしょの ようすだけです。くらい ときや 天気（てんき）が わるい ときは よく 見（み）えません。にげるか どうかは、川（かわ）の 水（みず）の たかさ・気象庁（きしょうちょう）の おしらせ・市役所（しやくしょ）の ひなんの おしらせを 見（み）て きめてください。この アプリは さんこうの じょうほうです。';

  @override
  String get updateRequiredTitle => 'あたらしく してください';

  @override
  String get updateRequiredBody =>
      'いまの アプリは もう つかえません。\nApp Storeで あたらしく してください。';

  @override
  String get updateOpenStore => 'App Storeを ひらく';

  @override
  String get categoryRiver => 'かわ（河川）';

  @override
  String get categoryRoad => 'どうろ（道路）';

  @override
  String get categoryVolcano => 'かざん（火山）';

  @override
  String get categoryDam => 'ダム';

  @override
  String get categoryCoast => 'うみ（海岸）';

  @override
  String get categoryPort => 'みなと（港湾）';

  @override
  String get categoryScenic => 'けしき（景観）';

  @override
  String get categoryHealing => 'いやし';

  @override
  String get categoryOther => 'そのほか';

  @override
  String get pref01 => '北海道';

  @override
  String get pref02 => '青森';

  @override
  String get pref03 => '岩手';

  @override
  String get pref04 => '宮城';

  @override
  String get pref05 => '秋田';

  @override
  String get pref06 => '山形';

  @override
  String get pref07 => '福島';

  @override
  String get pref08 => '茨城';

  @override
  String get pref09 => '栃木';

  @override
  String get pref10 => '群馬';

  @override
  String get pref11 => '埼玉';

  @override
  String get pref12 => '千葉';

  @override
  String get pref13 => '東京';

  @override
  String get pref14 => '神奈川';

  @override
  String get pref15 => '新潟';

  @override
  String get pref16 => '富山';

  @override
  String get pref17 => '石川';

  @override
  String get pref18 => '福井';

  @override
  String get pref19 => '山梨';

  @override
  String get pref20 => '長野';

  @override
  String get pref21 => '岐阜';

  @override
  String get pref22 => '静岡';

  @override
  String get pref23 => '愛知';

  @override
  String get pref24 => '三重';

  @override
  String get pref25 => '滋賀';

  @override
  String get pref26 => '京都';

  @override
  String get pref27 => '大阪';

  @override
  String get pref28 => '兵庫';

  @override
  String get pref29 => '奈良';

  @override
  String get pref30 => '和歌山';

  @override
  String get pref31 => '鳥取';

  @override
  String get pref32 => '島根';

  @override
  String get pref33 => '岡山';

  @override
  String get pref34 => '広島';

  @override
  String get pref35 => '山口';

  @override
  String get pref36 => '徳島';

  @override
  String get pref37 => '香川';

  @override
  String get pref38 => '愛媛';

  @override
  String get pref39 => '高知';

  @override
  String get pref40 => '福岡';

  @override
  String get pref41 => '佐賀';

  @override
  String get pref42 => '長崎';

  @override
  String get pref43 => '熊本';

  @override
  String get pref44 => '大分';

  @override
  String get pref45 => '宮崎';

  @override
  String get pref46 => '鹿児島';

  @override
  String get pref47 => '沖縄';

  @override
  String get settingsTitle => 'せってい';

  @override
  String get settingsSupportTitle => 'つくった 人（ひと）を おうえんする';

  @override
  String get settingsSupportBody =>
      'かんコーヒー 1本（200円）から。一人（ひとり）で つくって います。たすけて ください';

  @override
  String get settingsSupportButton => 'おうえん';

  @override
  String get settingsSectionNotify => 'さいがいの おしらせ';

  @override
  String get settingsQuakeTitle => 'しんど 5弱（じゃく）いじょうの じしん';

  @override
  String get settingsQuakeSubtitleOff =>
      '大（おお）きな じしんが あったら おしらせします。ちかくの カメラを 見（み）られます';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return 'おしらせする おおきさ: $level';
  }

  @override
  String get settingsWarningTitle => 'とくべつ けいほう（＝いちばん つよい おしらせ）';

  @override
  String get settingsWarningSubtitle =>
      '大雨（おおあめ）・つよい かぜ・高潮（たかしお）などの とくべつ けいほうが 出（で）たら おしらせします';

  @override
  String get settingsNotifyArea => 'おしらせを うけとる ばしょ';

  @override
  String get settingsNotifyAreaAll => '日本ぜんぶ';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first など$countか しょ';
  }

  @override
  String get settingsNotifyAreaHint =>
      'えらんだ 県（けん）の とくべつ けいほうだけ おしらせします。えらばないと 日本ぜんぶが たいしょうです';

  @override
  String get settingsNotifyAreaResetAll => '日本ぜんぶに もどす';

  @override
  String get settingsNotifyLevel => 'おしらせする つよさ';

  @override
  String get settingsNotifyLevelSpecialOnly => 'とくべつ けいほうだけ（レベル5）';

  @override
  String get settingsNotifyLevelDangerUp => '危険（きけん）けいほうから（レベル4いじょう）';

  @override
  String get settingsNotifyLevelNote =>
      '危険（きけん）けいほうは、大雨（おおあめ）・こうずい・高潮（たかしお）・どしゃくずれの レベル4の おしらせです';

  @override
  String get settingsNotifyDelayNote =>
      '※おしらせは 気象庁（きしょうちょう）の はっぴょうより 5〜15分（ふん）くらい おそく なることが あります。きんきゅう じしん そくほうの かわりには なりません';

  @override
  String get settingsNotifyDenied =>
      'おしらせが きんしに なって います。iOSの せっていで おしらせを ゆるして ください';

  @override
  String get settingsSectionData => 'データの とりこみ';

  @override
  String get settingsWifiOnly => 'Wi-Fiの ときだけ しゃしんを とりこむ';

  @override
  String get settingsWifiOnlySubtitle =>
      'けいたいの つうしんりょうを へらせます（ちずと カメラの いちらんは 見（み）られます）';

  @override
  String get settingsClearCache => 'ほぞんした データを けす';

  @override
  String get settingsClearCacheSubtitle => 'カメラの いちらんなどの ほぞんデータを けして、とりなおします';

  @override
  String get settingsClearCacheDone => 'ほぞんデータを けして、とりなおしました';

  @override
  String get settingsSectionFilterDefaults => 'さいしょの しぼりこみ';

  @override
  String get settingsShowWorld => 'せかいの カメラを 見（み）せる';

  @override
  String get settingsVideoOnly => 'うごく えいぞうだけ';

  @override
  String get settingsHideUncertain => 'ばしょが はっきり しない カメラを かくす';

  @override
  String get settingsHideUncertainSubtitle => 'きいろい わくの ピン（だいたいの ばしょ）を かくします';

  @override
  String get settingsFilterDefaultsNote =>
      'ここで きめた ことは、つぎに アプリを ひらいた ときの さいしょの じょうたいに なります（ちずの はんれいからも かえられます）';

  @override
  String get settingsSectionRequest => 'カメラを ふやす・けす おねがい';

  @override
  String get settingsRequestForm => 'そうだん・おねがいの フォーム';

  @override
  String get settingsRequestFormSubtitle =>
      'カメラを ふやして ほしい とき・けして ほしい ときは ここから（ログインは いりません）。カメラを もって いる 人（ひと）からの 「けして ほしい」には すぐ たいおうします';

  @override
  String get settingsSectionLicense => 'しゅってん・ライセンス';

  @override
  String get settingsAttributionList => 'しゅってん・ライセンスの いちらん';

  @override
  String get settingsAttributionListSubtitle => 'えいぞうを だして いる ところの いちらん';

  @override
  String get settingsTerms => 'つかいかたの きまり（利用規約）';

  @override
  String get settingsPrivacy => 'こじん じょうほうの あつかい（プライバシーポリシー）';

  @override
  String get settingsLegalJapaneseOnly =>
      'つかいかたの きまりと こじん じょうほうの あつかいは 日本語（にほんご）だけです（日本語が 正式（せいしき）です）';

  @override
  String get settingsSectionAbout => 'この アプリに ついて';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsInvite => 'ともだちを さそう';

  @override
  String get settingsInviteSubtitle => 'QRコードか リンクで App Storeの ページを おくる';

  @override
  String get settingsInviteDialogBody =>
      'QRコードを よみとるか、リンクを おくると\nApp Storeの ページが ひらきます';

  @override
  String get settingsInviteShareText => '全国ライブカメラ地図 - かわ・どうろ・ぼうさい';

  @override
  String get settingsLinkCopied => 'リンクを コピーしました';

  @override
  String get settingsReview => 'アプリを ひょうかする';

  @override
  String get settingsReviewSubtitle => 'App Storeに かんそうを かく';

  @override
  String get settingsFollowX => 'Xで フォローする';

  @override
  String get settingsFollowXSubtitle => '@kotopapa8 — あたらしい カメラや アプリの おしらせ';

  @override
  String get settingsOtherApps => 'つくった 人（ひと）の ほかの アプリ';

  @override
  String get settingsShowMoreApps => 'ほかの アプリを 見（み）る';

  @override
  String get settingsSectionDisclaimer => 'きを つけて ほしい こと（免責）';

  @override
  String get settingsOssLicenses => 'OSSライセンス';

  @override
  String get settingsNotifyDiag => 'おしらせの チェック';

  @override
  String get settingsNotifyDiagSubtitle => 'おしらせが こない ときの チェック';

  @override
  String get settingsNotifyDiagUnlocked =>
      'おしらせの チェックを 出（だ）しました（さいがいの おしらせの なかです）';

  @override
  String settingsNotifyPermission(String value) {
    return 'おしらせの きょか: $value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'APNsトークン: $value';
  }

  @override
  String get settingsNotifyFcm => 'FCMトークン:';

  @override
  String get settingsCopyToken => 'トークンを コピー';

  @override
  String get settingsTokenCopied => 'FCMトークンを コピーしました';

  @override
  String get settingsCrashDiag => 'きゅうに とまった ときの きろく';

  @override
  String get settingsCrashDiagSubtitle =>
      'きゅうに とまった ときの きろく（MetricKit）を 見（み）る・コピーする';

  @override
  String get settingsCrashDiagNone => 'きろくは まだ ありません';

  @override
  String get settingsCrashDiagNoneHint =>
      'きろくは まだ ありません。\nとまった あとに アプリを もう一回（いっかい）ひらくと きろくされます';

  @override
  String get settingsCopyFullText => 'ぜんぶ コピー';

  @override
  String get settingsJsonCopied => 'きろくの JSONを コピーしました';

  @override
  String get attributionScreenTitle => 'しゅってん・ライセンスの いちらん';

  @override
  String get attributionOpenYoutube => 'YouTubeで だしもとを 見（み）る';

  @override
  String get attributionOpenSite => 'だしもとの サイトを ひらく';

  @override
  String listTitle(int count) {
    return 'いちらん（$count）';
  }

  @override
  String get listSearchHint => 'カメラの なまえ・かわの なまえ・どうろの なまえで さがす';

  @override
  String get listEmpty => 'じょうけんに あう カメラは ありません';

  @override
  String get listRanking => 'ランキング';

  @override
  String favoritesTitle(int count) {
    return 'おきにいり（$count）';
  }

  @override
  String get favoritesEmpty => 'おきにいりは まだ ありません。\nちずで カメラを ひらいて ★を おすと ふえます。';

  @override
  String get favoritesEmptyFiltered => 'しぼりこみに あう おきにいりは ありません';

  @override
  String get favoritesSort => 'ならびかえ';

  @override
  String get favoritesSortNewest => 'あたらしく いれた じゅん';

  @override
  String get favoritesSortOldest => 'ふるく いれた じゅん';

  @override
  String get favoritesSortName => 'なまえの じゅん';

  @override
  String get favoritesSortCategory => 'しゅるいの じゅん';

  @override
  String get favoritesToggleView => 'みせかたを かえる';

  @override
  String get favoritesRefreshAll => 'まとめて あたらしく する（3つずつ）';

  @override
  String get favoritesVideoOnly => 'うごく えいぞうだけ';

  @override
  String get rankingTitle => 'ぜんこく ランキング';

  @override
  String get rankingModeNow => 'いま よく 見（み）られて いる（24時間 トップ10）';

  @override
  String get rankingModeWeek => 'よく 見（み）られて いる（7日間 トップ30）';

  @override
  String get rankingModeFavorites => 'おきにいり とうろく（TOP20）';

  @override
  String get rankingNote => 'みんなの 名前（なまえ）の ない きろくから つくって います（まいにち あたらしく なります）';

  @override
  String get rankingEmpty => 'まだ データが ありません（1日 1回 あたらしく なります）';

  @override
  String get rankingPreparing => 'ぜんこく ランキングは じゅんびちゅうです。\n3時間ごとに あつめて います。';

  @override
  String get rankingFetchFailed => 'とれませんでした';

  @override
  String rankingFetchFailedHttp(int code) {
    return 'とれませんでした（HTTP $code）';
  }

  @override
  String get rankingUnitViews => 'かい';

  @override
  String get rankingUnitFavorites => 'けん';

  @override
  String get detailLive => 'いま ライブ';

  @override
  String get detailTimeUnknown => 'とった 時間（じかん）が わかりません';

  @override
  String detailRefreshEvery(int sec) {
    return '$secびょうごとに あたらしく なります';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$secびょう';
  }

  @override
  String get detailRefreshNow => 'あたらしく する';

  @override
  String get detailPosRepresentative => 'ばしょは だいたいの ちてん';

  @override
  String get detailPosApprox => 'ばしょは だいたい';

  @override
  String get detailNotUpdating => 'しゃしんが あたらしく なって いません';

  @override
  String get detailWorld => 'がいこく';

  @override
  String get detailCategoryAndPlace => 'しゅるい・ばしょ';

  @override
  String get detailOpenMap => 'ちずで 見（み）る';

  @override
  String get detailHotelsTitle => 'この ちかくの やどを さがす';

  @override
  String get detailOpenSourceSite => 'だしもとの サイトを 見（み）る';

  @override
  String get detailOpenYoutube => 'YouTubeで 見（み）る';

  @override
  String get detailOpenChannel => 'チャンネルの ページを 見（み）る';

  @override
  String get detailOpenOriginalPage => 'もとの ページで 見（み）る';

  @override
  String get detailReportProblem => 'この カメラの ちょうしが わるい ことを しらせる';

  @override
  String get detailNearby => 'ちかくの カメラ';

  @override
  String detailDistanceKm(String km) {
    return 'だいたい ${km}km';
  }

  @override
  String get detailWifiOnlyBlocked => 'せっていで、Wi-Fiの ときだけ しゃしんを とる ように なって います';

  @override
  String get detailNoImage => 'いまは えいぞうを とれません';

  @override
  String get detailEmbedBlockedYoutube =>
      'だしもとの せっていで、この えいぞうは\nアプリの なかでは 見（み）られません';

  @override
  String get detailEmbedBlockedPage => 'だしもとの きまりで\nアプリの なかでは 見（み）られません';

  @override
  String get detailIHighwayTitle => 'NEXCOの こうしき「iHighway」で\nライブカメラを 見（み）る';

  @override
  String get detailIHighwayBody =>
      'おすと アプリの なかで こうしきサイトが ひらいて、\nこの カメラの ばしょまで じどうで うごきます';

  @override
  String get detailIHighwayHost => 'ihighway.jp（NEXCOの こうしき）';

  @override
  String get detailMapTileGsi => '地理院（ちりいん）タイル';

  @override
  String get elevationLoading => 'たかさ …';

  @override
  String elevationValue(String value, String source) {
    return 'たかさ $value（$source）';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return '$time に とりました$relative';
  }

  @override
  String get timeRelJustNow => '（いま）';

  @override
  String timeRelMinutes(int n) {
    return '（$nふん まえ）';
  }

  @override
  String timeRelHours(int n) {
    return '（$nじかん まえ）';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get intensity5Lower => '5弱（じゃく）';

  @override
  String get intensity5Upper => '5強（きょう）';

  @override
  String get intensity6Lower => '6弱（じゃく）';

  @override
  String get intensity6Upper => '6強（きょう）';

  @override
  String get quakeLevel5Lower => 'しんど 5弱（じゃく）いじょう';

  @override
  String get quakeLevel5Upper => 'しんど 5強（きょう）いじょう';

  @override
  String get quakeLevel6Lower => 'しんど 6弱（じゃく）いじょう';

  @override
  String get warning02 => 'ゆきと つよい かぜの けいほう（暴風雪警報）';

  @override
  String get warning03 => '大雨（おおあめ）の けいほう（大雨警報）';

  @override
  String get warning04 => 'こうずいの けいほう（洪水警報）';

  @override
  String get warning05 => 'つよい かぜの けいほう（暴風警報）';

  @override
  String get warning06 => '大雪（おおゆき）の けいほう（大雪警報）';

  @override
  String get warning07 => 'たかい なみの けいほう（波浪警報）';

  @override
  String get warning08 => 'たかしおの けいほう（高潮警報）';

  @override
  String get warning09 => 'どしゃくずれの けいほう（土砂災害警報）';

  @override
  String get warning43 => '大雨（おおあめ）が あぶない（大雨危険警報・レベル4）';

  @override
  String get warning44 => '川（かわ）が あふれる きけんが あります（洪水危険警報・レベル4）';

  @override
  String get warning48 => 'たかしおが あぶない（高潮危険警報・レベル4）';

  @override
  String get warning49 => 'どしゃくずれが あぶない（土砂災害危険警報・レベル4）';

  @override
  String get warning32 => 'ゆきと かぜが とても きけん（暴風雪特別警報・レベル5）';

  @override
  String get warning33 => '大雨（おおあめ）が とても きけん（大雨特別警報・レベル5）';

  @override
  String get warning34 => '川（かわ）が あふれて とても きけん（洪水特別警報・レベル5）';

  @override
  String get warning35 => 'かぜが とても きけん（暴風特別警報・レベル5）';

  @override
  String get warning36 => '大雪（おおゆき）が とても きけん（大雪特別警報・レベル5）';

  @override
  String get warning37 => 'なみが とても たかくて きけん（波浪特別警報・レベル5）';

  @override
  String get warning38 => 'たかしおが とても きけん（高潮特別警報・レベル5）';

  @override
  String get warning39 => 'どしゃくずれが とても きけん（土砂災害特別警報・レベル5）';

  @override
  String get advisory10 => '大雨（おおあめ）に きを つけて（大雨注意報）';

  @override
  String get advisory12 => '大雪（おおゆき）に きを つけて（大雪注意報）';

  @override
  String get advisory13 => 'ゆきと かぜに きを つけて（風雪注意報）';

  @override
  String get advisory14 => 'かみなりに きを つけて（雷注意報）';

  @override
  String get advisory15 => 'つよい かぜに きを つけて（強風注意報）';

  @override
  String get advisory16 => 'たかい なみに きを つけて（波浪注意報）';

  @override
  String get advisory17 => 'ゆきが とけるので きを つけて（融雪注意報）';

  @override
  String get advisory18 => 'こうずいに きを つけて（洪水注意報）';

  @override
  String get advisory19 => 'たかしおに きを つけて（高潮注意報）';

  @override
  String get advisory20 => 'こい きりに きを つけて（濃霧注意報）';

  @override
  String get advisory21 => 'くうきが かわいて います（乾燥注意報）';

  @override
  String get advisory22 => 'なだれに きを つけて（なだれ注意報）';

  @override
  String get advisory23 => 'きおんが ひくいので きを つけて（低温注意報）';

  @override
  String get advisory24 => 'しもに きを つけて（霜注意報）';

  @override
  String get advisory25 => 'こおりが つくので きを つけて（着氷注意報）';

  @override
  String get advisory26 => 'ゆきが つくので きを つけて（着雪注意報）';

  @override
  String get advisory29 => 'どしゃくずれに きを つけて（土砂災害注意報）';

  @override
  String get mapLocationDenied => 'いまの ばしょを つかう ことが きんしに なって います（せっていで かえられます）';

  @override
  String get mapLocationFailed => 'いまの ばしょが わかりませんでした';

  @override
  String get mapLegendTitle => 'はんれい・しぼりこみ';

  @override
  String get mapLegendSearchHint => 'カメラの なまえ・だしもと・かわ／どうろの なまえで さがす';

  @override
  String get mapFilterFavoritesOnly => 'おきにいりだけ';

  @override
  String get mapFilterOkOnly => 'いま うつって いる ものだけ';

  @override
  String get mapLegendLiveDot => 'あかい てん ＝ うごく えいぞう（ライブ）';

  @override
  String get mapLegendUncertain => 'きいろい わく ＝ ばしょが はっきり しない（だいたい）';

  @override
  String get mapLegendFrozen => 'うすい ピン ＝ しゃしんが ながい あいだ あたらしく なって いない';

  @override
  String get mapLegendFavorite => 'きんの ほし ＝ おきにいり';

  @override
  String get mapLegendCluster => 'すうじの まる ＝ ちかくの カメラの まとまり（おすと ズーム）';

  @override
  String get mapSearchTitle => 'ばしょを さがす';

  @override
  String get mapSearchHint => 'ちめい・じゅうしょ（れい: 渋谷、金沢市広坂）';

  @override
  String get mapSearchNotFound => '見（み）つかりませんでした。ちめい・じゅうしょ・カメラの なまえで ためして ください';

  @override
  String get mapSearchSectionCameras => 'カメラ';

  @override
  String get mapSearchSectionPlaces => 'ばしょ';

  @override
  String mapPointCameras(int count) {
    return 'ここの カメラ（$countだい）';
  }

  @override
  String mapFilteredCount(int count) {
    return 'しぼりこみちゅう $countだい';
  }

  @override
  String mapTotalCount(int count) {
    return '$countだい';
  }

  @override
  String get mapLayersTooltip => 'ちずの レイヤー';

  @override
  String get bosaiTitle => 'さいがいの おしらせ';

  @override
  String get bosaiTabQuake => 'じしん・つなみ';

  @override
  String get bosaiTabWarning => 'きしょうの けいほう';

  @override
  String get bosaiTabHeat => 'ねっちゅうしょう';

  @override
  String get bosaiNoWarnings => 'いま、けいほうと ちゅういほうは 出（で）て いません';

  @override
  String get bosaiWarningNoteNone =>
      '出典（しゅってん）：気象庁。いま けいほうは 出（で）て いません。ちゅういほうだけの ばしょは 下（した）の いちらんで 見（み）られます。';

  @override
  String get bosaiWarningNote =>
      '出典（しゅってん）：気象庁。おすと その 県（けん）の カメラの いちらんが 出（で）ます。';

  @override
  String bosaiAdvisoryRegions(int count) {
    return 'ちゅういほうが 出（で）て いる ばしょ（$countの 県（けん）など）';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return '$prefで けいほうが 出（で）て いる ばしょ';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return '$prefで ちゅういほうが 出（で）て いる ばしょ';
  }

  @override
  String get bosaiMuniNote =>
      '出典（しゅってん）：気象庁。おすと その 市（し）・町（まち）の カメラの いちらんが 出（で）ます';

  @override
  String get bosaiMuniFetchFailed => 'くわしい ばしょが とれませんでした';

  @override
  String get bosaiMuniNone => 'いま、出（で）て いる 市（し）・町（まち）は ありません';

  @override
  String bosaiCameraCount(int count) {
    return 'カメラ $countだい';
  }

  @override
  String get bosaiNoCamera => 'カメラは ありません';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return '$nameの カメラ（けいほうが 出（で）て います）';
  }

  @override
  String get settingsJmaDictionary => 'ぼうさいの ことばの ほんやくに ついて';

  @override
  String get settingsJmaDictionaryNote =>
      'けいほうや しんどの ことばの ほんやくは、気象庁（きしょうちょう）の 「多言語辞書（たげんごじしょ）」を つかって います。出典（しゅってん）：気象庁ホームページ';

  @override
  String get hazardFloodTitle => 'こうずいで 水（みず）が くる ところ（いちばん 大（おお）きい ばあい）';

  @override
  String get hazardLandslideTitle => 'どしゃくずれが おきそうな ところ';

  @override
  String get hazardTsunamiTitle => 'つなみで 水（みず）が くる ところ';

  @override
  String get hazardHightideTitle => 'たかしおで 水（みず）が くる ところ';

  @override
  String get hazardLandslideSteepSlope => 'きゅうな がけ';

  @override
  String get hazardLandslideDebrisFlow => 'どせきりゅう（土（つち）と 石（いし）が ながれる）';

  @override
  String get hazardLandslideSlide => 'じすべり（じめんが すべる）';

  @override
  String get hazardDisclaimer =>
      'くわしいことは 住（す）んでいる 市（し）や 町（まち）の ハザードマップを 見（み）て ください。にげるかどうかは 市（し）や 町（まち）の おしらせに したがって ください';

  @override
  String get facilityKindWater => '水（みず）を もらえる ところ';

  @override
  String get facilityKindStock => 'ひじょうようひんの そうこ（防災備蓄倉庫）';

  @override
  String get facilityKindFireWater => 'しょうぼうの 水（みず）（しょうかせん・ぼうかすいそう）';

  @override
  String get facilityKindWaterShort => '水（みず）を もらえる ところ';

  @override
  String get facilityKindStockShort => 'ひじょうようひんの そうこ';

  @override
  String get facilityKindFireWaterShort => 'しょうぼうの 水（みず）';

  @override
  String get facilityDisclaimer =>
      'データを 出（だ）している 市（し）や 町（まち）だけです。あたらしい ことは 市（し）や 町（まち）に きいて ください';

  @override
  String get facilityNoData => 'この ちいきの データは まだ ありません';

  @override
  String get shelterHazardFlood => 'こうずい';

  @override
  String get shelterHazardSediment => 'どしゃくずれ';

  @override
  String get shelterHazardHightide => 'たかしお';

  @override
  String get shelterHazardEarthquake => 'じしん';

  @override
  String get shelterHazardTsunami => 'つなみ';

  @override
  String get shelterHazardFire => 'かじ';

  @override
  String get shelterHazardInlandFlood => 'ないすい（まちの 中（なか）の みずびたし）';

  @override
  String get shelterHazardVolcano => 'かざん';

  @override
  String get shelterDisclaimer => 'くわしいことは 市（し）や 町（まち）に きいて ください';

  @override
  String get riskLandTitle => 'どしゃくずれの きけんど（キキクル）';

  @override
  String get riskInundTitle => 'みずびたしの きけんど（キキクル）';

  @override
  String get riskFloodTitle => 'こうずいの きけんど（キキクル）';

  @override
  String get riskLandSubtitle => 'どしゃくずれの きけんど（1kmごと・10ぷんごとに あたらしくなる）';

  @override
  String get riskInundSubtitle => 'みずびたしの きけんど（1kmごと・10ぷんごとに あたらしくなる）';

  @override
  String get riskFloodSubtitle => 'こうずいの きけんど（かわごと・10ぷんごとに あたらしくなる）';

  @override
  String get riskLevelWatch => '気（き）を つける';

  @override
  String get riskLevelCaution => 'ちゅうい';

  @override
  String get riskLevelWarning => 'けいかい';

  @override
  String get riskLevelDanger => 'きけん';

  @override
  String get riskLevelCritical => 'とても あぶない';

  @override
  String get wbgtLevelDanger => 'きけん';

  @override
  String get wbgtLevelSevereWarning => 'とても 気（き）を つける';

  @override
  String get wbgtLevelWarning => '気（き）を つける';

  @override
  String get wbgtLevelCaution => 'ちゅうい';

  @override
  String get wbgtLevelSafe => 'だいたい あんぜん';

  @override
  String get heatAlertSpecial => 'ねっちゅうしょう とくべつ けいかい';

  @override
  String get heatAlertSpecialPending => 'ねっちゅうしょう とくべつ けいかい（きめる まえ）';

  @override
  String get heatAlertWarning => 'ねっちゅうしょう けいかい';

  @override
  String get heatAlertDisclaimer =>
      'これは さんこうの じょうほうです。ただしい おしらせは ねっちゅうしょう よぼう じょうほう サイトを 見（み）て ください';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어';

  @override
  String get languageNameVi => 'Tiếng Việt';

  @override
  String get mapLayerPanelSubtitle => '地図（ちず）に かさねられるのは 1つだけです';

  @override
  String get mapLayerNone => 'なにも 出（だ）さない';

  @override
  String get mapLayerSectionWeather => '天気（てんき）';

  @override
  String get mapLayerRainRadarTitle => '雨（あめ）のレーダー（いま）';

  @override
  String get mapLayerRainRadarSubtitle =>
      'くわしい 雨（あめ）の 予報（よほう）。5分（ふん）ごとに 新（あたら）しくなります';

  @override
  String get mapLayerQuakesTitle => '地震（じしん）が おきた ところ';

  @override
  String get mapQuakePeriodDay => '24時間（じかん）';

  @override
  String get mapQuakePeriodWeek => '7日間（なのかかん）';

  @override
  String get mapQuakePeriodMonth => '30日間（さんじゅうにちかん）';

  @override
  String get mapLayerRain24hTitle => '24時間（じかん）に ふった 雨（あめ）の 量（りょう）';

  @override
  String get mapLayerRain24hSubtitle =>
      '気象庁（きしょうちょう）が 出（だ）した 雨（あめ）の 量（りょう）。大（おお）きくすると 観測（かんそく）した 数字（すうじ）も 出（で）ます';

  @override
  String get mapLayerSectionHazard => 'ハザードマップ（あぶない ところの 地図（ちず））';

  @override
  String get mapHazardLandslideSubtitle =>
      'がけ・土石流（どせきりゅう）・地（じ）すべり（黄色（きいろ）＝あぶない ところ／赤（あか）＝とても あぶない ところ）';

  @override
  String get mapHazardDepthSubtitle =>
      '水（みず）が どのくらい 深（ふか）く なるかを 色（いろ）で 見（み）せます';

  @override
  String get mapShelterTitle => 'にげる ところ';

  @override
  String get mapLayerShelterTitle => 'にげる ところ（すぐに にげる ところ・しばらく くらす ところ）';

  @override
  String get mapLayerShelterSubtitle =>
      '地図（ちず）を 大（おお）きくすると 出（で）ます。災害（さいがい）の 種類（しゅるい）で えらべます';

  @override
  String get mapFacilityTitle => '防災（ぼうさい）の 施設（しせつ）';

  @override
  String get mapLayerFacilityTitle =>
      '防災（ぼうさい）の 施設（しせつ）（水（みず）を くばる ところ・備蓄倉庫（びちくそうこ））';

  @override
  String get mapLayerFacilitySubtitle =>
      '地図（ちず）を 大（おお）きくすると 出（で）ます。種類（しゅるい）で えらべます';

  @override
  String mapQuakeNearbyTitle(int count) {
    return 'この 近（ちか）くの 地震（じしん） $count件（けん）';
  }

  @override
  String get mapQuakeUnknownPlace =>
      '地震（じしん）が おきた ところ（くわしいことは まだ 発表（はっぴょう）されていません）';

  @override
  String mapQuakeMaxIntensity(String value) {
    return 'いちばん 大（おお）きい ゆれ $value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return '$nameの 近（ちか）くの カメラ';
  }

  @override
  String get mapQuakeTapHint => 'さわると 近（ちか）く（50km いない）の カメラが 出（で）ます';

  @override
  String get mapShelterNoticeTitle => 'にげる ところの 表示（ひょうじ）について';

  @override
  String get mapShelterNoticeBody =>
      '・「指定緊急避難場所（していきんきゅうひなんばしょ）」は 災害（さいがい）から 命（いのち）を まもるために すぐ にげる ところです。「指定避難所（していひなんじょ）」は しばらく くらす ところです（二重（にじゅう）の わくで 見（み）せます）\n・指定緊急避難場所（していきんきゅうひなんばしょ）は 災害（さいがい）の 種類（しゅるい）ごとに きめられています。災害（さいがい）の 種類（しゅるい）に よっては にげられない ことが あります\n・市（し）や 町（まち）から もらった 情報（じょうほう）です。古（ふる）い ことや のっていない ところが あります。くわしいことは その 市（し）や 町（まち）に 聞（き）いてください';

  @override
  String get mapShelterHazardAll => 'ぜんぶ';

  @override
  String get mapShelterDesignated => 'くらす ところ';

  @override
  String get mapShelterHazardsLabel => 'にげられる 災害（さいがい）の 種類（しゅるい）';

  @override
  String get mapOpenRoute => 'Googleマップで 道（みち）を 見（み）る';

  @override
  String get mapNearbyCamerasButton => '近（ちか）くの カメラ';

  @override
  String get mapFacilityNoticeTitle => '防災（ぼうさい）の 施設（しせつ）の 表示（ひょうじ）について';

  @override
  String get mapFacilityNoticeBody =>
      '・市（し）や 町（まち）が 公開（こうかい）している「水（みず）を くばる 施設（しせつ）」「備蓄倉庫（びちくそうこ）」「消防（しょうぼう）の 水（みず）の 施設（しせつ）」を あつめた ものです。公開（こうかい）している 市（し）や 町（まち）だけで、日本（にほん）ぜんぶでは ありません\n・消火栓（しょうかせん）や 防火水槽（ぼうかすいそう）は 消防（しょうぼう）が つかう ものです。ふつうの 人（ひと）は つかえません\n・水（みず）を くばる ところは 災害（さいがい）の ときに ひらきます。ふだんは 水（みず）を もらえない ことが あります\n・新（あたら）しくする 時期（じき）は 市（し）や 町（まち）に よって ちがいます。くわしいことは その 市（し）や 町（まち）に 聞（き）いてください';

  @override
  String mapFacilityOwner(String owner) {
    return '出（だ）している ところ：$owner';
  }

  @override
  String get mapFacilityGeocodedNote =>
      '住所（じゅうしょ）から おおよそで 出（だ）した 場所（ばしょ）です。本当（ほんとう）の 場所（ばしょ）と ちがう ことが あります';

  @override
  String get mapFacilitySourceDataset => '出（で）どころ（データ）';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value時間（じかん）';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value分（ふん）';
  }

  @override
  String get mapNowcastNow => 'いま（じっさいの ようす）';

  @override
  String get mapNowcastForecastHourly => '予報（よほう）・1時間（じかん）の 雨（あめ）の 量（りょう）';

  @override
  String get mapNowcastForecast => 'よそく';

  @override
  String mapNowcastAfter(String span, String kind) {
    return '$spanあと（$kind）';
  }

  @override
  String mapNowcastBefore(String span) {
    return '$spanまえ（じっさいの ようす）';
  }

  @override
  String get mapNowcastBackToNow => 'いまに もどる';

  @override
  String get mapNowcastNowMarker => '▲ いま';

  @override
  String mapNowcastLast(String label) {
    return '$label（6時間（じかん） さき）';
  }

  @override
  String mapLegendRainRadar(String label) {
    return '雨（あめ）のレーダー $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return '雨（あめ）のレーダー $label（$kind）';
  }

  @override
  String get mapLegendRainWeak => 'よわい';

  @override
  String mapLegendQuakes(String period, int count) {
    return '地震（じしん）が おきた ところ $period（$count件（けん））';
  }

  @override
  String mapLegendIntensity(String value) {
    return 'ゆれ $value';
  }

  @override
  String get mapLegendIntensity6Up => '6弱（じゃく）から うえ';

  @override
  String mapLegendRain24h(String label) {
    return '24時間（じかん）の 雨（あめ）の 量（りょう） $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return '24時間（じかん）の 雨（あめ）の 量（りょう） $label（大（おお）きくすると 数字（すうじ）が 出（で）ます）';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title（あぶない／とても あぶない）';
  }

  @override
  String get mapLegendShelterZoomIn => 'にげる ところ（地図（ちず）を 大（おお）きくすると 出（で）ます）';

  @override
  String mapLegendShelter(int count) {
    return 'にげる ところ（$count件（けん））';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return 'にげる ところ（$count件（けん）・まとめて 見（み）せています）';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return 'にげる ところ・$hazard（$count件（けん））';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return 'にげる ところ・$hazard（$count件（けん）・まとめて 見（み）せています）';
  }

  @override
  String get mapLegendShelterEmergency => 'すぐに にげる ところ';

  @override
  String get mapLegendShelterDesignated => '二重（にじゅう）の わく＝しばらく くらす ところ';

  @override
  String get mapLegendFacilityZoomIn =>
      '防災（ぼうさい）の 施設（しせつ）（地図（ちず）を 大（おお）きくすると 出（で）ます）';

  @override
  String mapLegendFacilityNoData(String message) {
    return '防災（ぼうさい）の 施設（しせつ）（$message）';
  }

  @override
  String mapLegendFacility(int count) {
    return '防災（ぼうさい）の 施設（しせつ）（$count件（けん））';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return '防災（ぼうさい）の 施設（しせつ）（$count件（けん）・まとめて 見（み）せています）';
  }

  @override
  String get mapLegendFetchFailed => 'とれません';

  @override
  String get mapShelterFetchFailed =>
      'にげる ところの 情報（じょうほう）が とれませんでした（さわると もう一度（いちど））';

  @override
  String get mapFacilityFetchFailed =>
      '防災（ぼうさい）の 施設（しせつ）の 情報（じょうほう）が とれませんでした（さわると もう一度（いちど））';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24時間（じかん） ${mm}mm';
  }

  @override
  String get bosaiFetchFailedPull => 'とれませんでした（下（した）に ひっぱると もう いちど ためせます）';

  @override
  String get bosaiTsunamiInfo => 'つなみの おしらせ';

  @override
  String get bosaiUnknownPlace => 'わかりません';

  @override
  String bosaiFetchFailedDetail(String error) {
    return 'とれませんでした（$error）';
  }

  @override
  String get bosaiTimeJustNow => 'いま';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$nふん まえ';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$nじかん まえ';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return '$month月$day日 $hourじ ごろ';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return '$placeの ゆれの つよさ（震度／しんど）';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return '$placeの ちかくの カメラ';
  }

  @override
  String get bosaiQuakeEmpty => 'この 72じかんに じしんの おしらせは ありません';

  @override
  String bosaiQuakeAsOf(String time) {
    return '（$timeの じょうほう・あたらしい じゅん）';
  }

  @override
  String bosaiQuakeNote(String at) {
    return '出典（しゅってん）：気象庁 じしんの おしらせ（この 72じかん）$at。おすと ゆれた 市（し）・町（まち）の ライブカメラの いちらんが 出（で）ます。市（し）・町（まち）ごとの しんどが ない ときは 震源（しんげん）の ちかくの カメラを 出（だ）します。';
  }

  @override
  String get bosaiBadgeTsunami => 'つなみ';

  @override
  String bosaiBadgeIntensity(String value) {
    return 'しんど\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return '$countの 市（し）・町（まち）で かんそく';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return 'あたらしい じょうほうが とれませんでした（$timeの じょうほうを 出（だ）して います）';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return '$timeの じょうほう';
  }

  @override
  String get bosaiHeatOffSeason =>
      'いまは ねっちゅうしょうの おしらせを 出（だ）す きかんでは ありません（まいとし 4月の おわりから 10月の おわりまで 出（で）ます）';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return '（$month月$day日 $hourじに 出（で）ました）';
  }

  @override
  String get bosaiHeatTapHint => 'おすと その 県（けん）の カメラの いちらんが 出（で）ます。';

  @override
  String get bosaiHeatNone => 'いま、ねっちゅうしょうの けいかいの おしらせは 出（で）て いません';

  @override
  String get bosaiHeatToday => 'きょう';

  @override
  String get bosaiHeatTomorrow => 'あした';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return '$prefの カメラ（ねっちゅうしょう けいかい）';
  }

  @override
  String get bosaiWbgtCardTitle => 'ちかくの ばしょの あつさの ゆびすう（WBGT）';

  @override
  String get bosaiWbgtUnavailable => 'とれませんでした';

  @override
  String bosaiApproxDistance(String value) {
    return 'だいたい $value';
  }

  @override
  String get bosaiWbgtNow => 'いま';

  @override
  String get bosaiWbgtNoCurrent => 'いまの あたいは ありません';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level（$time）';
  }

  @override
  String get bosaiWbgtForecast => 'よそく';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hourじ';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return 'つぎの日（ひ）の $hourじ';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$month月$day日 $hourじ';
  }

  @override
  String get bosaiQuakeMuniNote =>
      '出典（しゅってん）：気象庁 じしんの おしらせ（ゆれが つよい じゅん）。おすと その 市（し）・町（まち）の カメラの いちらんが 出（で）ます。カメラが ない ときは 震源（しんげん）の ちかくの カメラを 出（だ）します。';

  @override
  String get bosaiEpicenterNearby => '震源（しんげん）の ちかくの カメラ（ちかい じゅん）';

  @override
  String bosaiMuniCodeFallback(String code) {
    return '市（し）・町（まち） $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref・震源（しんげん）の ちかくの カメラを 出（だ）します';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return '$nameの カメラ（しんど $intensity）';
  }

  @override
  String bosaiLiveOnly(int count) {
    return 'ライブだけ（$count）';
  }

  @override
  String get bosaiMuniFallbackNote =>
      'この 市（し）・町（まち）の カメラが ないので、県（けん）ぜんぶの カメラを 出（だ）して います';

  @override
  String get bosaiPrefNoCameras => 'この 県（けん）には カメラが ありません';

  @override
  String get bosaiNoLiveCameras => 'ライブの カメラは ありません';

  @override
  String get bosaiNoCamerasWithin50km => '50kmの なかに カメラは ありません';

  @override
  String get tipTitle => 'つくった 人（ひと）を おうえん';

  @override
  String get tipIntro =>
      'この アプリは 1人（ひとり）で つくって、うごかして います。カメラを さがして ふやす こと、サーバーを うごかしつづける こと、天気（てんき）の データに たいおうする ことの ちからに なります。おうえんは じゆうです。おうえんしても できることは かわりません。';

  @override
  String get tipCoffeeTitle => 'かんコーヒーで ひとやすみ';

  @override
  String get tipCoffeeSubtitle => 'かいはつの あいまに のむ かんコーヒーを おくります';

  @override
  String get tipSweetsTitle => 'あまい もので げんきを チャージ';

  @override
  String get tipSweetsSubtitle => 'しゅうちゅうして つくる ときの おかしと カフェの おかねを たすけます';

  @override
  String get tipLunchTitle => 'ひるごはんで かいはつを パワーアップ';

  @override
  String get tipLunchSubtitle => 'つぎの あたらしい しくみの ために、えいようの ある ひるごはんを ごちそうします';

  @override
  String get tipDevToolsTitle => 'かいはつの どうぐの おかねを おうえん';

  @override
  String get tipDevToolsSubtitle =>
      'カメラを さがす ことや サーバーを みまもる ことに つかう サービスの おかねを たすけます';

  @override
  String get tipPreparing => 'おうえんの メニューは まだ じゅんびちゅうです。あとで もういちど ためして ください。';

  @override
  String get tipUnavailable => 'この きかいでは アプリの なかで おかねを はらう ことが できません。';

  @override
  String get tipPurchaseStartFailed => 'かう てつづきを はじめられませんでした';

  @override
  String get tipThanks => 'おうえん ありがとう ございます！かいはつの ちからに なります。';

  @override
  String tipPurchaseFailed(String error) {
    return 'かう てつづきを おわらせられませんでした（$error）';
  }

  @override
  String get tipUnknownError => 'わからない エラー';

  @override
  String get tipNoticeTitle => 'かう まえに かくにん して ください';

  @override
  String get tipNoticeBody =>
      'おうえんの おかねは App Storeの アプリない かきん（アプリの なかで はらう しくみ）で しはらいます。はらいもどしは Appleの きまりに したがいます。';

  @override
  String get tipEula => 'EULA（Appleの つかいかたの やくそく）';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return 'きろく: $countけん\nいちばん あたらしい: $name';
  }

  @override
  String get settingsDiagKindCrash => 'きゅうに とまった（クラッシュ）';

  @override
  String get settingsDiagKindHang => 'うごかなく なった（ハング）';

  @override
  String get settingsDiagKindCpu => 'CPU（けいさんする ぶひん）の いじょう';

  @override
  String get settingsDiagKindDiskWrite => 'ほぞんの いじょう（ディスクへの 書（か）きこみ）';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return 'しゅるい: $kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return 'よみとりの エラー: $error';
  }

  @override
  String get settingsDiagFetchFailed => 'とれませんでした';

  @override
  String get settingsDiagNotAcquired => 'まだ ありません（null）';

  @override
  String settingsDiagAcquired(String prefix) {
    return 'とれました（$prefix…）';
  }

  @override
  String settingsDiagError(String error) {
    return 'エラー: $error';
  }

  @override
  String get stockpileTitle => 'ぼうさいの そなえ（防災の備え）';

  @override
  String get stockpileEntryTitle => 'ぼうさいの そなえ（備蓄チェックリスト）';

  @override
  String get stockpileEntrySubtitle => 'かぞくの 人数（にんずう）から ひつような 量（りょう）を けいさん します';

  @override
  String get stockpileBosaiLink => 'そなえは たりて いますか？ リストを ひらく';

  @override
  String get stockpileHouseholdTitle => 'いっしょに すむ 人（ひと）の 人数（にんずう）';

  @override
  String get stockpileAdults => 'おとな';

  @override
  String get stockpileChildren => 'こども';

  @override
  String get stockpileDaysLabel => 'なんにち ぶん そなえるか';

  @override
  String stockpileDaysValue(int days) {
    return '$days日（にち）ぶん';
  }

  @override
  String get stockpileSummaryTitle => 'ひつような 量（りょう）の めやす';

  @override
  String stockpileSummaryWater(int liters) {
    return 'みず $litersリットル';
  }

  @override
  String stockpileSummaryMeals(int meals) {
    return 'たべもの $meals食（しょく）';
  }

  @override
  String get stockpileSummaryNote =>
      'くにの めやす（1人（ひとり）1日（にち）で みず3リットル・3食（しょく））で けいさん して います';

  @override
  String get stockpileSourceMaff => 'のうりんすいさんしょう「家庭備蓄ポータル」';

  @override
  String get stockpileSourceCao => 'ないかくふ「防災情報のページ」';

  @override
  String stockpileProgress(int done, int total) {
    return '$totalこ の うち $doneこ できた';
  }

  @override
  String stockpileRequired(String quantity, String unit) {
    return 'ひつよう $quantity$unit';
  }

  @override
  String get stockpileSearchButton => 'さがす';

  @override
  String get stockpileExpirySet => 'きげんを いれる';

  @override
  String stockpileExpiryOn(String date) {
    return 'きげん $date';
  }

  @override
  String get stockpileExpirySoon => 'もうすぐ きげん';

  @override
  String get stockpileExpired => 'きげんが すぎた';

  @override
  String get stockpileExpiryClear => 'きげんを けす';

  @override
  String get stockpileAddItem => 'こうもくを ふやす';

  @override
  String get stockpileItemNameLabel => 'なまえ';

  @override
  String get stockpileItemQuantityLabel => 'ひつような かず';

  @override
  String get stockpileItemCategoryLabel => 'なかま わけ';

  @override
  String get stockpileDeleteItem => 'こうもくを けす';

  @override
  String get stockpileMarkPrepared => 'よういできた';

  @override
  String get stockpileSectionExpiry => 'きげん';

  @override
  String get stockpileItemTapHint => 'こうもくを おすと きげんや えらびかた、かうところが みられます';

  @override
  String get stockpileOfficialSite => 'こうしきサイト';

  @override
  String get stockpileInfants => 'あかちゃん（ミルク・おむつ）';

  @override
  String stockpileNotifyExpiryBodyMany(String names, String date) {
    return '$names の きげんが ちかづいて います（$date）';
  }

  @override
  String stockpileNotifyMoreItems(int count) {
    return 'ほか $countこ';
  }

  @override
  String get stockpileNotifyNameSeparator => '・';

  @override
  String stockpileDeleted(String item) {
    return '「$item」を けしました';
  }

  @override
  String get stockpileUndo => 'もとに もどす';

  @override
  String get stockpileReset => 'さいしょに もどす';

  @override
  String get stockpileResetConfirm => 'チェックと きげんと ふやした こうもくを ぜんぶ けします。いいですか？';

  @override
  String get stockpileSectionReminder => 'おしらせ';

  @override
  String get stockpileExpiryReminder => 'きげんの 1かげつ まえに おしらせ';

  @override
  String get stockpileExpiryReminderSubtitle =>
      'きげんの 1かげつ まえの あさ9じに この スマホが おしらせ します';

  @override
  String get stockpileInspectionReminder => 'てんけんの 日（ひ）に おしらせ';

  @override
  String get stockpileInspectionReminderSubtitle =>
      '3月（がつ）11日（にち）と 9月（がつ）1日（にち）の あさ9じに おしらせ します';

  @override
  String get stockpileNotifyDenied =>
      'おしらせが きょか されて いません。スマホの せっていで きょか して ください';

  @override
  String get stockpileNotifyTitle => 'そなえの てんけん';

  @override
  String stockpileNotifyExpiryBody(String item, String date) {
    return '「$item」の きげんが ちかづいて います（$date）';
  }

  @override
  String get stockpileNotifyInspectionBody => 'そなえた ものの きげんと かずを たしかめましょう';

  @override
  String get stockpileGuideWhy => 'えらびかたの ポイント';

  @override
  String get stockpileGuideProducts => 'さんこうに なる せいひん';

  @override
  String get stockpileGuideProductsNote =>
      'しょうひんの なまえで ショップを さがします（ぎょうの みぎの ↗ は メーカーの こうしきページ）。ねだんや うっているかは ショップで たしかめて ください。';

  @override
  String get stockpileGuideSearch => 'しょうひんを さがす';

  @override
  String stockpileGuideSearchAt(String shop) {
    return '$shopで さがす';
  }

  @override
  String get stockpileGuideSources => 'でどころ';

  @override
  String get stockpileDisclaimer => 'ひつような 量（りょう）は めやすです。かぞくに あわせて かえて ください';

  @override
  String get stockpileCatWaterFood => 'みずと たべもの';

  @override
  String get stockpileCatLightPower => 'あかりと でんき';

  @override
  String get stockpileCatSanitation => 'せいけつに する もの';

  @override
  String get stockpileCatFirstAid => 'きゅうきゅうと くすり';

  @override
  String get stockpileCatEvacuation => 'にげる ときの もの';

  @override
  String get stockpileCatValuables => 'たいせつな ものと じょうほう';

  @override
  String get stockpileUnitLiter => 'リットル';

  @override
  String get stockpileUnitMeal => '食（しょく）';

  @override
  String get stockpileUnitPiece => 'こ';

  @override
  String get stockpileUnitSheet => 'まい';

  @override
  String get stockpileUnitRoll => 'ロール';

  @override
  String get stockpileUnitPair => 'くみ';

  @override
  String get stockpileUnitPack => 'パック';

  @override
  String get stockpileUnitTimes => 'かいぶん';

  @override
  String get stockpileUnitDays => 'にちぶん';

  @override
  String get stockpileUnitSet => 'セット';

  @override
  String get stockpileItemWater => 'ほぞんすい（みず）';

  @override
  String get stockpileItemStapleFood => 'ひじょうしょく（ごはん・パン）';

  @override
  String get stockpileItemRetortFood => 'レトルトしょくひん';

  @override
  String get stockpileItemCannedFood => 'かんづめ';

  @override
  String get stockpileItemBabyFormula => 'あかちゃんの ミルク';

  @override
  String get stockpileItemFlashlight => 'かいちゅうでんとう（ライト）';

  @override
  String get stockpileItemBatteries => 'かんでんち';

  @override
  String get stockpileItemPowerBank => 'モバイルバッテリー';

  @override
  String get stockpileItemRadio => 'ラジオ';

  @override
  String get stockpileItemPortableToilet => 'かんいトイレ';

  @override
  String get stockpileItemToiletPaper => 'トイレットペーパー';

  @override
  String get stockpileItemWetWipes => 'ウェットティッシュ';

  @override
  String get stockpileItemGarbageBags => 'ゴミぶくろ';

  @override
  String get stockpileItemDiapers => 'おむつ';

  @override
  String get stockpileItemFirstAidKit => 'きゅうきゅうセット';

  @override
  String get stockpileItemMedicine => 'いつも のむ くすり';

  @override
  String get stockpileItemMask => 'マスク';

  @override
  String get stockpileItemDisinfectant => 'しょうどくえき';

  @override
  String get stockpileItemBackpack => 'ぼうさいリュック';

  @override
  String get stockpileItemBlanket => 'アルミの ブランケット';

  @override
  String get stockpileItemGloves => 'ぐんて（てぶくろ）';

  @override
  String get stockpileItemRope => 'ロープ';

  @override
  String get stockpileItemCash => 'げんきん（こぜにも）';

  @override
  String get stockpileItemIdCopy => 'みぶんしょうめいしょの コピー';

  @override
  String get stockpileItemContactMemo => 'れんらくさきの メモ';

  @override
  String get stockpileItemCable => 'じゅうでんケーブル';

  @override
  String get stockpileChooseShop => 'みせを えらぶ';
}
