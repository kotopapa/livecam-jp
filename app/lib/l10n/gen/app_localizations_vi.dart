// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Japan Live Camera Map';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonOk => 'OK';

  @override
  String get commonNext => 'Tiếp';

  @override
  String get commonSkip => 'Bỏ qua';

  @override
  String get commonCopy => 'Sao chép';

  @override
  String get commonShare => 'Chia sẻ';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonOpenInSafari => 'Mở bằng Safari';

  @override
  String get commonSource => 'Nguồn';

  @override
  String commonCameraCount(int count) {
    return '$count camera';
  }

  @override
  String get legalJapaneseAuthoritative =>
      'Bản tiếng Nhật là bản chính thức. Bản dịch chỉ mang tính tham khảo.';

  @override
  String get languageLabel => 'Ngôn ngữ';

  @override
  String get languageSettingTitle => 'Ngôn ngữ / 言語';

  @override
  String get languageNameJa => '日本語';

  @override
  String get languageNameJaHira => 'やさしい日本語';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => 'Theo thiết bị';

  @override
  String get languageChooseTitle => 'Chọn ngôn ngữ';

  @override
  String get tabMap => 'Bản đồ';

  @override
  String get tabList => 'Danh sách';

  @override
  String get tabBosai => 'Thảm họa';

  @override
  String get tabFavorites => 'Yêu thích';

  @override
  String get tabStockpile => 'Chuẩn bị';

  @override
  String get tabSettings => 'Cài đặt';

  @override
  String get onboardingTitle1 => 'Tìm ngay trên bản đồ';

  @override
  String get onboardingBody1 =>
      'Hơn 10.000 camera trực tiếp trên khắp Nhật Bản được hiển thị trên bản đồ, phân màu theo loại: sông ngòi, đường bộ, bờ biển và nhiều loại khác.';

  @override
  String get onboardingTitle2 => 'Tự động ẩn camera không hoạt động';

  @override
  String get onboardingBody2 =>
      'Chúng tôi kiểm tra định kỳ. Camera không lấy được hình sẽ bị gỡ khỏi bản đồ, và thời điểm chụp luôn được hiển thị.';

  @override
  String get onboardingTitle3 => 'Ghi rõ nguồn và giấy phép';

  @override
  String get onboardingBody3 =>
      'Mọi hình ảnh đều được hiển thị kèm tên đơn vị cung cấp. Quyền đối với hình ảnh thuộc về từng đơn vị cung cấp.';

  @override
  String get onboardingNotifyOptIn => 'Nhận thông báo thiên tai';

  @override
  String get onboardingNotifyOptInDetail =>
      'Thông báo khi có động đất cường độ 5 yếu trở lên hoặc Cảnh báo đặc biệt (toàn quốc). Bạn có thể thay đổi trong Cài đặt.';

  @override
  String get onboardingDisclaimerTitle => 'Lưu ý quan trọng trước khi sử dụng';

  @override
  String get onboardingAgreeAndStart => 'Đồng ý và bắt đầu';

  @override
  String get disclaimerText =>
      'Hình ảnh camera chỉ cho thấy tình hình trong một phạm vi hạn chế. Do đặc tính của camera, hình ảnh có thể không rõ tùy theo điều kiện ánh sáng và thời tiết. Khi quyết định lánh nạn, hãy tuân theo thông tin mực nước, cảnh báo khí tượng và thông tin lánh nạn của chính quyền địa phương. Ứng dụng này chỉ cung cấp thông tin tham khảo.';

  @override
  String get updateRequiredTitle => 'Cần cập nhật ứng dụng';

  @override
  String get updateRequiredBody =>
      'Phiên bản này đã ngừng được hỗ trợ.\nVui lòng cập nhật lên bản mới nhất từ App Store.';

  @override
  String get updateOpenStore => 'Mở App Store';

  @override
  String get categoryRiver => 'Sông ngòi';

  @override
  String get categoryRoad => 'Đường bộ';

  @override
  String get categoryVolcano => 'Núi lửa';

  @override
  String get categoryDam => 'Đập nước';

  @override
  String get categoryCoast => 'Bờ biển';

  @override
  String get categoryPort => 'Cảng biển';

  @override
  String get categoryScenic => 'Cảnh quan';

  @override
  String get categoryHealing => 'Thư giãn';

  @override
  String get categoryOther => 'Khác';

  @override
  String get pref01 => 'Hokkaido';

  @override
  String get pref02 => 'Aomori';

  @override
  String get pref03 => 'Iwate';

  @override
  String get pref04 => 'Miyagi';

  @override
  String get pref05 => 'Akita';

  @override
  String get pref06 => 'Yamagata';

  @override
  String get pref07 => 'Fukushima';

  @override
  String get pref08 => 'Ibaraki';

  @override
  String get pref09 => 'Tochigi';

  @override
  String get pref10 => 'Gunma';

  @override
  String get pref11 => 'Saitama';

  @override
  String get pref12 => 'Chiba';

  @override
  String get pref13 => 'Tokyo';

  @override
  String get pref14 => 'Kanagawa';

  @override
  String get pref15 => 'Niigata';

  @override
  String get pref16 => 'Toyama';

  @override
  String get pref17 => 'Ishikawa';

  @override
  String get pref18 => 'Fukui';

  @override
  String get pref19 => 'Yamanashi';

  @override
  String get pref20 => 'Nagano';

  @override
  String get pref21 => 'Gifu';

  @override
  String get pref22 => 'Shizuoka';

  @override
  String get pref23 => 'Aichi';

  @override
  String get pref24 => 'Mie';

  @override
  String get pref25 => 'Shiga';

  @override
  String get pref26 => 'Kyoto';

  @override
  String get pref27 => 'Osaka';

  @override
  String get pref28 => 'Hyogo';

  @override
  String get pref29 => 'Nara';

  @override
  String get pref30 => 'Wakayama';

  @override
  String get pref31 => 'Tottori';

  @override
  String get pref32 => 'Shimane';

  @override
  String get pref33 => 'Okayama';

  @override
  String get pref34 => 'Hiroshima';

  @override
  String get pref35 => 'Yamaguchi';

  @override
  String get pref36 => 'Tokushima';

  @override
  String get pref37 => 'Kagawa';

  @override
  String get pref38 => 'Ehime';

  @override
  String get pref39 => 'Kochi';

  @override
  String get pref40 => 'Fukuoka';

  @override
  String get pref41 => 'Saga';

  @override
  String get pref42 => 'Nagasaki';

  @override
  String get pref43 => 'Kumamoto';

  @override
  String get pref44 => 'Oita';

  @override
  String get pref45 => 'Miyazaki';

  @override
  String get pref46 => 'Kagoshima';

  @override
  String get pref47 => 'Okinawa';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsSupportTitle => 'Ủng hộ nhà phát triển';

  @override
  String get settingsSupportBody =>
      'Chỉ từ giá một lon cà phê (¥200). Hãy giúp ứng dụng cá nhân này tiếp tục được duy trì';

  @override
  String get settingsSupportButton => 'Ủng hộ';

  @override
  String get settingsSectionNotify => 'Thông báo thảm họa';

  @override
  String get settingsQuakeTitle => 'Động đất cường độ 5 yếu trở lên';

  @override
  String get settingsQuakeSubtitleOff =>
      'Nhận thông báo khi có động đất lớn và chuyển nhanh đến camera lân cận';

  @override
  String settingsQuakeSubtitleOn(String level) {
    return 'Mức thông báo: $level';
  }

  @override
  String get settingsWarningTitle => 'Cảnh báo đặc biệt';

  @override
  String get settingsWarningSubtitle =>
      'Nhận thông báo khi có cảnh báo đặc biệt về mưa to, gió bão dữ dội, triều cường và các hiện tượng khác';

  @override
  String get settingsNotifyArea => 'Khu vực nhận thông báo';

  @override
  String get settingsNotifyAreaAll => 'Toàn quốc';

  @override
  String settingsNotifyAreaSummary(String first, int count) {
    return '$first và $count khu vực';
  }

  @override
  String get settingsNotifyAreaHint =>
      'Chỉ thông báo cảnh báo đặc biệt của các tỉnh thành đã chọn. Nếu không chọn tỉnh thành nào thì toàn quốc sẽ là đối tượng thông báo';

  @override
  String get settingsNotifyAreaResetAll => 'Đặt lại về toàn quốc';

  @override
  String get settingsNotifyLevel => 'Mức độ thông báo';

  @override
  String get settingsNotifyLevelSpecialOnly =>
      'Chỉ cảnh báo đặc biệt (cấp độ 5)';

  @override
  String get settingsNotifyLevelDangerUp =>
      'Từ cảnh báo khẩn cấp (cấp độ 4 trở lên)';

  @override
  String get settingsNotifyLevelNote =>
      'Cảnh báo khẩn cấp là thông tin tương đương cấp độ cảnh giác 4 đối với mưa to, lũ lụt, triều cường và tai họa sạt lở đất';

  @override
  String get settingsNotifyDelayNote =>
      '※Thông báo có thể đến chậm khoảng 5–15 phút so với thời điểm Cơ quan Khí tượng công bố. Thông báo này không thay thế cho tin động đất khẩn cấp';

  @override
  String get settingsNotifyDenied =>
      'Thông báo chưa được cho phép. Vui lòng bật thông báo trong ứng dụng Cài đặt của iOS';

  @override
  String get settingsSectionData => 'Lấy dữ liệu';

  @override
  String get settingsWifiOnly => 'Chỉ tải hình ảnh khi có Wi-Fi';

  @override
  String get settingsWifiOnlySubtitle =>
      'Giúp tiết kiệm dung lượng mạng di động (bản đồ và danh sách camera vẫn hiển thị)';

  @override
  String get settingsClearCache => 'Xóa bộ nhớ đệm';

  @override
  String get settingsClearCacheSubtitle =>
      'Xóa dữ liệu đã lưu như danh sách camera rồi tải lại';

  @override
  String get settingsClearCacheDone => 'Đã xóa bộ nhớ đệm và tải lại dữ liệu';

  @override
  String get settingsSectionFilterDefaults => 'Thiết lập lọc mặc định';

  @override
  String get settingsShowWorld => 'Hiển thị camera ngoài Nhật Bản';

  @override
  String get settingsVideoOnly => 'Chỉ camera video';

  @override
  String get settingsHideUncertain => 'Ẩn camera có vị trí không rõ';

  @override
  String get settingsHideUncertainSubtitle =>
      'Ẩn các ghim viền vàng (vị trí gần đúng hoặc điểm đại diện)';

  @override
  String get settingsFilterDefaultsNote =>
      'Nội dung thiết lập tại đây sẽ là trạng thái ban đầu ở lần mở ứng dụng tiếp theo (bạn cũng có thể thay đổi tạm thời từ chú giải bản đồ)';

  @override
  String get settingsSectionRequest => 'Yêu cầu thêm hoặc gỡ camera';

  @override
  String get settingsRequestForm => 'Biểu mẫu tư vấn, yêu cầu';

  @override
  String get settingsRequestFormSubtitle =>
      'Hãy dùng biểu mẫu này để yêu cầu thêm camera hoặc gỡ camera khỏi ứng dụng (không cần đăng nhập). Chúng tôi xử lý nhanh chóng đề nghị gỡ bỏ từ đơn vị lắp đặt và vận hành';

  @override
  String get settingsSectionLicense => 'Nguồn và giấy phép';

  @override
  String get settingsAttributionList => 'Danh sách nguồn và giấy phép';

  @override
  String get settingsAttributionListSubtitle =>
      'Danh sách các đơn vị cung cấp hình ảnh camera';

  @override
  String get settingsTerms => 'Điều khoản sử dụng';

  @override
  String get settingsPrivacy => 'Chính sách quyền riêng tư';

  @override
  String get settingsLegalJapaneseOnly =>
      'Nội dung Điều khoản sử dụng và Chính sách quyền riêng tư chỉ có bằng tiếng Nhật (bản tiếng Nhật là bản chính thức)';

  @override
  String get settingsSectionAbout => 'Về ứng dụng này';

  @override
  String get settingsVersion => 'Phiên bản';

  @override
  String get settingsInvite => 'Mời bạn bè';

  @override
  String get settingsInviteSubtitle =>
      'Chia sẻ trang App Store bằng mã QR hoặc đường liên kết';

  @override
  String get settingsInviteDialogBody =>
      'Quét mã QR hoặc gửi đường liên kết\nđể mở trang ứng dụng trên App Store';

  @override
  String get settingsInviteShareText =>
      'Japan Live Camera Map - sông ngòi, đường bộ, phòng chống thiên tai';

  @override
  String get settingsLinkCopied => 'Đã sao chép đường liên kết';

  @override
  String get settingsReview => 'Đánh giá ứng dụng';

  @override
  String get settingsReviewSubtitle => 'Viết đánh giá trên App Store';

  @override
  String get settingsOtherApps => 'Ứng dụng khác của nhà phát triển';

  @override
  String get settingsShowMoreApps => 'Xem thêm ứng dụng khác';

  @override
  String get settingsSectionDisclaimer => 'Miễn trừ trách nhiệm';

  @override
  String get settingsOssLicenses => 'Giấy phép mã nguồn mở';

  @override
  String get settingsNotifyDiag => 'Chẩn đoán thông báo';

  @override
  String get settingsNotifyDiagSubtitle =>
      'Kiểm tra trạng thái khi không nhận được thông báo';

  @override
  String get settingsNotifyDiagUnlocked =>
      'Đã hiển thị mục chẩn đoán thông báo (trong phần Thông báo thảm họa)';

  @override
  String settingsNotifyPermission(String value) {
    return 'Quyền thông báo: $value';
  }

  @override
  String settingsNotifyApns(String value) {
    return 'Mã APNs: $value';
  }

  @override
  String get settingsNotifyFcm => 'Mã FCM:';

  @override
  String get settingsCopyToken => 'Sao chép mã token';

  @override
  String get settingsTokenCopied => 'Đã sao chép mã FCM';

  @override
  String get settingsCrashDiag => 'Dữ liệu chẩn đoán sự cố';

  @override
  String get settingsCrashDiagSubtitle =>
      'Xem và sao chép bản ghi thoát đột ngột (MetricKit)';

  @override
  String get settingsCrashDiagNone => 'Chưa có dữ liệu chẩn đoán';

  @override
  String get settingsCrashDiagNoneHint =>
      'Chưa có dữ liệu chẩn đoán.\nBản ghi xuất hiện khi bạn mở lại ứng dụng sau một sự cố';

  @override
  String get settingsCopyFullText => 'Sao chép toàn văn';

  @override
  String get settingsJsonCopied => 'Đã sao chép JSON chẩn đoán';

  @override
  String get attributionScreenTitle => 'Danh sách nguồn và giấy phép';

  @override
  String get attributionOpenYoutube => 'Xem nguồn phát trên YouTube';

  @override
  String get attributionOpenSite => 'Mở trang web của đơn vị cung cấp';

  @override
  String listTitle(int count) {
    return 'Danh sách ($count)';
  }

  @override
  String get listSearchHint => 'Tìm theo tên camera, tên sông, tên tuyến đường';

  @override
  String get listEmpty => 'Không có camera nào phù hợp với điều kiện';

  @override
  String get listRanking => 'Bảng xếp hạng';

  @override
  String favoritesTitle(int count) {
    return 'Yêu thích ($count)';
  }

  @override
  String get favoritesEmpty =>
      'Bạn chưa có mục yêu thích nào.\nHãy mở một camera trên bản đồ và nhấn ★ để thêm.';

  @override
  String get favoritesEmptyFiltered =>
      'Không có mục yêu thích nào phù hợp với điều kiện lọc';

  @override
  String get favoritesSort => 'Sắp xếp';

  @override
  String get favoritesSortNewest => 'Thêm mới nhất trước';

  @override
  String get favoritesSortOldest => 'Thêm cũ nhất trước';

  @override
  String get favoritesSortName => 'Theo tên';

  @override
  String get favoritesSortCategory => 'Theo danh mục';

  @override
  String get favoritesToggleView => 'Đổi cách hiển thị';

  @override
  String get favoritesRefreshAll => 'Cập nhật tất cả (lần lượt 3 camera)';

  @override
  String get favoritesVideoOnly => 'Chỉ video';

  @override
  String get rankingTitle => 'Xếp hạng toàn quốc';

  @override
  String get rankingModeNow => 'Đang được xem (TOP 10 trong 24 giờ)';

  @override
  String get rankingModeWeek => 'Được xem nhiều (TOP 30 trong 7 ngày)';

  @override
  String get rankingModeFavorites => 'Được yêu thích (Top 20)';

  @override
  String get rankingNote =>
      'Bảng xếp hạng dựa trên thống kê ẩn danh của toàn bộ người dùng (cập nhật hằng ngày)';

  @override
  String get rankingEmpty =>
      'Chưa có dữ liệu thống kê (cập nhật mỗi ngày một lần)';

  @override
  String get rankingPreparing =>
      'Bảng xếp hạng toàn quốc đang được chuẩn bị.\nDữ liệu được tổng hợp ba giờ một lần.';

  @override
  String get rankingFetchFailed => 'Không tải được dữ liệu';

  @override
  String rankingFetchFailedHttp(int code) {
    return 'Không tải được dữ liệu (HTTP $code)';
  }

  @override
  String get rankingUnitViews => 'lượt xem';

  @override
  String get rankingUnitFavorites => 'lượt lưu';

  @override
  String get detailLive => 'Đang phát trực tiếp';

  @override
  String get detailTimeUnknown => 'Không rõ thời điểm chụp';

  @override
  String detailRefreshEvery(int sec) {
    return 'Cập nhật mỗi $sec giây';
  }

  @override
  String detailRefreshIn(int sec) {
    return '$sec giây';
  }

  @override
  String get detailRefreshNow => 'Cập nhật';

  @override
  String get detailPosRepresentative =>
      'Vị trí là điểm đại diện của khu vực rộng';

  @override
  String get detailPosApprox => 'Vị trí chỉ là gần đúng';

  @override
  String get detailNotUpdating => 'Hình ảnh không được cập nhật';

  @override
  String get detailWorld => 'Ngoài Nhật Bản';

  @override
  String get detailCategoryAndPlace => 'Danh mục và vị trí';

  @override
  String get detailOpenMap => 'Xem trên bản đồ';

  @override
  String get detailHotelsTitle => 'Tìm chỗ nghỉ gần đây';

  @override
  String get detailOpenSourceSite => 'Xem trang nguồn';

  @override
  String get detailOpenYoutube => 'Xem trên YouTube';

  @override
  String get detailOpenChannel => 'Xem trang kênh';

  @override
  String get detailOpenOriginalPage => 'Xem trang gốc';

  @override
  String get detailReportProblem => 'Báo lỗi của camera này';

  @override
  String get detailNearby => 'Camera lân cận';

  @override
  String detailDistanceKm(String km) {
    return 'Khoảng $km km';
  }

  @override
  String get detailWifiOnlyBlocked =>
      'Theo thiết lập của bạn, hình ảnh chỉ được tải khi có kết nối Wi-Fi';

  @override
  String get detailNoImage => 'Hiện không lấy được hình ảnh';

  @override
  String get detailEmbedBlockedYoutube =>
      'Theo thiết lập của đơn vị cung cấp,\nvideo này không phát được trong ứng dụng';

  @override
  String get detailEmbedBlockedPage =>
      'Theo điều kiện sử dụng của nguồn phát,\nnội dung này không hiển thị được trong ứng dụng';

  @override
  String get detailIHighwayTitle =>
      'Xem camera trực tiếp trên\ntrang “iHighway” chính thức của NEXCO';

  @override
  String get detailIHighwayBody =>
      'Nhấn để mở trang chính thức trong trình duyệt của ứng dụng và\ntự động di chuyển đến vị trí của camera này';

  @override
  String get detailIHighwayHost => 'ihighway.jp (trang chính thức của NEXCO)';

  @override
  String get detailMapTileGsi => 'Bản đồ nền GSI';

  @override
  String get elevationLoading => 'Độ cao …';

  @override
  String elevationValue(String value, String source) {
    return 'Độ cao $value ($source)';
  }

  @override
  String timeTakenAt(String time, String relative) {
    return 'Chụp lúc $time$relative';
  }

  @override
  String get timeRelJustNow => ' (vừa xong)';

  @override
  String timeRelMinutes(int n) {
    return ' ($n phút trước)';
  }

  @override
  String timeRelHours(int n) {
    return ' ($n giờ trước)';
  }

  @override
  String timeMonthDay(int month, int day) {
    return '$day/$month';
  }

  @override
  String get intensity5Lower => '5 yếu';

  @override
  String get intensity5Upper => '5 mạnh';

  @override
  String get intensity6Lower => '6 yếu';

  @override
  String get intensity6Upper => '6 mạnh';

  @override
  String get quakeLevel5Lower => 'Cường độ địa chấn 5 độ yếu trở lên';

  @override
  String get quakeLevel5Upper => 'Cường độ địa chấn 5 độ mạnh trở lên';

  @override
  String get quakeLevel6Lower => 'Cường độ địa chấn 6 độ yếu trở lên';

  @override
  String get warning02 => 'Cảnh báo bão tuyết';

  @override
  String get warning03 => 'Cảnh báo mưa to';

  @override
  String get warning04 => 'Cảnh báo lũ lụt';

  @override
  String get warning05 => 'Cảnh báo gió bão dữ dội';

  @override
  String get warning06 => 'Cảnh báo tuyết nhiều';

  @override
  String get warning07 => 'Cảnh báo sóng cao';

  @override
  String get warning08 => 'Cảnh báo triều cường';

  @override
  String get warning09 => 'Cảnh báo tai họa sạt lở đất';

  @override
  String get warning43 => 'Cảnh báo khẩn cấp mưa to';

  @override
  String get warning44 => 'Cảnh báo khẩn cấp lũ lụt';

  @override
  String get warning48 => 'Cảnh báo khẩn cấp triều cường';

  @override
  String get warning49 => 'Cảnh báo khẩn cấp tai họa sạt lở đất';

  @override
  String get warning32 => 'Cảnh báo đặc biệt bão tuyết';

  @override
  String get warning33 => 'Cảnh báo đặc biệt mưa to';

  @override
  String get warning34 => 'Cảnh báo đặc biệt lũ lụt';

  @override
  String get warning35 => 'Cảnh báo đặc biệt gió bão dữ dội';

  @override
  String get warning36 => 'Cảnh báo đặc biệt tuyết nhiều';

  @override
  String get warning37 => 'Cảnh báo đặc biệt sóng cao';

  @override
  String get warning38 => 'Cảnh báo đặc biệt triều cường';

  @override
  String get warning39 => 'Cảnh báo đặc biệt tai họa sạt lở đất';

  @override
  String get advisory10 => 'Thông tin lưu ý mưa to';

  @override
  String get advisory12 => 'Thông tin lưu ý tuyết nhiều';

  @override
  String get advisory13 => 'Thông tin lưu ý gió và tuyết';

  @override
  String get advisory14 => 'Thông tin lưu ý sấm sét';

  @override
  String get advisory15 => 'Thông tin lưu ý gió mạnh';

  @override
  String get advisory16 => 'Thông tin lưu ý sóng cao';

  @override
  String get advisory17 => 'Thông tin lưu ý tuyết tan';

  @override
  String get advisory18 => 'Thông tin lưu ý ngập lụt';

  @override
  String get advisory19 => 'Thông tin lưu ý triều cường';

  @override
  String get advisory20 => 'Thông tin lưu ý sương mù';

  @override
  String get advisory21 => 'Thông tin lưu ý không khí khô';

  @override
  String get advisory22 => 'Thông tin lưu ý tuyết lở';

  @override
  String get advisory23 => 'Thông tin lưu ý nhiệt độ thấp';

  @override
  String get advisory24 => 'Thông tin lưu ý sương giá';

  @override
  String get advisory25 => 'Thông tin lưu ý đóng băng';

  @override
  String get advisory26 => 'Thông tin lưu ý tuyết bám dính';

  @override
  String get advisory29 => 'Thông tin lưu ý tai họa sạt lở đất';

  @override
  String get mapLocationDenied =>
      'Ứng dụng chưa được phép sử dụng vị trí (bạn có thể thay đổi trong Cài đặt)';

  @override
  String get mapLocationFailed => 'Không lấy được vị trí hiện tại';

  @override
  String get mapLegendTitle => 'Chú giải và bộ lọc';

  @override
  String get mapLegendSearchHint =>
      'Tìm theo tên camera, đơn vị vận hành, tên sông hoặc tuyến đường';

  @override
  String get mapFilterFavoritesOnly => 'Chỉ mục yêu thích';

  @override
  String get mapFilterOkOnly => 'Chỉ camera đang hoạt động';

  @override
  String get mapLegendLiveDot => 'Chấm đỏ = video (phát trực tiếp)';

  @override
  String get mapLegendUncertain =>
      'Viền vàng = vị trí chưa xác định (gần đúng hoặc điểm đại diện)';

  @override
  String get mapLegendFrozen => 'Mờ = hình ảnh lâu chưa được cập nhật';

  @override
  String get mapLegendFavorite => 'Sao vàng = đã thêm vào yêu thích';

  @override
  String get mapLegendCluster =>
      'Vòng tròn có số = nhóm camera lân cận (nhấn để phóng to)';

  @override
  String get mapSearchTitle => 'Tìm địa điểm';

  @override
  String get mapSearchHint =>
      'Tên địa danh hoặc địa chỉ (ví dụ: Shibuya, Kanazawa Hirosaka)';

  @override
  String get mapSearchNotFound =>
      'Không tìm thấy. Hãy thử tên địa danh, địa chỉ hoặc tên camera';

  @override
  String get mapSearchSectionCameras => 'Camera';

  @override
  String get mapSearchSectionPlaces => 'Địa điểm';

  @override
  String mapPointCameras(int count) {
    return 'Camera tại điểm này ($count)';
  }

  @override
  String mapFilteredCount(int count) {
    return 'Đang lọc: $count camera';
  }

  @override
  String mapTotalCount(int count) {
    return '$count camera';
  }

  @override
  String get mapLayersTooltip => 'Lớp bản đồ';

  @override
  String get bosaiTitle => 'Tin thảm họa';

  @override
  String get bosaiTabQuake => 'Động đất, sóng thần';

  @override
  String get bosaiTabWarning => 'Cảnh báo khí tượng';

  @override
  String get bosaiTabHeat => 'Sốc nhiệt';

  @override
  String get bosaiNoWarnings =>
      'Hiện không có cảnh báo hay thông tin lưu ý nào đang được công bố';

  @override
  String get bosaiWarningNoteNone =>
      'Nguồn: Cơ quan Khí tượng. Hiện không có cảnh báo hay cảnh báo đặc biệt nào được công bố. Các khu vực chỉ có thông tin lưu ý có thể xem ở danh sách bên dưới.';

  @override
  String get bosaiWarningNote =>
      'Nguồn: Cơ quan Khí tượng, Cảnh báo và thông tin lưu ý khí tượng. Nhấn vào một tỉnh thành để xem danh sách camera của tỉnh thành đó.';

  @override
  String bosaiAdvisoryRegions(int count) {
    return 'Khu vực đang có thông tin lưu ý ($count tỉnh thành)';
  }

  @override
  String bosaiWarningAreasTitle(String pref) {
    return 'Khu vực có cảnh báo tại $pref';
  }

  @override
  String bosaiAdvisoryAreasTitle(String pref) {
    return 'Khu vực có thông tin lưu ý tại $pref';
  }

  @override
  String get bosaiMuniNote =>
      'Nguồn: Cơ quan Khí tượng. Nhấn vào một quận, huyện, thành phố để xem danh sách camera tại đó';

  @override
  String get bosaiMuniFetchFailed =>
      'Không tải được chi tiết khu vực được công bố';

  @override
  String get bosaiMuniNone =>
      'Hiện không có quận, huyện, thành phố nào được công bố';

  @override
  String bosaiCameraCount(int count) {
    return '$count camera';
  }

  @override
  String get bosaiNoCamera => 'Không có camera';

  @override
  String bosaiMuniCamerasTitle(String name) {
    return 'Camera tại $name (đang có cảnh báo)';
  }

  @override
  String get settingsJmaDictionary =>
      'Về bản dịch thuật ngữ phòng chống thiên tai';

  @override
  String get settingsJmaDictionaryNote =>
      'Bản dịch tên cảnh báo, tên thông tin lưu ý và cường độ địa chấn sang các ngôn ngữ tuân theo “Từ điển đa ngôn ngữ về thông tin khí tượng” của Cơ quan Khí tượng. Nguồn: trang web của Cơ quan Khí tượng';

  @override
  String get hazardFloodTitle =>
      'Khu vực ngập lụt giả định do lũ (quy mô tối đa giả định)';

  @override
  String get hazardLandslideTitle => 'Khu vực cảnh giác tai họa sạt lở đất';

  @override
  String get hazardTsunamiTitle => 'Khu vực ngập lụt giả định do sóng thần';

  @override
  String get hazardHightideTitle => 'Khu vực ngập lụt giả định do triều cường';

  @override
  String get hazardLandslideSteepSlope => 'Sườn dốc đứng';

  @override
  String get hazardLandslideDebrisFlow => 'Dòng mảnh vụn';

  @override
  String get hazardLandslideSlide => 'Trượt đất';

  @override
  String get hazardDisclaimer =>
      'Vui lòng xem bản đồ nguy cơ thiên tai của từng thành phố, thị trấn để có thông tin mới nhất và chi tiết. Khi quyết định lánh nạn, hãy tuân theo thông tin lánh nạn của chính quyền địa phương';

  @override
  String get facilityKindWater => 'Điểm cấp nước và cơ sở cấp nước khẩn cấp';

  @override
  String get facilityKindStock => 'Kho dự trữ phòng chống thiên tai';

  @override
  String get facilityKindFireWater =>
      'Nguồn nước chữa cháy (trụ nước, bể chứa)';

  @override
  String get facilityKindWaterShort => 'Điểm cấp nước';

  @override
  String get facilityKindStockShort => 'Kho dự trữ';

  @override
  String get facilityKindFireWaterShort => 'Nước chữa cháy';

  @override
  String get facilityDisclaimer =>
      'Chỉ gồm các địa phương có công bố. Vui lòng hỏi từng địa phương để có thông tin mới nhất';

  @override
  String get facilityNoData => 'Chưa có dữ liệu cho khu vực này';

  @override
  String get shelterHazardFlood => 'Lũ lụt';

  @override
  String get shelterHazardSediment => 'Tai họa sạt lở đất';

  @override
  String get shelterHazardHightide => 'Triều cường';

  @override
  String get shelterHazardEarthquake => 'Động đất';

  @override
  String get shelterHazardTsunami => 'Sóng thần';

  @override
  String get shelterHazardFire => 'Hỏa hoạn';

  @override
  String get shelterHazardInlandFlood => 'Ngập úng cục bộ';

  @override
  String get shelterHazardVolcano => 'Núi lửa';

  @override
  String get shelterDisclaimer =>
      'Vui lòng hỏi từng thành phố, thị trấn để biết tình hình mới nhất và chi tiết';

  @override
  String get riskLandTitle => 'Nguy cơ sạt lở đất (Kikikuru)';

  @override
  String get riskInundTitle => 'Nguy cơ ngập lụt (Kikikuru)';

  @override
  String get riskFloodTitle => 'Nguy cơ lũ lụt (Kikikuru)';

  @override
  String get riskLandSubtitle =>
      'Mức độ nguy cơ tai họa sạt lở đất (lưới 1 km, cập nhật 10 phút một lần)';

  @override
  String get riskInundSubtitle =>
      'Mức độ nguy cơ tai họa ngập lụt (lưới 1 km, cập nhật 10 phút một lần)';

  @override
  String get riskFloodSubtitle =>
      'Mức độ nguy cơ lũ lụt (theo từng sông, cập nhật 10 phút một lần)';

  @override
  String get riskLevelWatch => 'Lưu ý thông tin tiếp theo';

  @override
  String get riskLevelCaution => 'Lưu ý';

  @override
  String get riskLevelWarning => 'Cảnh giác';

  @override
  String get riskLevelDanger => 'Nguy hiểm';

  @override
  String get riskLevelCritical => 'Thảm họa đến gần';

  @override
  String get wbgtLevelDanger => 'Nguy hiểm';

  @override
  String get wbgtLevelSevereWarning => 'Cảnh giác cao';

  @override
  String get wbgtLevelWarning => 'Cảnh giác';

  @override
  String get wbgtLevelCaution => 'Lưu ý';

  @override
  String get wbgtLevelSafe => 'Khá an toàn';

  @override
  String get heatAlertSpecial => 'Cảnh báo đặc biệt chứng sốc nhiệt';

  @override
  String get heatAlertSpecialPending =>
      'Cảnh báo đặc biệt chứng sốc nhiệt (đang xác định)';

  @override
  String get heatAlertWarning => 'Cảnh báo chứng sốc nhiệt';

  @override
  String get heatAlertDisclaimer =>
      'Đây là thông tin tham khảo. Vui lòng xem trang thông tin phòng chống chứng sốc nhiệt để biết công bố chính thức';

  @override
  String get languageNameZhHans => '简体中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameKo => '한국어';

  @override
  String get languageNameVi => 'Tiếng Việt';

  @override
  String get mapLayerPanelSubtitle =>
      'Mỗi lần chỉ chồng được một lớp lên bản đồ.';

  @override
  String get mapLayerNone => 'Không hiển thị';

  @override
  String get mapLayerSectionWeather => 'Khí tượng';

  @override
  String get mapLayerRainRadarTitle => 'Ra đa mây mưa (hiện tại)';

  @override
  String get mapLayerRainRadarSubtitle =>
      'Bản tin lượng nước mưa có độ phân giải cao, cập nhật 5 phút một lần';

  @override
  String get mapLayerQuakesTitle => 'Tâm chấn';

  @override
  String get mapQuakePeriodDay => '24 giờ';

  @override
  String get mapQuakePeriodWeek => '7 ngày';

  @override
  String get mapQuakePeriodMonth => '30 ngày';

  @override
  String get mapLayerRain24hTitle => 'Lượng mưa 24 giờ';

  @override
  String get mapLayerRain24hSubtitle =>
      'Lượng mưa phân tích của Cơ quan Khí tượng (theo vùng) và giá trị quan trắc AMeDAS khi phóng to';

  @override
  String get mapLayerSectionHazard => 'Bản đồ nguy cơ thiên tai';

  @override
  String get mapHazardLandslideSubtitle =>
      'Sườn dốc đứng, dòng mảnh vụn và trượt đất (vàng = khu vực cảnh giác / đỏ = khu vực cảnh giác đặc biệt)';

  @override
  String get mapHazardDepthSubtitle =>
      'Hiển thị độ sâu ngập lụt dự kiến theo màu';

  @override
  String get mapShelterTitle => 'Nơi lánh nạn';

  @override
  String get mapLayerShelterTitle =>
      'Nơi lánh nạn (nơi lánh nạn khẩn cấp chỉ định và nơi trú ẩn chỉ định)';

  @override
  String get mapLayerShelterSubtitle =>
      'Hiển thị khi phóng to. Có thể lọc theo loại thảm họa.';

  @override
  String get mapFacilityTitle => 'Cơ sở phòng chống thiên tai';

  @override
  String get mapLayerFacilityTitle =>
      'Cơ sở phòng chống thiên tai (điểm cấp nước và kho dự trữ)';

  @override
  String get mapLayerFacilitySubtitle =>
      'Hiển thị khi phóng to. Có thể lọc theo loại.';

  @override
  String mapQuakeNearbyTitle(int count) {
    return 'Động đất quanh đây: $count trận';
  }

  @override
  String get mapQuakeUnknownPlace => 'Tâm chấn (chưa công bố chi tiết)';

  @override
  String mapQuakeMaxIntensity(String value) {
    return 'Cường độ địa chấn tối đa $value';
  }

  @override
  String mapNearbyCamerasTitle(String name) {
    return 'Camera quanh $name';
  }

  @override
  String get mapQuakeTapHint =>
      'Nhấn để xem camera trực tiếp trong bán kính 50 km.';

  @override
  String get mapShelterNoticeTitle => 'Về lớp nơi lánh nạn';

  @override
  String get mapShelterNoticeBody =>
      '・“Nơi lánh nạn khẩn cấp chỉ định” là nơi chạy đến để bảo vệ tính mạng khỏi nguy hiểm của thảm họa; “Nơi trú ẩn chỉ định” là cơ sở để ở lại trong một khoảng thời gian (hiển thị bằng viền đôi)\n・Nơi lánh nạn khẩn cấp chỉ định được chỉ định theo từng loại thảm họa, nên tùy loại thảm họa có thể không lánh nạn được\n・Vì là thông tin do các thành phố, thị trấn cung cấp nên có thể chưa mới nhất hoặc có nơi chưa được đăng tải. Vui lòng hỏi thành phố, thị trấn liên quan để có thông tin chính xác';

  @override
  String get mapShelterHazardAll => 'Tất cả';

  @override
  String get mapShelterDesignated => 'Nơi trú ẩn chỉ định';

  @override
  String get mapShelterHazardsLabel => 'Loại thảm họa tương ứng';

  @override
  String get mapOpenRoute => 'Xem đường đi trên Google Maps';

  @override
  String get mapNearbyCamerasButton => 'Camera trực tiếp lân cận';

  @override
  String get mapFacilityNoticeTitle => 'Về lớp cơ sở phòng chống thiên tai';

  @override
  String get mapFacilityNoticeBody =>
      '・Đây là tập hợp danh sách “cơ sở cấp nước khẩn cấp”, “kho dự trữ” và “cơ sở nguồn nước chữa cháy” do từng địa phương công bố dưới dạng dữ liệu mở. Chỉ gồm các địa phương có công bố nên chưa bao phủ toàn quốc\n・Trụ nước chữa cháy và bể chứa nước chữa cháy là thiết bị phục vụ hoạt động chữa cháy, không dành cho người dân sử dụng\n・Điểm cấp nước được mở khi xảy ra thảm họa, không nhất thiết cấp nước trong điều kiện bình thường\n・Thời điểm cập nhật khác nhau tùy từng địa phương. Vui lòng hỏi từng địa phương để có thông tin chính xác';

  @override
  String mapFacilityOwner(String owner) {
    return 'Cung cấp: $owner';
  }

  @override
  String get mapFacilityGeocodedNote =>
      'Đây là vị trí ước tính từ địa chỉ (có thể lệch so với vị trí thực tế).';

  @override
  String get mapFacilitySourceDataset => 'Nguồn (bộ dữ liệu)';

  @override
  String mapNowcastSpanHours(String value) {
    return '$value giờ';
  }

  @override
  String mapNowcastSpanMinutes(int value) {
    return '$value phút';
  }

  @override
  String get mapNowcastNow => 'Hiện tại (quan trắc)';

  @override
  String get mapNowcastForecastHourly => 'Dự báo, lượng mưa 1 giờ';

  @override
  String get mapNowcastForecast => 'Dự báo';

  @override
  String mapNowcastAfter(String span, String kind) {
    return 'Sau $span ($kind)';
  }

  @override
  String mapNowcastBefore(String span) {
    return 'Trước $span (quan trắc)';
  }

  @override
  String get mapNowcastBackToNow => 'Về hiện tại';

  @override
  String get mapNowcastNowMarker => '▲ Hiện tại';

  @override
  String mapNowcastLast(String label) {
    return '$label (6 giờ tới)';
  }

  @override
  String mapLegendRainRadar(String label) {
    return 'Ra đa mây mưa $label';
  }

  @override
  String mapLegendRainRadarKind(String label, String kind) {
    return 'Ra đa mây mưa $label ($kind)';
  }

  @override
  String get mapLegendRainWeak => 'Yếu';

  @override
  String mapLegendQuakes(String period, int count) {
    return 'Tâm chấn $period ($count trận)';
  }

  @override
  String mapLegendIntensity(String value) {
    return 'Cường độ địa chấn $value';
  }

  @override
  String get mapLegendIntensity6Up => '6 yếu trở lên';

  @override
  String mapLegendRain24h(String label) {
    return 'Lượng mưa 24 giờ $label';
  }

  @override
  String mapLegendRain24hZoom(String label) {
    return 'Lượng mưa 24 giờ $label (phóng to để xem giá trị quan trắc)';
  }

  @override
  String mapLegendLandslide(String title) {
    return '$title (cảnh giác / cảnh giác đặc biệt)';
  }

  @override
  String get mapLegendShelterZoomIn =>
      'Nơi lánh nạn (phóng to để hiển thị nơi lánh nạn)';

  @override
  String mapLegendShelter(int count) {
    return 'Nơi lánh nạn ($count)';
  }

  @override
  String mapLegendShelterCluster(int count) {
    return 'Nơi lánh nạn ($count, gộp nhóm)';
  }

  @override
  String mapLegendShelterHazard(String hazard, int count) {
    return 'Nơi lánh nạn · $hazard ($count)';
  }

  @override
  String mapLegendShelterHazardCluster(String hazard, int count) {
    return 'Nơi lánh nạn · $hazard ($count, gộp nhóm)';
  }

  @override
  String get mapLegendShelterEmergency => 'Nơi lánh nạn khẩn cấp chỉ định';

  @override
  String get mapLegendShelterDesignated => 'Viền đôi = nơi trú ẩn chỉ định';

  @override
  String get mapLegendFacilityZoomIn =>
      'Cơ sở phòng chống thiên tai (phóng to để hiển thị)';

  @override
  String mapLegendFacilityNoData(String message) {
    return 'Cơ sở phòng chống thiên tai ($message)';
  }

  @override
  String mapLegendFacility(int count) {
    return 'Cơ sở phòng chống thiên tai ($count)';
  }

  @override
  String mapLegendFacilityCluster(int count) {
    return 'Cơ sở phòng chống thiên tai ($count, gộp nhóm)';
  }

  @override
  String get mapLegendFetchFailed => 'Không tải được';

  @override
  String get mapShelterFetchFailed =>
      'Không tải được nơi lánh nạn (nhấn để thử lại)';

  @override
  String get mapFacilityFetchFailed =>
      'Không tải được cơ sở phòng chống thiên tai (nhấn để thử lại)';

  @override
  String mapRainTooltip(String name, String mm) {
    return '$name 24 giờ $mm mm';
  }

  @override
  String get bosaiFetchFailedPull =>
      'Không tải được dữ liệu (kéo xuống để thử lại)';

  @override
  String get bosaiTsunamiInfo => 'Thông tin sóng thần';

  @override
  String get bosaiUnknownPlace => 'Không rõ';

  @override
  String bosaiFetchFailedDetail(String error) {
    return 'Không tải được dữ liệu ($error)';
  }

  @override
  String get bosaiTimeJustNow => 'Vừa xong';

  @override
  String bosaiTimeMinutesAgo(int n) {
    return '$n phút trước';
  }

  @override
  String bosaiTimeHoursAgo(int n) {
    return '$n giờ trước';
  }

  @override
  String bosaiTimeMonthDayHour(int month, int day, int hour) {
    return 'Khoảng $hour giờ ngày $day/$month';
  }

  @override
  String bosaiQuakeIntensityTitle(String place) {
    return 'Cường độ địa chấn tại $place';
  }

  @override
  String bosaiNearbyCamerasTitle(String place) {
    return 'Camera quanh $place';
  }

  @override
  String get bosaiQuakeEmpty =>
      'Không có thông tin động đất trong 72 giờ gần nhất';

  @override
  String bosaiQuakeAsOf(String time) {
    return ' (tính đến $time, mới nhất trước)';
  }

  @override
  String bosaiQuakeNote(String at) {
    return 'Nguồn: Cơ quan Khí tượng, Thông tin động đất (72 giờ gần nhất)$at. Nhấn vào một trận động đất để xem danh sách camera trực tiếp tại các quận, huyện, thành phố đã rung lắc (nếu không có cường độ địa chấn theo quận, huyện, thành phố thì hiển thị camera quanh tâm chấn).';
  }

  @override
  String get bosaiBadgeTsunami => 'Sóng thần';

  @override
  String bosaiBadgeIntensity(String value) {
    return 'Cường độ\n$value';
  }

  @override
  String bosaiMuniObserved(int count) {
    return 'Quan trắc tại $count quận, huyện, thành phố';
  }

  @override
  String bosaiWarningStaleAt(String time) {
    return 'Không tải được thông tin mới nhất (đang hiển thị thông tin tính đến $time)';
  }

  @override
  String bosaiWarningAsOf(String time) {
    return 'Tính đến $time';
  }

  @override
  String get bosaiHeatOffSeason =>
      'Hiện ngoài thời gian vận hành của thông tin cảnh báo chứng sốc nhiệt (được công bố từ cuối tháng 4 đến cuối tháng 10 hằng năm)';

  @override
  String bosaiHeatReportAt(int month, int day, String hour) {
    return ' (công bố $hour giờ ngày $day/$month)';
  }

  @override
  String get bosaiHeatTapHint =>
      'Nhấn vào một tỉnh thành để xem danh sách camera của tỉnh thành đó.';

  @override
  String get bosaiHeatNone =>
      'Hiện không có thông tin cảnh báo chứng sốc nhiệt nào được công bố';

  @override
  String get bosaiHeatToday => 'Hôm nay';

  @override
  String get bosaiHeatTomorrow => 'Ngày mai';

  @override
  String bosaiHeatPrefCamerasTitle(String pref) {
    return 'Camera tại $pref (cảnh báo chứng sốc nhiệt)';
  }

  @override
  String get bosaiWbgtCardTitle => 'Chỉ số nắng nóng (WBGT) tại điểm gần bạn';

  @override
  String get bosaiWbgtUnavailable => 'Không tải được dữ liệu';

  @override
  String bosaiApproxDistance(String value) {
    return 'Khoảng $value';
  }

  @override
  String get bosaiWbgtNow => 'Hiện tại';

  @override
  String get bosaiWbgtNoCurrent => 'Không có giá trị quan trắc';

  @override
  String bosaiWbgtLevelAt(String level, String time) {
    return '$level ($time)';
  }

  @override
  String get bosaiWbgtForecast => 'Dự báo';

  @override
  String bosaiWbgtHour(int hour) {
    return '$hour giờ';
  }

  @override
  String bosaiWbgtNextDayHour(int hour) {
    return '$hour giờ hôm sau';
  }

  @override
  String bosaiWbgtDateHour(int month, int day, int hour) {
    return '$hour giờ $day/$month';
  }

  @override
  String get bosaiQuakeMuniNote =>
      'Nguồn: Cơ quan Khí tượng, Thông tin động đất (theo cường độ địa chấn giảm dần). Nhấn vào một quận, huyện, thành phố để xem danh sách camera tại đó. Nơi không có camera sẽ hiển thị camera quanh tâm chấn.';

  @override
  String get bosaiEpicenterNearby => 'Camera quanh tâm chấn (theo khoảng cách)';

  @override
  String bosaiMuniCodeFallback(String code) {
    return 'Quận, huyện, thành phố $code';
  }

  @override
  String bosaiPrefEpicenterFallback(String pref) {
    return '$pref · Hiển thị camera quanh tâm chấn';
  }

  @override
  String bosaiMuniIntensityCamerasTitle(String name, String intensity) {
    return 'Camera tại $name (cường độ địa chấn $intensity)';
  }

  @override
  String bosaiLiveOnly(int count) {
    return 'Chỉ LIVE ($count)';
  }

  @override
  String get bosaiMuniFallbackNote =>
      'Vì không có camera tương ứng với quận, huyện, thành phố này nên đang hiển thị toàn bộ camera trong tỉnh thành';

  @override
  String get bosaiPrefNoCameras => 'Không có camera nào ở tỉnh thành này';

  @override
  String get bosaiNoLiveCameras => 'Không có camera phát trực tiếp';

  @override
  String get bosaiNoCamerasWithin50km => 'Không có camera trong bán kính 50 km';

  @override
  String get tipTitle => 'Ủng hộ nhà phát triển';

  @override
  String get tipIntro =>
      'Ứng dụng này do một cá nhân phát triển và vận hành. Sự ủng hộ của bạn giúp khảo sát và bổ sung camera, duy trì máy chủ giám sát, xử lý dữ liệu khí tượng, và là động lực để tiếp tục cập nhật. Việc ủng hộ là tự nguyện và không tạo ra khác biệt về tính năng.';

  @override
  String get tipCoffeeTitle => 'Nghỉ giải lao với lon cà phê';

  @override
  String get tipCoffeeSubtitle =>
      'Tặng tiền lon cà phê uống giữa những lúc phát triển';

  @override
  String get tipSweetsTitle => 'Bổ sung đường bằng đồ ngọt';

  @override
  String get tipSweetsSubtitle =>
      'Ủng hộ tiền đồ ngọt và cà phê cho những lúc lập trình tập trung';

  @override
  String get tipLunchTitle => 'Bữa trưa tiếp sức phát triển';

  @override
  String get tipLunchSubtitle =>
      'Mời một bữa trưa đầy dinh dưỡng cho tính năng mới tiếp theo';

  @override
  String get tipDevToolsTitle => 'Ủng hộ chi phí công cụ phát triển';

  @override
  String get tipDevToolsSubtitle =>
      'Ủng hộ chi phí dịch vụ dùng để khảo sát camera và giám sát máy chủ';

  @override
  String get tipPreparing =>
      'Các gói ủng hộ đang được chuẩn bị. Vui lòng thử lại sau ít lâu.';

  @override
  String get tipUnavailable =>
      'Thiết bị này không sử dụng được thanh toán trong ứng dụng.';

  @override
  String get tipPurchaseStartFailed => 'Không bắt đầu được giao dịch mua';

  @override
  String get tipThanks =>
      'Cảm ơn bạn đã ủng hộ! Đây là động lực lớn cho việc phát triển.';

  @override
  String tipPurchaseFailed(String error) {
    return 'Không hoàn tất được giao dịch mua ($error)';
  }

  @override
  String get tipUnknownError => 'Lỗi không xác định';

  @override
  String get tipNoticeTitle => 'Vui lòng xác nhận trước khi mua';

  @override
  String get tipNoticeBody =>
      'Việc ủng hộ được xử lý bằng thanh toán trong ứng dụng của App Store (việc hoàn tiền tuân theo quy định của Apple).';

  @override
  String get tipEula => 'EULA (Hợp đồng cấp phép sử dụng tiêu chuẩn của Apple)';

  @override
  String settingsDiagCrashRecords(int count, String name) {
    return 'Bản ghi: $count\nMới nhất: $name';
  }

  @override
  String get settingsDiagKindCrash => 'Sự cố';

  @override
  String get settingsDiagKindHang => 'Treo';

  @override
  String get settingsDiagKindCpu => 'Lỗi CPU';

  @override
  String get settingsDiagKindDiskWrite => 'Lỗi ghi đĩa';

  @override
  String settingsDiagCrashKinds(String kinds) {
    return 'Loại: $kinds';
  }

  @override
  String settingsDiagReadError(String error) {
    return 'Lỗi đọc: $error';
  }

  @override
  String get settingsDiagFetchFailed => 'Không lấy được';

  @override
  String get settingsDiagNotAcquired => 'Chưa lấy được (null)';

  @override
  String settingsDiagAcquired(String prefix) {
    return 'Đã lấy được ($prefix…)';
  }

  @override
  String settingsDiagError(String error) {
    return 'Lỗi: $error';
  }

  @override
  String get stockpileTitle => 'Dự trữ phòng chống thiên tai';

  @override
  String get stockpileEntryTitle => 'Danh sách dự trữ phòng chống thiên tai';

  @override
  String get stockpileEntrySubtitle =>
      'Tính lượng cần thiết theo số người trong gia đình và đánh dấu';

  @override
  String get stockpileBosaiLink => 'Dự trữ đã đủ chưa? Mở danh sách kiểm tra';

  @override
  String get stockpileHouseholdTitle => 'Số người trong gia đình';

  @override
  String get stockpileAdults => 'Người lớn';

  @override
  String get stockpileChildren => 'Trẻ em';

  @override
  String get stockpileDaysLabel => 'Số ngày dự trữ';

  @override
  String stockpileDaysValue(int days) {
    return '$days ngày';
  }

  @override
  String get stockpileSummaryTitle => 'Lượng cần thiết (tham khảo)';

  @override
  String stockpileSummaryWater(int liters) {
    return 'Nước $liters L';
  }

  @override
  String stockpileSummaryMeals(int meals) {
    return 'Thực phẩm $meals bữa';
  }

  @override
  String get stockpileSummaryNote =>
      'Tính theo hướng dẫn của chính phủ Nhật Bản (3 L nước và 3 bữa/người/ngày)';

  @override
  String get stockpileSourceMaff =>
      'Bộ Nông Lâm Ngư nghiệp – Cổng dự trữ thực phẩm gia đình';

  @override
  String get stockpileSourceCao =>
      'Nội các phủ – Trang thông tin phòng chống thiên tai';

  @override
  String stockpileProgress(int done, int total) {
    return 'Đã xong $done/$total';
  }

  @override
  String stockpileRequired(String quantity, String unit) {
    return 'Cần $quantity $unit';
  }

  @override
  String get stockpileSearchButton => 'Tìm mua';

  @override
  String get stockpileExpirySet => 'Đặt hạn dùng';

  @override
  String stockpileExpiryOn(String date) {
    return 'Hạn $date';
  }

  @override
  String get stockpileExpirySoon => 'Sắp hết hạn';

  @override
  String get stockpileExpired => 'Đã hết hạn';

  @override
  String get stockpileExpiryClear => 'Xóa hạn';

  @override
  String get stockpileAddItem => 'Thêm mục';

  @override
  String get stockpileItemNameLabel => 'Tên vật phẩm';

  @override
  String get stockpileItemQuantityLabel => 'Số lượng';

  @override
  String get stockpileItemCategoryLabel => 'Nhóm';

  @override
  String get stockpileDeleteItem => 'Xóa mục';

  @override
  String get stockpileMarkPrepared => 'Đã chuẩn bị';

  @override
  String get stockpileSectionExpiry => 'Hạn dùng';

  @override
  String get stockpileItemTapHint =>
      'Chạm vào mục để đặt hạn dùng, xem cách chọn và nơi mua';

  @override
  String get stockpileOfficialSite => 'Trang chính thức';

  @override
  String get stockpileInfants => 'Trẻ nhỏ (sữa, tã)';

  @override
  String stockpileNotifyExpiryBodyMany(String names, String date) {
    return '$names sắp hết hạn ($date)';
  }

  @override
  String stockpileNotifyMoreItems(int count) {
    return 'và $count mục khác';
  }

  @override
  String get stockpileNotifyNameSeparator => ', ';

  @override
  String stockpileDeleted(String item) {
    return 'Đã xóa “$item”';
  }

  @override
  String get stockpileUndo => 'Hoàn tác';

  @override
  String get stockpileReset => 'Khôi phục ban đầu';

  @override
  String get stockpileResetConfirm =>
      'Thao tác này xóa mọi đánh dấu, hạn dùng và mục đã thêm. Tiếp tục?';

  @override
  String get stockpileSectionReminder => 'Nhắc nhở';

  @override
  String get stockpileExpiryReminder => 'Nhắc trước hạn 1 tháng';

  @override
  String get stockpileExpiryReminderSubtitle =>
      'Máy sẽ báo lúc 9 giờ sáng, một tháng trước mỗi hạn bạn đặt';

  @override
  String get stockpileInspectionReminder => 'Nhắc vào ngày kiểm tra';

  @override
  String get stockpileInspectionReminderSubtitle =>
      'Lúc 9 giờ sáng ngày 11/3 và 1/9 (Ngày phòng chống thiên tai)';

  @override
  String get stockpileNotifyDenied =>
      'Thông báo chưa được cho phép. Hãy bật trong ứng dụng Cài đặt';

  @override
  String get stockpileNotifyTitle => 'Kiểm tra đồ dự trữ';

  @override
  String stockpileNotifyExpiryBody(String item, String date) {
    return '“$item” sắp hết hạn ($date)';
  }

  @override
  String get stockpileNotifyInspectionBody =>
      'Hãy kiểm tra hạn dùng và số lượng đồ dự trữ';

  @override
  String get stockpileGuideWhy => 'Cách chọn';

  @override
  String get stockpileGuideProducts => 'Sản phẩm tham khảo';

  @override
  String get stockpileGuideProductsNote =>
      'Chạm để tìm sản phẩm tại cửa hàng liên kết (↗ ở cuối dòng mở trang chính thức của nhà sản xuất). Vui lòng kiểm tra tình trạng bán và giá tại từng cửa hàng.';

  @override
  String get stockpileGuideSearch => 'Tìm sản phẩm';

  @override
  String stockpileGuideSearchAt(String shop) {
    return 'Tìm trên $shop';
  }

  @override
  String get stockpileGuideSources => 'Nguồn';

  @override
  String get stockpileDisclaimer =>
      'Đây là số liệu tham khảo. Hãy điều chỉnh cho phù hợp với gia đình bạn';

  @override
  String get stockpileCatWaterFood => 'Nước & thực phẩm';

  @override
  String get stockpileCatLightPower => 'Ánh sáng & điện';

  @override
  String get stockpileCatSanitation => 'Vệ sinh';

  @override
  String get stockpileCatFirstAid => 'Sơ cứu & y tế';

  @override
  String get stockpileCatEvacuation => 'Đồ sơ tán';

  @override
  String get stockpileCatValuables => 'Giấy tờ & thông tin';

  @override
  String get stockpileUnitLiter => 'L';

  @override
  String get stockpileUnitMeal => 'bữa';

  @override
  String get stockpileUnitPiece => 'cái';

  @override
  String get stockpileUnitSheet => 'tờ';

  @override
  String get stockpileUnitRoll => 'cuộn';

  @override
  String get stockpileUnitPair => 'đôi';

  @override
  String get stockpileUnitPack => 'gói';

  @override
  String get stockpileUnitTimes => 'lần';

  @override
  String get stockpileUnitDays => 'ngày';

  @override
  String get stockpileUnitSet => 'bộ';

  @override
  String get stockpileItemWater => 'Nước đóng chai';

  @override
  String get stockpileItemStapleFood => 'Lương thực chính';

  @override
  String get stockpileItemRetortFood => 'Đồ ăn đóng gói tiệt trùng';

  @override
  String get stockpileItemCannedFood => 'Đồ hộp';

  @override
  String get stockpileItemBabyFormula => 'Sữa bột / sữa pha sẵn';

  @override
  String get stockpileItemFlashlight => 'Đèn pin';

  @override
  String get stockpileItemBatteries => 'Pin';

  @override
  String get stockpileItemPowerBank => 'Sạc dự phòng';

  @override
  String get stockpileItemRadio => 'Radio cầm tay';

  @override
  String get stockpileItemPortableToilet => 'Nhà vệ sinh di động';

  @override
  String get stockpileItemToiletPaper => 'Giấy vệ sinh';

  @override
  String get stockpileItemWetWipes => 'Khăn ướt';

  @override
  String get stockpileItemGarbageBags => 'Túi rác';

  @override
  String get stockpileItemDiapers => 'Tã giấy';

  @override
  String get stockpileItemFirstAidKit => 'Bộ sơ cứu';

  @override
  String get stockpileItemMedicine => 'Thuốc thường dùng';

  @override
  String get stockpileItemMask => 'Khẩu trang';

  @override
  String get stockpileItemDisinfectant => 'Dung dịch sát khuẩn';

  @override
  String get stockpileItemBackpack => 'Ba lô khẩn cấp';

  @override
  String get stockpileItemBlanket => 'Chăn giữ nhiệt';

  @override
  String get stockpileItemGloves => 'Găng tay lao động';

  @override
  String get stockpileItemRope => 'Dây thừng';

  @override
  String get stockpileItemCash => 'Tiền mặt (gồm tiền xu)';

  @override
  String get stockpileItemIdCopy => 'Bản sao giấy tờ tùy thân';

  @override
  String get stockpileItemContactMemo => 'Ghi chú liên lạc';

  @override
  String get stockpileItemCable => 'Cáp sạc';

  @override
  String get stockpileChooseShop => 'Chọn cửa hàng';
}
