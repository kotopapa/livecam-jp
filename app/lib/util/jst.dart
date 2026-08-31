/// 日本時間(JST = UTC+9・夏時間なし)を扱うユーティリティ。
///
/// このアプリは「気象庁・環境省・国交省の日本時間」と「端末のローカル時刻」と
/// 「UTC」が同居する。過去に9時間ずれの不具合が2件実発生しているため、
/// 時刻の扱いを次の**2種類だけ**に統一する。
///
/// 1. **絶対時刻（instant）** … `DateTime.now()`（ローカルフラグ）や
///    `DateTime.parse('...Z' / '...+09:00')`（UTCフラグ）。
///    `isAfter` / `isBefore` / `difference` はエポック値で比較されるので、
///    ローカルフラグとUTCフラグを混ぜて比較しても**正しい**。
/// 2. **JSTの壁時計（wall clock）** … [jstNow] / [toJstWallClock] が返す
///    **素の(naive) DateTime**。year/month/day/hour… が日本時間の値になる。
///    URL・ファイル名の組み立てと、日本時間で書かれた素の日時（環境省CSV等）
///    との比較にだけ使う。
///
/// **禁止**: `DateTime.now().toUtc().add(Duration(hours: 9))` の戻り値を
/// そのまま比較に使うこと。UTCフラグが付いたままエポックが9時間先にずれた値に
/// なるため、素のDateTimeと `isAfter` すると9時間ずれる（2026-09-01 実発生）。
/// 壁時計が欲しいときは必ず [jstNow] / [toJstWallClock] を通すこと。
library;

/// JSTのUTCオフセット
const jstOffset = Duration(hours: 9);

/// 日本時間の「今」を**壁時計（素のDateTime）**で返す。端末のTZに依存しない。
///
/// 絶対時刻としては正しくないので、`DateTime.now()` や UTC由来の値と
/// `isAfter` / `difference` してはいけない。
DateTime jstNow() => toJstWallClock(DateTime.now());

/// 絶対時刻 [t]（ローカル/UTCどちらでも可）を日本時間の壁時計に直す。
DateTime toJstWallClock(DateTime t) {
  final u = t.toUtc().add(jstOffset);
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second,
      u.millisecond, u.microsecond);
}

/// 日本時間の壁時計 [wall] を絶対時刻（UTCフラグ付き）に戻す。
DateTime jstWallClockToUtc(DateTime wall) => DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    ).subtract(jstOffset);

/// 素のDateTimeへ正規化する（UTCフラグ付きの値を壁時計として読み直す）。
///
/// 呼び出し側がうっかりUTCフラグ付きの「JST壁時計もどき」を渡してきても
/// 素のDateTimeと安全に比較できるようにするための保険。
DateTime asWallClock(DateTime t) => t.isUtc
    ? DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second,
        t.millisecond, t.microsecond)
    : t;

/// [t] と同じ日の 00:00（素のDateTime）。
DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// カレンダー上の日数を [days] 日進めた日付。
///
/// `DateTime.add(Duration(days: n))` は絶対時間の加算なので、夏時間のある
/// タイムゾーンの端末では 23時 / 1時 にずれる。日付だけが欲しい場面では
/// こちらを使う（日本にDSTは無いが、端末TZは日本とは限らない）。
DateTime addDays(DateTime t, int days) =>
    DateTime(t.year, t.month, t.day + days, t.hour, t.minute, t.second,
        t.millisecond, t.microsecond);

/// カレンダー上の日数差（[to] の日 − [from] の日）。夏時間の影響を受けない。
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// `YYYYMMDD`（JSTの日付キー。全国集計・ランキングのキーに使う）
String jstDayKey(DateTime wall) => '${wall.year}'
    '${wall.month.toString().padLeft(2, '0')}'
    '${wall.day.toString().padLeft(2, '0')}';
