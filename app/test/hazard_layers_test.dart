import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/hazard_layers.dart';
import 'package:livecam_jp/data/jma_layers.dart';

void main() {
  test('レイヤー種別→重ねるハザードマップのタイルURL', () {
    expect(HazardLayers.tileTemplates(MapLayerKind.hazardFlood), [
      'https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/{z}/{x}/{y}.png',
    ]);
    expect(HazardLayers.tileTemplates(MapLayerKind.hazardTsunami), [
      'https://disaportaldata.gsi.go.jp/raster/04_tsunami_newlegend_data/{z}/{x}/{y}.png',
    ]);
    expect(HazardLayers.tileTemplates(MapLayerKind.hazardHightide), [
      'https://disaportaldata.gsi.go.jp/raster/03_hightide_l2_shinsuishin_data/{z}/{x}/{y}.png',
    ]);
    // 土砂災害は3区分を同時に重ねる
    expect(HazardLayers.tileIds(MapLayerKind.hazardLandslide), [
      '05_kyukeishakeikaikuiki',
      '05_dosekiryukeikaikuiki',
      '05_jisuberikeikaikuiki',
    ]);
  });

  test('気象レイヤーはハザード扱いにならずタイルIDも持たない', () {
    for (final k in [MapLayerKind.none, MapLayerKind.rainRadar, MapLayerKind.quakes, MapLayerKind.rain24h]) {
      expect(HazardLayers.isHazard(k), isFalse);
      expect(HazardLayers.tileIds(k), isEmpty);
      expect(HazardLayers.titleKey(k), '');
    }
    for (final k in [MapLayerKind.hazardFlood, MapLayerKind.hazardLandslide, MapLayerKind.hazardTsunami, MapLayerKind.hazardHightide]) {
      expect(HazardLayers.isHazard(k), isTrue);
      expect(HazardLayers.tileIds(k), isNotEmpty);
      // 1.4.0: 表示名ではなく l10n キーを返す（解決は hazardLayerTitleOf）
      expect(HazardLayers.titleKey(k), isNotEmpty);
    }
  });

  test('凡例は地理院の配色（浸水深6段階・土砂災害3区分）', () {
    expect(HazardLayers.depthScale.length, 6);
    expect(HazardLayers.depthScale.first.$1, const Color(0xFFF7F5A9)); // 0.5m未満
    expect(HazardLayers.depthScale.last.$1, const Color(0xFFDC7ADC)); // 20m以上
    expect(HazardLayers.landslideScale.map((s) => s.$1),
        ['steepSlope', 'debrisFlow', 'landslide']);
    expect(HazardLayers.maxZoom, 17);
  });
}
