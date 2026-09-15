import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_layers.dart';

void main() {
  test('targetTimes から最新の実況（basetime==validtime かつ snowd あり）を選ぶ', () {
    final t = JmaLayers.latestSnowTime([
      {'basetime': '20260915140000', 'validtime': '20260915200000', 'elements': ['snowd']},
      {'basetime': '20260915130000', 'validtime': '20260915130000', 'elements': ['snowd', 'snowf24h']},
      {'basetime': '20260915140000', 'validtime': '20260915140000', 'elements': ['snowd', 'snowf24h']},
      {'basetime': '20260915150000', 'validtime': '20260915150000', 'elements': ['snowf01h']},
    ])!;
    expect(t.basetime, '20260915140000');
    expect(t.validtime, '20260915140000');
    expect(t.validAt, DateTime.utc(2026, 9, 15, 14));
    expect(t.label, '23:00'); // JST
    expect(JmaLayers.latestSnowTime([]), isNull);
    expect(JmaLayers.latestSnowTime('x'), isNull);
  });

  test('タイルURLは要素ごと（偶数ズームのみ生成。EvenZoomTileProvider で表示）', () {
    const t = SnowTime('20260915140000', '20260915140000');
    expect(t.tileTemplate(MapLayerKind.snowDepth),
        'https://www.jma.go.jp/bosai/jmatile/data/snow/20260915140000/none/20260915140000/surf/snowd/{z}/{x}/{y}.png');
    expect(t.tileTemplate(MapLayerKind.snowfall24h), contains('/surf/snowf24h/'));
    expect(t.tileTemplate(MapLayerKind.rainRadar), '');
    expect(SnowLayers.isSnow(MapLayerKind.snowDepth), isTrue);
    expect(SnowLayers.isSnow(MapLayerKind.typhoon), isFalse);
    expect(SnowLayers.depthScale.length, 7);
    expect(SnowLayers.snowfall24hScale.length, 8);
  });
}
