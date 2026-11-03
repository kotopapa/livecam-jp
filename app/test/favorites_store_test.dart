import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/favorites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('reconcileOrder', () {
    test('保存済みの順を保ち、新しい登録は先頭、消えた登録は除く', () {
      expect(FavoritesStore.reconcileOrder(['b', 'a', 'gone'], ['c', 'b', 'a']),
          ['c', 'b', 'a']);
      expect(FavoritesStore.reconcileOrder(['a', 'b'], ['c', 'b', 'a']), ['c', 'a', 'b']);
      expect(FavoritesStore.reconcileOrder(['a', 'a'], ['a']), ['a'], reason: '重複を除く');
      expect(FavoritesStore.reconcileOrder([], ['b', 'a']), ['b', 'a'],
          reason: '未保存なら登録が新しい順');
    });
  });

  test('toggle: 追加は表示順の先頭、解除は両方から外す。再起動後も順が残る', () async {
    SharedPreferences.setMockInitialValues({});
    final s = FavoritesStore();
    await s.load();
    await s.toggle('a');
    await s.toggle('b');
    await s.toggle('c');
    expect(s.newestFirst, ['c', 'b', 'a']);
    expect(s.ordered, ['c', 'b', 'a']);
    await s.move(2, 0); // a を先頭へ
    expect(s.ordered, ['a', 'c', 'b']);
    expect(s.newestFirst, ['c', 'b', 'a'], reason: '登録順は変わらない');
    await s.toggle('c');
    expect(s.ordered, ['a', 'b']);
    await s.toggle('d');
    expect(s.ordered, ['d', 'a', 'b']);

    final again = FavoritesStore();
    await again.load();
    expect(again.ordered, ['d', 'a', 'b']);
    expect(again.ids, {'a', 'b', 'd'});
  });

  test('move: onReorderItem の意味（取り出した後の位置）。範囲外は無視', () async {
    SharedPreferences.setMockInitialValues({});
    final s = FavoritesStore();
    await s.load();
    for (final id in ['a', 'b', 'c', 'd']) {
      await s.toggle(id);
    }
    expect(s.ordered, ['d', 'c', 'b', 'a']);
    await s.move(0, 2); // d を 2 番目（取り出し後）へ
    expect(s.ordered, ['c', 'b', 'd', 'a']);
    await s.move(3, 0);
    expect(s.ordered, ['a', 'c', 'b', 'd']);
    await s.move(1, 1);
    expect(s.ordered, ['a', 'c', 'b', 'd']);
    await s.move(9, 0);
    expect(s.ordered, ['a', 'c', 'b', 'd']);
    await s.move(0, 99);
    expect(s.ordered, ['c', 'b', 'd', 'a'], reason: '末尾に丸める');
  });
}
