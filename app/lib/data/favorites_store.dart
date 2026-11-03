import 'package:shared_preferences/shared_preferences.dart';

/// お気に入りカメラIDの永続化（shared_preferences）。
///
/// - `favorite_camera_ids`: 登録順（古い順）。「登録が新しい順／古い順」の並べ替えに使う
/// - `favorite_camera_order`: 利用者が並べ替えた表示順（先頭が一番上）。
///   お気に入り画面の既定の並びとホーム画面ウィジェットの順（2026-11-04 ユーザー要望）。
///   新しく登録したカメラは先頭に入る。未保存なら登録が新しい順と同じ
class FavoritesStore {
  static const _key = 'favorite_camera_ids';
  static const _orderKey = 'favorite_camera_order';

  final List<String> _ids = [];
  final List<String> _order = [];
  SharedPreferences? _prefs;

  Set<String> get ids => Set.unmodifiable(_ids.toSet());

  /// 登録が新しい順
  List<String> get newestFirst => _ids.reversed.toList();

  /// 利用者が並べた順（ウィジェットもこの順）
  List<String> get ordered => List.unmodifiable(_order);

  bool contains(String cameraId) => _ids.contains(cameraId);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(_prefs!.getStringList(_key) ?? const []);
    _order
      ..clear()
      ..addAll(reconcileOrder(
          _prefs!.getStringList(_orderKey) ?? const [], newestFirst));
  }

  /// 保存済みの表示順 [saved] を現在の登録 [newest]（新しい順）に合わせる。
  /// 登録から消えたIDを除き、表示順に無い新しいIDを先頭に足す（重複は除く）
  static List<String> reconcileOrder(List<String> saved, List<String> newest) {
    final known = newest.toSet();
    final seen = <String>{};
    final kept = [
      for (final id in saved)
        if (known.contains(id) && seen.add(id)) id,
    ];
    return [
      for (final id in newest)
        if (!seen.contains(id)) id,
      ...kept,
    ];
  }

  Future<bool> toggle(String cameraId) async {
    final added = !_ids.remove(cameraId);
    _order.remove(cameraId);
    if (added) {
      _ids.add(cameraId);
      _order.insert(0, cameraId);
    }
    await _save();
    return added;
  }

  /// 表示順の [oldIndex] 番目を取り出して [newIndex] に挿し直す（ReorderableListView
  /// の onReorderItem と同じ意味: newIndex は取り出した後の並びでの位置）
  Future<void> move(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _order.length) return;
    final to = newIndex.clamp(0, _order.length - 1);
    if (to == oldIndex) return;
    final id = _order.removeAt(oldIndex);
    _order.insert(to, id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs?.setStringList(_key, _ids);
    await _prefs?.setStringList(_orderKey, _order);
  }
}
