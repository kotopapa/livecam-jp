import 'package:shared_preferences/shared_preferences.dart';

/// お気に入りカメラIDの永続化（shared_preferences）。
class FavoritesStore {
  static const _key = 'favorite_camera_ids';

  // 登録順（古い順）を保持する。ランキングの「お気に入り登録順」に使う
  final List<String> _ids = [];
  SharedPreferences? _prefs;

  Set<String> get ids => Set.unmodifiable(_ids.toSet());

  /// 登録が新しい順
  List<String> get newestFirst => _ids.reversed.toList();
  bool contains(String cameraId) => _ids.contains(cameraId);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(_prefs!.getStringList(_key) ?? const []);
  }

  Future<bool> toggle(String cameraId) async {
    final added = !_ids.remove(cameraId);
    if (added) _ids.add(cameraId);
    await _prefs?.setStringList(_key, _ids);
    return added;
  }
}
