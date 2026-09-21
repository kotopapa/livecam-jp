import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'road_regulation.dart';
import 'underpass.dart';

/// 道路の通行止め・規制（統合レイヤー。1.5.2）。
///
/// 自治体の冠水センサー（underpass_status.json）と国交省の通行規制（road_regulation.json）を
/// 1つのレイヤーにまとめ、**色＝原因**（冠水・土砂・気象・その他）、**塗りつぶし＝通行止め／
/// 白抜き＝規制・注意／小さい丸＝センサー正常** で描く（2026-09-21 ユーザー要望）。
enum ClosureCause { flood, landslide, weather, other }

Color closureCauseColor(ClosureCause c) => switch (c) {
      ClosureCause.flood => const Color(0xFF1E88E5),
      ClosureCause.landslide => const Color(0xFF8D6E63),
      ClosureCause.weather => const Color(0xFF8E24AA),
      ClosureCause.other => const Color(0xFF616161),
    };

/// 規制原因の文字列（国交省の「規制原因」や県の理由）→ 原因の分類
ClosureCause classifyCause(String text) {
  final t = text;
  if (RegExp(r'冠水|浸水|越波|溢水|氾濫|内水').hasMatch(t)) return ClosureCause.flood;
  if (RegExp(r'土砂|土石|落石|崩落|崩壊|道路損壊|法面|地すべり|地滑り|陥没|路面損壊|倒木').hasMatch(t)) {
    return ClosureCause.landslide;
  }
  if (RegExp(r'雨|雪|凍結|風|波|台風|気象|吹雪|霧|雷|津波|高潮|なだれ|雪崩').hasMatch(t)) {
    return ClosureCause.weather;
  }
  return ClosureCause.other;
}

class ClosureItem {
  const ClosureItem({
    required this.id,
    required this.name,
    required this.section,
    required this.cause,
    required this.causeText,
    required this.level,
    required this.label,
    required this.at,
    required this.pos,
    required this.lines,
    required this.sourceName,
    required this.sourceUrl,
    required this.attribution,
    required this.isSensor,
  });

  final String id;
  final String name;
  final String section;
  final ClosureCause cause;

  /// 情報源の原因表記（「土砂崩れ」「冠水を検知」など）
  final String causeText;

  /// 2=通行止め / 1=規制・注意 / 0=通行可（センサー正常）/ -1=不明
  final int level;
  final String label;
  final String at;
  final LatLng pos;
  final List<List<LatLng>> lines;
  final String sourceName;
  final String sourceUrl;
  final String attribution;

  /// true=自治体の冠水センサー、false=道路管理者の規制情報
  final bool isSensor;

  Color get color => closureCauseColor(cause);
  bool get isAlert => level >= 1;
}

class RoadClosures {
  RoadClosures._();

  /// 2つの配信データを統合する
  static List<ClosureItem> merge(UnderpassStatus underpass, RoadRegulationStatus reg) {
    final out = <ClosureItem>[];
    for (final s in underpass.sources) {
      for (final p in s.points) {
        // 県の規制系（静岡県の冠水規制区間・兵庫県の規制）はラベルに原因が入るので分類、センサーは冠水
        final cause = p.label.contains('（') && !p.name.contains('センサ')
            ? classifyCause(p.label)
            : ClosureCause.flood;
        out.add(ClosureItem(
          id: '${s.id}:${p.id}',
          name: p.name,
          section: '',
          cause: cause == ClosureCause.other ? ClosureCause.flood : cause,
          causeText: p.label,
          level: p.level,
          label: p.label,
          at: p.at,
          pos: p.pos,
          lines: p.lines,
          sourceName: s.name,
          sourceUrl: s.url,
          attribution: s.attribution,
          isSensor: true,
        ));
      }
    }
    for (final s in reg.sources) {
      for (final it in s.items) {
        out.add(ClosureItem(
          id: '${s.id}:${it.id}',
          name: it.name,
          section: it.section,
          cause: classifyCause('${it.cause} ${it.content}'),
          causeText: it.cause.isNotEmpty ? it.cause : it.label,
          level: it.level,
          label: it.label,
          at: it.at,
          pos: it.pos,
          lines: it.lines,
          sourceName: s.name,
          sourceUrl: s.url,
          attribution: s.attribution,
          isSensor: false,
        ));
      }
    }
    return out;
  }
}
