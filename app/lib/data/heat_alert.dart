// 環境省「熱中症警戒アラート（熱中症特別警戒情報・熱中症警戒情報）」の公開CSV。
// 無料・認証不要（SPEC C2）。アプリが直接取得し、当方サーバーには保存しない。
//
// - URL: `https://www.wbgt.env.go.jp/alert/dl/<YYYY>/alert_<YYYYMMDD>_<HH>.csv`
//   HH は 05/10/14/17 の1日4回発表。UTF-8・メタ23行＋ヘッダ1行＋58府県予報区
// - `府県予報区等コード` は気象庁 area.json の6桁コードと同一のため、
//   既存の警報表示と同じ区域単位で扱える
// - **運用期間は4/22〜10/21**。期間外は404が正常（機能自体を出さない）
//
// 規約上、表示する画面には必ず「出典：環境省熱中症予防情報サイト」と
// [disclaimer] を併記すること。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../util/jst.dart';

/// フラグ（CSVの FlagExplanation より）
/// `発表無し:0、熱中症警戒情報発表:1、熱中症特別警戒情報判定:2、
///  熱中症特別警戒情報発表:3、発表時間外:9`
enum HeatAlertLevel {
  /// 0: 発表無し
  none,

  /// 1: 熱中症警戒情報（いわゆる熱中症警戒アラート）
  warning,

  /// 2: 熱中症特別警戒情報「判定」（発表前段階）
  specialPending,

  /// 3: 熱中症特別警戒情報 発表
  special,

  /// 9: 発表時間外（翌日分がまだ確定していない等）／不明
  unknown;

  /// 一覧に載せる対象か
  bool get isAlert =>
      this == warning || this == specialPending || this == special;

  /// 重い順（0が最も重い）。並び替えに使う
  int get rank => switch (this) {
        HeatAlertLevel.special => 0,
        HeatAlertLevel.specialPending => 1,
        HeatAlertLevel.warning => 2,
        _ => 9,
      };

  // バッジ用の短い表示名は lib/l10n/l10n.dart の heatAlertLabelOf() で解決する
}

/// フラグ文字列 → レベル。未知の値は [HeatAlertLevel.unknown]
HeatAlertLevel heatLevelFromFlag(String flag) => switch (flag.trim()) {
      '0' => HeatAlertLevel.none,
      '1' => HeatAlertLevel.warning,
      '2' => HeatAlertLevel.specialPending,
      '3' => HeatAlertLevel.special,
      _ => HeatAlertLevel.unknown,
    };

/// バッジ色（特別＝赤・警戒＝オレンジ。気象警報の配色に合わせる）
Color heatLevelColor(HeatAlertLevel level) => switch (level) {
      HeatAlertLevel.special ||
      HeatAlertLevel.specialPending =>
        const Color(0xFFD93025),
      HeatAlertLevel.warning => const Color(0xFFE8710A),
      _ => const Color(0xFF616E7C),
    };

/// 府県予報区1件分
class HeatAlertArea {
  const HeatAlertArea({
    required this.areaName,
    required this.areaCode,
    required this.prefName,
    required this.prefCode,
    required this.day1,
    required this.day2,
  });

  /// 府県予報区名（例: 宗谷地方 / 東京都）
  final String areaName;

  /// 府県予報区等コード（6桁。気象庁 area.json と同一）
  final String areaCode;

  /// 都道府県名（CSVの表記）
  final String prefName;

  /// 都道府県コード（JIS 2桁）
  final String prefCode;

  /// TargetDate1（＝発表日当日）のレベル
  final HeatAlertLevel day1;

  /// TargetDate2（＝翌日）のレベル
  final HeatAlertLevel day2;
}

/// 都道府県単位に丸めた表示用データ（北海道・鹿児島・沖縄は複数区域を持つ）
class HeatAlertPref {
  const HeatAlertPref({
    required this.prefCode,
    required this.prefName,
    required this.today,
    required this.tomorrow,
    required this.areas,
  });

