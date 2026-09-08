import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/even_zoom_tile_provider.dart';

/// 気象庁タイルは偶数ズームしか生成されない（zoomUse="even"）。
/// 奇数ズームのタイルは1段下の偶数ズームの親タイルの4分の1から作る
void main() {
  test('偶数ズームはそのまま（親なし）', () {
    for (final z in [4, 6, 8, 10]) {
      expect(EvenZoomTileProvider.parentFor(z, 123, 45), isNull);
    }
  });

  test('奇数ズームは親タイルと4分の1の位置を返す', () {
    // z7 の (113, 51) → z6 の (56, 25) の右下
    final p = EvenZoomTileProvider.parentFor(7, 113, 51)!;
    expect((p.z, p.x, p.y, p.qx, p.qy), (6, 56, 25, 1, 1));
    // z7 の (112, 50) → 同じ親の左上
    final q = EvenZoomTileProvider.parentFor(7, 112, 50)!;
    expect((q.z, q.x, q.y, q.qx, q.qy), (6, 56, 25, 0, 0));
    // z9 の (455, 201) → z8 の (227, 100) の右下
    final r = EvenZoomTileProvider.parentFor(9, 455, 201)!;
    expect((r.z, r.x, r.y, r.qx, r.qy), (8, 227, 100, 1, 1));
  });

  test('親の4分の1は必ず4通りのどれかに落ちる', () {
    final seen = <(int, int)>{};
    for (var x = 0; x < 4; x++) {
      for (var y = 0; y < 4; y++) {
        final p = EvenZoomTileProvider.parentFor(5, x, y)!;
        seen.add((p.qx, p.qy));
        expect(p.x, x ~/ 2);
        expect(p.y, y ~/ 2);
      }
    }
    expect(seen, {(0, 0), (0, 1), (1, 0), (1, 1)});
  });
}
