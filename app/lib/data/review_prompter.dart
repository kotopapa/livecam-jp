import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ストアレビュー訴求（HANDOFF 2-8-2）。
///
/// 「価値を感じた直後」に一度だけOSのレビューダイアログを要求する。
/// - 詳細閲覧が合計10回に達したとき
/// - お気に入りが3件に達したとき
/// iOSは表示回数を年3回に制限しており、要求しても出ないことがある
/// （出るかどうかはOS任せ）。プロンプト済みフラグで再要求はしない。
class ReviewPrompter {
  static const _promptedKey = 'review_prompted_v1';
  static const viewThreshold = 10;
  static const favoriteThreshold = 3;

  bool _prompted = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _prompted = _prefs!.getBool(_promptedKey) ?? false;
  }

  /// 条件を満たしたら要求する。失敗しても本体機能に影響させない
  void maybePrompt({required int totalViews, required int favoriteCount}) {
    if (_prompted) return;
    if (totalViews < viewThreshold && favoriteCount < favoriteThreshold) {
      return;
    }
    _prompted = true;
    _prefs?.setBool(_promptedKey, true);
    Future(() async {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    }).catchError((_) {});
  }
}
