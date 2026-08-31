import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/hazard_layers.dart';
import 'package:livecam_jp/data/jma_layers.dart';

/// 気象庁「キキクル（危険度分布）」レイヤーの純粋関数。
/// 実データの構造・配色は 2026-08-31 に実サイトから採取して確認済み
/// （targetTimes.json / 実タイルのPLTE / 公式凡例SVG。RiskLayers のコメント参照）
void main() {
  const kinds = [MapLayerKind.riskLand, MapLayerKind.riskInund, MapLayerKind.riskFlood];

  test('レイヤー種別 → element とタイルURL', () {
    expect(RiskLayers.element(MapLayerKind.riskLand), 'land');
    expect(RiskLayers.element(MapLayerKind.riskInund), 'inund');
    expect(RiskLayers.element(MapLayerKind.riskFlood), 'flood');

    // targetTimes.json の実エントリ。member はエントリの値をそのまま使う（none にすると404）
    const t = RiskTime('20260831034000', '20260831034000', 'immed0');
    expect(
      t.tileTemplate(MapLayerKind.riskLand),
      'https://www.jma.go.jp/bosai/jmatile/data/risk/20260831034000/immed0/20260831034000/surf/land/{z}/{x}/{y}.png',
    );
    expect(
      t.tileTemplate(MapLayerKind.riskInund),
      'https://www.jma.go.jp/bosai/jmatile/data/risk/20260831034000/immed0/20260831034000/surf/inund/{z}/{x}/{y}.png',
    );
    expect(
      t.tileTemplate(MapLayerKind.riskFlood),
      'https://www.jma.go.jp/bosai/jmatile/data/risk/20260831034000/immed0/20260831034000/surf/flood/{z}/{x}/{y}.png',
    );
    // 実況の古いエントリは member=none
    const old = RiskTime('20260831020000', '20260831020000', 'none');
    expect(
      old.tileTemplate(MapLayerKind.riskFlood),
      'https://www.jma.go.jp/bosai/jmatile/data/risk/20260831020000/none/20260831020000/surf/flood/{z}/{x}/{y}.png',
    );
    // キキクル以外は空文字（URL を組み立てない）
    expect(t.tileTemplate(MapLayerKind.rainRadar), '');
  });

  test('時刻はUTC表記→JST表示（端末TZに依存しない）', () {
    // 02:40Z = 11:40 JST
    const t = RiskTime('20260831024000', '20260831024000', 'none');
    expect(t.label, '11:40');
    // JST側は「壁時計」＝素の DateTime（絶対時刻ではない）
    expect(t.validAtJst, DateTime(2026, 8, 31, 11, 40));
    expect(t.validAtJst.isUtc, isFalse);
    // 絶対時刻は validAt（UTCフラグ付き）
    expect(t.validAt, DateTime.utc(2026, 8, 31, 2, 40));
    // 日付をまたぐ場合
    expect(jmaTimeLabel('20260831154000'), '00:40');
    expect(jmaTimeToJst('20260831154000'), DateTime(2026, 9, 1, 0, 40));
    expect(jmaTimeToUtc('20260831154000'), DateTime.utc(2026, 8, 31, 15, 40));
    // 雨雲レーダー側と同じ変換であること
    expect(const NowcastTime('20260831024000', '20260831024000').label, t.label);
  });

  test('validAt の差はUTCの実時間差（スライダーの「n分前/後」）', () {
    // 実況 02:40Z と 予測 03:10Z の差は +30分。JST壁時計ではなく絶対時刻で引く
    const obs = NowcastTime('20260831024000', '20260831024000');
    const fc = NowcastTime('20260831024000', '20260831031000');
    expect(fc.validAt.difference(obs.validAt).inMinutes, 30);
    // 壁時計どうしの差でも同じ値になること（DSTの無い端末TZでの回帰確認）
    expect(fc.validAtJst.difference(obs.validAtJst).inMinutes, 30);
  });

  test('凡例は気象庁の危険度配色5段階（低→高）', () {
    for (final k in kinds) {
      final s = RiskLayers.scale(k);
      expect(s.length, 5);
      // 1.4.0: 表示名ではなく l10n キー（解決は riskLevelLabelOf）
      expect([for (final e in s) e.$2],
          ['watch', 'caution', 'warning', 'danger', 'critical']);
      // 注意=黄 / 警戒=赤 / 危険=紫 / 切迫=黒紫（実タイルPLTE・公式凡例SVGと一致）
      expect([for (final e in s.skip(1)) e.$1], const [
        Color(0xFFF2E700),
        Color(0xFFFF2800),
        Color(0xFFAA00AA),
        Color(0xFF0C000C),
      ]);
    }
    // 「今後の情報等に留意」は土砂・浸水が白、洪水だけ水色の線
    expect(RiskLayers.baseColor(MapLayerKind.riskLand), const Color(0xFFFFFFFF));
    expect(RiskLayers.baseColor(MapLayerKind.riskInund), const Color(0xFFFFFFFF));
    expect(RiskLayers.baseColor(MapLayerKind.riskFlood), const Color(0xFF3CFFFF));
  });

  test('キキクルは名称を持ち、ハザードマップ/他レイヤーと排他に区別される', () {
    for (final k in kinds) {
      expect(RiskLayers.isRisk(k), isTrue);
      // 1.4.0: 表示名ではなく l10n キーを返す（解決は riskLayerTitleOf）
      expect(RiskLayers.titleKey(k), isNotEmpty);
      // 出典行は「出典：気象庁」（ハザードマップ扱いにしない）
      expect(HazardLayers.isHazard(k), isFalse);
      expect(HazardLayers.tileIds(k), isEmpty);
    }
    for (final k in [
      MapLayerKind.none,
      MapLayerKind.rainRadar,
      MapLayerKind.quakes,
      MapLayerKind.rain24h,
      MapLayerKind.hazardFlood,
      MapLayerKind.shelters,
    ]) {
      expect(RiskLayers.isRisk(k), isFalse);
      expect(RiskLayers.element(k), '');
      expect(RiskLayers.titleKey(k), '');
    }
  });

  test('気象庁の表示ズーム範囲（risk.properties の 4〜14）', () {
    expect(RiskLayers.minZoom, 4);
    expect(RiskLayers.maxZoom, 14);
    expect(RiskLayers.timesUrl,
        'https://www.jma.go.jp/bosai/jmatile/data/risk/targetTimes.json');
  });
}
