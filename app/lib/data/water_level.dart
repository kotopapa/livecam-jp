/// 河川カメラの詳細画面に出す水位の時系列（国土交通省「川の防災情報」）。
///
/// - 観測所の一覧は配信ファイル site/v1/water_stations.json（tools/water_stations.py が
///   一度限りの対応付けで作る。名称・座標・基準水位）。1日1回だけ取り直す
/// - 水位の値は詳細画面を開いたときに端末が川の防災情報から直接取る（サーバー側では
///   収集しない。同サイトは規約でツールによる定期収集を控えるよう求めているため）。
///   同じ観測所は5分間メモリに控える
/// - ファイルは SPA 内部のもので、構造が変わると取れなくなる。失敗時はグラフを出さないだけ
///   （カメラ表示には影響させない）
///   - 現況: `tmlist/stg/YYYYMMDD/HHmm/<obsFcd>.json`（10分刻みの時刻スロット。最新スロットは
///     まだ無いことがあるので 3 スロット分さかのぼる）。obsValue=最新値、min10Values=10分値
///     （新しい順、約8時間分）、predstgValues=予測
///   - 過去: `tmlist/past/stg/YYYYMMDD/<obsFcd>.json`。pastValues=時間値（約7日分）
/// - 時刻は "2026/10/04 22:30" の JST 壁時計。素の DateTime のまま扱い UTC に変換しない
///   （app/lib/util/jst.dart の原則）
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../util/jst.dart';

const _ua = {'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'};

/// 水位観測所（配信ファイルの1件）
class WaterStation {
  const WaterStation({
    required this.obs,
    required this.name,
    required this.lat,
    required this.lon,
    this.river,
    this.ofc,
    this.obsCd,
    this.levels = const {},
  });

  final String obs;
  final String name;
  final double lat;
  final double lon;
  final String? river;
  final int? ofc;
  final int? obsCd;

  /// 基準水位（m）。キー: rsrv=水防団待機 / warn=氾濫注意 / spcl=避難判断 / dng=氾濫危険 / fld=計画高水位
  final Map<String, double> levels;

  static WaterStation? fromJson(String obs, Map<String, dynamic> m) {
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final levels = <String, double>{};
    for (final e in (m['levels'] as Map<String, dynamic>? ?? const {}).entries) {
      final v = e.value;
      if (v is num) levels[e.key] = v.toDouble();
    }
    return WaterStation(
      obs: obs,
      name: m['name'] as String? ?? obs,
      lat: lat,
      lon: lon,
      river: m['rvr'] as String?,
      ofc: (m['ofc'] as num?)?.toInt(),
      obsCd: (m['obs'] as num?)?.toInt(),
      levels: levels,
    );
  }

  /// 川の防災情報の観測所ページ（出典リンク）
  Uri get siteUrl => Uri.parse(
      'https://www.river.go.jp/kawabou/pc/tm?itmkndCd=4&ofcCd=${ofc ?? ''}&obsCd=${obsCd ?? ''}');
}

/// 配信ファイル water_stations.json（1日1回取り直し）
class WaterStations {
  WaterStations._();

  static const url = '${apiBaseUrl}water_stations.json';
  static Map<String, WaterStation>? _cache;
  static DateTime? _cachedAt;

  static Map<String, WaterStation> parse(Map<String, dynamic> json) {
    final out = <String, WaterStation>{};
    for (final e in (json['stations'] as Map<String, dynamic>? ?? const {}).entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        final st = WaterStation.fromJson(e.key, v);
        if (st != null) out[e.key] = st;
      }
    }
    return out;
  }

  static Future<WaterStation?> find(String obs, {http.Client? client}) async {
    final c = _cache;
    if (c != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(hours: 24)) {
      return c[obs];
    }
    final cl = client ?? http.Client();
    try {
      final r = await cl.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return c?[obs];
      final parsed = parse(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
      _cache = parsed;
      _cachedAt = DateTime.now();
      return parsed[obs];
    } catch (_) {
      return c?[obs];
    } finally {
      if (client == null) cl.close();
    }
  }

  /// テスト用
  static void resetCache() {
    _cache = null;
    _cachedAt = null;
  }
}

/// 1時刻の水位。[time] は JST 壁時計（素の DateTime）
class WaterLevelPoint {
  const WaterLevelPoint(this.time, this.stage);

  final DateTime time;
  final double stage;
}

class WaterLevelSeries {
  const WaterLevelSeries({
    required this.points,
    required this.latest,
    this.forecast = const [],
  });

  /// 時刻の昇順。直近48時間分
  final List<WaterLevelPoint> points;

  /// 最新の観測値（欠測なら null）
  final WaterLevelPoint? latest;

  /// 予測値（指定河川など一部の観測所のみ）
  final List<WaterLevelPoint> forecast;

  bool get isEmpty => points.isEmpty && latest == null;

