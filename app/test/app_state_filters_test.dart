// 地図画面の絞り込み系ロジック（AppState.activeFilterCount / clearFilters）のテスト。
// 地図UI再設計（コミット 5fcf7d6 の残り5項目）の1・4項目に対応
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';

AppState _buildApp() => AppState(CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ));

void main() {
  group('AppState.activeFilterCount', () {
    test('絞り込みが無ければ0', () {
      final app = _buildApp();
      expect(app.activeFilterCount, 0);
      expect(app.hasActiveFilters, isFalse);
    });

    test('検索語・動画のみ・海外非表示・位置不確か非表示・お気に入りのみ・正常のみを'
        'それぞれ1として数える', () {
      final app = _buildApp();
      app.setSearchQuery('雷門');
      expect(app.activeFilterCount, 1);

      app.setVideoOnly(true);
      expect(app.activeFilterCount, 2);

      app.setShowWorld(false);
      expect(app.activeFilterCount, 3);

      app.setHideUncertain(true);
      expect(app.activeFilterCount, 4);

      app.setFavoritesOnly(true);
      expect(app.activeFilterCount, 5);

      app.setOkOnly(true);
      expect(app.activeFilterCount, 6);
    });

    test('カテゴリを1つでも外すと1として数える（外した数に比例しない）', () {
      final app = _buildApp();
      app.toggleCategory('river');
      expect(app.activeFilterCount, 1);
      app.toggleCategory('road');
      expect(app.activeFilterCount, 1, reason: '複数外しても件数は1のまま');
    });
  });

  group('AppState.clearFilters', () {
    test('全ての絞り込みを解除し、カテゴリを9種すべて有効に戻す', () {
      final app = _buildApp();
      app.setSearchQuery('渋谷');
      app.setVideoOnly(true);
      app.setShowWorld(false);
      app.setHideUncertain(true);
      app.setFavoritesOnly(true);
      app.setOkOnly(true);
      app.toggleCategory('river');
      app.toggleCategory('road');
      expect(app.hasActiveFilters, isTrue);

      var notified = 0;
      app.addListener(() => notified++);
      app.clearFilters();

      expect(notified, greaterThanOrEqualTo(1));
      expect(app.searchQuery, isEmpty);
      expect(app.videoOnly, isFalse);
      expect(app.showWorld, isTrue);
      expect(app.hideUncertain, isFalse);
      expect(app.favoritesOnly, isFalse);
      expect(app.okOnly, isFalse);
      expect(app.enabledCategories.length, 9);
      expect(app.hasActiveFilters, isFalse);
      expect(app.activeFilterCount, 0);
    });
  });
}
