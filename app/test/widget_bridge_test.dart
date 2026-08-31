import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/widget_bridge.dart';
import 'package:livecam_jp/models/camera.dart';

Camera cam(String id, FeedType type, String url,
        {bool referer = false, Map<String, String> headers = const {}}) =>
    Camera(
      id: id, name: 'カメラ$id', category: 'river', prefecture: '13',
      feed: Feed(type: type, url: url, requiresReferer: referer, headers: headers),
      operator: '運営', attribution: 'x', sourcePageUrl: 'https://example.jp/page',
      lat: 35.0, lng: 139.0,
    );

void main() {
  group('widgetImageUrlFor', () {
    String? repo(Camera c) => c.feed.type == FeedType.stillImage
        ? c.feed.url
        : (c.feed.type == FeedType.mlitRoadinfo ? 'https://s/status.jpg' : null);

    test('静止画は feed.url', () {
      expect(widgetImageUrlFor(cam('a', FeedType.stillImage, 'http://x/a.jpg'), repo),
          'http://x/a.jpg');
    });
    test('都度解決型は status 側のURL', () {
      expect(widgetImageUrlFor(cam('a', FeedType.mlitRoadinfo, 'u'), repo),
          'https://s/status.jpg');
    });
    test('YouTube動画は hqdefault サムネイル', () {
      expect(widgetImageUrlFor(cam('a', FeedType.youtubeVideo, 'MHp6BWO-z1M'), repo),
          'https://i.ytimg.com/vi/MHp6BWO-z1M/hqdefault.jpg');
    });
    test('誘導型(web_page)のYouTube watch URLもサムネイルにする', () {
      expect(
          widgetImageUrlFor(
              cam('a', FeedType.webPage, 'https://www.youtube.com/watch?v=0AdHcmVg7lg'),
              repo),
          'https://i.ytimg.com/vi/0AdHcmVg7lg/hqdefault.jpg');
      expect(widgetImageUrlFor(cam('a', FeedType.webPage, 'https://example.jp/'), repo),
          isNull);
    });
    test('youtube_channel は画像なし', () {
      expect(widgetImageUrlFor(cam('a', FeedType.youtubeChannel, 'UCxxx'), repo), isNull);
    });
  });

  test('widgetImageHeadersFor: requires_referer なら出典ページを Referer に', () {
    expect(widgetImageHeadersFor(cam('a', FeedType.stillImage, 'u')), isEmpty);
    expect(widgetImageHeadersFor(cam('a', FeedType.stillImage, 'u', referer: true)),
        {'Referer': 'https://example.jp/page'});
    expect(
        widgetImageHeadersFor(cam('a', FeedType.stillImage, 'u',
            referer: true, headers: {'referer': 'https://other/'})),
        {'referer': 'https://other/'},
        reason: '台帳側の明示ヘッダを優先');
  });

  test('buildFavoritesWidgetData: 順序・上限・キー形状', () {
    final favs = [
      for (var i = 0; i < 10; i++) cam('c$i', FeedType.stillImage, 'http://x/$i.jpg'),
    ];
    final data = buildFavoritesWidgetData(
      favorites: favs,
      imageUrlFor: (c) => c.feed.url,
      imageTimeFor: (c) => c.id == 'c1' ? '2026-08-31T12:00:00+09:00' : null,
      now: DateTime.utc(2026, 8, 31, 3, 4, 5),
    );
    expect(data['generated_at'], '2026-08-31T03:04:05.000Z');
    final cams = data['cameras'] as List;
    expect(cams.length, favoritesWidgetMaxCameras);
    final first = cams.first as Map<String, dynamic>;
    expect(first['id'], 'c0');
    expect(first['name'], 'カメラc0');
    expect(first['image_url'], 'http://x/0.jpg');
    expect(first['category'], 'river');
    expect(first['prefecture'], '13');
    expect(first['operator'], '運営');
    expect(first['updated_at'], isNull);
    expect(first['headers'], isEmpty);
    expect((cams[1] as Map)['updated_at'], '2026-08-31T12:00:00+09:00');
    expect((cams.last as Map)['id'], 'c7');
  });

  test('buildFavoritesWidgetData: 空なら cameras が空配列', () {
    final data = buildFavoritesWidgetData(favorites: const [], imageUrlFor: (_) => null);
    expect(data['cameras'], isEmpty);
  });

  test('buildBosaiWidgetSettings: ソート済み配列', () {
    expect(buildBosaiWidgetSettings({'16', '01'}), {'prefs': ['01', '16']});
    expect(buildBosaiWidgetSettings({}), {'prefs': <String>[]});
  });

  group('parseWidgetDeepLink', () {
    test('カメラ詳細', () {
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://camera/abc-123?homeWidget')),
          'camera/abc-123');
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://camera/abc%2F1')), 'camera/abc/1');
    });
    test('災害速報・地図', () {
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://bosai?homeWidget')), 'bosai');
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://bosai/quake')), 'bosai/quake');
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://map?homeWidget')), 'map');
    });
    test('対象外', () {
      expect(parseWidgetDeepLink(null), isNull);
      expect(parseWidgetDeepLink(Uri.parse('https://example.jp/camera/1')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://camera')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('livecamjp://unknown/x')), isNull);
    });
  });

  test('WidgetBridge はテスト環境(非iOS)では何もしない', () {
    expect(WidgetBridge.supported, isFalse);
    WidgetBridge.syncFavorites(const {'cameras': []});
  });
}
