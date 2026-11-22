import 'package:shared_preferences/shared_preferences.dart';

/// カメラ詳細に出す「応援のお願い」の出し分け（1.7.5）。
///
/// よく使う人にだけ出す: カメラ詳細を開いた累計が [threshold] 回に達してから。
/// 回数は端末内（SharedPreferences）にだけ持つ。
class SupportPrompt {
  static const threshold = 20;
  static const _countKey = 'camera_open_count';

  /// カメラ詳細を開いた回数を 1 増やし、増やした後の累計を返す。
  /// 保存領域が使えない環境では 0（＝出さない）
  static Future<int> recordCameraOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, n);
      return n;
    } catch (_) {
      return 0;
    }
  }

  static bool shouldShow({required int openCount, required bool adFreeActive}) =>
      openCount >= threshold && !adFreeActive;
}
