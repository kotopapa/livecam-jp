import 'package:flutter/material.dart';

import 'jma_layers.dart' show MapLayerKind;

/// 国土地理院「重ねるハザードマップ」のオープンデータタイル（無料・認証不要）。
/// URL・ズーム範囲は https://disaportal.gsi.go.jp/hazardmap/copyright/opendata.html、
/// 凡例色は同ページの凡例画像（shinsui_legend3.png / keikai_*.png）の画素値。
/// タイルは静的（更新は年数回）なので定期更新は不要。データの無い範囲は404。
class HazardLayers {
  static const tileBase = 'https://disaportaldata.gsi.go.jp/raster';
  static const minZoom = 2;
  static const maxZoom = 17;

  static bool isHazard(MapLayerKind k) => switch (k) {
        MapLayerKind.hazardFlood ||
        MapLayerKind.hazardLandslide ||
        MapLayerKind.hazardTsunami ||
        MapLayerKind.hazardHightide =>
          true,
        _ => false,
      };

  /// レイヤー種別 → 重ねるタイルID（土砂災害は3区分を同時に重ねる）
  static List<String> tileIds(MapLayerKind k) => switch (k) {
        MapLayerKind.hazardFlood => const ['01_flood_l2_shinsuishin_data'],
        MapLayerKind.hazardLandslide => const [
            '05_kyukeishakeikaikuiki', // 急傾斜地の崩壊
            '05_dosekiryukeikaikuiki', // 土石流
            '05_jisuberikeikaikuiki', // 地すべり
          ],
        MapLayerKind.hazardTsunami => const ['04_tsunami_newlegend_data'],
        MapLayerKind.hazardHightide => const ['03_hightide_l2_shinsuishin_data'],
        _ => const [],
      };

  static String tileTemplate(String id) => '$tileBase/$id/{z}/{x}/{y}.png';

  static List<String> tileTemplates(MapLayerKind k) =>
      [for (final id in tileIds(k)) tileTemplate(id)];

  static String title(MapLayerKind k) => switch (k) {
        MapLayerKind.hazardFlood => '洪水浸水想定区域（想定最大規模）',
        MapLayerKind.hazardLandslide => '土砂災害警戒区域',
        MapLayerKind.hazardTsunami => '津波浸水想定',
        MapLayerKind.hazardHightide => '高潮浸水想定区域',
        _ => '',
      };

  /// 浸水深の凡例（洪水・高潮・津波共通。shinsui_legend3.png の配色）
  static const depthScale = <(Color, String)>[
    (Color(0xFFF7F5A9), '〜0.5m'),
    (Color(0xFFFFD8C0), '0.5〜3m'),
    (Color(0xFFFFB7B7), '3〜5m'),
    (Color(0xFFFF9191), '5〜10m'),
    (Color(0xFFF285C9), '10〜20m'),
    (Color(0xFFDC7ADC), '20m〜'),
  ];

  /// 土砂災害の凡例。区分ごとに配色が異なる（keikai_kyukeisya/dosekiryu/jisuberi.png）
  /// (区分名, 警戒区域, 特別警戒区域)
  static const landslideScale = <(String, Color, Color)>[
    ('急傾斜地', Color(0xFFFAE600), Color(0xFFFA2800)),
    ('土石流', Color(0xFFE6C832), Color(0xFFA50021)),
    ('地すべり', Color(0xFFFF9900), Color(0xFFB40028)),
  ];

  static const attribution = '出典：ハザードマップポータルサイト（国土地理院）';
  static const disclaimer =
      '最新かつ詳細な情報は各市町村のハザードマップをご確認ください。避難判断は自治体の避難情報に従ってください';
}
