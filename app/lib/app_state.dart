import 'package:flutter/foundation.dart';

import 'data/camera_repository.dart';
import 'data/favorites_store.dart';
import 'models/camera.dart';
import 'models/status.dart';

/// アプリ全体で共有するデータ状態（ChangeNotifier 構成）。
class AppState extends ChangeNotifier {
  AppState(this.repository, {FavoritesStore? favorites})
      : favorites = favorites ?? FavoritesStore();

  final CameraRepository repository;
  final FavoritesStore favorites;

  bool isFavorite(Camera c) => favorites.contains(c.id);

  Future<void> toggleFavorite(Camera c) async {
    await favorites.toggle(c.id);
    notifyListeners();
  }

  bool initialized = false;
  bool refreshing = false;
  String? notice;

  List<Camera> get displayableCameras => repository.displayableCameras();

  CameraState stateOf(Camera c) =>
      repository.status[c.id]?.state ?? CameraState.unknown;

  String? imageUrlFor(Camera c) => repository.imageUrlFor(c);

  String? imageTimeFor(Camera c) {
    final st = repository.status[c.id];
    return st?.imageTime ?? st?.lastOkAt;
  }

  /// 起動時: キャッシュ即時復元 → バックグラウンドで更新（SPEC 8.2）
  Future<void> init() async {
    await repository.loadCached();
    await favorites.load();
    initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      await repository.refresh();
      notice = repository.manifest?.notice;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}
