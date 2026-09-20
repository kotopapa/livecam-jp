import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 開発者支援（投げ銭）へのお礼としての広告非表示期間（1.5.1）。
///
/// 広告非表示を「買う」のではなく、支援への **お礼** として一定期間広告を出さない。
/// 支援商品（消耗型）ごとの日数は [daysByProduct]。期間中に再度支援があれば
/// 残り期間に加算する（重複購入で損をさせない）。
///
/// サーバーもアカウントも無いので期限は端末内（SharedPreferences）に保存する。
/// 消耗型はストアの購入復元の対象外のため、再インストールや機種変更では
/// 引き継がれない（支援画面に明記）。
class AdFree extends ChangeNotifier {
  AdFree([this._prefs]);

  static final AdFree instance = AdFree();

  static const _untilKey = 'ad_free_until';
  static const _historyKey = 'tip_history';

  /// 商品ID → お礼の日数
  static const Map<String, int> daysByProduct = {
    'jp.livecam.tip.coffee': 30,
    'jp.livecam.tip.sweets': 90,
    'jp.livecam.tip.lunch': 240,
    'jp.livecam.tip.devtools': 730,
  };

  /// 表示用の月数（30日=1か月として切り捨て）
  static int monthsFor(String productId) => (daysByProduct[productId] ?? 0) ~/ 30;

  SharedPreferences? _prefs;
  DateTime? _until;

  /// お礼期間の終了時刻（UTC）。未設定なら null
  DateTime? get until => _until;

  bool get isActive {
    final u = _until;
    return u != null && DateTime.now().toUtc().isBefore(u);
  }

  /// 支援履歴（"商品ID|購入時刻(ISO8601 UTC)" の並び。新しいものが末尾）
  List<String> get history =>
      _prefs?.getStringList(_historyKey) ?? const <String>[];

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final s = _prefs!.getString(_untilKey);
      _until = s == null ? null : DateTime.tryParse(s)?.toUtc();
    } catch (_) {
      // 保存領域が使えない環境では常に広告あり
    }
    notifyListeners();
  }

  /// 現在の期限 [until] に [days] を加える。期限切れなら [now] から数える
  static DateTime extend(DateTime? until, DateTime now, int days) {
    final base = (until != null && until.isAfter(now)) ? until : now;
    return base.add(Duration(days: days));
  }

  /// 支援 [productId] へのお礼を付与し、新しい期限を返す。
  /// 未知の商品IDは何もしない（null）
  Future<DateTime?> grant(String productId, {DateTime? now}) async {
    final days = daysByProduct[productId];
    if (days == null) return null;
    final t = (now ?? DateTime.now()).toUtc();
    _until = extend(_until, t, days);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_untilKey, _until!.toIso8601String());
      final h = [...history, '$productId|${t.toIso8601String()}'];
      await _prefs!.setStringList(_historyKey, h);
    } catch (_) {}
    notifyListeners();
    return _until;
  }
}
