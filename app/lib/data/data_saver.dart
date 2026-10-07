/// 通信節約モード（災害時に回線が混み合うため、通信量を抑える）。
///
/// 設定は SharedPreferences `data_saver_mode`（auto / on / off。既定 auto）。
/// 自動のときは次のどちらかで入る:
///  1. 端末の省データ設定が有効（iOS: 低データモード、Android: データセーバー）
///  2. 利用者が特別警報（レベル5）の発表エリアに居る（`AppState.viewerInSpecialWarningArea`）
library;

enum DataSaverMode {
  auto('auto'),
  on('on'),
  off('off');

  const DataSaverMode(this.wire);
  final String wire;

  static DataSaverMode parse(String? v) => DataSaverMode.values
      .firstWhere((m) => m.wire == v, orElse: () => DataSaverMode.auto);
}

/// 通信節約モードが有効かの判定（純粋関数）
bool resolveDataSaver({
  required DataSaverMode mode,
  required bool deviceLowData,
  required bool inSpecialWarningArea,
}) {
  switch (mode) {
    case DataSaverMode.on:
      return true;
    case DataSaverMode.off:
      return false;
    case DataSaverMode.auto:
      return deviceLowData || inSpecialWarningArea;
  }
}

/// 「いま起きていること」の取得間隔（status の間隔は CameraRepository.statusMaxAgeSaver）
const Duration situationIntervalNormal = Duration(minutes: 10);
const Duration situationIntervalSaver = Duration(minutes: 30);

Duration situationInterval(bool saver) =>
    saver ? situationIntervalSaver : situationIntervalNormal;

/// YouTube 動画のサムネイル（通信節約中の再生前表示）。動画IDが無ければ null
String? youtubeThumbnailUrl(String? videoId) =>
    (videoId == null || videoId.isEmpty)
        ? null
        : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
