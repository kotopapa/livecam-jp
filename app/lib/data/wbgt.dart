// 環境省「熱中症予防情報サイト」の地点別 暑さ指数（WBGT）。
// 無料・認証不要（SPEC C2）。アプリが直接取得し、当方サーバーには保存しない。
// 規約・出典表記は熱中症警戒情報（heat_alert.dart）と同じ。
//
// - 地点マスタ: `https://www.wbgt.env.go.jp/man15NH/wbgt_point_master-<YYYYMMDD>.csv`
//   UTF-8(BOM付き)、区切りは「, 」(カンマ+空白)。18列（2026-08-31実測）:
//   地方, 振興局, 地点番号, 観測所名, よみがな, ローマ字表記, 所在地,
//   Latitude(度), Latitude_3(分.小数), Longitude(度), Longitude_4(分.小数),
//   Start(開始日), End(終了日。運用中は 9999-99-99), Old Station Number,
//   実測開始日, 実測終了日, 特別警戒判定除外開始日, 同終了日
//   **緯度経度は「度」と「分」の2列**（45, 31.2 → 45+31.2/60）。
//   ファイル名に日付が入り、ディレクトリ索引は403なので、既知のファイル名を
//   試し、取れなければ端末キャッシュ→同梱アセットの順に使う
// - 予測値: `https://www.wbgt.env.go.jp/prev15WG/dl/yohou_<地点番号>.csv`
//   1行目 `,,YYYYMMDDHH,...`（3時間刻み。HH=24 は翌日0時）、
//   2行目 `地点番号, 作成時刻, 値, ...`（**値は10倍整数**。220→22.0）。毎時更新
// - 実況値（実況推定値）: `https://www.wbgt.env.go.jp/est15WG/dl/wbgt_<地点番号>_<YYYYMM>.csv`
//   `Date,Time,<地点番号>` の3列。`2026/8/31,21:00,22.1`。未来の行は値が空欄。
//   毎正時更新
// - 運用期間は熱中症警戒情報と同じ 4/22〜10/21。期間外は404（取得しない）
//
// 段階（環境省 wbgt_data.php の凡例。色は /css/color_theme.css の値）:
//   31以上=危険 #ff2800 / 28以上31未満=厳重警戒 #ff9600 /
//   25以上28未満=警戒 #faf500 / 21以上25未満=注意 #a0d2ff / 21未満=ほぼ安全 #218cff
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../util/geo.dart';
import 'heat_alert.dart';

/// 暑さ指数の段階（環境省の5段階）
enum WbgtLevel {
  /// 31以上
  danger,

  /// 28以上31未満
  severeWarning,

  /// 25以上28未満
  warning,

  /// 21以上25未満
  caution,

  /// 21未満
  safe;

  // 表示名は lib/l10n/l10n.dart の wbgtLevelLabelOf() で解決する
  // （ここは BuildContext を持たないため名前を持たない）

  /// 背景色（環境省サイト color_theme.css の .wbgt_lv1〜5 と同じ）
  Color get color => switch (this) {
        WbgtLevel.danger => const Color(0xFFFF2800),
        WbgtLevel.severeWarning => const Color(0xFFFF9600),
        WbgtLevel.warning => const Color(0xFFFAF500),
        WbgtLevel.caution => const Color(0xFFA0D2FF),
        WbgtLevel.safe => const Color(0xFF218CFF),
      };

  /// 文字色（同CSS。危険・ほぼ安全は白、それ以外は黒）
  Color get textColor => switch (this) {
        WbgtLevel.danger || WbgtLevel.safe => Colors.white,
        _ => Colors.black,
      };
}

/// 値[℃] → 段階
WbgtLevel wbgtLevelOf(double v) {
  if (v >= 31) return WbgtLevel.danger;
  if (v >= 28) return WbgtLevel.severeWarning;
  if (v >= 25) return WbgtLevel.warning;
  if (v >= 21) return WbgtLevel.caution;
  return WbgtLevel.safe;
}

