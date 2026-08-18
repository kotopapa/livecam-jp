import 'package:flutter_test/flutter_test.dart';

import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/util/clustering.dart';

Camera cam(String id, double lat, double lng) => Camera(
      id: id,
      name: id,
      category: 'river',
      prefecture: '13',
      feed: const Feed(type: FeedType.stillImage, url: 'https://example.jp/x.jpg'),
      operator: 'x',
      attribution: 'x',
      lat: lat,
      lng: lng,
      coordAccuracy: CoordAccuracy.exact,
    );

void main() {
  test('低ズームでは近接カメラがクラスタにまとまり件数が保存される', () {
    final cams = [
      cam('a', 35.60, 139.60),
      cam('b', 35.61, 139.61),
      cam('c', 35.605, 139.605),
      cam('d', 43.0, 141.35), // 札幌（別クラスタ or 単独）
    ];
    final items = clusterCameras(cams, 5);
    final total = items.fold<int>(0, (sum, i) => sum + i.count);
    expect(total, 4, reason: 'クラスタリングで台数が失われない');
    expect(items.any((i) => i.isCluster && i.count == 3), isTrue,
        reason: '東京の3台は1クラスタになる');
  });

  test('高ズームでは全て個別ピンになる', () {
    final cams = [cam('a', 35.60, 139.60), cam('b', 35.6001, 139.6001)];
    final items = clusterCameras(cams, 14);
    expect(items.length, 2);
    expect(items.every((i) => !i.isCluster), isTrue);
  });

  test('座標のないカメラは対象外', () {
    final noLoc = Camera(
      id: 'x', name: 'x', category: 'road', prefecture: '11',
      feed: const Feed(type: FeedType.stillImage, url: 'u'),
      operator: 'x', attribution: 'x',
    );
    expect(clusterCameras([noLoc], 5), isEmpty);
  });

  test('クラスタ中心は所属カメラの重心になる', () {
    final items = clusterCameras([cam('a', 35.0, 139.0), cam('b', 35.01, 139.01)], 6);
    final c = items.single;
    expect(c.latitude, closeTo(35.005, 1e-9));
    expect(c.longitude, closeTo(139.005, 1e-9));
  });
}