  final String prefCode;
  final String prefName;

  /// 当日のレベル（該当なしは [HeatAlertLevel.none] / [HeatAlertLevel.unknown]）
  final HeatAlertLevel today;

  /// 翌日のレベル
  final HeatAlertLevel tomorrow;

  /// 発表中の府県予報区名（都道府県がひとつの区域だけなら空）
  final List<String> areas;

  /// 重い方のレベル（並び替え・アイコン色に使う）
  HeatAlertLevel get top => today.rank <= tomorrow.rank ? today : tomorrow;
}

/// CSV1本＝1回の発表
class HeatAlertReport {
  const HeatAlertReport({
    required this.reportAt,
    required this.date1,
    required this.date2,
    required this.areas,
  });

  /// 発表日時（ReportDate + ReportTime。JSTのローカル表記）
  final DateTime? reportAt;

  /// TargetDate1（通常は発表日当日）
  final DateTime? date1;

  /// TargetDate2（通常は翌日）
  final DateTime? date2;

  final List<HeatAlertArea> areas;

  /// 指定日の区域レベル。対象日でなければ [HeatAlertLevel.unknown]
  HeatAlertLevel levelOn(HeatAlertArea a, DateTime day) {
    if (_sameDay(date1, day)) return a.day1;
    if (_sameDay(date2, day)) return a.day2;
    return HeatAlertLevel.unknown;
  }

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 純粋関数群（テスト対象）＋取得
class HeatAlerts {
  /// 出典表記は翻訳しない
  static const attribution = '出典：環境省熱中症予防情報サイト';
  static const siteUrl = 'https://www.wbgt.env.go.jp/alert.php';

  /// 発表時刻（1日4回）
  static const publishHours = [5, 10, 14, 17];

  /// 1回の更新で試すURLの上限（全滅時にリクエストが増えすぎないように）
  static const maxCandidates = 3;

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// 日本時間の「現在」を、端末のTZに依存しない**素のDateTime（壁時計）**で返す。
  ///
  /// かつては `DateTime.now().toUtc().add(9h)` を返していたが、UTCフラグが付いた
  /// まま値が9時間先にずれるため、CSV由来の素のDateTimeと `isAfter` すると
  /// 予測が9時間先から表示される不具合が起きた（2026-09-01 実発生）。
  /// 実装は [jstNow] に集約している（lib/util/jst.dart）
  static DateTime nowJstNaive() => jstNow();

  /// 運用期間（4/22〜10/21）。期間外はCSVが404になるため機能自体を出さない
  static bool isInSeason(DateTime jst) {
    final md = jst.month * 100 + jst.day;
    return md >= 422 && md <= 1021;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 発表回のCSV URL
  static Uri urlFor(DateTime jstDay, int hour) => Uri.parse(
      'https://www.wbgt.env.go.jp/alert/dl/${jstDay.year}/alert_'
      '${jstDay.year}${_two(jstDay.month)}${_two(jstDay.day)}_${_two(hour)}.csv');

  /// 新しい発表から順に試すURL。当日の発表済みの回（新しい順）→ 前日17時。
  /// 運用期間外の日付は除外する
  static List<Uri> candidateUrls(DateTime now) {
    final nowJst = asWallClock(now);
    final out = <Uri>[];
    if (isInSeason(nowJst)) {
      for (final h in publishHours.reversed) {
        if (h <= nowJst.hour) out.add(urlFor(nowJst, h));
      }
    }
    final prev = addDays(nowJst, -1);
    if (isInSeason(prev)) out.add(urlFor(prev, publishHours.last));
    return out.take(maxCandidates).toList();
  }

  /// CSVを解析する。メタ行（`キー,値,,,…`）と、`府県予報区,` で始まるヘッダ行の
  /// 後ろに続く区域行を読む。値にクォートや区切りのカンマは現れない
  static HeatAlertReport parseCsv(String body) {
    DateTime? reportDate, date1, date2;
    String? reportTime;
    final areas = <HeatAlertArea>[];
    var inRows = false;
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      final f = line.split(',');
      if (!inRows) {
        if (f.first == '府県予報区') {
          inRows = true;
          continue;
        }
        final v = f.length > 1 ? f[1].trim() : '';
        switch (f.first) {
          case 'ReportDate':
            reportDate = _parseDate(v);
          case 'ReportTime':
            reportTime = v;
          case 'TargetDate1':
            date1 = _parseDate(v);
          case 'TargetDate2':
            date2 = _parseDate(v);
        }
        continue;
      }
      if (f.length < 8) continue;
      final code = f[3].trim();
      final pref = f[5].trim();
      if (code.length != 6 || pref.length != 2) continue;
      areas.add(HeatAlertArea(
        areaName: f[0].trim(),
        areaCode: code,
        prefName: f[4].trim(),
        prefCode: pref,
        day1: heatLevelFromFlag(f[6]),
        day2: heatLevelFromFlag(f[7]),
      ));
    }
    return HeatAlertReport(
      reportAt: _withTime(reportDate, reportTime),
      date1: date1,
      date2: date2,
      areas: areas,
    );
  }

