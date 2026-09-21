/// 「いま起きていること」の要約（地図の起動時に重ねるカード用）。
///
/// 特別警報（レベル5）・危険警報（レベル4相当）の都道府県、台風、指定河川洪水予報、
/// 直近24時間の震度4以上の地震をまとめる。いずれも気象庁の公開JSONで、
/// 既存の取得処理（JmaTyphoon / JmaFlood / JmaLayers.fetchQuakes）を組み合わせる。
/// 1つでも失敗しても他は表示する（部分的な要約を返す）。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jma_flood.dart';
import 'jma_layers.dart';
import 'jma_typhoon.dart';
import 'underpass.dart';

/// 特別警報・危険警報が出ている都道府県（r8 map.json）
class WarningPrefs {
  const WarningPrefs({this.special = const {}, this.danger = const {}});

  /// 特別警報（レベル5）の都道府県 JIS 2桁
  final Set<String> special;

  /// 危険警報（レベル4相当。2026年新体系）の都道府県
  final Set<String> danger;

  static const specialCodes = {'32', '33', '34', '35', '36', '37', '38', '39'};
  static const dangerCodes = {'43', '44', '48', '49'};

  /// 官署×報種別ごとに最新報を採り、発表中（解除・なし以外）の県を集める
  static WarningPrefs parse(List<dynamic> reports) {
    final latest = <String, Map<String, dynamic>>{};
    for (final rep in reports.whereType<Map<String, dynamic>>()) {
      final key = '${rep['publishingOffice'] ?? ''}/${rep['dataTypeCode'] ?? ''}';
      final dt = rep['reportDatetime'] as String? ?? '';
      final cur = latest[key];
      if (cur == null || dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
        latest[key] = rep;
      }
    }
    final special = <String>{};
    final danger = <String>{};
    for (final rep in latest.values) {
      final warning = rep['warning'];
      if (warning is! Map) continue;
      for (final area in (warning['class10Items'] as List? ?? const [])) {
        if (area is! Map) continue;
        final areaCode = (area['areaCode'] ?? area['code'])?.toString() ?? '';
        if (areaCode.length < 2) continue;
        final pref = areaCode.substring(0, 2);
        for (final w in (area['kinds'] as List? ?? const [])) {
          if (w is! Map) continue;
          final status = w['status']?.toString() ?? '';
          if (status == '解除' || status.contains('なし')) continue;
          final code = w['code']?.toString() ?? '';
          if (specialCodes.contains(code)) special.add(pref);
          if (dangerCodes.contains(code)) danger.add(pref);
        }
      }
    }
    return WarningPrefs(special: special, danger: danger);
  }
}

class Situation {
  const Situation({
    required this.warnings,
    required this.typhoons,
    required this.floods,
    required this.quakes,
    required this.loadedAt,
    this.underpass = const [],
  });

  final WarningPrefs warnings;
  final List<Typhoon> typhoons;
  final List<FloodForecast> floods;

  /// 直近24時間の震度4以上（新しい順）
  final List<QuakePoint> quakes;

  /// 取得時刻（[empty] だけ null）
  final DateTime? loadedAt;

  /// 通行注意・通行止めの地下道がある情報源（自治体の冠水情報システム）
  final List<UnderpassSource> underpass;

  static const empty = Situation(
    warnings: WarningPrefs(),
    typhoons: [],
    floods: [],
    quakes: [],
    loadedAt: null,
  );

  /// 何か1つでもあればカードを出す
  bool get isNotable =>
      warnings.special.isNotEmpty ||
      warnings.danger.isNotEmpty ||
      typhoons.isNotEmpty ||
      floods.isNotEmpty ||
      quakes.isNotEmpty ||
      underpass.isNotEmpty;

  /// 内容の識別子。閉じたカードは同じ内容のあいだ再表示しない（内容が変われば出る）
  String get signature => [
        's:${(warnings.special.toList()..sort()).join(',')}',
        'd:${(warnings.danger.toList()..sort()).join(',')}',
        't:${typhoons.map((t) => '${t.id}/${t.analysis.categoryEn}').join(',')}',
        'f:${floods.map((f) => '${f.riverCode}/${f.level.level}').join(',')}',
        'q:${quakes.map((q) => '${q.at.toUtc().toIso8601String()}/${q.maxIntensity}').join(',')}',
        'u:${underpass.map((s) => s.alerts.map((p) => '${s.id}/${p.id}/${p.level}').join(',')).join(',')}',
      ].join('|');

  /// 震度4以上か（'4','5-','5+','6-','6+','7'）
  static bool intensityAtLeast4(String s) =>
      s == '4' || s.startsWith('5') || s.startsWith('6') || s == '7';
}

class SituationLoader {
  SituationLoader._();

  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static Future<WarningPrefs> fetchWarnings({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(
              Uri.parse('https://www.jma.go.jp/bosai/warning/data/r8/map.json'),
              headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const WarningPrefs();
      return WarningPrefs.parse(jsonDecode(utf8.decode(r.bodyBytes)) as List);
    } catch (_) {
      return const WarningPrefs();
    } finally {
      if (client == null) c.close();
    }
  }

  /// 5系統を並列に取得。失敗した系統は空として扱う
  static Future<Situation> load() async {
    final results = await Future.wait<Object?>([
      fetchWarnings().catchError((_) => const WarningPrefs()),
      JmaTyphoon.fetchAll().catchError((_) => const <Typhoon>[]),
      JmaFlood.fetch().catchError((_) => null),
      JmaLayers.fetchQuakes(QuakePeriod.day).catchError((_) => const <QuakePoint>[]),
      Underpass.fetch().catchError((_) => UnderpassStatus.empty),
    ]);
    final quakes = (results[3] as List<QuakePoint>? ?? const [])
        .where((q) => Situation.intensityAtLeast4(q.maxIntensity))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return Situation(
      warnings: results[0] as WarningPrefs? ?? const WarningPrefs(),
      typhoons: results[1] as List<Typhoon>? ?? const [],
      floods: results[2] as List<FloodForecast>? ?? const [],
      quakes: quakes,
      loadedAt: DateTime.now(),
      underpass: (results[4] as UnderpassStatus? ?? UnderpassStatus.empty).alertSources,
    );
  }
}
