import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/ui/detail_screen.dart';

void main() {
  YoutubeEmbedNavigation nav(String url, {bool main = true}) =>
      youtubeEmbedNavigation(url, isMainFrame: main);

  test('最初の自前HTMLと枠内のプレーヤー読み込みは通す', () {
    expect(nav('https://livecam-jp.local'), YoutubeEmbedNavigation.allow);
    expect(nav('about:blank'), YoutubeEmbedNavigation.allow);
    expect(nav('https://www.youtube.com/embed/abc?autoplay=1', main: false),
        YoutubeEmbedNavigation.allow);
    expect(nav('https://www.google.com/recaptcha/api2/anchor', main: false),
        YoutubeEmbedNavigation.allow);
  });

  test('Google のサインインは枠内でも最上位でも止める（Play 審査の却下原因）', () {
    const u = 'https://accounts.google.com/ServiceLogin?service=youtube';
    expect(nav(u), YoutubeEmbedNavigation.prevent);
    expect(nav(u, main: false), YoutubeEmbedNavigation.prevent);
  });

  test('最上位フレームが YouTube へ移ろうとしたら外部で開く', () {
    expect(nav('https://www.youtube.com/watch?v=abc'),
        YoutubeEmbedNavigation.openExternal);
    expect(nav('https://youtu.be/abc'), YoutubeEmbedNavigation.openExternal);
    expect(nav('https://m.youtube.com/channel/UC1'),
        YoutubeEmbedNavigation.openExternal);
  });

  test('それ以外の最上位の遷移は止める', () {
    expect(nav('https://example.com/'), YoutubeEmbedNavigation.prevent);
    expect(nav('https://evil-youtube.com/'), YoutubeEmbedNavigation.prevent);
    expect(nav('javascript:alert(1)'), YoutubeEmbedNavigation.prevent);
    expect(nav('::not a url::'), YoutubeEmbedNavigation.prevent);
  });
}