/// 地点マスタ1行
class WbgtPoint {
  const WbgtPoint({
    required this.id,
    required this.name,
    required this.kana,
    required this.address,
    required this.lat,
    required this.lng,
  });

  /// 地点番号（例 44132）
  final String id;

  /// 観測所名（例 東京）
  final String name;
  final String kana;

  /// 所在地（例 千代田区北の丸公園）
  final String address;
  final double lat;
  final double lng;
}

/// 時刻付きの値（予測1コマ／実況の最新値）
class WbgtValue {
  const WbgtValue(this.at, this.value);

  /// JSTのローカル表記（tz情報なし）
  final DateTime at;
  final double value;

  WbgtLevel get level => wbgtLevelOf(value);

  @override
  String toString() => 'WbgtValue($at, $value)';
}

/// 1地点分の取得結果
class WbgtPointData {
  const WbgtPointData({
    required this.point,
    required this.current,
    required this.forecast,
    required this.hourKey,
    required this.failed,
  });

  final WbgtPoint point;

  /// 実況の最新値（未取得・欠測は null）
  final WbgtValue? current;

  /// 予測（3時間刻み・ファイル全体）
  final List<WbgtValue> forecast;

  /// 取得した正時（`YYYYMMDDHH`）。同じ正時内は再取得しない
  final String hourKey;

  /// 実況・予測の両方が取得できなかった
  final bool failed;
}

/// 純粋関数群（テスト対象）＋取得・キャッシュ
class Wbgt {
  static const attribution = HeatAlerts.attribution;
  static const siteUrl = 'https://www.wbgt.env.go.jp/wbgt_data.php';

  static const _base = 'https://www.wbgt.env.go.jp';

  /// 既知の地点マスタのファイル名（新しいものを先頭に）。ディレクトリ索引は
  /// 403で取れないため、環境省が更新したらここに追記する
  static const knownMasterFiles = ['wbgt_point_master-20260515.csv'];

  /// 同梱アセット（ネットワーク・キャッシュとも無いときの最終手段）
  static const assetPath = 'assets/wbgt/wbgt_point_master-20260515.csv';

  /// 端末キャッシュの有効期間（地点マスタは年1回程度しか変わらない）
  static const masterCacheMaxAge = Duration(days: 30);

  /// 最寄り地点の表示数
  static const nearestCount = 3;

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static List<Uri> get masterUrls =>
      [for (final f in knownMasterFiles) Uri.parse('$_base/man15NH/$f')];

  static Uri forecastUrl(String pointId) =>
      Uri.parse('$_base/prev15WG/dl/yohou_$pointId.csv');

  static Uri actualUrl(String pointId, DateTime jstMonth) => Uri.parse(
      '$_base/est15WG/dl/wbgt_${pointId}_${jstMonth.year}'
      '${_two(jstMonth.month)}.csv');

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 正時のキー（`YYYYMMDDHH`）
  static String hourKey(DateTime jst) =>
      '${jst.year}${_two(jst.month)}${_two(jst.day)}${_two(jst.hour)}';

  /// 度・分（小数）→ 度。解析できなければ null
  static double? dmToDeg(String deg, String min) {
    final d = double.tryParse(deg.trim());
    final m = double.tryParse(min.trim());
    if (d == null || m == null) return null;
    return d + m / 60.0;
  }