  /// 標高（T.P.）で水位を表す観測所か。零点高からの水位が 30m を超えることは無いので、
  /// 観測値か基準水位がそれ以上なら標高表示とみなす（札幌 石山は 104m 台。2026-10-07 利用者の問い合わせ）
  bool isElevationBased(Map<String, double> levels) {
    const limit = 30.0;
    if ((latest?.stage ?? 0) > limit) return true;
    if (points.any((p) => p.stage > limit)) return true;
    return levels.values.any((v) => v > limit);
  }
}

class WaterLevel {
  WaterLevel._();

  static const base = 'https://www.river.go.jp/kawabou/file/files/';
  static const window = Duration(hours: 48);
  static final Map<String, (DateTime, WaterLevelSeries)> _mem = {};

  /// "2026/10/04 22:30" → JST 壁時計の素の DateTime
  static DateTime? parseTime(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
        int.parse(m[4]!), int.parse(m[5]!));
  }

  static List<WaterLevelPoint> _pointsOf(dynamic list) {
    final out = <WaterLevelPoint>[];
    for (final v in (list as List<dynamic>? ?? const [])) {
      if (v is! Map<String, dynamic>) continue;
      final t = parseTime(v['obsTime'] as String?);
      final stg = v['stg'];
      if (t == null || stg is! num || !_valid(v)) continue;
      out.add(WaterLevelPoint(t, stg.toDouble()));
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  /// 欠測・異常（stgCcd≠0。欠測は stg=0 で届くのでそのまま描くと 0m に落ちる）を除く
  static bool _valid(Map<String, dynamic> v) {
    final ccd = v['stgCcd'];
    return ccd == null || ccd == 0;
  }

  /// 現況ファイル（10分値・最新値・予測）を読む
  static WaterLevelSeries parseCurrent(Map<String, dynamic> json) {
    final ov = json['obsValue'];
    WaterLevelPoint? latest;
    if (ov is Map<String, dynamic>) {
      final t = parseTime(ov['obsTime'] as String?);
      final stg = ov['stg'];
      if (t != null && stg is num && _valid(ov)) latest = WaterLevelPoint(t, stg.toDouble());
    }
    return WaterLevelSeries(
      points: _pointsOf(json['min10Values']),
      latest: latest,
      forecast: _pointsOf(json['predstgValues']),
    );
  }

  /// 過去ファイル（時間値）を読む
  static List<WaterLevelPoint> parsePast(Map<String, dynamic> json) =>
      _pointsOf(json['pastValues']);

  /// 時間値と10分値を結合し直近 [window] に絞る
  static List<WaterLevelPoint> merge(List<WaterLevelPoint> past, List<WaterLevelPoint> recent,
      DateTime nowJst) {
    final from = nowJst.subtract(window);
    final firstRecent = recent.isEmpty ? null : recent.first.time;
    final out = <WaterLevelPoint>[
      for (final p in past)
        if (!p.time.isBefore(from) && (firstRecent == null || p.time.isBefore(firstRecent))) p,
      for (final p in recent)
        if (!p.time.isBefore(from)) p,
    ];
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  static String _ymd(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}';

  /// 観測所 [obs] の直近48時間。取れなければ null。5分メモリ控え
  /// メモリ控えを捨てる（復帰時に5分控えを無視して取り直すため）
  static void invalidate(String obs) => _mem.remove(obs);

  static Future<WaterLevelSeries?> fetch(String obs,
      {http.Client? client, DateTime? nowJst, bool force = false}) async {
    final cached = _mem[obs];
    if (!force && cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 5)) {
      return cached.$2;
    }
    final now = nowJst ?? jstNow();
    final cl = client ?? http.Client();
    try {
      Future<Map<String, dynamic>?> getJson(String path) async {
        try {
          final r = await cl.get(Uri.parse('$base$path'), headers: _ua)
              .timeout(const Duration(seconds: 15));
          if (r.statusCode != 200) return null;
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          return j is Map<String, dynamic> ? j : null;
        } catch (_) {
          return null;
        }
      }

      // 現況: 10分刻みのスロット。最新スロットは未生成のことがあるので3つさかのぼる
      final slot0 = DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 10);
      WaterLevelSeries? current;
      for (var i = 0; i < 3 && current == null; i++) {
        final slot = slot0.subtract(Duration(minutes: 10 * i));
        final j = await getJson('tmlist/stg/${_ymd(slot)}/${_hm(slot)}/$obs.json');
        if (j != null) current = parseCurrent(j);
      }
      // 過去: 当日のファイル（約7日分の時間値）。無ければ前日
      var past = const <WaterLevelPoint>[];
      for (var d = 0; d < 2 && past.isEmpty; d++) {
        final day = now.subtract(Duration(days: d));
        final j = await getJson('tmlist/past/stg/${_ymd(day)}/$obs.json');
        if (j != null) past = parsePast(j);
      }
      if (current == null && past.isEmpty) return cached?.$2;
      final series = WaterLevelSeries(
        points: merge(past, current?.points ?? const [], now),
        latest: current?.latest,
        forecast: current?.forecast ?? const [],
      );
      _mem[obs] = (DateTime.now(), series);
      return series;
    } finally {
      if (client == null) cl.close();
    }
  }

  /// テスト用
  static void resetCache() => _mem.clear();
}
