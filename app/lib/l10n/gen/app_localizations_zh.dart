// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Japan Live Camera Map';

  @override
  String get commonClose => '关闭';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '确定';

  @override
  String get commonNext => '下一步';

  @override
  String get commonSkip => '跳过';

  @override
  String get commonCopy => '复制';

  @override
  String get commonShare => '分享';

  @override
  String get commonRetry => '重试';

  @override
  String get commonOpenInSafari => '用 Safari 打开';

  @override
  String get commonSource => '出处';

  @override
  String commonCameraCount(int count) {
    return '$count台';
  }

  @override
  String get legalJapaneseAuthoritative => '以本日语版为正式文本，翻译仅供参考。';

  @override
  String get languageLabel => '语言';

  @override
  String get languageSettingTitle => '语言 / 言語';

  @override
  String get languageNameJa => '日本語（日语）';

  @override
  String get languageNameJaHira => 'やさしい日本語（简明日语）';

  @override
  String get languageNameEn => 'English（英语）';

  @override
  String get languageFollowSystem => '跟随系统设置';

  @override
  String get languageChooseTitle => '选择语言';

  @override
  String get tabMap => '地图';

  @override
  String get tabList => '列表';

  @override
  String get tabBosai => '灾害速报';

  @override
  String get tabFavorites => '收藏';

  @override
  String get tabStockpile => '备灾';

  @override
  String get tabSettings => '设置';

  @override
  String get onboardingTitle1 => '在地图上快速查找';

  @override
  String get onboardingBody1 => '全国超过1万台实时摄像头显示在地图上，按河川、道路、海岸等类别用颜色区分。';

  @override
  String get onboardingTitle2 => '无法显示的摄像头自动隐藏';

  @override
  String get onboardingBody2 => '系统会定期自动检查，无法获取画面的摄像头将从地图上移除。画面的获取时间一定会显示。';

  @override
  String get onboardingTitle3 => '明确标注出处与许可';

  @override
  String get onboardingBody3 => '所有画面都与提供方的名称一并显示。画面的权利归各提供方所有。';

  @override
  String get onboardingNotifyOptIn => '接收灾害通知';

  @override
  String get onboardingNotifyOptInDetail =>
      '当发生烈度5弱以上的地震或发布特别警报（全国）时通知您。之后可在设置中更改。';

  @override
  String get onboardingDisclaimerTitle => '使用前的重要提示';

  @override
  String get onboardingAgreeAndStart => '同意并开始';

  @override
  String get disclaimerText =>
      '摄像头画面只反映有限范围内的状况。受摄像头性能、光照环境和气象条件影响，画面可能不清晰。是否避难请依据水位信息、气象警报以及地方政府发布的避难信息判断。本软件仅提供参考信息。';

  @override
  String get updateRequiredTitle => '需要更新';

  @override
  String get updateRequiredBody => '此版本已停止支持。\n请从 App Store 更新到最新版本。';

  @override
  String get updateOpenStore => '打开 App Store';

  @override
  String get categoryRiver => '河川';

  @override
  String get categoryRoad => '道路';

  @override
  String get categoryVolcano => '火山';

  @override
  String get categoryDam => '水坝';

  @override
  String get categoryCoast => '海岸';

  @override
  String get categoryPort => '港口';

  @override
  String get categoryScenic => '景观';

  @override
  String get categoryHealing => '治愈';

  @override
  String get categoryOther => '其他';

  @override
  String get pref01 => '北海道';

  @override
  String get pref02 => '青森';

  @override
  String get pref03 => '岩手';

  @override
  String get pref04 => '宫城';

  @override
  String get pref05 => '秋田';

  @override
  String get pref06 => '山形';

  @override
  String get pref07 => '福岛';

  @override
  String get pref08 => '茨城';

  @override
  String get pref09 => '栃木';

  @override
  String get pref10 => '群马';

  @override
  String get pref11 => '埼玉';

  @override
  String get pref12 => '千叶';

  @override
  String get pref13 => '东京';

  @override
  String get pref14 => '神奈川';

  @override
  String get pref15 => '新泻';

  @override
  String get pref16 => '富山';

  @override
  String get pref17 => '石川';

  @override
  String get pref18 => '福井';

  @override
  String get pref19 => '山梨';

  @override
  String get pref20 => '长野';

  @override
  String get pref21 => '岐阜';

  @override
  String get pref22 => '静冈';

  @override
  String get pref23 => '爱知';

  @override
  String get pref24 => '三重';

  @override
  String get pref25 => '滋贺';

  @override
  String get pref26 => '京都';

  @override
  String get pref27 => '大阪';

  @override
  String get pref28 => '兵库';

  @override
  String get pref29 => '奈良';

  @override
  String get pref30 => '和歌山';

  @override
  String get pref31 => '鸟取';

  @override
  String get pref32 => '岛根';

  @override
  String get pref33 => '冈山';

  @override
  String get pref34 => '广岛';

  @override
  String get pref35 => '山口';

  @override
  String get pref36 => '德岛';

  @override
  String get pref37 => '香川';

  @override
  String get pref38 => '爱媛';

  @override
  String get pref39 => '高知';

  @override
  String get pref40 => '福冈';

  @override
  String get pref41 => '佐贺';

  @override
  String get pref42 => '长崎';

  @override
  String get pref43 => '熊本';

  @override
  String get pref44 => '大分';

  @override
  String get pref45 => '宫崎';

  @override
  String get pref46 => '鹿儿岛';

  @override
  String get pref47 => '冲绳';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSupportTitle => '支持开发者';

  @override
  String get settingsSupportBody => '一罐咖啡（¥200）起。请支持个人开发的持续进行';

  @override
  String get settingsSupportButton => '支持';

  @override
  String get settingsSectionNotify => '灾害通知';

  @override
  String get settingsQuakeTitle => '烈度5弱以上的地震';

  @override
  String get settingsQuakeSubtitleOff => '发生大地震时通知您，并引导至周边的摄像头';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return '通知级别：$level';
  }

  @override
  String get settingsWarningTitle => '特别警报';

  @override
  String get settingsWarningSubtitle => '发布大雨、暴风、暴潮等特别警报时通知您';

  @override
  String get settingsNotifyArea => '接收通知的地区';

  @override
  String get settingsNotifyAreaAll => '全国';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first 等$count个地区';
  }

  @override
  String get settingsNotifyAreaHint => '仅通知所选都道府县的特别警报。未选择任何地区时，通知范围为全国';

  @override
  String get settingsNotifyAreaResetAll => '恢复为全国';

  @override
  String get settingsNotifyLevel => '接收通知的级别';

  @override
  String get settingsNotifyLevelSpecialOnly => '仅特别警报（等级5）';

  @override
  String get settingsNotifyLevelDangerUp => '从危险警报起（等级4以上）';

  @override
  String get settingsNotifyLevelNote => '危险警报是相当于大雨、洪水、暴潮、土石流警戒等级4的发布';

  @override
  String get settingsNotifyDelayNote => '※通知可能比气象厅发布晚5〜15分钟左右，不能代替紧急地震速报';

  @override
  String get settingsNotifyDenied => '未获得通知权限。请在 iOS 的“设置”应用中允许通知';

  @override
  String get settingsSectionData => '数据获取';

  @override
  String get settingsWifiOnly => '仅在 Wi-Fi 连接时获取图像';

  @override
  String get settingsWifiOnlySubtitle => '可减少移动数据流量（地图和摄像头列表仍会显示）';

  @override
  String get settingsClearCache => '删除缓存';

  @override
  String get settingsClearCacheSubtitle => '清除摄像头列表等已保存的数据并重新获取';

  @override
  String get settingsClearCacheDone => '已删除缓存并重新获取';

  @override
  String get settingsSectionFilterDefaults => '筛选的初始设置';

  @override
  String get settingsShowWorld => '显示日本以外的摄像头';

  @override
  String get settingsVideoOnly => '仅视频摄像头';

  @override
  String get settingsHideUncertain => '隐藏位置不确切的摄像头';

  @override
  String get settingsHideUncertainSubtitle => '隐藏黄色边框的图钉（大致位置／代表点）';

  @override
  String get settingsFilterDefaultsNote => '此处的设置将作为下次启动时的初始状态（也可从地图图例中临时更改）';

  @override
  String get settingsSectionRequest => '摄像头的添加与删除申请';

  @override
  String get settingsRequestForm => '咨询与申请表单';

  @override
  String get settingsRequestFormSubtitle =>
      '如需申请添加摄像头或要求删除已刊登的内容，请使用此表单（无需登录）。对于设置方、运营方提出的删除请求，我们会迅速处理';

  @override
  String get settingsSectionLicense => '出处与许可';

  @override
  String get settingsAttributionList => '出处与许可一览';

  @override
  String get settingsAttributionListSubtitle => '摄像头画面提供方的一览';

  @override
  String get settingsTerms => '使用条款';

  @override
  String get settingsPrivacy => '隐私政策';

  @override
  String get settingsLegalJapaneseOnly => '使用条款和隐私政策的正文仅有日语版（以日语为正式文本）';

  @override
  String get settingsSectionAbout => '关于本软件';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsInvite => '邀请好友';

  @override
  String get settingsInviteSubtitle => '通过二维码或链接分享 App Store 页面';

  @override
  String get settingsInviteDialogBody => '扫描二维码或发送链接，\n即可打开 App Store 的应用页面';

  @override
  String get settingsInviteShareText => 'Japan Live Camera Map - 河川、道路、防灾';

  @override
  String get settingsLinkCopied => '已复制链接';

  @override
  String get settingsReview => '为本软件评分';

  @override
  String get settingsReviewSubtitle => '在 App Store 撰写评价';

  @override
  String get settingsFollowX => '在 X 上关注';

  @override
  String get settingsFollowXSubtitle => '@kotopapa8 — 新摄像头和新功能的通知';

  @override
  String get settingsOtherApps => '开发者的其他软件';

  @override
  String get settingsShowMoreApps => '查看其他软件';

  @override
  String get settingsSectionDisclaimer => '免责';

  @override
  String get settingsOssLicenses => '开源许可';

  @override
  String get settingsNotifyDiag => '通知诊断';

  @override
  String get settingsNotifyDiagSubtitle => '收不到通知时确认状态';

  @override
  String get settingsNotifyDiagUnlocked => '已显示通知诊断（位于“灾害通知”项内）';

  @override
  String settingsNotifyPermission(String value) {
    return '通知权限：$value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'APNs 令牌：$value';
  }

  @override
  String get settingsNotifyFcm => 'FCM 令牌：';

  @override
  String get settingsCopyToken => '复制令牌';

  @override
  String get settingsTokenCopied => '已复制 FCM 令牌';

  @override
  String get settingsCrashDiag => '崩溃诊断数据';

  @override
  String get settingsCrashDiagSubtitle => '查看并复制强制退出的记录（MetricKit）';

  @override
  String get settingsCrashDiagNone => '尚无诊断数据';

  @override
  String get settingsCrashDiagNoneHint => '尚无诊断数据。\n崩溃后重新启动软件即会记录';

  @override
  String get settingsCopyFullText => '复制全文';

  @override
  String get settingsJsonCopied => '已复制诊断 JSON';

  @override
  String get attributionScreenTitle => '出处与许可一览';

  @override
  String get attributionOpenYoutube => '在 YouTube 上查看提供方';

  @override
  String get attributionOpenSite => '打开提供方的网站';

  @override
  String listTitle(int count) {
    return '列表（$count）';
  }

  @override
  String get listSearchHint => '按摄像头名、河川名、路线名搜索';

  @override
  String get listEmpty => '没有符合条件的摄像头';

  @override
  String get listRanking => '排行榜';

  @override
  String favoritesTitle(int count) {
    return '收藏（$count）';
  }

  @override
  String get favoritesEmpty => '尚无收藏。\n在地图上打开摄像头并点击★即可添加。';

  @override
  String get favoritesEmptyFiltered => '没有符合筛选条件的收藏';

  @override
  String get favoritesSort => '排序';

  @override
  String get favoritesSortNewest => '按添加时间从新到旧';

  @override
  String get favoritesSortOldest => '按添加时间从旧到新';

  @override
  String get favoritesSortName => '按名称';

  @override
  String get favoritesSortCategory => '按类别';

  @override
  String get favoritesToggleView => '切换显示';

  @override
  String get favoritesRefreshAll => '批量更新（每次3台依次获取）';

  @override
  String get favoritesVideoOnly => '仅视频';

  @override
  String get rankingTitle => '全国排行榜';

  @override
  String get rankingModeNow => '正在观看（24小时 TOP10）';

  @override
  String get rankingModeWeek => '观看较多（7天 TOP30）';

  @override
  String get rankingModeFavorites => '收藏最多（TOP20）';

  @override
  String get rankingNote => '基于全体用户的匿名统计生成的排行榜（每天更新）';

  @override
  String get rankingEmpty => '尚无统计数据（每天更新一次）';

  @override
  String get rankingPreparing => '全国排行榜正在准备中。\n统计每3小时进行一次。';

  @override
  String get rankingFetchFailed => '获取失败';

  @override
  String rankingFetchFailedHttp(int code) {
    return '获取失败（HTTP $code）';
  }

  @override
  String get rankingUnitViews => '次';

  @override
  String get rankingUnitFavorites => '个';

  @override
  String get detailLive => '直播中';

  @override
  String get detailTimeUnknown => '获取时间不明';

  @override
  String detailRefreshEvery(int sec) {
    return '每$sec秒更新';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$sec秒';
  }

  @override
  String get detailRefreshNow => '更新';

  @override
  String get detailPosRepresentative => '位置为广域代表点';

  @override
  String get detailPosApprox => '位置为大致位置';

  @override
  String get detailNotUpdating => '图像未更新';

  @override
  String get detailWorld => '日本境外';

  @override
  String get detailCategoryAndPlace => '类别与位置';

  @override
  String get detailOpenMap => '在地图上查看';

  @override
  String get detailHotelsTitle => '查找附近住宿';

  @override
  String get detailOpenSourceSite => '查看出处网站';

  @override
  String get detailOpenYoutube => '在 YouTube 上观看';

  @override
  String get detailOpenChannel => '查看频道页面';

  @override
  String get detailOpenOriginalPage => '在原页面查看';

  @override
  String get detailReportProblem => '报告此摄像头的问题';

  @override
  String get detailNearby => '周边的摄像头';

  @override
  String detailDistanceKm(String km) {
    return '约${km}km';
  }

  @override
  String get detailWifiOnlyBlocked => '根据设置，仅在 Wi-Fi 连接时获取图像';

  @override
  String get detailNoImage => '当前无法获取画面';

  @override
  String get detailEmbedBlockedYoutube => '由于提供方的设置，\n此画面无法在软件内播放';

  @override
  String get detailEmbedBlockedPage => '根据发布方的使用条件，\n无法在软件内显示';

  @override
  String get detailIHighwayTitle => '在 NEXCO 官方“iHighway”\n查看实时摄像头';

  @override
  String get detailIHighwayBody => '点击后将在软件内浏览器中打开官方网站，\n并自动移动到此摄像头的位置';

  @override
  String get detailIHighwayHost => 'ihighway.jp（NEXCO 官方）';

  @override
  String get detailMapTileGsi => '地理院瓦片';

  @override
  String get elevationLoading => '海拔 …';

  @override
  String elevationValue(String value, String source) {
    return '海拔 $value（$source）';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return '$time 获取$relative';
  }

  @override
  String get timeRelJustNow => '（刚刚）';

  @override
  String timeRelMinutes(int n) {
    return '（$n分钟前）';
  }

  @override
  String timeRelHours(int n) {
    return '（$n小时前）';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get intensity5Lower => '近5级';

  @override
  String get intensity5Upper => '超5级';

  @override
  String get intensity6Lower => '近6级';

  @override
  String get intensity6Upper => '超6级';

  @override
  String get quakeLevel5Lower => '烈度5弱以上';

  @override
  String get quakeLevel5Upper => '烈度5强以上';

  @override
  String get quakeLevel6Lower => '烈度6弱以上';

  @override
  String get warning02 => '暴风雪警报';

  @override
  String get warning03 => '大雨警报';

  @override
  String get warning04 => '洪水警报';

  @override
  String get warning05 => '暴风警报';

  @override
  String get warning06 => '大雪警报';

  @override
  String get warning07 => '海浪警报';

  @override
  String get warning08 => '暴潮警报';

  @override
  String get warning09 => '土石流警报';

  @override
  String get warning43 => '大雨危险警报';

  @override
  String get warning44 => '洪水危险警报';

  @override
  String get warning48 => '暴潮危险警报';

  @override
  String get warning49 => '土石流危险警报';

  @override
  String get warning32 => '暴风雪特别警报';

  @override
  String get warning33 => '大雨特别警报';

  @override
  String get warning34 => '洪水特别警报';

  @override
  String get warning35 => '暴风特别警报';

  @override
  String get warning36 => '大雪特别警报';

  @override
  String get warning37 => '海浪特别警报';

  @override
  String get warning38 => '暴潮特别警报';

  @override
  String get warning39 => '土石流特别警报';

  @override
  String get advisory10 => '大雨注意报';

  @override
  String get advisory12 => '大雪注意报';

  @override
  String get advisory13 => '风雪注意报';

  @override
  String get advisory14 => '闪电注意报';

  @override
  String get advisory15 => '强风注意报';

  @override
  String get advisory16 => '波浪注意报';

  @override
  String get advisory17 => '化雪注意报';

  @override
  String get advisory18 => '洪水注意报';

  @override
  String get advisory19 => '暴潮注意报';

  @override
  String get advisory20 => '浓雾注意报';

  @override
  String get advisory21 => '干燥注意报';

  @override
  String get advisory22 => '雪崩注意报';

  @override
  String get advisory23 => '低温注意报';

  @override
  String get advisory24 => '结霜注意报';

  @override
  String get advisory25 => '结冰注意报';

  @override
  String get advisory26 => '积雪注意报';

  @override
  String get advisory29 => '土石流注意报';

  @override
  String get mapLocationDenied => '未获得位置信息使用权限（可在“设置”中更改）';

  @override
  String get mapLocationFailed => '无法获取当前位置';

  @override
  String get mapLegendTitle => '图例与筛选';

  @override
  String get mapLegendSearchHint => '按摄像头名、运营方、河川／路线名搜索';

  @override
  String get mapFilterFavoritesOnly => '仅收藏';

  @override
  String get mapFilterOkOnly => '仅当前有画面的';

  @override
  String get mapLegendLiveDot => '红点 = 视频（直播）';

  @override
  String get mapLegendUncertain => '黄色边框 = 位置未确定（大致／代表点）';

  @override
  String get mapLegendFrozen => '半透明 = 图像长时间未更新';

  @override
  String get mapLegendFavorite => '金色星标 = 已收藏';

  @override
  String get mapLegendCluster => '数字圆圈 = 周边摄像头的聚合（点击可放大）';

  @override
  String get mapSearchTitle => '搜索地点';

  @override
  String get mapSearchHint => '地名或地址（例：涩谷、金泽市广坂）';

  @override
  String get mapSearchNotFound => '未找到。请尝试用地名、地址或摄像头名搜索';

  @override
  String get mapSearchSectionCameras => '摄像头';

  @override
  String get mapSearchSectionPlaces => '地点';

  @override
  String mapPointCameras(int count) {
    return '此地点的摄像头（$count台）';
  }

  @override
  String mapFilteredCount(int count) {
    return '筛选中 $count台';
  }

  @override
  String mapTotalCount(int count) {
    return '$count台';
  }

  @override
  String get mapLayersTooltip => '地图图层';

  @override
  String get bosaiTitle => '灾害速报';

  @override
  String get bosaiTabQuake => '地震・海啸';

  @override
  String get bosaiTabWarning => '气象警报';

  @override
  String get bosaiTabHeat => '中暑';

  @override
  String get bosaiNoWarnings => '当前没有正在发布的警报和注意报';

  @override
  String get bosaiWarningNoteNone => '来源：气象厅。当前没有发布警报和特别警报。仅有注意报的地区可在下方一览中确认。';

  @override
  String get bosaiWarningNote => '来源：气象厅 气象警报・注意报。点击后将显示该都道府县的摄像头列表。';

  @override
  String bosaiAdvisoryRegions(int count) {
    return '正在发布注意报的地区（$count个都道府县）';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return '$pref的警报发布地区';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return '$pref的注意报发布地区';
  }

  @override
  String get bosaiMuniNote => '来源：气象厅。点击后将显示该市区町村的摄像头列表';

  @override
  String get bosaiMuniFetchFailed => '无法获取发布区域的详细信息';

  @override
  String get bosaiMuniNone => '当前没有正在发布的市区町村';

  @override
  String bosaiCameraCount(int count) {
    return '摄像头$count台';
  }

  @override
  String get bosaiNoCamera => '无摄像头';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return '$name的摄像头（警报发布中）';
  }

  @override
  String get settingsJmaDictionary => '关于防灾用语的翻译';

  @override
  String get settingsJmaDictionaryNote =>
      '警报名称、注意报名称、烈度等各语言译文依据气象厅《气象信息等多语言辞典》。来源：气象厅官网';

  @override
  String get hazardFloodTitle => '洪水淹水预想区域（假定最大规模）';

  @override
  String get hazardLandslideTitle => '土砂灾害警戒区域（崖崩·泥石流·滑坡）';

  @override
  String get hazardTsunamiTitle => '海啸淹水预想';

  @override
  String get hazardHightideTitle => '暴潮淹水预想区域';

  @override
  String get hazardLandslideSteepSlope => '陡坡地';

  @override
  String get hazardLandslideDebrisFlow => '土石流';

  @override
  String get hazardLandslideSlide => '滑坡';

  @override
  String get hazardDisclaimer => '最新且详细的信息请查阅各市町村的灾害风险地图。是否避难请遵从地方政府发布的避难信息';

  @override
  String get facilityKindWater => '供水点与应急供水设施';

  @override
  String get facilityKindStock => '防灾储备仓库';

  @override
  String get facilityKindFireWater => '消防水源（消火栓、消防水池）';

  @override
  String get facilityKindWaterShort => '供水点';

  @override
  String get facilityKindStockShort => '储备仓库';

  @override
  String get facilityKindFireWaterShort => '消防水源';

  @override
  String get facilityDisclaimer => '仅限已公开数据的地方政府。最新信息请向各地方政府确认';

  @override
  String get facilityNoData => '此地区尚无数据';

  @override
  String get shelterHazardFlood => '洪水';

  @override
  String get shelterHazardSediment => '土石流';

  @override
  String get shelterHazardHightide => '暴潮';

  @override
  String get shelterHazardEarthquake => '地震';

  @override
  String get shelterHazardTsunami => '海啸';

  @override
  String get shelterHazardFire => '火灾';

  @override
  String get shelterHazardInlandFlood => '内涝';

  @override
  String get shelterHazardVolcano => '火山';

  @override
  String get shelterDisclaimer => '最新且详细的情况请向各市町村确认';

  @override
  String get riskLandTitle => '土石流危险分布图（Kikikuru）';

  @override
  String get riskInundTitle => '水灾危险分布图（Kikikuru）';

  @override
  String get riskFloodTitle => '洪水危险分布图（Kikikuru）';

  @override
  String get riskLandSubtitle => '土石流灾害的危险度（1km网格、每10分钟更新）';

  @override
  String get riskInundSubtitle => '水灾的危险度（1km网格、每10分钟更新）';

  @override
  String get riskFloodSubtitle => '洪水灾害的危险度（按河川、每10分钟更新）';

  @override
  String get riskLevelWatch => '留意后续信息';

  @override
  String get riskLevelCaution => '注意';

  @override
  String get riskLevelWarning => '警戒';

  @override
  String get riskLevelDanger => '危险';

  @override
  String get riskLevelCritical => '灾害逼近';

  @override
  String get wbgtLevelDanger => '危险';

  @override
  String get wbgtLevelSevereWarning => '严重警戒';

  @override
  String get wbgtLevelWarning => '警戒';

  @override
  String get wbgtLevelCaution => '注意';

  @override
  String get wbgtLevelSafe => '基本安全';

  @override
  String get heatAlertSpecial => '中暑特别警报';

  @override
  String get heatAlertSpecialPending => '中暑特别警报（判定中）';

  @override
  String get heatAlertWarning => '中暑警报';

  @override
  String get heatAlertDisclaimer => '本信息仅供参考。正式发布请查阅中暑预防信息网站等';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어（韩语）';

  @override
  String get languageNameVi => 'Tiếng Việt（越南语）';

  @override
  String get mapLayerPanelSubtitle => '地图上一次只能叠加一种图层。';

  @override
  String get mapLayerNone => '不显示';

  @override
  String get mapLayerSectionWeather => '气象';

  @override
  String get mapLayerRainRadarTitle => '雨云雷达（当前）';

  @override
  String get mapLayerRainRadarSubtitle => '高清降水实时预测、每5分钟更新';

  @override
  String get mapLayerQuakesTitle => '震源';

  @override
  String get mapQuakePeriodDay => '24小时';

  @override
  String get mapQuakePeriodWeek => '7天';

  @override
  String get mapQuakePeriodMonth => '30天';

  @override
  String get mapLayerRain24hTitle => '24小时降雨量';

  @override
  String get mapLayerRain24hSubtitle => '气象厅的解析雨量（面）＋放大后显示 AMeDAS 观测值';

  @override
  String get mapLayerSectionHazard => '灾害风险地图';

  @override
  String get mapHazardLandslideSubtitle => '陡坡地、土石流、滑坡（黄=警戒区域／红=特别警戒区域）';

  @override
  String get mapHazardDepthSubtitle => '用颜色区分显示预想的淹水深度';

  @override
  String get mapShelterTitle => '避难场所';

  @override
  String get mapLayerShelterTitle => '避难场所（指定紧急避难场所、指定避难所）';

  @override
  String get mapLayerShelterSubtitle => '放大后显示。可按灾害种类筛选';

  @override
  String get mapFacilityTitle => '防灾据点';

  @override
  String get mapLayerFacilityTitle => '防灾据点（供水点、防灾储备仓库）';

  @override
  String get mapLayerFacilitySubtitle => '放大后显示。可按种类筛选';

  @override
  String mapQuakeNearbyTitle(int count) {
    return '此附近的地震 $count次';
  }

  @override
  String get mapQuakeUnknownPlace => '震源（详情未发布）';

  @override
  String mapQuakeMaxIntensity(String value) {
    return '最大烈度$value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return '$name 周边的摄像头';
  }

  @override
  String get mapQuakeTapHint => '点击可显示周边（50km以内）的实时摄像头。';

  @override
  String get mapShelterNoticeTitle => '关于避难场所图层';

  @override
  String get mapShelterNoticeBody =>
      '・“指定紧急避难场所”是为躲避灾害危险、保护生命而逃往的场所，“指定避难所”是可停留一段时间的设施（以双层边框显示）\n・指定紧急避难场所按灾害种类分别指定，根据灾害种类不同，有些场所可能无法用于避难\n・信息由市町村提供，可能不是最新的，也可能有未收录的场所。准确信息请向相关市町村确认';

  @override
  String get mapShelterHazardAll => '全部';

  @override
  String get mapShelterDesignated => '指定避难所';

  @override
  String get mapShelterHazardsLabel => '对应的灾害种类';

  @override
  String get mapOpenRoute => '在 Google 地图中查看路线';

  @override
  String get mapNearbyCamerasButton => '周边的实时摄像头';

  @override
  String get mapFacilityNoticeTitle => '关于防灾据点图层';

  @override
  String get mapFacilityNoticeBody =>
      '・汇总了各地方政府作为开放数据公开的“应急供水设施”“储备仓库”“消防水源设施”一览。仅包含已公开数据的地方政府，未覆盖全国\n・消火栓和消防水池是消防作业用的设备，并非供一般民众使用\n・供水点在灾害发生时才开设，平时不一定能取水\n・更新时间因地方政府而异。准确信息请向各地方政府确认';

  @override
  String mapFacilityOwner(String owner) {
    return '提供：$owner';
  }

  @override
  String get mapFacilityGeocodedNote => '此位置根据地址推算得出（可能与实际位置有偏差）';

  @override
  String get mapFacilitySourceDataset => '出处（数据集）';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value小时';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value分钟';
  }

  @override
  String get mapNowcastNow => '当前（实测）';

  @override
  String get mapNowcastForecastHourly => '预报、1小时雨量';

  @override
  String get mapNowcastForecast => '预测';

  @override
  String mapNowcastAfter(String span, String kind) {
    return '$span后（$kind）';
  }

  @override
  String mapNowcastBefore(String span) {
    return '$span前（实测）';
  }

  @override
  String get mapNowcastBackToNow => '回到当前';

  @override
  String get mapNowcastNowMarker => '▲ 当前';

  @override
  String mapNowcastLast(String label) {
    return '$label（6小时后）';
  }

  @override
  String mapLegendRainRadar(String label) {
    return '雨云雷达 $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return '雨云雷达 $label（$kind）';
  }

  @override
  String get mapLegendRainWeak => '弱';

  @override
  String mapLegendQuakes(String period, int count) {
    return '震源 $period（$count次）';
  }

  @override
  String mapLegendIntensity(String value) {
    return '烈度$value';
  }

  @override
  String get mapLegendIntensity6Up => '近6级〜';

  @override
  String mapLegendRain24h(String label) {
    return '24小时降雨量 $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return '24小时降雨量 $label（放大显示观测值）';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title（警戒／特别警戒）';
  }

  @override
  String get mapLegendShelterZoomIn => '避难场所（放大后显示避难场所）';

  @override
  String mapLegendShelter(int count) {
    return '避难场所（$count处）';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return '避难场所（$count处、聚合显示）';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return '避难场所・$hazard（$count处）';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return '避难场所・$hazard（$count处、聚合显示）';
  }

  @override
  String get mapLegendShelterEmergency => '指定紧急避难场所';

  @override
  String get mapLegendShelterDesignated => '双层边框=指定避难所';

  @override
  String get mapLegendFacilityZoomIn => '防灾据点（放大后显示防灾据点）';

  @override
  String mapLegendFacilityNoData(String message) {
    return '防灾据点（$message）';
  }

  @override
  String mapLegendFacility(int count) {
    return '防灾据点（$count处）';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return '防灾据点（$count处、聚合显示）';
  }

  @override
  String get mapLegendFetchFailed => '无法获取';

  @override
  String get mapShelterFetchFailed => '无法获取避难场所（点击重试）';

  @override
  String get mapFacilityFetchFailed => '无法获取防灾据点（点击重试）';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24小时 ${mm}mm';
  }

  @override
  String get bosaiFetchFailedPull => '获取失败（下拉可重试）';

  @override
  String get bosaiTsunamiInfo => '海啸信息';

  @override
  String get bosaiUnknownPlace => '不明';

  @override
  String bosaiFetchFailedDetail(String error) {
    return '获取失败（$error）';
  }

  @override
  String get bosaiTimeJustNow => '刚刚';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$n分钟前';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$n小时前';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return '$month月$day日 $hour点左右';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return '$place的烈度';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return '$place周边的摄像头';
  }

  @override
  String get bosaiQuakeEmpty => '最近72小时内没有地震信息';

  @override
  String bosaiQuakeAsOf(String time) {
    return '（截至$time、从新到旧）';
  }

  @override
  String bosaiQuakeNote(String at) {
    return '来源：气象厅 地震信息（最近72小时）$at。点击后将显示发生震动的市区町村的实时摄像头列表（若没有按市区町村的烈度信息，则显示震源周边的摄像头）。';
  }

  @override
  String get bosaiBadgeTsunami => '海啸';

  @override
  String bosaiBadgeIntensity(String value) {
    return '烈度\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return '在$count个市区町村观测到';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return '无法获取最新信息（正在显示截至$time的信息）';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return '截至$time';
  }

  @override
  String get bosaiHeatOffSeason => '当前不在中暑警报的运行期间（每年4月下旬至10月下旬发布）';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return '（$month/$day $hour点发布）';
  }

  @override
  String get bosaiHeatTapHint => '点击后将显示该都道府县的摄像头列表。';

  @override
  String get bosaiHeatNone => '当前没有发布中暑警报';

  @override
  String get bosaiHeatToday => '今天';

  @override
  String get bosaiHeatTomorrow => '明天';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return '$pref的摄像头（中暑警报）';
  }

  @override
  String get bosaiWbgtCardTitle => '附近地点的暑热指数（WBGT）';

  @override
  String get bosaiWbgtUnavailable => '无法获取';

  @override
  String bosaiApproxDistance(String value) {
    return '约$value';
  }

  @override
  String get bosaiWbgtNow => '当前';

  @override
  String get bosaiWbgtNoCurrent => '无实测值';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level（$time）';
  }

  @override
  String get bosaiWbgtForecast => '预测';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hour点';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return '次日$hour点';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$month/$day $hour点';
  }

  @override
  String get bosaiQuakeMuniNote =>
      '来源：气象厅 地震信息（按烈度从大到小）。点击后将显示该市区町村的摄像头列表。没有摄像头的市区町村将显示震源周边的摄像头。';

  @override
  String get bosaiEpicenterNearby => '震源周边的摄像头（按距离排序）';

  @override
  String bosaiMuniCodeFallback(String code) {
    return '市区町村 $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref・显示震源周边的摄像头';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return '$name的摄像头（烈度$intensity）';
  }

  @override
  String bosaiLiveOnly(int count) {
    return '仅LIVE（$count）';
  }

  @override
  String get bosaiMuniFallbackNote => '由于没有对应此市区町村的摄像头，正在显示该都道府县内的全部摄像头';

  @override
  String get bosaiPrefNoCameras => '此都道府县没有摄像头';

  @override
  String get bosaiNoLiveCameras => '没有 LIVE 直播的摄像头';

  @override
  String get bosaiNoCamerasWithin50km => '50km以内没有摄像头';

  @override
  String get tipTitle => '支持开发者';

  @override
  String get tipIntro =>
      '本软件由个人开发和运营。您的支持将用于摄像头的调查与添加、监控服务器的维护、气象数据的支持等，也是持续更新的动力。支持完全自愿，不会带来功能上的差别。';

  @override
  String get tipCoffeeTitle => '用一罐咖啡歇口气';

  @override
  String get tipCoffeeSubtitle => '请开发者喝一罐开发间隙的咖啡';

  @override
  String get tipSweetsTitle => '用甜点补充糖分';

  @override
  String get tipSweetsSubtitle => '支持专注编码时的甜点与咖啡费用';

  @override
  String get tipLunchTitle => '用午餐为开发加油';

  @override
  String get tipLunchSubtitle => '请开发者吃一顿营养丰富的午餐，为下一个新功能做准备';

  @override
  String get tipDevToolsTitle => '支持开发工具费用';

  @override
  String get tipDevToolsSubtitle => '支持摄像头调查和服务器监控所用服务的费用';

  @override
  String get tipPreparing => '支持选项正在准备中。请稍后再试。';

  @override
  String get tipUnavailable => '此设备无法使用应用内购买。';

  @override
  String get tipPurchaseStartFailed => '无法开始购买';

  @override
  String get tipThanks => '感谢您的支持！这将成为开发的动力。';

  @override
  String tipPurchaseFailed(String error) {
    return '无法完成购买（$error）';
  }

  @override
  String get tipUnknownError => '未知错误';

  @override
  String get tipNoticeTitle => '购买前请确认';

  @override
  String get tipNoticeBody => '支持将通过 App Store 的应用内购买处理（退款遵循 Apple 的规定）。';

  @override
  String get tipEula => 'EULA（Apple 标准使用许可协议）';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return '记录：$count条\n最新：$name';
  }

  @override
  String get settingsDiagKindCrash => '崩溃';

  @override
  String get settingsDiagKindHang => '无响应';

  @override
  String get settingsDiagKindCpu => 'CPU 异常';

  @override
  String get settingsDiagKindDiskWrite => '磁盘写入异常';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return '类型：$kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return '读取错误：$error';
  }

  @override
  String get settingsDiagFetchFailed => '获取失败';

  @override
  String get settingsDiagNotAcquired => '未获取(null)';

  @override
  String settingsDiagAcquired(String prefix) {
    return '已获取($prefix…)';
  }

  @override
  String settingsDiagError(String error) {
    return '错误：$error';
  }

  @override
  String get stockpileTitle => '防灾储备';

  @override
  String get stockpileEntryTitle => '防灾储备（物资清单）';

  @override
  String get stockpileEntrySubtitle => '根据家庭人数计算所需数量并逐项确认';

  @override
  String get stockpileBosaiLink => '储备够了吗？打开物资清单';

  @override
  String get stockpileHouseholdTitle => '家庭人数';

  @override
  String get stockpileAdults => '成人';

  @override
  String get stockpileChildren => '儿童';

  @override
  String get stockpileDaysLabel => '储备天数';

  @override
  String stockpileDaysValue(int days) {
    return '$days天份';
  }

  @override
  String get stockpileSummaryTitle => '所需数量参考';

  @override
  String stockpileSummaryWater(int liters) {
    return '水 ${liters}L';
  }

  @override
  String stockpileSummaryMeals(int meals) {
    return '食物 $meals餐';
  }

  @override
  String get stockpileSummaryNote => '基于日本内阁府、农林水产省的参考标准（每人每天3L水、3餐）计算';

  @override
  String get stockpileSourceMaff => '农林水产省“家庭储备门户”';

  @override
  String get stockpileSourceCao => '内阁府“防灾信息页面”';

  @override
  String stockpileProgress(int done, int total) {
    return '已完成 $done/$total';
  }

  @override
  String stockpileRequired(String quantity, String unit) {
    return '需要 $quantity$unit';
  }

  @override
  String get stockpileSearchButton => '查找';

  @override
  String get stockpileExpirySet => '登记保质期';

  @override
  String stockpileExpiryOn(String date) {
    return '保质期 $date';
  }

  @override
  String get stockpileExpirySoon => '即将到期';

  @override
  String get stockpileExpired => '已过期';

  @override
  String get stockpileExpiryClear => '清除保质期';

  @override
  String get stockpileAddItem => '添加项目';

  @override
  String get stockpileItemNameLabel => '物品名称';

  @override
  String get stockpileItemQuantityLabel => '需要数量';

  @override
  String get stockpileItemCategoryLabel => '分类';

  @override
  String get stockpileDeleteItem => '删除项目';

  @override
  String get stockpileMarkPrepared => '已备好';

  @override
  String get stockpileSectionExpiry => '保质期';

  @override
  String get stockpileItemTapHint => '点击项目可登记保质期、查看选购要点和购买链接';

  @override
  String get stockpileOfficialSite => '官方网站';

  @override
  String get stockpileInfants => '婴幼儿（奶粉、尿布）';

  @override
  String stockpileNotifyExpiryBodyMany(String names, String date) {
    return '$names 即将到期（$date）';
  }

  @override
  String stockpileNotifyMoreItems(int count) {
    return '等$count项';
  }

  @override
  String get stockpileNotifyNameSeparator => '、';

  @override
  String stockpileDeleted(String item) {
    return '已删除“$item”';
  }

  @override
  String get stockpileUndo => '撤销';

  @override
  String get stockpileReset => '恢复初始状态';

  @override
  String get stockpileResetConfirm => '将清除所有勾选、保质期和添加的项目，恢复初始状态。确定吗？';

  @override
  String get stockpileSectionReminder => '提醒';

  @override
  String get stockpileExpiryReminder => '保质期前1个月提醒';

  @override
  String get stockpileExpiryReminderSubtitle => '在所登记保质期前1个月的上午9点，本机会发出通知';

  @override
  String get stockpileInspectionReminder => '检查日提醒';

  @override
  String get stockpileInspectionReminderSubtitle => '3月11日和9月1日（防灾日）上午9点通知';

  @override
  String get stockpileNotifyDenied => '未允许通知。请在系统“设置”中允许通知';

  @override
  String get stockpileNotifyTitle => '防灾储备检查';

  @override
  String stockpileNotifyExpiryBody(String item, String date) {
    return '“$item”即将到期（$date）';
  }

  @override
  String get stockpileNotifyInspectionBody => '请检查储备物资的保质期和数量';

  @override
  String get stockpileGuideWhy => '选购要点';

  @override
  String get stockpileGuideProducts => '可参考的产品';

  @override
  String get stockpileGuideProductsNote =>
      '点击可在合作商店搜索该商品（行尾的 ↗ 为厂商官方页面）。库存与价格请在各商店确认。';

  @override
  String get stockpileGuideSearch => '查找商品';

  @override
  String stockpileGuideSearchAt(String shop) {
    return '在$shop查找';
  }

  @override
  String get stockpileGuideSources => '出处';

  @override
  String get stockpileDisclaimer => '所需数量为参考值，请根据家庭情况调整';

  @override
  String get stockpileCatWaterFood => '水与食物';

  @override
  String get stockpileCatLightPower => '照明与电源';

  @override
  String get stockpileCatSanitation => '卫生';

  @override
  String get stockpileCatFirstAid => '急救与卫生用品';

  @override
  String get stockpileCatEvacuation => '避难用品';

  @override
  String get stockpileCatValuables => '贵重物品与信息';

  @override
  String get stockpileUnitLiter => 'L';

  @override
  String get stockpileUnitMeal => '餐';

  @override
  String get stockpileUnitPiece => '个';

  @override
  String get stockpileUnitSheet => '张';

  @override
  String get stockpileUnitRoll => '卷';

  @override
  String get stockpileUnitPair => '双';

  @override
  String get stockpileUnitPack => '包';

  @override
  String get stockpileUnitTimes => '次份';

  @override
  String get stockpileUnitDays => '天份';

  @override
  String get stockpileUnitSet => '套';

  @override
  String get stockpileItemWater => '长期保存水';

  @override
  String get stockpileItemStapleFood => '主食类应急食品';

  @override
  String get stockpileItemRetortFood => '软罐头食品';

  @override
  String get stockpileItemCannedFood => '罐头';

  @override
  String get stockpileItemBabyFormula => '婴儿奶粉、液态奶';

  @override
  String get stockpileItemFlashlight => '手电筒';

  @override
  String get stockpileItemBatteries => '干电池';

  @override
  String get stockpileItemPowerBank => '移动电源';

  @override
  String get stockpileItemRadio => '便携收音机';

  @override
  String get stockpileItemPortableToilet => '简易厕所';

  @override
  String get stockpileItemToiletPaper => '卫生纸';

  @override
  String get stockpileItemWetWipes => '湿纸巾';

  @override
  String get stockpileItemGarbageBags => '垃圾袋';

  @override
  String get stockpileItemDiapers => '纸尿裤';

  @override
  String get stockpileItemFirstAidKit => '急救包';

  @override
  String get stockpileItemMedicine => '常备药';

  @override
  String get stockpileItemMask => '口罩';

  @override
  String get stockpileItemDisinfectant => '消毒液';

  @override
  String get stockpileItemBackpack => '防灾背包';

  @override
  String get stockpileItemBlanket => '铝箔保温毯';

  @override
  String get stockpileItemGloves => '劳保手套';

  @override
  String get stockpileItemRope => '绳索';

  @override
  String get stockpileItemCash => '现金（含硬币）';

  @override
  String get stockpileItemIdCopy => '身份证件复印件';

  @override
  String get stockpileItemContactMemo => '联系方式备忘';

  @override
  String get stockpileItemCable => '充电线';

  @override
  String get stockpileChooseShop => '选择商店';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Japan Live Camera Map';

  @override
  String get commonClose => '關閉';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '確定';

  @override
  String get commonNext => '下一步';

  @override
  String get commonSkip => '略過';

  @override
  String get commonCopy => '複製';

  @override
  String get commonShare => '分享';

  @override
  String get commonRetry => '重試';

  @override
  String get commonOpenInSafari => '用 Safari 開啟';

  @override
  String get commonSource => '來源';

  @override
  String commonCameraCount(int count) {
    return '$count 台';
  }

  @override
  String get legalJapaneseAuthoritative => '本日文版為正文，翻譯僅供參考。';

  @override
  String get languageLabel => '語言';

  @override
  String get languageSettingTitle => '語言 / 言語';

  @override
  String get languageNameJa => '日本語（日文）';

  @override
  String get languageNameJaHira => 'やさしい日本語（簡明日文）';

  @override
  String get languageNameEn => 'English（英文）';

  @override
  String get languageFollowSystem => '依裝置設定';

  @override
  String get languageChooseTitle => '選擇語言';

  @override
  String get tabMap => '地圖';

  @override
  String get tabList => '列表';

  @override
  String get tabBosai => '災害快報';

  @override
  String get tabFavorites => '我的最愛';

  @override
  String get tabStockpile => '備災';

  @override
  String get tabSettings => '設定';

  @override
  String get onboardingTitle1 => '從地圖立即找到';

  @override
  String get onboardingBody1 => '地圖上顯示全日本超過 1 萬台即時攝影機，並依河川、道路、海岸等類別以顏色區分。';

  @override
  String get onboardingTitle2 => '無法顯示的攝影機會自動隱藏';

  @override
  String get onboardingBody2 => '系統會定期自動確認，無法取得影像的攝影機將從地圖上移除，並必定顯示取得時間。';

  @override
  String get onboardingTitle3 => '明確標示來源與授權';

  @override
  String get onboardingBody3 => '所有影像都會與提供者一併顯示。影像的權利歸各提供者所有。';

  @override
  String get onboardingNotifyOptIn => '接收災害通知';

  @override
  String get onboardingNotifyOptInDetail =>
      '當發生震度5弱以上的地震或發布特別警報（全國）時通知您。之後可在設定中變更。';

  @override
  String get onboardingDisclaimerTitle => '使用前的重要提醒';

  @override
  String get onboardingAgreeAndStart => '同意並開始';

  @override
  String get disclaimerText =>
      '攝影機影像僅顯示有限範圍的狀況。受攝影機性能所限，在光線環境或氣象條件不佳時可能不清晰。是否避難，請依水位資訊、氣象警報及地方政府發布的避難資訊判斷。本應用程式僅提供參考資訊。';

  @override
  String get updateRequiredTitle => '需要更新';

  @override
  String get updateRequiredBody => '此版本已停止支援。\n請至 App Store 更新至最新版本。';

  @override
  String get updateOpenStore => '開啟 App Store';

  @override
  String get categoryRiver => '河川';

  @override
  String get categoryRoad => '道路';

  @override
  String get categoryVolcano => '火山';

  @override
  String get categoryDam => '水壩';

  @override
  String get categoryCoast => '海岸';

  @override
  String get categoryPort => '港灣';

  @override
  String get categoryScenic => '景觀';

  @override
  String get categoryHealing => '療癒';

  @override
  String get categoryOther => '其他';

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
  String get pref22 => '靜岡';

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
  String get pref34 => '廣島';

  @override
  String get pref35 => '山口';

  @override
  String get pref36 => '德島';

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
  String get pref46 => '鹿兒島';

  @override
  String get pref47 => '沖繩';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSupportTitle => '支持開發者';

  @override
  String get settingsSupportBody => '從一罐咖啡（¥200）開始。請支持個人開發持續下去';

  @override
  String get settingsSupportButton => '支持';

  @override
  String get settingsSectionNotify => '災害通知';

  @override
  String get settingsQuakeTitle => '震度5弱以上的地震';

  @override
  String get settingsQuakeSubtitleOff => '發生大地震時通知您，並引導至周邊的攝影機';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return '通知等級：$level';
  }

  @override
  String get settingsWarningTitle => '特別警報';

  @override
  String get settingsWarningSubtitle => '發布大雨、暴風、暴潮等特別警報時通知您';

  @override
  String get settingsNotifyArea => '通知的地區';

  @override
  String get settingsNotifyAreaAll => '全日本';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first 等 $count 個地區';
  }

  @override
  String get settingsNotifyAreaHint => '僅通知所選都道府縣的特別警報。未選擇任何項目時，通知範圍為全日本';

  @override
  String get settingsNotifyAreaResetAll => '恢復為全日本';

  @override
  String get settingsNotifyLevel => '通知的等級';

  @override
  String get settingsNotifyLevelSpecialOnly => '僅特別警報（等級5）';

  @override
  String get settingsNotifyLevelDangerUp => '危險警報以上（等級4以上）';

  @override
  String get settingsNotifyLevelNote => '危險警報是相當於大雨、洪水、暴潮、土石流警戒等級4的發布';

  @override
  String get settingsNotifyDelayNote => '※通知可能比氣象廳發布晚 5～15 分鐘左右，無法取代緊急地震速報';

  @override
  String get settingsNotifyDenied => '尚未允許通知。請於 iOS 的「設定」App 中允許通知';

  @override
  String get settingsSectionData => '資料取得';

  @override
  String get settingsWifiOnly => '僅在 Wi-Fi 連線時取得影像';

  @override
  String get settingsWifiOnlySubtitle => '可節省行動網路用量（地圖與攝影機列表仍會顯示）';

  @override
  String get settingsClearCache => '清除快取';

  @override
  String get settingsClearCacheSubtitle => '刪除攝影機列表等已儲存的資料並重新取得';

  @override
  String get settingsClearCacheDone => '已清除快取並重新取得資料';

  @override
  String get settingsSectionFilterDefaults => '篩選的預設值';

  @override
  String get settingsShowWorld => '顯示海外的攝影機';

  @override
  String get settingsVideoOnly => '僅影片攝影機';

  @override
  String get settingsHideUncertain => '隱藏位置不明確的攝影機';

  @override
  String get settingsHideUncertainSubtitle => '隱藏黃色外框的圖釘（大致位置／代表點）';

  @override
  String get settingsFilterDefaultsNote => '此處的設定會成為下次啟動時的初始狀態（也可從地圖圖例暫時變更）';

  @override
  String get settingsSectionRequest => '攝影機的新增與移除申請';

  @override
  String get settingsRequestForm => '諮詢・申請表單';

  @override
  String get settingsRequestFormSubtitle =>
      '申請新增攝影機或要求移除刊登請由此進入（免登入）。設置者與營運者提出的移除申請將儘速處理';

  @override
  String get settingsSectionLicense => '來源・授權';

  @override
  String get settingsAttributionList => '來源・授權一覽';

  @override
  String get settingsAttributionListSubtitle => '攝影機影像提供者的一覽';

  @override
  String get settingsTerms => '使用條款';

  @override
  String get settingsPrivacy => '隱私權政策';

  @override
  String get settingsLegalJapaneseOnly => '使用條款與隱私權政策的內文僅有日文版（以日文為正文）';

  @override
  String get settingsSectionAbout => '關於本應用程式';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsInvite => '邀請朋友';

  @override
  String get settingsInviteSubtitle => '以 QR 碼或連結分享 App Store 頁面';

  @override
  String get settingsInviteDialogBody =>
      '掃描 QR 碼或傳送連結，\n即可開啟 App Store 的應用程式頁面';

  @override
  String get settingsInviteShareText => 'Japan Live Camera Map - 河川、道路、防災';

  @override
  String get settingsLinkCopied => '已複製連結';

  @override
  String get settingsReview => '為應用程式評分';

  @override
  String get settingsReviewSubtitle => '在 App Store 撰寫評論';

  @override
  String get settingsFollowX => '在 X 上追蹤';

  @override
  String get settingsFollowXSubtitle => '@kotopapa8 — 新攝影機與新功能的消息';

  @override
  String get settingsOtherApps => '開發者的其他應用程式';

  @override
  String get settingsShowMoreApps => '查看其他應用程式';

  @override
  String get settingsSectionDisclaimer => '免責聲明';

  @override
  String get settingsOssLicenses => '開放原始碼授權';

  @override
  String get settingsNotifyDiag => '通知診斷';

  @override
  String get settingsNotifyDiagSubtitle => '通知未送達時的狀態確認';

  @override
  String get settingsNotifyDiagUnlocked => '已顯示通知診斷（位於災害通知項目內）';

  @override
  String settingsNotifyPermission(String value) {
    return '通知權限：$value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'APNs 權杖：$value';
  }

  @override
  String get settingsNotifyFcm => 'FCM 權杖：';

  @override
  String get settingsCopyToken => '複製權杖';

  @override
  String get settingsTokenCopied => '已複製 FCM 權杖';

  @override
  String get settingsCrashDiag => '當機診斷資料';

  @override
  String get settingsCrashDiagSubtitle => '顯示並複製強制結束的紀錄（MetricKit）';

  @override
  String get settingsCrashDiagNone => '目前尚無診斷資料';

  @override
  String get settingsCrashDiagNoneHint => '目前尚無診斷資料。\n當機後重新啟動應用程式便會留下紀錄';

  @override
  String get settingsCopyFullText => '複製全文';

  @override
  String get settingsJsonCopied => '已複製診斷 JSON';

  @override
  String get attributionScreenTitle => '來源・授權一覽';

  @override
  String get attributionOpenYoutube => '在 YouTube 查看提供者';

  @override
  String get attributionOpenSite => '開啟提供者的網站';

  @override
  String listTitle(int count) {
    return '列表（$count）';
  }

  @override
  String get listSearchHint => '以攝影機、河川、路線名稱搜尋';

  @override
  String get listEmpty => '沒有符合條件的攝影機';

  @override
  String get listRanking => '排行榜';

  @override
  String favoritesTitle(int count) {
    return '我的最愛（$count）';
  }

  @override
  String get favoritesEmpty => '尚未加入任何最愛。\n在地圖上開啟攝影機並點選★即可加入。';

  @override
  String get favoritesEmptyFiltered => '沒有符合篩選條件的最愛';

  @override
  String get favoritesSort => '排序';

  @override
  String get favoritesSortNewest => '依加入時間由新到舊';

  @override
  String get favoritesSortOldest => '依加入時間由舊到新';

  @override
  String get favoritesSortName => '依名稱';

  @override
  String get favoritesSortCategory => '依類別';

  @override
  String get favoritesToggleView => '切換顯示';

  @override
  String get favoritesRefreshAll => '全部更新（每次 3 台依序取得）';

  @override
  String get favoritesVideoOnly => '僅影片';

  @override
  String get rankingTitle => '全日本排行榜';

  @override
  String get rankingModeNow => '現在熱門（24 小時 TOP10）';

  @override
  String get rankingModeWeek => '熱門觀看（7 天 TOP30）';

  @override
  String get rankingModeFavorites => '收藏最多（TOP20）';

  @override
  String get rankingNote => '依據所有使用者的匿名統計製作的排行榜（每日更新）';

  @override
  String get rankingEmpty => '尚無統計資料（每日更新一次）';

  @override
  String get rankingPreparing => '全日本排行榜準備中。\n統計每 3 小時進行一次。';

  @override
  String get rankingFetchFailed => '取得失敗';

  @override
  String rankingFetchFailedHttp(int code) {
    return '取得失敗（HTTP $code）';
  }

  @override
  String get rankingUnitViews => '次';

  @override
  String get rankingUnitFavorites => '件';

  @override
  String get detailLive => '直播中';

  @override
  String get detailTimeUnknown => '取得時間不明';

  @override
  String detailRefreshEvery(int sec) {
    return '每 $sec 秒更新';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$sec 秒';
  }

  @override
  String get detailRefreshNow => '更新';

  @override
  String get detailPosRepresentative => '位置為廣域的代表點';

  @override
  String get detailPosApprox => '位置為大致位置';

  @override
  String get detailNotUpdating => '影像未更新';

  @override
  String get detailWorld => '日本境外';

  @override
  String get detailCategoryAndPlace => '類別・位置';

  @override
  String get detailOpenMap => '在地圖上查看';

  @override
  String get detailHotelsTitle => '尋找附近住宿';

  @override
  String get detailOpenSourceSite => '查看來源網站';

  @override
  String get detailOpenYoutube => '在 YouTube 觀看';

  @override
  String get detailOpenChannel => '查看頻道頁面';

  @override
  String get detailOpenOriginalPage => '在原始頁面觀看';

  @override
  String get detailReportProblem => '回報這台攝影機的問題';

  @override
  String get detailNearby => '周邊的攝影機';

  @override
  String detailDistanceKm(String km) {
    return '約 $km 公里';
  }

  @override
  String get detailWifiOnlyBlocked => '依您的設定，僅在 Wi-Fi 連線時取得影像';

  @override
  String get detailNoImage => '目前無法取得影像';

  @override
  String get detailEmbedBlockedYoutube => '依提供者的設定，\n此影片無法在應用程式內播放';

  @override
  String get detailEmbedBlockedPage => '依提供者的使用條件，\n無法在應用程式內顯示';

  @override
  String get detailIHighwayTitle => '在 NEXCO 官方「iHighway」\n查看即時攝影機';

  @override
  String get detailIHighwayBody => '點選後會以應用程式內建瀏覽器開啟官方網站，\n並自動移動至這台攝影機的位置';

  @override
  String get detailIHighwayHost => 'ihighway.jp（NEXCO 官方）';

  @override
  String get detailMapTileGsi => '地理院圖磚';

  @override
  String get elevationLoading => '海拔 …';

  @override
  String elevationValue(String value, String source) {
    return '海拔 $value（$source）';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return '$time 取得$relative';
  }

  @override
  String get timeRelJustNow => '（剛剛）';

  @override
  String timeRelMinutes(int n) {
    return '（$n 分鐘前）';
  }

  @override
  String timeRelHours(int n) {
    return '（$n 小時前）';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$month 月 $day 日';
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
  String get warning07 => '海浪警報';

  @override
  String get warning08 => '暴潮警報';

  @override
  String get warning09 => '土石流警報';

  @override
  String get warning43 => '大雨危險警報';

  @override
  String get warning44 => '洪水危險警報';

  @override
  String get warning48 => '暴潮危險警報';

  @override
  String get warning49 => '土石流危險警報';

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
  String get warning37 => '海浪特別警報';

  @override
  String get warning38 => '暴潮特別警報';

  @override
  String get warning39 => '土石流特別警報';

  @override
  String get advisory10 => '大雨注意報';

  @override
  String get advisory12 => '大雪注意報';

  @override
  String get advisory13 => '風雪注意報';

  @override
  String get advisory14 => '閃電注意報';

  @override
  String get advisory15 => '強風注意報';

  @override
  String get advisory16 => '浪高注意報';

  @override
  String get advisory17 => '融雪注意報';

  @override
  String get advisory18 => '洪水注意報';

  @override
  String get advisory19 => '暴潮注意報';

  @override
  String get advisory20 => '濃霧注意報';

  @override
  String get advisory21 => '乾燥注意報';

  @override
  String get advisory22 => '雪崩注意報';

  @override
  String get advisory23 => '低溫注意報';

  @override
  String get advisory24 => '結霜注意報';

  @override
  String get advisory25 => '結冰注意報';

  @override
  String get advisory26 => '積雪注意報';

  @override
  String get advisory29 => '土石流注意報';

  @override
  String get mapLocationDenied => '尚未允許使用定位資訊（可從設定變更）';

  @override
  String get mapLocationFailed => '無法取得目前位置';

  @override
  String get mapLegendTitle => '圖例・篩選';

  @override
  String get mapLegendSearchHint => '以攝影機、營運者、河川／路線名稱搜尋';

  @override
  String get mapFilterFavoritesOnly => '僅我的最愛';

  @override
  String get mapFilterOkOnly => '僅顯示目前有影像的';

  @override
  String get mapLegendLiveDot => '紅點 = 影片（直播）';

  @override
  String get mapLegendUncertain => '黃色外框 = 位置未確定（大致位置／代表點）';

  @override
  String get mapLegendFrozen => '半透明 = 影像長時間未更新';

  @override
  String get mapLegendFavorite => '金色星號 = 已加入最愛';

  @override
  String get mapLegendCluster => '數字圓圈 = 周邊攝影機的集合（點選可放大）';

  @override
  String get mapSearchTitle => '搜尋地點';

  @override
  String get mapSearchHint => '地名、地址（例：渋谷、金沢市広坂）';

  @override
  String get mapSearchNotFound => '找不到結果。請改以地名、地址或攝影機名稱試試';

  @override
  String get mapSearchSectionCameras => '攝影機';

  @override
  String get mapSearchSectionPlaces => '地點';

  @override
  String mapPointCameras(int count) {
    return '此地點的攝影機（$count 台）';
  }

  @override
  String mapFilteredCount(int count) {
    return '篩選中 $count 台';
  }

  @override
  String mapTotalCount(int count) {
    return '$count 台';
  }

  @override
  String get mapLayersTooltip => '地圖圖層';

  @override
  String get bosaiTitle => '災害快報';

  @override
  String get bosaiTabQuake => '地震・海嘯';

  @override
  String get bosaiTabWarning => '氣象警報';

  @override
  String get bosaiTabHeat => '中暑';

  @override
  String get bosaiNoWarnings => '目前沒有發布中的警報與注意報';

  @override
  String get bosaiWarningNoteNone => '來源：氣象廳。目前沒有發布警報與特別警報。僅發布注意報的地區可從下方列表確認。';

  @override
  String get bosaiWarningNote => '來源：氣象廳 氣象警報・注意報。點選後會顯示該都道府縣的攝影機列表。';

  @override
  String bosaiAdvisoryRegions(int count) {
    return '發布注意報中的地區（$count 個都道府縣）';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return '$pref的警報發布地區';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return '$pref的注意報發布地區';
  }

  @override
  String get bosaiMuniNote => '來源：氣象廳。點選後會顯示該市區町村的攝影機列表';

  @override
  String get bosaiMuniFetchFailed => '無法取得發布區域的詳細資訊';

  @override
  String get bosaiMuniNone => '目前沒有發布中的市區町村';

  @override
  String bosaiCameraCount(int count) {
    return '攝影機 $count 台';
  }

  @override
  String get bosaiNoCamera => '無攝影機';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return '$name的攝影機（警報發布中）';
  }

  @override
  String get settingsJmaDictionary => '關於防災用語的翻譯';

  @override
  String get settingsJmaDictionaryNote =>
      '警報名稱、注意報名稱與震度等各語言譯文，均依循氣象廳「氣象資訊等多語言辭典」。來源：氣象廳網站';

  @override
  String get hazardFloodTitle => '洪水淹水預想區域（假設最大規模）';

  @override
  String get hazardLandslideTitle => '土砂災害警戒區域（崖崩·土石流·地滑）';

  @override
  String get hazardTsunamiTitle => '海嘯淹水預想';

  @override
  String get hazardHightideTitle => '暴潮淹水預想區域';

  @override
  String get hazardLandslideSteepSlope => '陡坡地';

  @override
  String get hazardLandslideDebrisFlow => '土石流';

  @override
  String get hazardLandslideSlide => '地滑';

  @override
  String get hazardDisclaimer => '最新且詳細的資訊請確認各市町村的災害潛勢地圖。避難判斷請依循地方政府發布的避難資訊';

  @override
  String get facilityKindWater => '供水據點・緊急供水設施';

  @override
  String get facilityKindStock => '防災儲備倉庫';

  @override
  String get facilityKindFireWater => '消防水源（消防栓・防火水槽）';

  @override
  String get facilityKindWaterShort => '供水據點';

  @override
  String get facilityKindStockShort => '防災儲備倉庫';

  @override
  String get facilityKindFireWaterShort => '消防水源';

  @override
  String get facilityDisclaimer => '僅限有公開資料的地方政府。最新資訊請洽各地方政府';

  @override
  String get facilityNoData => '此地區尚無資料';

  @override
  String get shelterHazardFlood => '洪水';

  @override
  String get shelterHazardSediment => '土石流';

  @override
  String get shelterHazardHightide => '暴潮';

  @override
  String get shelterHazardEarthquake => '地震';

  @override
  String get shelterHazardTsunami => '海嘯';

  @override
  String get shelterHazardFire => '火災';

  @override
  String get shelterHazardInlandFlood => '內澇';

  @override
  String get shelterHazardVolcano => '火山';

  @override
  String get shelterDisclaimer => '最新且詳細的狀況請洽各市町村';

  @override
  String get riskLandTitle => '土石流危險分布圖';

  @override
  String get riskInundTitle => '淹水危險分布圖';

  @override
  String get riskFloodTitle => '洪水危險分布圖';

  @override
  String get riskLandSubtitle => '土石流災害的危險度（1 公里網格・每 10 分鐘更新）';

  @override
  String get riskInundSubtitle => '淹水災害的危險度（1 公里網格・每 10 分鐘更新）';

  @override
  String get riskFloodSubtitle => '洪水災害的危險度（依河川・每 10 分鐘更新）';

  @override
  String get riskLevelWatch => '留意後續資訊';

  @override
  String get riskLevelCaution => '注意';

  @override
  String get riskLevelWarning => '警戒';

  @override
  String get riskLevelDanger => '危險';

  @override
  String get riskLevelCritical => '災害逼近';

  @override
  String get wbgtLevelDanger => '危險';

  @override
  String get wbgtLevelSevereWarning => '嚴重警戒';

  @override
  String get wbgtLevelWarning => '警戒';

  @override
  String get wbgtLevelCaution => '注意';

  @override
  String get wbgtLevelSafe => '大致安全';

  @override
  String get heatAlertSpecial => '中暑特別警報';

  @override
  String get heatAlertSpecialPending => '中暑特別警報（判定中）';

  @override
  String get heatAlertWarning => '中暑警報';

  @override
  String get heatAlertDisclaimer => '本資訊僅供參考。正式發布內容請確認中暑預防資訊網站等';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어（韓文）';

  @override
  String get languageNameVi => 'Tiếng Việt（越南文）';

  @override
  String get mapLayerPanelSubtitle => '地圖上僅能疊加顯示一種圖層';

  @override
  String get mapLayerNone => '不顯示';

  @override
  String get mapLayerSectionWeather => '氣象';

  @override
  String get mapLayerRainRadarTitle => '雨雲雷達（現在）';

  @override
  String get mapLayerRainRadarSubtitle => '高清降水即時預測・每 5 分鐘更新';

  @override
  String get mapLayerQuakesTitle => '震源';

  @override
  String get mapQuakePeriodDay => '24 小時';

  @override
  String get mapQuakePeriodWeek => '7 天';

  @override
  String get mapQuakePeriodMonth => '30 天';

  @override
  String get mapLayerRain24hTitle => '24 小時降雨量';

  @override
  String get mapLayerRain24hSubtitle => '氣象廳的解析雨量（面）＋放大後顯示 AMeDAS 觀測值';

  @override
  String get mapLayerSectionHazard => '災害潛勢地圖';

  @override
  String get mapHazardLandslideSubtitle => '陡坡地・土石流・地滑（黃＝警戒區域／紅＝特別警戒區域）';

  @override
  String get mapHazardDepthSubtitle => '以顏色區分顯示預想的淹水深度';

  @override
  String get mapShelterTitle => '避難場所';

  @override
  String get mapLayerShelterTitle => '避難場所（指定緊急避難場所・指定避難所）';

  @override
  String get mapLayerShelterSubtitle => '放大後顯示。可依災害種類篩選';

  @override
  String get mapFacilityTitle => '防災據點';

  @override
  String get mapLayerFacilityTitle => '防災據點（供水據點・防災儲備倉庫）';

  @override
  String get mapLayerFacilitySubtitle => '放大後顯示。可依種類篩選';

  @override
  String mapQuakeNearbyTitle(int count) {
    return '這附近的地震 $count 件';
  }

  @override
  String get mapQuakeUnknownPlace => '震源（詳細尚未發布）';

  @override
  String mapQuakeMaxIntensity(String value) {
    return '最大震度$value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return '$name 周邊的攝影機';
  }

  @override
  String get mapQuakeTapHint => '點選可顯示周邊的即時攝影機（50 公里以內）';

  @override
  String get mapShelterNoticeTitle => '關於避難場所圖層';

  @override
  String get mapShelterNoticeBody =>
      '・「指定緊急避難場所」是為了保護生命、躲避災害危險而前往的場所；「指定避難所」則是可停留一段時間的設施（以雙框顯示）\n・指定緊急避難場所是依災害種類個別指定的，因此依災害種類不同，可能無法前往避難\n・因資訊由各市町村提供，可能並非最新，也可能有未刊載的場所。正確資訊請洽該市町村確認';

  @override
  String get mapShelterHazardAll => '全部';

  @override
  String get mapShelterDesignated => '指定避難所';

  @override
  String get mapShelterHazardsLabel => '對應的災害種類';

  @override
  String get mapOpenRoute => '用 Google 地圖查看路線';

  @override
  String get mapNearbyCamerasButton => '周邊的即時攝影機';

  @override
  String get mapFacilityNoticeTitle => '關於防災據點圖層';

  @override
  String get mapFacilityNoticeBody =>
      '・本圖層彙整了各地方政府以開放資料公開的「緊急供水設施」「儲備倉庫」「消防水源設施」清單。僅包含有公開資料的地方政府，並未涵蓋全日本\n・消防栓與防火水槽是供消防活動使用的設備，並非供一般民眾使用\n・供水據點是在災害發生時才開設，平時不一定能取得供水\n・更新時期因地方政府而異。正確資訊請洽各地方政府確認';

  @override
  String mapFacilityOwner(String owner) {
    return '提供：$owner';
  }

  @override
  String get mapFacilityGeocodedNote => '這是依地址推估的位置（可能與實際地點有落差）';

  @override
  String get mapFacilitySourceDataset => '來源（資料集）';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value 小時';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value 分鐘';
  }

  @override
  String get mapNowcastNow => '現在（實測）';

  @override
  String get mapNowcastForecastHourly => '預報・1 小時雨量';

  @override
  String get mapNowcastForecast => '預測';

  @override
  String mapNowcastAfter(String span, String kind) {
    return '$span後（$kind）';
  }

  @override
  String mapNowcastBefore(String span) {
    return '$span前（實測）';
  }

  @override
  String get mapNowcastBackToNow => '回到現在';

  @override
  String get mapNowcastNowMarker => '▲ 現在';

  @override
  String mapNowcastLast(String label) {
    return '$label（6 小時後）';
  }

  @override
  String mapLegendRainRadar(String label) {
    return '雨雲雷達 $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return '雨雲雷達 $label（$kind）';
  }

  @override
  String get mapLegendRainWeak => '弱';

  @override
  String mapLegendQuakes(String period, int count) {
    return '震源 $period（$count 件）';
  }

  @override
  String mapLegendIntensity(String value) {
    return '震度$value';
  }

  @override
  String get mapLegendIntensity6Up => '6弱～';

  @override
  String mapLegendRain24h(String label) {
    return '24 小時降雨量 $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return '24 小時降雨量 $label（放大顯示觀測值）';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title（警戒／特別警戒）';
  }

  @override
  String get mapLegendShelterZoomIn => '避難場所（放大後顯示避難場所）';

  @override
  String mapLegendShelter(int count) {
    return '避難場所（$count 件）';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return '避難場所（$count 件・合併顯示）';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return '避難場所・$hazard（$count 件）';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return '避難場所・$hazard（$count 件・合併顯示）';
  }

  @override
  String get mapLegendShelterEmergency => '指定緊急避難場所';

  @override
  String get mapLegendShelterDesignated => '雙框＝指定避難所';

  @override
  String get mapLegendFacilityZoomIn => '防災據點（放大後顯示防災據點）';

  @override
  String mapLegendFacilityNoData(String message) {
    return '防災據點（$message）';
  }

  @override
  String mapLegendFacility(int count) {
    return '防災據點（$count 件）';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return '防災據點（$count 件・合併顯示）';
  }

  @override
  String get mapLegendFetchFailed => '無法取得';

  @override
  String get mapShelterFetchFailed => '無法取得避難場所（點選可重試）';

  @override
  String get mapFacilityFetchFailed => '無法取得防災據點（點選可重試）';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24 小時 ${mm}mm';
  }

  @override
  String get bosaiFetchFailedPull => '取得失敗（下拉可重新取得）';

  @override
  String get bosaiTsunamiInfo => '海嘯訊息';

  @override
  String get bosaiUnknownPlace => '不明';

  @override
  String bosaiFetchFailedDetail(String error) {
    return '取得失敗（$error）';
  }

  @override
  String get bosaiTimeJustNow => '剛剛';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$n 分鐘前';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$n 小時前';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return '$month 月 $day 日 $hour 時左右';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return '$place的震度';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return '$place周邊的攝影機';
  }

  @override
  String get bosaiQuakeEmpty => '最近 72 小時內沒有地震資訊';

  @override
  String bosaiQuakeAsOf(String time) {
    return '（$time 時點・由新到舊）';
  }

  @override
  String bosaiQuakeNote(String at) {
    return '來源：氣象廳 地震資訊（最近 72 小時）$at。點選後會顯示感受到搖晃的市區町村的即時攝影機列表（若無各市區町村的震度，則顯示震源周邊）。';
  }

  @override
  String get bosaiBadgeTsunami => '海嘯';

  @override
  String bosaiBadgeIntensity(String value) {
    return '震度\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return '於 $count 個市區町村觀測到';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return '無法取得最新資訊（顯示的是 $time 時點的資訊）';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return '$time 時點';
  }

  @override
  String get bosaiHeatOffSeason => '目前不在中暑警報的運作期間（每年 4 月下旬至 10 月下旬發布）';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return '（$month/$day $hour 時發布）';
  }

  @override
  String get bosaiHeatTapHint => '點選後會顯示該都道府縣的攝影機列表。';

  @override
  String get bosaiHeatNone => '目前沒有發布中暑警報';

  @override
  String get bosaiHeatToday => '今天';

  @override
  String get bosaiHeatTomorrow => '明天';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return '$pref的攝影機（中暑警報）';
  }

  @override
  String get bosaiWbgtCardTitle => '附近地點的暑熱壓力指數（WBGT）';

  @override
  String get bosaiWbgtUnavailable => '無法取得';

  @override
  String bosaiApproxDistance(String value) {
    return '約 $value';
  }

  @override
  String get bosaiWbgtNow => '現在';

  @override
  String get bosaiWbgtNoCurrent => '無實測值';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level（$time）';
  }

  @override
  String get bosaiWbgtForecast => '預測';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hour 時';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return '隔天 $hour 時';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$month/$day $hour 時';
  }

  @override
  String get bosaiQuakeMuniNote =>
      '來源：氣象廳 地震資訊（依震度由大到小）。點選後會顯示該市區町村的攝影機列表。沒有攝影機的市區町村，將顯示震源周邊的攝影機。';

  @override
  String get bosaiEpicenterNearby => '震源周邊的攝影機（依距離排序）';

  @override
  String bosaiMuniCodeFallback(String code) {
    return '市區町村 $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref・顯示震源周邊的攝影機';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return '$name的攝影機（震度$intensity）';
  }

  @override
  String bosaiLiveOnly(int count) {
    return '僅 LIVE（$count）';
  }

  @override
  String get bosaiMuniFallbackNote => '由於沒有對應此市區町村的攝影機，因此顯示該都道府縣內的所有攝影機';

  @override
  String get bosaiPrefNoCameras => '此都道府縣沒有攝影機';

  @override
  String get bosaiNoLiveCameras => '沒有 LIVE 直播的攝影機';

  @override
  String get bosaiNoCamerasWithin50km => '50 公里以內沒有攝影機';

  @override
  String get tipTitle => '支持開發者';

  @override
  String get tipIntro =>
      '本應用程式由個人開發與營運。您的支持將用於攝影機的調查與新增、監控伺服器的維護、氣象資料的對應等，也是持續更新的動力。支持完全出於自願，不會有功能上的差異。';

  @override
  String get tipCoffeeTitle => '用罐裝咖啡休息一下';

  @override
  String get tipCoffeeSubtitle => '請開發者喝一罐開發空檔的咖啡';

  @override
  String get tipSweetsTitle => '用甜點補充糖分';

  @override
  String get tipSweetsSubtitle => '支持專注寫程式所需的甜點與咖啡廳費用';

  @override
  String get tipLunchTitle => '用午餐為開發加油';

  @override
  String get tipLunchSubtitle => '請開發者吃一頓營養滿分的午餐，迎接下一個新功能';

  @override
  String get tipDevToolsTitle => '支持開發工具的費用';

  @override
  String get tipDevToolsSubtitle => '支持攝影機調查與伺服器監控所使用的服務費用';

  @override
  String get tipPreparing => '支持選項準備中，請稍後再試。';

  @override
  String get tipUnavailable => '此裝置無法使用應用程式內購買。';

  @override
  String get tipPurchaseStartFailed => '無法開始購買';

  @override
  String get tipThanks => '感謝您的支持！這是開發的最大動力。';

  @override
  String tipPurchaseFailed(String error) {
    return '無法完成購買（$error）';
  }

  @override
  String get tipUnknownError => '不明的錯誤';

  @override
  String get tipNoticeTitle => '購買前請確認';

  @override
  String get tipNoticeBody => '支持將透過 App Store 的應用程式內購買處理（退款依 Apple 的規定辦理）。';

  @override
  String get tipEula => 'EULA（Apple 標準使用許可協議）';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return '紀錄：$count 件\n最新：$name';
  }

  @override
  String get settingsDiagKindCrash => '當機';

  @override
  String get settingsDiagKindHang => '停止回應';

  @override
  String get settingsDiagKindCpu => 'CPU 異常';

  @override
  String get settingsDiagKindDiskWrite => '磁碟寫入異常';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return '種類：$kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return '讀取錯誤：$error';
  }

  @override
  String get settingsDiagFetchFailed => '取得失敗';

  @override
  String get settingsDiagNotAcquired => '未取得(null)';

  @override
  String settingsDiagAcquired(String prefix) {
    return '已取得($prefix…)';
  }

  @override
  String settingsDiagError(String error) {
    return '錯誤：$error';
  }

  @override
  String get stockpileTitle => '防災儲備';

  @override
  String get stockpileEntryTitle => '防災儲備（物資清單）';

  @override
  String get stockpileEntrySubtitle => '依家庭人數計算所需數量並逐項確認';

  @override
  String get stockpileBosaiLink => '儲備夠了嗎？打開物資清單';

  @override
  String get stockpileHouseholdTitle => '家庭人數';

  @override
  String get stockpileAdults => '成人';

  @override
  String get stockpileChildren => '兒童';

  @override
  String get stockpileDaysLabel => '儲備天數';

  @override
  String stockpileDaysValue(int days) {
    return '$days天份';
  }

  @override
  String get stockpileSummaryTitle => '所需數量參考';

  @override
  String stockpileSummaryWater(int liters) {
    return '水 ${liters}L';
  }

  @override
  String stockpileSummaryMeals(int meals) {
    return '食物 $meals餐';
  }

  @override
  String get stockpileSummaryNote => '依據日本內閣府、農林水產省的參考標準（每人每天3L水、3餐）計算';

  @override
  String get stockpileSourceMaff => '農林水產省「家庭儲備入口網」';

  @override
  String get stockpileSourceCao => '內閣府「防災資訊網頁」';

  @override
  String stockpileProgress(int done, int total) {
    return '已完成 $done/$total';
  }

  @override
  String stockpileRequired(String quantity, String unit) {
    return '需要 $quantity$unit';
  }

  @override
  String get stockpileSearchButton => '查找';

  @override
  String get stockpileExpirySet => '登記保存期限';

  @override
  String stockpileExpiryOn(String date) {
    return '保存期限 $date';
  }

  @override
  String get stockpileExpirySoon => '即將到期';

  @override
  String get stockpileExpired => '已過期';

  @override
  String get stockpileExpiryClear => '清除保存期限';

  @override
  String get stockpileAddItem => '新增項目';

  @override
  String get stockpileItemNameLabel => '物品名稱';

  @override
  String get stockpileItemQuantityLabel => '需要數量';

  @override
  String get stockpileItemCategoryLabel => '分類';

  @override
  String get stockpileDeleteItem => '刪除項目';

  @override
  String get stockpileMarkPrepared => '已備妥';

  @override
  String get stockpileSectionExpiry => '保存期限';

  @override
  String get stockpileItemTapHint => '點選項目可登記保存期限、查看選購要點與購買連結';

  @override
  String get stockpileOfficialSite => '官方網站';

  @override
  String get stockpileInfants => '嬰幼兒（奶粉、尿布）';

  @override
  String stockpileNotifyExpiryBodyMany(String names, String date) {
    return '$names 即將到期（$date）';
  }

  @override
  String stockpileNotifyMoreItems(int count) {
    return '等$count項';
  }

  @override
  String get stockpileNotifyNameSeparator => '、';

  @override
  String stockpileDeleted(String item) {
    return '已刪除「$item」';
  }

  @override
  String get stockpileUndo => '復原';

  @override
  String get stockpileReset => '恢復初始狀態';

  @override
  String get stockpileResetConfirm => '將清除所有勾選、保存期限與新增的項目，恢復初始狀態。確定嗎？';

  @override
  String get stockpileSectionReminder => '提醒';

  @override
  String get stockpileExpiryReminder => '保存期限前1個月提醒';

  @override
  String get stockpileExpiryReminderSubtitle => '在所登記保存期限前1個月的上午9點，本機會發出通知';

  @override
  String get stockpileInspectionReminder => '檢查日提醒';

  @override
  String get stockpileInspectionReminderSubtitle => '3月11日與9月1日（防災日）上午9點通知';

  @override
  String get stockpileNotifyDenied => '未允許通知。請在系統「設定」中允許通知';

  @override
  String get stockpileNotifyTitle => '防災儲備檢查';

  @override
  String stockpileNotifyExpiryBody(String item, String date) {
    return '「$item」即將到期（$date）';
  }

  @override
  String get stockpileNotifyInspectionBody => '請檢查儲備物資的保存期限與數量';

  @override
  String get stockpileGuideWhy => '選購要點';

  @override
  String get stockpileGuideProducts => '可參考的產品';

  @override
  String get stockpileGuideProductsNote =>
      '點選可在合作商店搜尋該商品（行尾的 ↗ 為廠商官方頁面）。庫存與價格請在各商店確認。';

  @override
  String get stockpileGuideSearch => '尋找商品';

  @override
  String stockpileGuideSearchAt(String shop) {
    return '在$shop尋找';
  }

  @override
  String get stockpileGuideSources => '出處';

  @override
  String get stockpileDisclaimer => '所需數量為參考值，請依家庭情況調整';

  @override
  String get stockpileCatWaterFood => '水與食物';

  @override
  String get stockpileCatLightPower => '照明與電源';

  @override
  String get stockpileCatSanitation => '衛生';

  @override
  String get stockpileCatFirstAid => '急救與衛生用品';

  @override
  String get stockpileCatEvacuation => '避難用品';

  @override
  String get stockpileCatValuables => '貴重物品與資訊';

  @override
  String get stockpileUnitLiter => 'L';

  @override
  String get stockpileUnitMeal => '餐';

  @override
  String get stockpileUnitPiece => '個';

  @override
  String get stockpileUnitSheet => '張';

  @override
  String get stockpileUnitRoll => '卷';

  @override
  String get stockpileUnitPair => '雙';

  @override
  String get stockpileUnitPack => '包';

  @override
  String get stockpileUnitTimes => '次份';

  @override
  String get stockpileUnitDays => '天份';

  @override
  String get stockpileUnitSet => '套';

  @override
  String get stockpileItemWater => '長期保存水';

  @override
  String get stockpileItemStapleFood => '主食類應急食品';

  @override
  String get stockpileItemRetortFood => '軟罐頭食品';

  @override
  String get stockpileItemCannedFood => '罐頭';

  @override
  String get stockpileItemBabyFormula => '嬰兒奶粉、液態奶';

  @override
  String get stockpileItemFlashlight => '手電筒';

  @override
  String get stockpileItemBatteries => '乾電池';

  @override
  String get stockpileItemPowerBank => '行動電源';

  @override
  String get stockpileItemRadio => '攜帶式收音機';

  @override
  String get stockpileItemPortableToilet => '簡易廁所';

  @override
  String get stockpileItemToiletPaper => '衛生紙';

  @override
  String get stockpileItemWetWipes => '濕紙巾';

  @override
  String get stockpileItemGarbageBags => '垃圾袋';

  @override
  String get stockpileItemDiapers => '紙尿褲';

  @override
  String get stockpileItemFirstAidKit => '急救包';

  @override
  String get stockpileItemMedicine => '常備藥';

  @override
  String get stockpileItemMask => '口罩';

  @override
  String get stockpileItemDisinfectant => '消毒液';

  @override
  String get stockpileItemBackpack => '防災背包';

  @override
  String get stockpileItemBlanket => '鋁箔保溫毯';

  @override
  String get stockpileItemGloves => '工作手套';

  @override
  String get stockpileItemRope => '繩索';

  @override
  String get stockpileItemCash => '現金（含硬幣）';

  @override
  String get stockpileItemIdCopy => '身分證件影本';

  @override
  String get stockpileItemContactMemo => '聯絡方式備忘';

  @override
  String get stockpileItemCable => '充電線';

  @override
  String get stockpileChooseShop => '選擇商店';
}
