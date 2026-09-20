/// 気象庁の指定河川洪水予報（無料・認証不要の公開JSON。SPEC C2）。
///
/// `https://www.jma.go.jp/bosai/flood/data/r8/flood_xml.json` は発表中の洪水予報の配列。
/// 発表が無いときは `[]`。各要素（気象庁ページの JS が参照する項目）:
///   riverCode / riverName / reportDatetime / infoType（通常・訓練）/ text（本文）
///   item: {code, name} … 発表情報（コード 10=解除, 20〜22=氾濫注意情報,
///                        30〜31=氾濫警戒情報, 40〜41=氾濫危険情報, 50〜53=氾濫発生情報）
///   class20s（対象市町村コード）/ officeCodes（対象官署）/ pdfFilename
/// 実データが空のときに構造を確認したため、項目の有無は防御的に扱う。
/// 出典：気象庁ホームページ https://www.jma.go.jp/bosai/flood/
library;

import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:http/http.dart' as http;

import '../models/camera.dart';

/// 洪水予報の段階（警戒レベル相当）
enum FloodLevel {
  /// 解除・なし
  none(0),

  /// 氾濫注意情報（警戒レベル2相当）
  caution(2),

  /// 氾濫警戒情報（警戒レベル3相当）
  warning(3),

  /// 氾濫危険情報（警戒レベル4相当）
  danger(4),

  /// 氾濫発生情報（警戒レベル5相当）
  occurred(5);

  const FloodLevel(this.level);
  final int level;

  /// 表示色。キキクル（RiskLayers）と同じ気象庁の警戒レベル配色
  Color get color => switch (this) {
        FloodLevel.occurred => const Color(0xFF0C000C),
        FloodLevel.danger => const Color(0xFFAA00AA),
        FloodLevel.warning => const Color(0xFFFF2800),
        FloodLevel.caution => const Color(0xFFF2E700),
        FloodLevel.none => const Color(0xFFBDBDBD),
      };

  /// 気象庁の発表情報コード（2桁）→ 段階
  static FloodLevel fromCode(String code) {
    if (code.length < 2) return FloodLevel.none;
    return switch (code.substring(0, 1)) {
      '5' => FloodLevel.occurred,
      '4' => FloodLevel.danger,
      '3' => FloodLevel.warning,
      '2' => FloodLevel.caution,
      _ => FloodLevel.none,
    };
  }
}

/// 発表中の洪水予報1件（河川ごと）
class FloodForecast {
  const FloodForecast({
    required this.riverCode,
    required this.riverName,
    required this.level,
    required this.kindName,
    required this.reportAt,
    this.text = '',
    this.class20s = const [],
    this.officeCodes = const [],
    this.training = false,
  });

  final String riverCode;
  final String riverName;
  final FloodLevel level;

  /// 発表情報の名称（氾濫危険情報 など。気象庁の item.name そのまま）
  final String kindName;

  /// 発表時刻（UTCフラグ付き）
  final DateTime reportAt;
  final String text;

  /// 対象市町村コード（5〜7桁。先頭2桁が都道府県）
  final List<String> class20s;
  final List<String> officeCodes;

  /// 訓練報（表示しない）
  final bool training;

  /// 対象都道府県（JIS 2桁）。class20s から導き、無ければ officeCodes
  /// （官署コード 6桁。先頭2桁が都道府県。例 130000=東京）から導く。
  /// 2026-09-20 善福寺川の実発表で class20s が無く、都道府県が空になって
  /// プッシュが送られなかった
  Set<String> get prefectures {
    final fromCities = {
      for (final c in class20s)
        if (c.length >= 2) c.substring(0, 2),
    };
    if (fromCities.isNotEmpty) return fromCities;
    return {
      for (final o in officeCodes)
        if (o.length >= 2) o.substring(0, 2),
    };
  }

  /// 河川名の照合用（「水系」「（上流）」などの補足を落とす）
  static String normalizeRiver(String s) {
    var t = s.trim();
    t = t.replaceAll(RegExp(r'[（(].*?[）)]'), '');
    t = t.replaceAll('水系', '').replaceAll(RegExp(r'\s+'), '');
    return t;
  }

  /// この河川に紐づくカメラ。台帳の river_or_route に河川名が含まれ、
  /// 対象都道府県（分かる場合）に属するもの
  List<Camera> matchCameras(Iterable<Camera> cameras) {
    final river = normalizeRiver(riverName);
    if (river.length < 2) return const [];
    final prefs = prefectures;
    final out = <Camera>[];
    for (final c in cameras) {
      final r = c.riverOrRoute;
      if (r == null || r.isEmpty) continue;
      if (prefs.isNotEmpty && !prefs.contains(c.prefecture)) continue;
      final n = normalizeRiver(r);
      if (n == river || n.contains(river) || (n.length >= 3 && river.contains(n))) {
        out.add(c);
      }
    }
    return out;
  }

  static FloodForecast? fromJson(Map<String, dynamic> j) {
    final code = j['riverCode']?.toString() ?? '';
    final name = j['riverName']?.toString() ?? '';
    if (code.isEmpty || name.isEmpty) return null;
    final item = j['item'];
    var kindCode = '';
    var kindName = '';
    if (item is Map) {
      kindCode = item['code']?.toString() ?? '';
      kindName = item['name']?.toString() ?? '';
    }
    if (kindCode.isEmpty) kindCode = j['status']?.toString() ?? '';
    if (kindName.isEmpty) kindName = j['kind']?.toString() ?? '';
    final at = DateTime.tryParse(j['reportDatetime']?.toString() ?? '');
    if (at == null) return null;
    List<String> strList(Object? v) =>
        v is List ? [for (final e in v) e.toString()] : const [];
    return FloodForecast(
      riverCode: code,
      riverName: name,
      level: FloodLevel.fromCode(kindCode),
      kindName: kindName,
      reportAt: at.toUtc(),
      text: j['text']?.toString() ?? '',
      class20s: strList(j['class20s']),
      officeCodes: strList(j['officeCodes']),
      training: (j['infoType']?.toString() ?? '') == '訓練',
    );
  }
}

class JmaFlood {
  JmaFlood._();

  static const url = 'https://www.jma.go.jp/bosai/flood/data/r8/flood_xml.json';
  static const attribution = '出典：気象庁';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  /// 発表中の洪水予報（訓練・解除を除き、河川ごとに最新1件。段階の高い順）。
  /// 取得失敗は null（「無い」と区別する）
  static Future<List<FloodForecast>?> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse(url), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return parse(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  static List<FloodForecast> parse(Object? json) {
    if (json is! List) return const [];
    final byRiver = <String, FloodForecast>{};
    for (final e in json.whereType<Map<String, dynamic>>()) {
      final f = FloodForecast.fromJson(e);
      if (f == null || f.training) continue;
      final cur = byRiver[f.riverCode];
      if (cur == null || f.reportAt.isAfter(cur.reportAt)) byRiver[f.riverCode] = f;
    }
    final out = byRiver.values.where((f) => f.level != FloodLevel.none).toList()
      ..sort((a, b) {
        final d = b.level.level.compareTo(a.level.level);
        return d != 0 ? d : b.reportAt.compareTo(a.reportAt);
      });
    return out;
  }
}
