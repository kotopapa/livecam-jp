import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/util/jst.dart';

/// lib/util/jst.dart の時刻ユーティリティ。
///
/// このファイルの検証はすべて**端末（テストプロセス）のタイムゾーンに依存しない**
/// 形で書く。`TZ=UTC flutter test` / `TZ=America/Los_Angeles flutter test` でも
/// 同じ結果になること。
void main() {
  group('jstNow / toJstWallClock', () {
    test('返り値は素のDateTime（UTCフラグを持たない）', () {
      expect(jstNow().isUtc, isFalse);
      expect(toJstWallClock(DateTime.utc(2026, 9, 1, 3)).isUtc, isFalse);
    });

    test('UTCの絶対時刻を +9時間 した壁時計になる', () {
      // 2026-08-31T15:40Z = 2026-09-01 00:40 JST（日付をまたぐ）
      expect(toJstWallClock(DateTime.utc(2026, 8, 31, 15, 40)),
          DateTime(2026, 9, 1, 0, 40));
      expect(toJstWallClock(DateTime.utc(2026, 9, 1, 2, 40)),
          DateTime(2026, 9, 1, 11, 40));
    });

    test('ローカルフラグ付きの入力でも同じ壁時計になる（端末TZ非依存）', () {
      final utc = DateTime.utc(2026, 8, 31, 15, 40);
      expect(toJstWallClock(utc.toLocal()), toJstWallClock(utc));
    });

    test('jstNow は「いまのUTC + 9時間」と一致する', () {
      final expected = toJstWallClock(DateTime.now().toUtc());
      final actual = jstNow();
      // 実行のわずかな時間差だけを許容する
      expect(actual.difference(expected).inSeconds.abs(), lessThan(5));
    });

    test('jstWallClockToUtc は toJstWallClock の逆変換', () {
      final wall = DateTime(2026, 9, 1, 0, 40);
      expect(jstWallClockToUtc(wall), DateTime.utc(2026, 8, 31, 15, 40));
      expect(toJstWallClock(jstWallClockToUtc(wall)), wall);
    });
  });

  group('asWallClock', () {
    test('UTCフラグ付きの「JST壁時計もどき」を素のDateTimeに読み直す', () {
      // 旧 nowJst() 相当（エポックが9時間先にずれたUTCフラグ付きの値）
      final legacy = DateTime.utc(2026, 9, 1, 12, 0);
      final wall = asWallClock(legacy);
      expect(wall.isUtc, isFalse);
      expect(wall, DateTime(2026, 9, 1, 12, 0));
      // 素のDateTimeと isAfter で比較しても9時間ずれない
      expect(wall.isAfter(DateTime(2026, 9, 1, 11, 59)), isTrue);
      expect(wall.isAfter(DateTime(2026, 9, 1, 12, 1)), isFalse);
    });

    test('素のDateTimeはそのまま返す', () {
      final d = DateTime(2026, 9, 1, 12);
      expect(identical(asWallClock(d), d), isTrue);
    });
  });

  group('addDays / daysBetween（夏時間のある端末TZでも壊れない）', () {
    test('addDays はカレンダー上の日付を動かす', () {
      expect(addDays(DateTime(2026, 9, 1, 3), 1), DateTime(2026, 9, 2, 3));
      expect(addDays(DateTime(2026, 9, 1, 3), -1), DateTime(2026, 8, 31, 3));
      // 米国の夏時間切替日（2026-11-01 / 2026-03-08）をまたいでも時刻がずれない
      expect(addDays(DateTime(2026, 10, 31, 2, 30), 1),
          DateTime(2026, 11, 1, 2, 30));
      expect(addDays(DateTime(2026, 3, 7, 2, 30), 1), DateTime(2026, 3, 8, 2, 30));
    });

    test('daysBetween は時刻を無視した日数差', () {
      expect(daysBetween(DateTime(2026, 9, 1, 23), DateTime(2026, 9, 2, 0)), 1);
      expect(daysBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 1, 23, 59)), 0);
      expect(daysBetween(DateTime(2026, 9, 2), DateTime(2026, 9, 1)), -1);
      // DST切替日をまたぐと Duration.inDays は 0/2 になり得るが、こちらは常に1
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
      expect(daysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    });
  });

  test('jstDayKey は YYYYMMDD（ランキング集計のキー）', () {
    expect(jstDayKey(DateTime(2026, 9, 1)), '20260901');
    expect(jstDayKey(DateTime(2026, 12, 31, 23, 59)), '20261231');
    // 09:00Z は JST では翌日 18:00 ではなく同日 18:00。日付キーの境界を確認
    expect(jstDayKey(toJstWallClock(DateTime.utc(2026, 8, 31, 15, 0))),
        '20260901');
    expect(jstDayKey(toJstWallClock(DateTime.utc(2026, 8, 31, 14, 59))),
        '20260831');
  });
}
