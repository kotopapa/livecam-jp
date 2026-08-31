import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/heat_alert.dart';
import 'package:livecam_jp/data/jma_layers.dart';
import 'package:livecam_jp/data/wbgt.dart';
import 'package:livecam_jp/l10n/gen/app_localizations.dart';
import 'package:livecam_jp/ui/bosai_screen.dart';
import 'package:livecam_jp/util/jst.dart';
import 'package:livecam_jp/util/time_format.dart';

/// 2026-09-01 の時刻処理 全面点検（docs/time_audit_2026-09-01.md）の回帰テスト。
///
/// 実発生した不具合:
/// - アメダスの `latest_time.txt`(+09:00) を `DateTime.parse` した結果がUTCになり、
///   JST前提のファイル名を組み立てて9時間前のデータを読んでいた（2026-08-30）
/// - `nowJst()`（UTCフラグ付き）とCSV由来の素のDateTimeを `isAfter` で比べ、
///   暑さ指数の予測が9時間先から表示された（2026-09-01）
///
/// いずれも「絶対時刻(instant)」と「JSTの壁時計(wall clock)」の取り違えが原因。
/// ここでは端末TZに依存しない形で両者の混同を検出する。
void main() {
  late AppLocalizations ja;

  setUpAll(() async {
    ja = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  group('気象庁の "+09:00" 付き時刻（UTCフラグ付きで返る）', () {
    // 気象庁 quake/list.json の実データ形式
    const raw = '2026-08-31T18:49:00+09:00';

    test('DateTime.parse はUTCで返る（前提の再確認）', () {
      final at = DateTime.parse(raw);
      expect(at.isUtc, isTrue);
      expect(at.hour, 9); // ← UTCの時。ここをそのまま表示すると9時間ずれる
    });

    test('24時間より前の震源は toLocal() した日時で表示する（9時間ずれない）', () {
      final at = DateTime.parse(raw);
      // 3日後の「いま」＝相対表記ではなく絶対表記になる分岐
      final now = at.add(const Duration(days: 3));
      final s = formatQuakeWhen(ja, at, now: now);
      final local = at.toLocal();
      expect(s, ja.bosaiTimeMonthDayHour(local.month, local.day, local.hour));
      // 修正前は at のフィールド（＝UTCの 8/31 9時）をそのまま表示していた。
      // 端末TZがUTCのときは toLocal() の結果と一致してしまうので、
      // ずれが観測できるTZのときだけ差を確認する
      if (DateTime.now().timeZoneOffset != Duration.zero) {
        expect(s, isNot(ja.bosaiTimeMonthDayHour(at.month, at.day, at.hour)));
      }
    });

    test('24時間以内は相対表記（エポック比較なのでTZ非依存）', () {
      final at = DateTime.parse(raw);
      expect(formatQuakeWhen(ja, at, now: at.add(const Duration(minutes: 30))),
          ja.bosaiTimeMinutesAgo(30));
      expect(formatQuakeWhen(ja, at, now: at.add(const Duration(hours: 5))),
          ja.bosaiTimeHoursAgo(5));
      expect(formatQuakeWhen(ja, at, now: at.add(const Duration(seconds: 10))),
          ja.bosaiTimeJustNow);
    });
  });

  group('気象庁タイルの時刻（UTC表記）', () {
    test('validAtJst は壁時計・validAt は絶対時刻', () {
      const n = NowcastTime('20260831154000', '20260831154000');
      expect(n.validAtJst, DateTime(2026, 9, 1, 0, 40)); // 素のDateTime
      expect(n.validAtJst.isUtc, isFalse);
      expect(n.validAt, DateTime.utc(2026, 8, 31, 15, 40));
      expect(n.label, '00:40');
    });

    test('スライダーの「n分後」は絶対時刻の差で求める', () {
      const obs = NowcastTime('20260831024000', '20260831024000');
      const fc = NowcastTime('20260831024000', '20260831034000');
      expect(fc.validAt.difference(obs.validAt).inMinutes, 60);
    });

    test('validAtJst を DateTime.now() と引き算してはいけない（9時間ずれる例）', () {
      // 壁時計は絶対時刻ではないことを明示的に記録しておく
      final wall = jmaTimeToJst('20260831154000');
      final instant = jmaTimeToUtc('20260831154000');
      expect(jstWallClockToUtc(wall), instant);
    });
  });

  group('取得時刻の表示（time_format）', () {
    test('オフセット付きは端末ローカルへ変換して相対時刻を出す', () {
      final at = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      final s = formatTakenTime(at.toIso8601String());
      expect(s, contains('5分前'));
    });

    test('オフセットなし（提供元のJST表記）はJSTの「今」と比べる', () {
      // monitor の image_time は "2026-09-01 07:55:37"（JST・オフセットなし）。
      // 端末TZが日本以外でも「5分前」になること
      final jst5min = jstNow().subtract(const Duration(minutes: 5));
      String two(int v) => v.toString().padLeft(2, '0');
      final raw = '${jst5min.year}-${two(jst5min.month)}-${two(jst5min.day)} '
          '${two(jst5min.hour)}:${two(jst5min.minute)}:00';
      final s = formatTakenTime(raw);
      expect(s, contains('分前'));
      expect(s, contains('${two(jst5min.hour)}:${two(jst5min.minute)}'));
    });

    test('オフセットなしの表示は壁時計そのまま（端末TZで digits が変わらない）', () {
      expect(formatTakenTime('2000-01-02 10:15:26'), startsWith('1月2日 10:15'));
    });
  });

  group('暑さ指数（WBGT）', () {
    // 予測CSV: 3時間刻み。値は10倍整数
    const csv = ',,2026090103,2026090106,2026090109,2026090112,2026090200\n'
        '44132,2026/09/01 01:25,210,230,250,280,240\n';

    test('UTCフラグ付きの「JST壁時計もどき」を渡しても9時間ずれない', () {
      final forecast = Wbgt.parseForecast(csv);
      // 旧 nowJst() 相当（2026-09-01 02:00 JST をUTCフラグ付きで表現したもの）
      final legacy = DateTime.utc(2026, 9, 1, 2);
      final out = Wbgt.upcoming(forecast, legacy);
      expect(out.first.at, DateTime(2026, 9, 1, 3));
      // 素のDateTimeで渡した場合と一致する
      expect([for (final e in Wbgt.upcoming(forecast, DateTime(2026, 9, 1, 2))) e.at],
          [for (final e in out) e.at]);
    });

    test('nowJstNaive は素のDateTime（比較に使える）', () {
      expect(HeatAlerts.nowJstNaive().isUtc, isFalse);
      expect(HeatAlerts.nowJstNaive().difference(jstNow()).inSeconds.abs(),
          lessThan(5));
    });

    test('予測コマのラベルは当日/翌日をカレンダー日で判定する', () {
      final now = DateTime(2026, 9, 1, 23, 30);
      expect(wbgtTimeLabel(ja, DateTime(2026, 9, 1, 23), now), ja.bosaiWbgtHour(23));
      expect(wbgtTimeLabel(ja, DateTime(2026, 9, 2, 3), now),
          ja.bosaiWbgtNextDayHour(3));
      expect(wbgtTimeLabel(ja, DateTime(2026, 9, 3, 12), now),
          ja.bosaiWbgtDateHour(9, 3, 12));
      // UTCフラグ付きを渡しても壁時計として読み直す
      expect(wbgtTimeLabel(ja, DateTime.utc(2026, 9, 2, 3), now),
          ja.bosaiWbgtNextDayHour(3));
    });
  });

  group('熱中症警戒情報のURL組み立て（JSTのファイル名）', () {
    test('UTCフラグ付きの「JST壁時計もどき」でも当日のURLになる', () {
      // 2026-09-01 13:00 JST
      final legacy = DateTime.utc(2026, 9, 1, 13);
      final urls = HeatAlerts.candidateUrls(legacy);
      expect(urls.first.toString(), endsWith('/2026/alert_20260901_10.csv'));
      expect([for (final u in urls) u.toString()],
          [for (final u in HeatAlerts.candidateUrls(DateTime(2026, 9, 1, 13))) u.toString()]);
    });

    test('前日17時のフォールバックは月末をまたいでも正しい', () {
      final urls = HeatAlerts.candidateUrls(DateTime(2026, 9, 1, 3));
      // 当日は未発表（05時前）なので前日 8/31 17時
      expect(urls.single.toString(), endsWith('/2026/alert_20260831_17.csv'));
    });

    test('翌日判定は暦日で行う（byPrefecture の tomorrow）', () {
      // date1=当日 / date2=翌日 のCSVで、当日を月末にしても翌日が拾える
      const csv = 'ReportDate,2026/08/31,,,,,,\n'
          'ReportTime,14:00,,,,,,\n'
          'TargetDate1,2026/08/31,,,,,,\n'
          'TargetDate2,2026/09/01,,,,,,\n'
          '府県予報区,a,b,c,d,e,f,g\n'
          '東京都,-,-,130000,東京都,13,0,1\n';
      final r = HeatAlerts.parseCsv(csv);
      final list =
          HeatAlerts.byPrefecture(r, today: DateTime(2026, 8, 31));
      expect(list.length, 1);
      expect(list.first.today, HeatAlertLevel.none);
      expect(list.first.tomorrow, HeatAlertLevel.warning);
    });
  });
}