  /// 地点マスタCSVを解析する。終了日が [asOf] より前の地点（廃止済み）は除く
  static List<WbgtPoint> parseMaster(String body, {DateTime? asOf}) {
    final out = <WbgtPoint>[];
    final today = asOf ?? HeatAlerts.nowJst();
    var first = true;
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.replaceFirst('\uFEFF', '').trimRight();
      if (line.isEmpty) continue;
      if (first) {
        first = false;
        if (line.contains('地点番号')) continue; // ヘッダ行
      }
      final f = line.split(',').map((s) => s.trim()).toList();
      if (f.length < 11) continue;
      final id = f[2];
      if (!RegExp(r'^\d{3,6}$').hasMatch(id)) continue;
      final lat = dmToDeg(f[7], f[8]);
      final lng = dmToDeg(f[9], f[10]);
      if (lat == null || lng == null) continue;
      if (f.length > 12 && _endedBefore(f[12], today)) continue;
      out.add(WbgtPoint(
        id: id,
        name: f[3],
        kana: f[4],
        address: f[6],
        lat: lat,
        lng: lng,
      ));
    }
    return out;
  }

  /// `2021-03-09` が [day] より前なら true。`9999-99-99`（運用中）や不正値は false
  static bool _endedBefore(String end, DateTime day) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(end);
    if (m == null || end.startsWith('9999')) return false;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return false;
    return DateTime(y, mo, d).isBefore(DateTime(day.year, day.month, day.day));
  }

  /// `YYYYMMDDHH` → DateTime（HH=24 は翌日0時に正規化される）
  static DateTime? _parseHour(String s) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!), int.parse(m.group(4)!));
  }

  /// 予測CSVを解析する（値は10で割る）。時刻と値の対応が取れないコマは捨てる
  static List<WbgtValue> parseForecast(String body) {
    final lines = const LineSplitter()
        .convert(body)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final times = lines[0].split(',').map((s) => s.trim()).toList();
    final vals = lines[1].split(',').map((s) => s.trim()).toList();
    final out = <WbgtValue>[];
    for (var i = 2; i < times.length && i < vals.length; i++) {
      final t = _parseHour(times[i]);
      final v = double.tryParse(vals[i]);
      if (t == null || v == null || !v.isFinite) continue;
      out.add(WbgtValue(t, v / 10.0));
    }
    return out;
  }

  /// 実況CSVから最新の非空欄の値を返す。全て空欄なら null
  static WbgtValue? latestActual(String body) {
    WbgtValue? last;
    for (final raw in const LineSplitter().convert(body)) {
      final f = raw.split(',').map((s) => s.trim()).toList();
      if (f.length < 3 || f[2].isEmpty) continue;
      final v = double.tryParse(f[2]);
      if (v == null || !v.isFinite) continue; // ヘッダ行など
      final d = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(f[0]);
      final t = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(f[1]);
      if (d == null || t == null) continue;
      final at = DateTime(
          int.parse(d.group(1)!),
          int.parse(d.group(2)!),
          int.parse(d.group(3)!),
          int.parse(t.group(1)!),
          int.parse(t.group(2)!));
      last = WbgtValue(at, v);
    }
    return last;
  }

  /// [lat],[lng] に近い順に [limit] 地点（距離[m]付き）
  static List<(WbgtPoint, double)> nearest(
      List<WbgtPoint> points, double lat, double lng,
      {int limit = nearestCount}) {
    final scored = [
      for (final p in points) (p, distanceMeters(lat, lng, p.lat, p.lng))
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return scored.take(limit).toList();
  }

  /// 今後の予測コマ（[nowJst] より後〜翌日24時まで）
  static List<WbgtValue> upcoming(List<WbgtValue> forecast, DateTime nowJst) {
    final limit = DateTime(nowJst.year, nowJst.month, nowJst.day)
        .add(const Duration(days: 2)); // 翌日24時 = 翌々日0時
    return forecast
        .where((e) => e.at.isAfter(nowJst) && !e.at.isAfter(limit))
        .toList();
  }

  /// 距離の表示（1km未満はm）
  static String formatDistance(double m) =>
      m < 1000 ? '${m.round()}m' : '${(m / 1000).toStringAsFixed(1)}km';

  // ---- 取得・キャッシュ ----

  static List<WbgtPoint>? _master;
  static final Map<String, WbgtPointData> _pointCache = {};

  /// テスト用。キャッシュディレクトリの差し替え
  static Directory? cacheDirOverride;

  static Future<File?> _masterCacheFile() async {
    try {
      final dir = cacheDirOverride ?? await getApplicationSupportDirectory();
      return File('${dir.path}/wbgt_point_master.csv');
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response> _get(Uri u, http.Client? client) =>
      (client == null
              ? http.get(u, headers: _ua)
              : client.get(u, headers: _ua))
          .timeout(const Duration(seconds: 15));

  static Future<String?> _downloadMaster(http.Client? client) async {
    for (final u in masterUrls) {
      try {
        final r = await _get(u, client);
        if (r.statusCode != 200) continue;
        final body = utf8.decode(r.bodyBytes);
        if (body.contains('地点番号')) return body;
      } catch (_) {
        // 次の候補へ
      }
    }
    return null;
  }

  /// 地点マスタ。メモリ → 端末キャッシュ（30日以内）→ ネットワーク →
  /// 古い端末キャッシュ → 同梱アセット の順。失敗しても空リストを返すだけ
  static Future<List<WbgtPoint>> loadMaster(
      {http.Client? client, DateTime? now}) async {
    final mem = _master;
    if (mem != null) return mem;
    final jst = now ?? HeatAlerts.nowJst();

    final file = await _masterCacheFile();
    String? cachedBody;
    var fresh = false;
    if (file != null) {
      try {
        if (await file.exists()) {
          cachedBody = await file.readAsString();
          final age = DateTime.now().difference(await file.lastModified());
          fresh = age < masterCacheMaxAge && cachedBody.contains('地点番号');
        }
      } catch (_) {
        cachedBody = null;
      }
    }

    String? body = fresh ? cachedBody : null;
    if (body == null) {
      final downloaded = await _downloadMaster(client);
      if (downloaded != null) {
        body = downloaded;
        if (file != null) {
          try {
            await file.writeAsString(downloaded, flush: true);
          } catch (_) {
            // キャッシュ不可でも動作には影響しない
          }
        }
      }
    }
    body ??= cachedBody;
    if (body == null) {
      try {
        body = await rootBundle.loadString(assetPath);
      } catch (_) {
        body = null;
      }
    }
    final pts = body == null ? const <WbgtPoint>[] : parseMaster(body, asOf: jst);
    if (pts.isNotEmpty) _master = pts;
    return pts;
  }

  /// 地点の実況・予測を取得する。同じ正時内はキャッシュを返す。
  /// 失敗は例外にせず [WbgtPointData.failed] で返す（キャッシュしない）
  static Future<WbgtPointData> fetchPoint(WbgtPoint p,
      {DateTime? now, http.Client? client}) async {
    final jst = now ?? HeatAlerts.nowJst();
    final key = hourKey(jst);
    final cached = _pointCache[p.id];
    if (cached != null && cached.hourKey == key) return cached;

    final results = await Future.wait<Object?>([
      _fetchForecast(p.id, client),
      _fetchActual(p.id, jst, client),
    ]);
    final forecast = results[0] as List<WbgtValue>?;
    final current = results[1] as WbgtValue?;
    final failed = forecast == null && current == null;
    final data = WbgtPointData(
      point: p,
      current: current,
      forecast: forecast ?? const [],
      hourKey: key,
      failed: failed,
    );
    if (!failed) _pointCache[p.id] = data;
    return data;
  }

  /// 予測。取得失敗は null（0件のリストとは区別する）
  static Future<List<WbgtValue>?> _fetchForecast(
      String id, http.Client? client) async {
    try {
      final r = await _get(forecastUrl(id), client);
      if (r.statusCode != 200) return null;
      return parseForecast(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// 実況の最新値。当月ファイルに値が無ければ（月初の未明）前月も見る
  static Future<WbgtValue?> _fetchActual(
      String id, DateTime jst, http.Client? client) async {
    final months = [jst];
    if (jst.day <= 1) months.add(DateTime(jst.year, jst.month - 1, 1));
    for (final m in months) {
      try {
        final r = await _get(actualUrl(id, m), client);
        if (r.statusCode != 200) continue;
        final v = latestActual(utf8.decode(r.bodyBytes));
        if (v != null) return v;
      } catch (_) {
        // 次の候補へ
      }
    }
    return null;
  }

  /// テスト用。キャッシュを空にする
  static void clearCacheForTest() {
    _master = null;
    _pointCache.clear();
  }
}
