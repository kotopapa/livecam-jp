import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/camera.dart';
import '../util/jst.dart';
import 'jma_area.dart';

/// 波の高さ1つ分（"０．５メートル" / "１メートル未満"）
class WaveHeight {
  const WaveHeight(this.meters, {this.under = false});
  final double meters;

  /// 「未満」付き
  final bool under;

  @override
  bool operator ==(Object other) =>
      other is WaveHeight && other.meters == meters && other.under == under;
  @override
  int get hashCode => Object.hash(meters, under);
}

/// 高さをつなぐ語
enum WaveConnector {
  /// 後（のち）
  then,

  /// 時々
  sometimes,

  /// 一時
  temporarily,
}

/// 高さの並び＋接続語＋うねり有無
class WaveSeq {
  const WaveSeq(this.heights, this.connectors, {this.swell = false});
  final List<WaveHeight> heights;

  /// heights.length - 1 個
  final List<WaveConnector> connectors;
  final bool swell;
}

/// 「ただし 新島 では ３メートル うねり を伴う」
class WaveException {
  const WaveException(this.place, this.seq);
  final String place;
  final WaveSeq seq;
}

class WaveText {
  const WaveText(this.main, [this.exception]);
  final WaveSeq main;
  final WaveException? exception;
}

class WaveDay {
  const WaveDay({required this.dayOffset, required this.raw, required this.parsed});

  /// 今日=0 / 明日=1 / 明後日=2（JST の暦日）
  final int dayOffset;

  /// 気象庁の原文
  final String raw;

  /// 解析できなければ null（原文を出す）
  final WaveText? parsed;
}

class WaveForecast {
  const WaveForecast({required this.name, required this.enName, required this.days});

  /// 一次細分区域名（class10）
  final String name;
  final String enName;
  final List<WaveDay> days;
}

class WaveForecasts {
  WaveForecasts._();

  static const _base = 'https://www.jma.go.jp/bosai/forecast/data/forecast/';
  static const _ttl = Duration(minutes: 30);
  static final Map<String, (DateTime, List<dynamic>)> _mem = {};

  /// 対象カメラか（海岸・港湾で、国内で、市区町村コードがある）
  static bool appliesTo(Camera c) =>
      (c.category == 'coast' || c.category == 'port') &&
      !c.isWorld &&
      (c.municipality?.length == 5);

  static String normalize(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF10 && r <= 0xFF19) {
        b.writeCharCode(r - 0xFF10 + 0x30);
      } else if (r == 0xFF0E) {
        b.write('.');
      } else if (r == 0x3000 || r == 0x20 || r == 0x09 || r == 0x0A) {
        b.write(' ');
      } else {
        b.writeCharCode(r);
      }
    }
    return b
        .toString()
        .replaceAll(RegExp(r' +'), ' ')
        .trim()
        .replaceAll('うねり を伴う', 'うねりを伴う');
  }

  static final _heightRe = RegExp(r'^(\d+(?:\.\d+)?)メートル(未満)?$');

  static (WaveSeq, int)? _seq(List<String> t, int i) {
    final heights = <WaveHeight>[];
    final conns = <WaveConnector>[];
    WaveHeight? h(int k) {
      if (k >= t.length) return null;
      final m = _heightRe.firstMatch(t[k]);
      if (m == null) return null;
      return WaveHeight(double.parse(m[1]!), under: m[2] != null);
    }

    final first = h(i);
    if (first == null) return null;
    heights.add(first);
    i++;
    while (i + 1 < t.length) {
      final c = switch (t[i]) {
        '後' || 'のち' => WaveConnector.then,
        '時々' => WaveConnector.sometimes,
        '一時' => WaveConnector.temporarily,
        _ => null,
      };
      if (c == null) break;
      final next = h(i + 1);
      if (next == null) return null;
      conns.add(c);
      heights.add(next);
      i += 2;
    }
    var swell = false;
    if (i < t.length && t[i] == 'うねりを伴う') {
      swell = true;
      i++;
    }
    return (WaveSeq(heights, conns, swell: swell), i);
  }

  /// "２メートル　後　１．５メートル　うねり　を伴う" を解析する。解析できなければ null
  static WaveText? parse(String raw) {
    final t = normalize(raw).split(' ');
    final main = _seq(t, 0);
    if (main == null) return null;
    var i = main.$2;
    if (i == t.length) return WaveText(main.$1);
    if (i + 3 < t.length && t[i] == 'ただし' && t[i + 2] == 'では') {
      final place = t[i + 1];
      final ex = _seq(t, i + 3);
      if (ex != null && ex.$2 == t.length) {
        return WaveText(main.$1, WaveException(place, ex.$1));
      }
    }
    return null;
  }

  /// 府県予報 JSON（[0].timeSeries[0]）から [areaCode] の波の予報を取り出す
  static List<WaveDay> parseDays(List<dynamic> json, String areaCode, DateTime nowJst) {
    if (json.isEmpty) return const [];
    final series = (json[0] as Map<String, dynamic>)['timeSeries'] as List<dynamic>?;
    if (series == null || series.isEmpty) return const [];
    final ts = series[0] as Map<String, dynamic>;
    final times = (ts['timeDefines'] as List<dynamic>? ?? const []).cast<String>();
    for (final a in (ts['areas'] as List<dynamic>? ?? const [])) {
      final m = a as Map<String, dynamic>;
      if ((m['area'] as Map<String, dynamic>?)?['code'] != areaCode) continue;
      final waves = m['waves'] as List<dynamic>?;
      if (waves == null) return const [];
      final today = startOfDay(nowJst);
      final out = <WaveDay>[];
      for (var i = 0; i < waves.length && i < times.length; i++) {
        final raw = waves[i];
        final t = DateTime.tryParse(times[i]);
        if (raw is! String || raw.trim().isEmpty || t == null) continue;
        final off = daysBetween(today, toJstWallClock(t));
        if (off < 0 || off > 2) continue;
        if (out.any((d) => d.dayOffset == off)) continue;
        out.add(WaveDay(dayOffset: off, raw: raw, parsed: parse(raw)));
      }
      return out;
    }
    return const [];
  }

  /// 復帰時に控えを捨てる
  static void invalidate() => _mem.clear();

  static void resetCache() => _mem.clear();

  /// カメラの海域の波の予報。海に面さない区域・取得失敗は null
  static Future<WaveForecast?> fetch(Camera camera,
      {http.Client? client, DateTime? nowJst}) async {
    if (!appliesTo(camera)) return null;
    try {
      await JmaAreaNames.load();
    } catch (_) {
      return null;
    }
    final area = JmaAreaNames.class10Of(camera.municipality);
    if (area == null) return null;
    var cached = _mem[area.office];
    if (cached == null || DateTime.now().difference(cached.$1) >= _ttl) {
      final cl = client ?? http.Client();
      try {
        final r = await cl
            .get(Uri.parse('$_base${area.office}.json'))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) return null;
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is! List<dynamic>) return null;
        cached = (DateTime.now(), j);
        _mem[area.office] = cached;
      } catch (_) {
        return null;
      } finally {
        if (client == null) cl.close();
      }
    }
    final days = parseDays(cached.$2, area.code, nowJst ?? jstNow());
    if (days.isEmpty) return null;
    return WaveForecast(name: area.name, enName: area.enName, days: days);
  }
}