  /// `2026/08/31` → DateTime。解析できなければ null
  static DateTime? _parseDate(String v) {
    final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(v);
    if (m == null) return null;
    return DateTime(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  static DateTime? _withTime(DateTime? d, String? hhmmss) {
    if (d == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmmss ?? '');
    if (m == null) return d;
    return DateTime(d.year, d.month, d.day, int.parse(m.group(1)!),
        int.parse(m.group(2)!));
  }

  /// 当日・翌日いずれかで発表中の都道府県を、重い順→コード順に並べて返す
  static List<HeatAlertPref> byPrefecture(
    HeatAlertReport report, {
    required DateTime today,
    Map<String, String> prefNames = const {},
  }) {
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final byPref = <String, HeatAlertPref>{};
    for (final a in report.areas) {
      final d1 = report.levelOn(a, today);
      final d2 = report.levelOn(a, tomorrow);
      if (!d1.isAlert && !d2.isAlert) continue;
      final cur = byPref[a.prefCode];
      final areaNames = [
        ...?cur?.areas,
        if (report.areas.where((x) => x.prefCode == a.prefCode).length > 1)
          a.areaName,
      ];
      byPref[a.prefCode] = HeatAlertPref(
        prefCode: a.prefCode,
        prefName: prefNames[a.prefCode] ?? cur?.prefName ?? a.prefName,
        today: _heavier(cur?.today, d1),
        tomorrow: _heavier(cur?.tomorrow, d2),
        areas: areaNames,
      );
    }
    final out = byPref.values.toList()
      ..sort((a, b) => a.top.rank != b.top.rank
          ? a.top.rank.compareTo(b.top.rank)
          : a.prefCode.compareTo(b.prefCode));
    return out;
  }

  static HeatAlertLevel _heavier(HeatAlertLevel? a, HeatAlertLevel b) =>
      a == null || b.rank < a.rank ? b : a;

  /// 最新の発表を取得する。期間外・取得失敗・全404はいずれも null（正常系）
  static Future<HeatAlertReport?> fetch({
    DateTime? now,
    http.Client? client,
  }) async {
    final urls = candidateUrls(now ?? nowJstNaive());
    for (final u in urls) {
      try {
        final r = client == null
            ? await http.get(u, headers: _ua).timeout(const Duration(seconds: 15))
            : await client.get(u, headers: _ua).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue; // 未発表の回・期間外は404
        final report = parseCsv(utf8.decode(r.bodyBytes));
        if (report.areas.isNotEmpty) return report;
      } catch (_) {
        // 次の候補を試す
      }
    }
    return null;
  }
}
