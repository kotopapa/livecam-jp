// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Japan Live Camera Map';

  @override
  String get commonClose => '닫기';

  @override
  String get commonCancel => '취소';

  @override
  String get commonOk => '확인';

  @override
  String get commonNext => '다음';

  @override
  String get commonSkip => '건너뛰기';

  @override
  String get commonCopy => '복사';

  @override
  String get commonShare => '공유';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonOpenInSafari => 'Safari에서 열기';

  @override
  String get commonSource => '출처';

  @override
  String commonCameraCount(int count) {
    return '$count대';
  }

  @override
  String get legalJapaneseAuthoritative => '이 일본어판을 정본으로 합니다. 번역은 참고용입니다.';

  @override
  String get languageLabel => '언어';

  @override
  String get languageSettingTitle => '언어 / 言語';

  @override
  String get languageNameJa => '日本語';

  @override
  String get languageNameJaHira => 'やさしい日本語';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => '기기 설정 따름';

  @override
  String get languageChooseTitle => '언어 선택';

  @override
  String get tabMap => '지도';

  @override
  String get tabList => '목록';

  @override
  String get tabBosai => '재해 속보';

  @override
  String get tabFavorites => '즐겨찾기';

  @override
  String get tabSettings => '설정';

  @override
  String get onboardingTitle1 => '지도에서 바로 찾기';

  @override
  String get onboardingBody1 =>
      '전국 1만 대 이상의 라이브 카메라를 지도에 표시합니다. 하천·도로·해안 등 카테고리별로 색을 구분했습니다.';

  @override
  String get onboardingTitle2 => '작동하지 않는 카메라는 자동 숨김';

  @override
  String get onboardingBody2 =>
      '정기적으로 자동 확인하여 영상을 가져올 수 없는 카메라는 지도에서 제외합니다. 이미지를 가져온 시각은 반드시 표시합니다.';

  @override
  String get onboardingTitle3 => '출처·라이선스 명시';

  @override
  String get onboardingBody3 => '모든 영상은 제공처를 명시하여 표시합니다. 영상의 권리는 각 제공처에 있습니다.';

  @override
  String get onboardingDisclaimerTitle => '이용 전 꼭 확인해 주십시오';

  @override
  String get onboardingAgreeAndStart => '동의하고 시작';

  @override
  String get disclaimerText =>
      '카메라 영상은 한정된 범위의 상황만 보여 줍니다. 카메라 성능상 빛 환경이나 기상 조건에 따라 선명하지 않을 수 있습니다. 대피 판단은 수위 정보·기상 경보·지자체의 대피 정보에 따라 주십시오. 본 앱은 참고 정보를 제공합니다.';

  @override
  String get updateRequiredTitle => '업데이트가 필요합니다';

  @override
  String get updateRequiredBody =>
      '이 버전은 지원이 종료되었습니다.\nApp Store에서 최신 버전으로 업데이트해 주십시오.';

  @override
  String get updateOpenStore => 'App Store 열기';

  @override
  String get categoryRiver => '하천';

  @override
  String get categoryRoad => '도로';

  @override
  String get categoryVolcano => '화산';

  @override
  String get categoryDam => '댐';

  @override
  String get categoryCoast => '해안';

  @override
  String get categoryPort => '항만';

  @override
  String get categoryScenic => '경관';

  @override
  String get categoryHealing => '힐링';

  @override
  String get categoryOther => '기타';

  @override
  String get pref01 => '홋카이도';

  @override
  String get pref02 => '아오모리';

  @override
  String get pref03 => '이와테';

  @override
  String get pref04 => '미야기';

  @override
  String get pref05 => '아키타';

  @override
  String get pref06 => '야마가타';

  @override
  String get pref07 => '후쿠시마';

  @override
  String get pref08 => '이바라키';

  @override
  String get pref09 => '도치기';

  @override
  String get pref10 => '군마';

  @override
  String get pref11 => '사이타마';

  @override
  String get pref12 => '지바';

  @override
  String get pref13 => '도쿄';

  @override
  String get pref14 => '가나가와';

  @override
  String get pref15 => '니가타';

  @override
  String get pref16 => '도야마';

  @override
  String get pref17 => '이시카와';

  @override
  String get pref18 => '후쿠이';

  @override
  String get pref19 => '야마나시';

  @override
  String get pref20 => '나가노';

  @override
  String get pref21 => '기후';

  @override
  String get pref22 => '시즈오카';

  @override
  String get pref23 => '아이치';

  @override
  String get pref24 => '미에';

  @override
  String get pref25 => '시가';

  @override
  String get pref26 => '교토';

  @override
  String get pref27 => '오사카';

  @override
  String get pref28 => '효고';

  @override
  String get pref29 => '나라';

  @override
  String get pref30 => '와카야마';

  @override
  String get pref31 => '돗토리';

  @override
  String get pref32 => '시마네';

  @override
  String get pref33 => '오카야마';

  @override
  String get pref34 => '히로시마';

  @override
  String get pref35 => '야마구치';

  @override
  String get pref36 => '도쿠시마';

  @override
  String get pref37 => '카가와';

  @override
  String get pref38 => '에히메';

  @override
  String get pref39 => '고치';

  @override
  String get pref40 => '후쿠오카';

  @override
  String get pref41 => '사가';

  @override
  String get pref42 => '나가사키';

  @override
  String get pref43 => '구마모토';

  @override
  String get pref44 => '오이타';

  @override
  String get pref45 => '미야자키';

  @override
  String get pref46 => '가고시마';

  @override
  String get pref47 => '오키나와';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSupportTitle => '개발자 응원하기';

  @override
  String get settingsSupportBody =>
      '캔커피 한 개(¥200)부터. 1인 개발이 이어질 수 있도록 응원해 주십시오';

  @override
  String get settingsSupportButton => '응원';

  @override
  String get settingsSectionNotify => '재해 알림';

  @override
  String get settingsQuakeTitle => '진도 5약 이상 지진';

  @override
  String get settingsQuakeSubtitleOff => '큰 지진 발생을 알리고 주변 카메라로 안내합니다';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return '알림 레벨: $level';
  }

  @override
  String get settingsWarningTitle => '특별 경보';

  @override
  String get settingsWarningSubtitle => '호우·폭풍·고조 등 특별 경보 발표를 알립니다';

  @override
  String get settingsNotifyArea => '알림 받을 지역';

  @override
  String get settingsNotifyAreaAll => '전국';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first 등 $count건';
  }

  @override
  String get settingsNotifyAreaHint =>
      '선택한 도도부현의 특별 경보만 알립니다. 아무것도 선택하지 않으면 전국이 대상이 됩니다';

  @override
  String get settingsNotifyAreaResetAll => '전국으로 되돌리기';

  @override
  String get settingsNotifyLevel => '알림 레벨';

  @override
  String get settingsNotifyLevelSpecialOnly => '특별 경보만(레벨 5)';

  @override
  String get settingsNotifyLevelDangerUp => '위험 경보부터(레벨 4 이상)';

  @override
  String get settingsNotifyLevelNote =>
      '위험 경보는 호우·홍수·고조·토사 재해의 경계 레벨 4에 해당하는 발표입니다';

  @override
  String get settingsNotifyDelayNote =>
      '※알림은 기상청 발표보다 5~15분 정도 늦어질 수 있습니다. 긴급 지진 속보를 대신하지 않습니다';

  @override
  String get settingsNotifyDenied =>
      '알림이 허용되어 있지 않습니다. iOS 설정 앱에서 알림을 허용해 주십시오';

  @override
  String get settingsSectionData => '데이터 수신';

  @override
  String get settingsWifiOnly => 'Wi-Fi 연결 시에만 이미지 수신';

  @override
  String get settingsWifiOnlySubtitle => '모바일 데이터 사용을 줄입니다(지도와 카메라 목록은 표시됩니다)';

  @override
  String get settingsClearCache => '캐시 삭제';

  @override
  String get settingsClearCacheSubtitle => '카메라 목록 등 저장된 데이터를 지우고 다시 가져옵니다';

  @override
  String get settingsClearCacheDone => '캐시를 삭제하고 다시 가져왔습니다';

  @override
  String get settingsSectionFilterDefaults => '필터 기본 설정';

  @override
  String get settingsShowWorld => '해외 카메라 표시';

  @override
  String get settingsVideoOnly => '동영상 카메라만';

  @override
  String get settingsHideUncertain => '위치가 불명확한 카메라 숨기기';

  @override
  String get settingsHideUncertainSubtitle => '노란 테두리 핀(대략 위치/대표 지점)을 숨깁니다';

  @override
  String get settingsFilterDefaultsNote =>
      '여기서 설정한 내용이 다음 실행 시의 초기 상태가 됩니다(지도 범례에서 일시적으로 변경할 수도 있습니다)';

  @override
  String get settingsSectionRequest => '카메라 추가·삭제 요청';

  @override
  String get settingsRequestForm => '문의·요청 양식';

  @override
  String get settingsRequestFormSubtitle =>
      '카메라 추가 요청과 게재 삭제 요청은 여기에서(로그인 불필요). 설치자·운영자의 삭제 요청에는 신속히 대응합니다';

  @override
  String get settingsSectionLicense => '출처·라이선스';

  @override
  String get settingsAttributionList => '출처·라이선스 목록';

  @override
  String get settingsAttributionListSubtitle => '카메라 영상 제공처 목록';

  @override
  String get settingsTerms => '이용약관';

  @override
  String get settingsPrivacy => '개인정보 처리방침';

  @override
  String get settingsLegalJapaneseOnly =>
      '이용약관·개인정보 처리방침 본문은 일본어로만 제공됩니다(일본어를 정본으로 합니다)';

  @override
  String get settingsSectionAbout => '이 앱에 대하여';

  @override
  String get settingsVersion => '버전';

  @override
  String get settingsInvite => '친구 초대하기';

  @override
  String get settingsInviteSubtitle => 'QR 코드 또는 링크로 App Store 페이지를 공유';

  @override
  String get settingsInviteDialogBody =>
      'QR 코드를 스캔하거나 링크를 보내면\nApp Store의 앱 페이지가 열립니다';

  @override
  String get settingsInviteShareText => 'Japan Live Camera Map - 하천·도로·방재';

  @override
  String get settingsLinkCopied => '링크를 복사했습니다';

  @override
  String get settingsReview => '앱 평가하기';

  @override
  String get settingsReviewSubtitle => 'App Store에 리뷰 작성';

  @override
  String get settingsFollowX => 'X에서 팔로우하기';

  @override
  String get settingsFollowXSubtitle => '@kotopapa8 — 새 카메라와 기능 소식';

  @override
  String get settingsOtherApps => '개발자의 다른 앱';

  @override
  String get settingsShowMoreApps => '다른 앱 보기';

  @override
  String get settingsSectionDisclaimer => '면책';

  @override
  String get settingsOssLicenses => '오픈소스 라이선스';

  @override
  String get settingsNotifyDiag => '알림 진단';

  @override
  String get settingsNotifyDiagSubtitle => '알림이 오지 않을 때의 상태 확인';

  @override
  String get settingsNotifyDiagUnlocked => '알림 진단을 표시했습니다(재해 알림 항목 안)';

  @override
  String settingsNotifyPermission(String value) {
    return '알림 허용: $value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'APNs 토큰: $value';
  }

  @override
  String get settingsNotifyFcm => 'FCM 토큰:';

  @override
  String get settingsCopyToken => '토큰 복사';

  @override
  String get settingsTokenCopied => 'FCM 토큰을 복사했습니다';

  @override
  String get settingsCrashDiag => '충돌 진단 데이터';

  @override
  String get settingsCrashDiagSubtitle => '강제 종료 기록(MetricKit) 보기·복사';

  @override
  String get settingsCrashDiagNone => '진단 데이터가 아직 없습니다';

  @override
  String get settingsCrashDiagNoneHint =>
      '진단 데이터가 아직 없습니다.\n충돌 후 앱을 다시 실행하면 기록됩니다';

  @override
  String get settingsCopyFullText => '전문 복사';

  @override
  String get settingsJsonCopied => '진단 JSON을 복사했습니다';

  @override
  String get attributionScreenTitle => '출처·라이선스 목록';

  @override
  String get attributionOpenYoutube => 'YouTube에서 제공처 보기';

  @override
  String get attributionOpenSite => '제공처 사이트 열기';

  @override
  String listTitle(int count) {
    return '목록($count)';
  }

  @override
  String get listSearchHint => '카메라명·하천명·노선명으로 검색';

  @override
  String get listEmpty => '조건에 맞는 카메라가 없습니다';

  @override
  String get listRanking => '랭킹';

  @override
  String favoritesTitle(int count) {
    return '즐겨찾기($count)';
  }

  @override
  String get favoritesEmpty => '즐겨찾기가 아직 없습니다.\n지도에서 카메라를 열고 ★을 누르면 추가됩니다.';

  @override
  String get favoritesEmptyFiltered => '필터 조건에 맞는 즐겨찾기가 없습니다';

  @override
  String get favoritesSort => '정렬';

  @override
  String get favoritesSortNewest => '등록 최신순';

  @override
  String get favoritesSortOldest => '등록 오래된순';

  @override
  String get favoritesSortName => '이름순';

  @override
  String get favoritesSortCategory => '카테고리순';

  @override
  String get favoritesToggleView => '보기 전환';

  @override
  String get favoritesRefreshAll => '일괄 갱신(3건씩 순차 수신)';

  @override
  String get favoritesVideoOnly => '동영상만';

  @override
  String get rankingTitle => '전국 랭킹';

  @override
  String get rankingModeNow => '지금 인기(24시간 TOP10)';

  @override
  String get rankingModeWeek => '많이 본 순(7일간 TOP30)';

  @override
  String get rankingModeFavorites => '즐겨찾기 등록 수';

  @override
  String get rankingNote => '전체 사용자의 익명 통계를 바탕으로 한 랭킹입니다(매일 갱신)';

  @override
  String get rankingEmpty => '아직 집계 데이터가 없습니다(하루 1회 갱신됩니다)';

  @override
  String get rankingPreparing => '전국 랭킹은 준비 중입니다.\n집계는 3시간마다 이루어집니다.';

  @override
  String get rankingFetchFailed => '가져오지 못했습니다';

  @override
  String rankingFetchFailedHttp(int code) {
    return '가져오지 못했습니다 (HTTP $code)';
  }

  @override
  String get rankingUnitViews => '회';

  @override
  String get rankingUnitFavorites => '건';

  @override
  String get detailLive => '라이브 방송 중';

  @override
  String get detailTimeUnknown => '취득 시각 불명';

  @override
  String detailRefreshEvery(int sec) {
    return '$sec초마다 갱신';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$sec초';
  }

  @override
  String get detailRefreshNow => '갱신';

  @override
  String get detailPosRepresentative => '위치는 광역 대표 지점';

  @override
  String get detailPosApprox => '위치는 대략적';

  @override
  String get detailNotUpdating => '이미지가 갱신되지 않았습니다';

  @override
  String get detailWorld => '일본 국외';

  @override
  String get detailCategoryAndPlace => '카테고리·위치';

  @override
  String get detailOpenMap => '지도에서 보기';

  @override
  String get detailOpenSourceSite => '출처 사이트 보기';

  @override
  String get detailOpenYoutube => 'YouTube에서 보기';

  @override
  String get detailOpenChannel => '채널 페이지 보기';

  @override
  String get detailOpenOriginalPage => '원본 페이지에서 보기';

  @override
  String get detailReportProblem => '이 카메라의 문제 신고';

  @override
  String get detailNearby => '주변 카메라';

  @override
  String detailDistanceKm(String km) {
    return '약 ${km}km';
  }

  @override
  String get detailWifiOnlyBlocked => '설정에 따라 이미지는 Wi-Fi 연결 시에만 가져옵니다';

  @override
  String get detailNoImage => '현재 영상을 가져올 수 없습니다';

  @override
  String get detailEmbedBlockedYoutube => '제공자 설정으로 인해 이 영상은\n앱 내에서 재생할 수 없습니다';

  @override
  String get detailEmbedBlockedPage => '제공처의 이용 조건에 따라\n앱 내에서는 표시할 수 없습니다';

  @override
  String get detailIHighwayTitle => 'NEXCO 공식 「iHighway」에서\n라이브 카메라 보기';

  @override
  String get detailIHighwayBody =>
      '탭하면 앱 내 브라우저로 공식 사이트를 열고\n이 카메라의 위치로 자동 이동합니다';

  @override
  String get detailIHighwayHost => 'ihighway.jp(NEXCO 공식)';

  @override
  String get detailMapTileGsi => '지리원 타일';

  @override
  String get elevationLoading => '표고 …';

  @override
  String elevationValue(String value, String source) {
    return '표고 $value($source)';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return '$time 취득$relative';
  }

  @override
  String get timeRelJustNow => ' (방금 전)';

  @override
  String timeRelMinutes(int n) {
    return ' ($n분 전)';
  }

  @override
  String timeRelHours(int n) {
    return ' ($n시간 전)';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String get intensity5Lower => '5약';

  @override
  String get intensity5Upper => '5강';

  @override
  String get intensity6Lower => '6약';

  @override
  String get intensity6Upper => '6강';

  @override
  String get quakeLevel5Lower => '진도 5약 이상';

  @override
  String get quakeLevel5Upper => '진도 5강 이상';

  @override
  String get quakeLevel6Lower => '진도 6약 이상';

  @override
  String get warning02 => '폭풍설 경보';

  @override
  String get warning03 => '호우 경보';

  @override
  String get warning04 => '홍수 경보';

  @override
  String get warning05 => '폭풍 경보';

  @override
  String get warning06 => '대설 경보';

  @override
  String get warning07 => '풍랑 경보';

  @override
  String get warning08 => '폭풍 해일 경보';

  @override
  String get warning09 => '토사 재해 경보';

  @override
  String get warning43 => '호우 위험 경보';

  @override
  String get warning44 => '홍수 위험 경보';

  @override
  String get warning48 => '폭풍 해일 위험 경보';

  @override
  String get warning49 => '토사 재해 위험 경보';

  @override
  String get warning32 => '눈폭풍 특별 경보';

  @override
  String get warning33 => '호우 특별 경보';

  @override
  String get warning34 => '홍수 특별 경보';

  @override
  String get warning35 => '폭풍 특별 경보';

  @override
  String get warning36 => '대설 특별 경보';

  @override
  String get warning37 => '풍랑 특별 경보';

  @override
  String get warning38 => '폭풍 해일 특별 경보';

  @override
  String get warning39 => '토사 재해 특별 경보';

  @override
  String get advisory10 => '호우 주의보';

  @override
  String get advisory12 => '대설 주의보';

  @override
  String get advisory13 => '눈보라 주의보';

  @override
  String get advisory14 => '벼락 주의보';

  @override
  String get advisory15 => '강풍 주의보';

  @override
  String get advisory16 => '풍랑 주의보';

  @override
  String get advisory17 => '눈녹음(융설) 주의보';

  @override
  String get advisory18 => '홍수 주의보';

  @override
  String get advisory19 => '폭풍 해일 주의보';

  @override
  String get advisory20 => '짙은 안개 주의보';

  @override
  String get advisory21 => '건조 주의보';

  @override
  String get advisory22 => '눈사태 주의보';

  @override
  String get advisory23 => '저온 주의보';

  @override
  String get advisory24 => '서리 주의보';

  @override
  String get advisory25 => '착빙 주의보';

  @override
  String get advisory26 => '착설(눈이 달라붙음) 주의보';

  @override
  String get advisory29 => '토사 재해 주의보';

  @override
  String get mapLocationDenied => '위치 정보 사용이 허용되어 있지 않습니다(설정에서 변경할 수 있습니다)';

  @override
  String get mapLocationFailed => '현재 위치를 가져오지 못했습니다';

  @override
  String get mapLegendTitle => '범례·필터';

  @override
  String get mapLegendSearchHint => '카메라명·운영자·하천/노선명으로 검색';

  @override
  String get mapFilterFavoritesOnly => '즐겨찾기만';

  @override
  String get mapFilterOkOnly => '현재 보이는 것만';

  @override
  String get mapLegendLiveDot => '빨간 점 = 동영상(라이브 방송)';

  @override
  String get mapLegendUncertain => '노란 테두리 = 위치 미확정(대략/대표 지점)';

  @override
  String get mapLegendFrozen => '반투명 = 이미지가 오랫동안 갱신되지 않음';

  @override
  String get mapLegendFavorite => '금색 별 = 즐겨찾기에 등록됨';

  @override
  String get mapLegendCluster => '숫자 원 = 주변 카메라 묶음(탭하면 확대)';

  @override
  String get mapSearchTitle => '장소 검색';

  @override
  String get mapSearchHint => '지명·주소(예: 시부야, 가나자와시 히로사카)';

  @override
  String get mapSearchNotFound => '찾지 못했습니다. 지명·주소·카메라명으로 시도해 보십시오';

  @override
  String get mapSearchSectionCameras => '카메라';

  @override
  String get mapSearchSectionPlaces => '장소';

  @override
  String mapPointCameras(int count) {
    return '이 지점의 카메라($count대)';
  }

  @override
  String mapFilteredCount(int count) {
    return '필터 중 $count대';
  }

  @override
  String mapTotalCount(int count) {
    return '$count대';
  }

  @override
  String get mapLayersTooltip => '지도 레이어';

  @override
  String get bosaiTitle => '재해 속보';

  @override
  String get bosaiTabQuake => '지진·지진해일';

  @override
  String get bosaiTabWarning => '기상 경보';

  @override
  String get bosaiTabHeat => '열사병';

  @override
  String get bosaiNoWarnings => '현재 발표 중인 경보·주의보가 없습니다';

  @override
  String get bosaiWarningNoteNone =>
      '출처: 기상청. 현재 경보·특별 경보 발표가 없습니다. 주의보만 발표된 지역은 아래 목록에서 확인할 수 있습니다.';

  @override
  String get bosaiWarningNote =>
      '출처: 기상청 기상 경보·주의보. 탭하면 해당 도도부현의 카메라 목록을 표시합니다.';

  @override
  String bosaiAdvisoryRegions(int count) {
    return '주의보가 발표 중인 지역($count개 도도부현)';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return '$pref의 경보 발표 지역';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return '$pref의 주의보 발표 지역';
  }

  @override
  String get bosaiMuniNote => '출처: 기상청. 탭하면 해당 시구정촌의 카메라 목록을 표시합니다';

  @override
  String get bosaiMuniFetchFailed => '발표 지역의 상세 정보를 가져오지 못했습니다';

  @override
  String get bosaiMuniNone => '현재 발표 중인 시구정촌이 없습니다';

  @override
  String bosaiCameraCount(int count) {
    return '카메라 $count대';
  }

  @override
  String get bosaiNoCamera => '카메라 없음';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return '$name의 카메라(경보 발표 중)';
  }

  @override
  String get settingsJmaDictionary => '방재 용어 번역에 대하여';

  @override
  String get settingsJmaDictionaryNote =>
      '경보명·주의보명·진도 등의 각 언어 번역은 기상청 「기상정보 등에 관한 다국어 사전」에 따릅니다. 출처: 기상청 홈페이지';

  @override
  String get hazardFloodTitle => '홍수 침수 예상 구역(상정 최대 규모)';

  @override
  String get hazardLandslideTitle => '토사 재해 경계 구역';

  @override
  String get hazardTsunamiTitle => '지진해일 침수 상정';

  @override
  String get hazardHightideTitle => '폭풍 해일 침수 예상 구역';

  @override
  String get hazardLandslideSteepSlope => '급경사지';

  @override
  String get hazardLandslideDebrisFlow => '토석류';

  @override
  String get hazardLandslideSlide => '산사태';

  @override
  String get hazardDisclaimer =>
      '최신의 상세한 정보는 각 시정촌의 재해 위험 지도를 확인해 주십시오. 대피 판단은 지자체의 대피 정보에 따라 주십시오';

  @override
  String get facilityKindWater => '급수 거점·응급 급수 시설';

  @override
  String get facilityKindStock => '방재 비축 창고';

  @override
  String get facilityKindFireWater => '소방 용수(소화전·방화 수조)';

  @override
  String get facilityKindWaterShort => '급수 거점';

  @override
  String get facilityKindStockShort => '비축 창고';

  @override
  String get facilityKindFireWaterShort => '소방 용수';

  @override
  String get facilityDisclaimer => '공개하는 지자체만 해당됩니다. 최신 정보는 각 지자체에 확인해 주십시오';

  @override
  String get facilityNoData => '이 지역의 데이터는 아직 없습니다';

  @override
  String get shelterHazardFlood => '홍수';

  @override
  String get shelterHazardSediment => '토사 재해';

  @override
  String get shelterHazardHightide => '고조';

  @override
  String get shelterHazardEarthquake => '지진';

  @override
  String get shelterHazardTsunami => '지진해일';

  @override
  String get shelterHazardFire => '화재';

  @override
  String get shelterHazardInlandFlood => '내수 침수';

  @override
  String get shelterHazardVolcano => '화산';

  @override
  String get shelterDisclaimer => '최신의 상세한 상황은 각 시정촌에 확인해 주십시오';

  @override
  String get riskLandTitle => '토사 위험도 분포(키키쿠루)';

  @override
  String get riskInundTitle => '침수 위험도 분포(키키쿠루)';

  @override
  String get riskFloodTitle => '홍수 위험도 분포(키키쿠루)';

  @override
  String get riskLandSubtitle => '토사 재해 위험도(1km 메시·10분마다 갱신)';

  @override
  String get riskInundSubtitle => '침수 피해 위험도(1km 메시·10분마다 갱신)';

  @override
  String get riskFloodSubtitle => '홍수 재해 위험도(하천별·10분마다 갱신)';

  @override
  String get riskLevelWatch => '추후 정보에 유의';

  @override
  String get riskLevelCaution => '주의';

  @override
  String get riskLevelWarning => '경계';

  @override
  String get riskLevelDanger => '위험';

  @override
  String get riskLevelCritical => '재해 급박';

  @override
  String get wbgtLevelDanger => '위험';

  @override
  String get wbgtLevelSevereWarning => '엄중 경계';

  @override
  String get wbgtLevelWarning => '경계';

  @override
  String get wbgtLevelCaution => '주의';

  @override
  String get wbgtLevelSafe => '거의 안전';

  @override
  String get heatAlertSpecial => '열사병 특별경계경보';

  @override
  String get heatAlertSpecialPending => '열사병 특별경계경보(판정 중)';

  @override
  String get heatAlertWarning => '열사병 경계경보';

  @override
  String get heatAlertDisclaimer =>
      '본 정보는 참고 정보입니다. 공식 발표는 열사병 예방 정보 사이트 등에서 확인해 주십시오';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어';

  @override
  String get languageNameVi => 'Tiếng Việt';

  @override
  String get mapLayerPanelSubtitle => '지도에는 한 종류만 겹쳐서 표시합니다';

  @override
  String get mapLayerNone => '표시 안 함';

  @override
  String get mapLayerSectionWeather => '기상';

  @override
  String get mapLayerRainRadarTitle => '비구름 레이더(현재)';

  @override
  String get mapLayerRainRadarSubtitle => '고해상도 강수 나우캐스트·5분마다 갱신';

  @override
  String get mapLayerQuakesTitle => '진원';

  @override
  String get mapQuakePeriodDay => '24시간';

  @override
  String get mapQuakePeriodWeek => '7일';

  @override
  String get mapQuakePeriodMonth => '30일';

  @override
  String get mapLayerRain24hTitle => '24시간 강수량';

  @override
  String get mapLayerRain24hSubtitle => '기상청 해석 강수량(면)＋확대 시 아메다스 관측값';

  @override
  String get mapLayerSectionHazard => '재해 위험 지도';

  @override
  String get mapHazardLandslideSubtitle =>
      '급경사지·토석류·산사태(노랑=경계 구역 / 빨강=특별 경계 구역)';

  @override
  String get mapHazardDepthSubtitle => '예상되는 침수 깊이를 색으로 구분하여 표시';

  @override
  String get mapShelterTitle => '대피 장소';

  @override
  String get mapLayerShelterTitle => '대피 장소(지정 긴급 대피 장소·지정 대피소)';

  @override
  String get mapLayerShelterSubtitle => '확대하면 표시됩니다. 재해 종별로 필터링할 수 있습니다';

  @override
  String get mapFacilityTitle => '방재 거점';

  @override
  String get mapLayerFacilityTitle => '방재 거점(급수 거점·방재 비축 창고)';

  @override
  String get mapLayerFacilitySubtitle => '확대하면 표시됩니다. 종별로 필터링할 수 있습니다';

  @override
  String mapQuakeNearbyTitle(int count) {
    return '이 부근의 지진 $count건';
  }

  @override
  String get mapQuakeUnknownPlace => '진원(상세 미발표)';

  @override
  String mapQuakeMaxIntensity(String value) {
    return '최대 진도 $value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return '$name 주변의 카메라';
  }

  @override
  String get mapQuakeTapHint => '탭하면 주변 라이브 카메라(50km 이내)를 표시합니다';

  @override
  String get mapShelterNoticeTitle => '대피 장소 레이어에 대하여';

  @override
  String get mapShelterNoticeBody =>
      '・「지정 긴급 대피 장소」는 재해의 위험으로부터 생명을 지키기 위해 피하는 장소이고, 「지정 대피소」는 일정 기간 머무는 시설입니다(이중 테두리로 표시)\n・지정 긴급 대피 장소는 재해 종별로 지정되어 있어 재해 종류에 따라서는 대피할 수 없는 경우가 있습니다\n・시정촌이 제공한 정보이므로 최신이 아니거나 게재되지 않은 장소가 있을 수 있습니다. 정확한 정보는 해당 시정촌에 확인해 주십시오';

  @override
  String get mapShelterHazardAll => '전체';

  @override
  String get mapShelterDesignated => '지정 대피소';

  @override
  String get mapShelterHazardsLabel => '대응 재해 종별';

  @override
  String get mapOpenRoute => 'Google 지도에서 경로 보기';

  @override
  String get mapNearbyCamerasButton => '주변 라이브 카메라';

  @override
  String get mapFacilityNoticeTitle => '방재 거점 레이어에 대하여';

  @override
  String get mapFacilityNoticeBody =>
      '・각 지자체가 오픈 데이터로 공개하는 「응급 급수 시설」「비축 창고」「소방 용수 시설」 목록을 모은 것입니다. 공개하는 지자체만 포함되며 전국을 망라하지는 않습니다\n・소화전·방화 수조는 소방 활동용 설비이며 일반인이 사용하는 것이 아닙니다\n・급수 거점은 재해 시에 개설되는 것으로, 평상시에 급수를 받을 수 있다고는 할 수 없습니다\n・갱신 시기는 지자체마다 다릅니다. 정확한 정보는 각 지자체에 확인해 주십시오';

  @override
  String mapFacilityOwner(String owner) {
    return '제공: $owner';
  }

  @override
  String get mapFacilityGeocodedNote => '주소로부터 추정한 위치입니다(실제 장소와 다를 수 있습니다)';

  @override
  String get mapFacilitySourceDataset => '출처(데이터셋)';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value시간';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value분';
  }

  @override
  String get mapNowcastNow => '현재(관측)';

  @override
  String get mapNowcastForecastHourly => '예보·1시간 강수량';

  @override
  String get mapNowcastForecast => '예측';

  @override
  String mapNowcastAfter(String span, String kind) {
    return '$span 후($kind)';
  }

  @override
  String mapNowcastBefore(String span) {
    return '$span 전(관측)';
  }

  @override
  String get mapNowcastBackToNow => '현재로';

  @override
  String get mapNowcastNowMarker => '▲ 현재';

  @override
  String mapNowcastLast(String label) {
    return '$label(6시간 후)';
  }

  @override
  String mapLegendRainRadar(String label) {
    return '비구름 레이더 $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return '비구름 레이더 $label($kind)';
  }

  @override
  String get mapLegendRainWeak => '약';

  @override
  String mapLegendQuakes(String period, int count) {
    return '진원 $period($count건)';
  }

  @override
  String mapLegendIntensity(String value) {
    return '진도 $value';
  }

  @override
  String get mapLegendIntensity6Up => '6약~';

  @override
  String mapLegendRain24h(String label) {
    return '24시간 강수량 $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return '24시간 강수량 $label(확대 시 관측값)';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title(경계 / 특별 경계)';
  }

  @override
  String get mapLegendShelterZoomIn => '대피 장소(확대하면 표시)';

  @override
  String mapLegendShelter(int count) {
    return '대피 장소($count건)';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return '대피 장소($count건·묶음 표시)';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return '대피 장소·$hazard($count건)';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return '대피 장소·$hazard($count건·묶음 표시)';
  }

  @override
  String get mapLegendShelterEmergency => '지정 긴급 대피 장소';

  @override
  String get mapLegendShelterDesignated => '이중 테두리=지정 대피소';

  @override
  String get mapLegendFacilityZoomIn => '방재 거점(확대하면 표시)';

  @override
  String mapLegendFacilityNoData(String message) {
    return '방재 거점($message)';
  }

  @override
  String mapLegendFacility(int count) {
    return '방재 거점($count건)';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return '방재 거점($count건·묶음 표시)';
  }

  @override
  String get mapLegendFetchFailed => '가져올 수 없습니다';

  @override
  String get mapShelterFetchFailed => '대피 장소를 가져오지 못했습니다(탭하여 재시도)';

  @override
  String get mapFacilityFetchFailed => '방재 거점을 가져오지 못했습니다(탭하여 재시도)';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24시간 ${mm}mm';
  }

  @override
  String get bosaiFetchFailedPull => '가져오지 못했습니다(아래로 당겨 다시 시도)';

  @override
  String get bosaiTsunamiInfo => '지진해일 정보';

  @override
  String get bosaiUnknownPlace => '불명';

  @override
  String bosaiFetchFailedDetail(String error) {
    return '가져오지 못했습니다($error)';
  }

  @override
  String get bosaiTimeJustNow => '방금 전';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$n분 전';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$n시간 전';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return '$month월 $day일 $hour시경';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return '$place의 진도';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return '$place 주변의 카메라';
  }

  @override
  String get bosaiQuakeEmpty => '최근 72시간의 지진 정보가 없습니다';

  @override
  String bosaiQuakeAsOf(String time) {
    return '($time 기준·최신순)';
  }

  @override
  String bosaiQuakeNote(String at) {
    return '출처: 기상청 지진 정보(최근 72시간)$at. 탭하면 흔들림이 있었던 시구정촌의 라이브 카메라 목록(시구정촌별 진도가 없는 경우 진원 주변)을 표시합니다.';
  }

  @override
  String get bosaiBadgeTsunami => '지진해일';

  @override
  String bosaiBadgeIntensity(String value) {
    return '진도\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return '$count개 시구정촌에서 관측';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return '최신 정보를 가져오지 못했습니다($time 기준 정보 표시 중)';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return '$time 기준';
  }

  @override
  String get bosaiHeatOffSeason =>
      '열사병 경계경보 운용 기간이 아닙니다(매년 4월 하순~10월 하순에 발표됩니다)';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return ' ($month/$day $hour시 발표)';
  }

  @override
  String get bosaiHeatTapHint => '탭하면 해당 도도부현의 카메라 목록을 표시합니다.';

  @override
  String get bosaiHeatNone => '현재 열사병 경계경보가 발표되지 않았습니다';

  @override
  String get bosaiHeatToday => '오늘';

  @override
  String get bosaiHeatTomorrow => '내일';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return '$pref의 카메라(열사병 경계경보)';
  }

  @override
  String get bosaiWbgtCardTitle => '가까운 지점의 더위 지수(WBGT)';

  @override
  String get bosaiWbgtUnavailable => '가져오지 못했습니다';

  @override
  String bosaiApproxDistance(String value) {
    return '약 $value';
  }

  @override
  String get bosaiWbgtNow => '현재';

  @override
  String get bosaiWbgtNoCurrent => '관측값 없음';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level($time)';
  }

  @override
  String get bosaiWbgtForecast => '예측';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hour시';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return '다음날 $hour시';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$month/$day $hour시';
  }

  @override
  String get bosaiQuakeMuniNote =>
      '출처: 기상청 지진 정보(진도가 큰 순). 탭하면 해당 시구정촌의 카메라 목록을 표시합니다. 카메라가 없는 시구정촌은 진원 주변의 카메라를 표시합니다.';

  @override
  String get bosaiEpicenterNearby => '진원 주변의 카메라(거리순)';

  @override
  String bosaiMuniCodeFallback(String code) {
    return '시구정촌 $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref·진원 주변의 카메라를 표시합니다';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return '$name의 카메라(진도 $intensity)';
  }

  @override
  String bosaiLiveOnly(int count) {
    return 'LIVE만($count)';
  }

  @override
  String get bosaiMuniFallbackNote =>
      '이 시구정촌에 해당하는 카메라가 없어 도도부현 내 전체 카메라를 표시합니다';

  @override
  String get bosaiPrefNoCameras => '이 도도부현의 카메라가 없습니다';

  @override
  String get bosaiNoLiveCameras => 'LIVE 방송 카메라가 없습니다';

  @override
  String get bosaiNoCamerasWithin50km => '50km 이내에 카메라가 없습니다';

  @override
  String get tipTitle => '개발자 응원';

  @override
  String get tipIntro =>
      '이 앱은 개인이 개발·운영하고 있습니다. 카메라 조사와 추가, 모니터링 서버 유지, 기상 데이터 대응 등 지속적인 업데이트에 큰 힘이 됩니다. 후원은 선택 사항이며 기능 차이는 없습니다.';

  @override
  String get tipCoffeeTitle => '캔커피로 한숨 돌리기';

  @override
  String get tipCoffeeSubtitle => '개발 중간에 마실 캔커피 값을 선물';

  @override
  String get tipSweetsTitle => '디저트로 당 충전';

  @override
  String get tipSweetsSubtitle => '집중 코딩용 간식과 카페 비용을 후원';

  @override
  String get tipLunchTitle => '점심으로 개발 부스트';

  @override
  String get tipLunchSubtitle => '다음 신기능 개발을 위한 든든한 점심을 대접';

  @override
  String get tipDevToolsTitle => '개발 도구 비용 응원';

  @override
  String get tipDevToolsSubtitle => '카메라 조사와 서버 모니터링에 쓰는 서비스 비용을 후원';

  @override
  String get tipPreparing => '후원 메뉴는 준비 중입니다. 잠시 후 다시 시도해 주십시오.';

  @override
  String get tipUnavailable => '이 기기에서는 앱 내 구입을 이용할 수 없습니다.';

  @override
  String get tipPurchaseStartFailed => '구입을 시작하지 못했습니다';

  @override
  String get tipThanks => '후원해 주셔서 감사합니다! 개발에 큰 힘이 됩니다.';

  @override
  String tipPurchaseFailed(String error) {
    return '구입을 완료하지 못했습니다($error)';
  }

  @override
  String get tipUnknownError => '알 수 없는 오류';

  @override
  String get tipNoticeTitle => '구입 전에 확인해 주십시오';

  @override
  String get tipNoticeBody =>
      '후원은 App Store의 앱 내 구입으로 처리됩니다(환불은 Apple의 규정에 따릅니다).';

  @override
  String get tipEula => 'EULA(Apple 표준 사용권 계약)';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return '기록: $count건\n최신: $name';
  }

  @override
  String get settingsDiagKindCrash => '충돌';

  @override
  String get settingsDiagKindHang => '행(응답 없음)';

  @override
  String get settingsDiagKindCpu => 'CPU 이상';

  @override
  String get settingsDiagKindDiskWrite => '디스크 쓰기 이상';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return '종류: $kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return '읽기 오류: $error';
  }

  @override
  String get settingsDiagFetchFailed => '가져오기 실패';

  @override
  String get settingsDiagNotAcquired => '미취득(null)';

  @override
  String settingsDiagAcquired(String prefix) {
    return '취득됨($prefix…)';
  }

  @override
  String settingsDiagError(String error) {
    return '오류: $error';
  }
}
