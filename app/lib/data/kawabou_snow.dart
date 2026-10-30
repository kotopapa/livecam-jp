/// 国交省「川の防災情報」の積雪観測所（テレメータ）の積雪深。
///
/// - 観測所の表は同梱アセット `assets/data/kawabou_snow_stations.json`
///   （tools/kawabou_snow_stations.py が生成。アメダスの表と同じ形）
/// - 値は積雪タブを開いたとき、近くの観測点に出る観測所の分だけ端末が直接取る
///   （サーバーでは収集しない。同サイトは規約でツールによる定期収集を控えるよう求めている。
///   水位グラフ water_level.dart と同じ方針）
/// - 現況: `tmlist/snw/YYYYMMDD/HHmm/<obsFcd>.json`（JST の10分スロット。最新スロットは
///   未生成のことがあるので3つさかのぼる）。obsValue=最新値、hrValues=時間値（新しい順）
/// - snwdp は cm。snwdpCcd≠0 は欠測（値は 0 などで届くので捨てる）
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../util/jst.dart';
import 'amedas_snow.dart';

class KawabouSnow {
  const KawabouSnow._();

  static const sourceId = 'kawabou';
  static const sourceShort = '川の防災情報';

  /// 出典表記に並べる名前
  static const attributionName = '国土交通省 川の防災情報';

  static const base = 'https://www.river.go.jp/kawabou/file/files/';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };
  static const okTtl = Duration(minutes: 30);
  static const failTtl = Duration(minutes: 10);

  static Future<List<SnowStation>>? _loading;

  /// 同梱の観測所表（1回だけ読む）
  static Future<List<SnowStation>> loadStations() =>
      _loading ??= _loadStations();

  static Future<List<SnowStation>> _loadStations() async {
    try {
      final raw = await rootBundle
          .loadString('assets/data/kawabou_snow_stations.json');
      return parseStations(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// テスト用に観測所表を差し替える
  static void setStations(List<SnowStation>? stations) {
    _loading = stations == null ? null : Future.value(stations);
  }

  /// 表の解析。観測所の id は `kawabou:<obsFcd>`
  static List<SnowStation> parseStations(Object? json) {
    return [
      for (final s in AmedasSnow.parseStations(json))
        SnowStation(
          id: '$sourceId:${s.id}',
          name: s.name,
          lat: s.lat,
          lng: s.lng,
          municipality: s.municipality,
          source: sourceShort,
          sourceId: sourceId,
        )
    ];
  }

  /// 観測所 id（`kawabou:<obsFcd>`）から観測所コードを取り出す
  static String obsFcdOf(SnowStation s) => s.id.replaceFirst('$sourceId:', '');

  /// 現況ファイルの解析（純粋関数）。積雪深 cm、欠測・形違いは null。
  /// obsValue が欠測なら hrValues の先頭（新しい順）から欠測でない最新値を使う
  static int? parse(Object? json) {
    if (json is! Map) return null;
    final v = _valid(json['obsValue']);
    if (v != null) return v;
    final hr = json['hrValues'];
    if (hr is List) {
      for (final e in hr) {
        final d = _valid(e);
        if (d != null) return d;
      }
    }
    return null;
  }

  static int? _valid(Object? e) {
    if (e is! Map) return null;
    final d = e['snwdp'];
    final ccd = e['snwdpCcd'];
    if (d is! num || d < 0) return null;
    if (ccd != null && ccd != 0) return null;
    return d.round();
  }

  static final Map<String, (DateTime, int?)> _mem = {};

  /// テスト用
  static void resetCache() => _mem.clear();

  /// 積雪深（cm）。欠測・失敗は null。成功は30分、失敗は10分メモリに控える
  static Future<int?> fetchDepth(String obsFcd,
      {http.Client? client, DateTime? nowJst}) async {
    final c = _mem[obsFcd];
    if (c != null) {
      final ttl = c.$2 == null ? failTtl : okTtl;
      if (DateTime.now().difference(c.$1) < ttl) return c.$2;
    }
    final now = nowJst ?? jstNow();
    final cl = client ?? http.Client();
    int? depth;
    try {
      final slot0 = DateTime(
          now.year, now.month, now.day, now.hour, now.minute - now.minute % 10);
      for (var i = 0; i < 3; i++) {
        final s = slot0.subtract(Duration(minutes: 10 * i));
        final path = 'tmlist/snw/${_ymd(s)}/${_hm(s)}/$obsFcd.json';
        try {
          final r = await cl
              .get(Uri.parse('$base$path'), headers: _ua)
              .timeout(const Duration(seconds: 15));
          if (r.statusCode != 200) continue;
          depth = parse(jsonDecode(utf8.decode(r.bodyBytes)));
          break; // 取れたスロットの内容が欠測ならさかのぼらない
        } catch (_) {
          continue;
        }
      }
    } finally {
      if (client == null) cl.close();
    }
    _mem[obsFcd] = (DateTime.now(), depth);
    return depth;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _ymd(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
  static String _hm(DateTime d) => '${_two(d.hour)}${_two(d.minute)}';
}
