import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/ad_free.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('extend: 期限切れなら今から、有効なら残りに加算', () {
    final now = DateTime.utc(2026, 9, 20);
    expect(AdFree.extend(null, now, 30), DateTime.utc(2026, 10, 20));
    expect(AdFree.extend(DateTime.utc(2026, 9, 1), now, 30), DateTime.utc(2026, 10, 20));
    expect(AdFree.extend(DateTime.utc(2026, 10, 1), now, 30), DateTime.utc(2026, 10, 31));
  });

  test('商品ごとのお礼期間と月数表示', () {
    expect(AdFree.daysByProduct['jp.livecam.tip.coffee'], 30);
    expect(AdFree.daysByProduct['jp.livecam.tip.sweets'], 90);
    expect(AdFree.daysByProduct['jp.livecam.tip.lunch'], 240);
    expect(AdFree.daysByProduct['jp.livecam.tip.devtools'], 730);
    expect(AdFree.monthsFor('jp.livecam.tip.lunch'), 8);
    expect(AdFree.monthsFor('jp.livecam.tip.devtools'), 24);
    expect(AdFree.monthsFor('unknown'), 0);
  });

  test('grant: 保存・加算・履歴、未知の商品は無視', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AdFree(prefs);
    await a.load();
    expect(a.isActive, isFalse);
    final now = DateTime.utc(2026, 9, 20, 3);
    expect(await a.grant('jp.livecam.tip.coffee', now: now), DateTime.utc(2026, 10, 20, 3));
    expect(await a.grant('jp.livecam.tip.sweets', now: now.add(const Duration(days: 1))),
        DateTime.utc(2027, 1, 18, 3));
    expect(await a.grant('nope', now: now), isNull);
    expect(a.history.length, 2);
    expect(a.history.first, startsWith('jp.livecam.tip.coffee|2026-09-20T03:00:00'));
    // 再読み込みしても残る
    final b = AdFree(prefs);
    await b.load();
    expect(b.until, DateTime.utc(2027, 1, 18, 3));
    expect(b.isActive, isTrue);
  });
}
