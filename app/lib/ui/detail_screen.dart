import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../app_state.dart';
import '../config.dart';
import '../models/camera.dart';
import '../models/status.dart';
import '../util/geo.dart';
import '../util/time_format.dart';
// AdMob導入時に ad_banner.dart のインポートを戻す（下の広告位置コメント参照）
// import 'ad_banner.dart';
import 'pin_style.dart';

/// 免責文言（SPEC 9.5。削ってはいけない）
const disclaimerText =
    'カメラ映像は限られた範囲の状況を示すものです。カメラの性能上、光環境や気象条件により'
    '不鮮明になる場合があります。避難の判断は、水位情報・気象警報・自治体の避難情報に'
    '従ってください。本アプリは参考情報を提供するものです。';

/// カメラ詳細画面（SPEC 9.2③・デザイン画面6/7）。
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.camera, required this.app});

  final Camera camera;
  final AppState app;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  DateTime? _lastManualRefresh;
  int _refreshTick = 0; // 画像再取得用のキー
  Timer? _cooldownTimer;
  // 静止画をアプリが読み込んだ時刻。画像は表示のたびに配信元から直接取得される
  DateTime _imageLoadedAt = DateTime.now();

  Camera get camera => widget.camera;
  AppState get app => widget.app;

  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();
    // 誤タップの一瞬の表示をカウントしないよう、5秒以上見た場合のみ記録する
    _viewTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) app.recordView(camera);
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _viewTimer?.cancel();
    super.dispose();
  }

  /// 手動更新の残りクールダウン秒（SPEC 9.4: 最短60秒を強制・変更不可）
  int get _cooldownLeft {
    if (_lastManualRefresh == null) return 0;
    final elapsed = DateTime.now().difference(_lastManualRefresh!);
    final left = minRefetchInterval - elapsed;
    return left.isNegative ? 0 : left.inSeconds + 1;
  }

  void _manualRefresh() {
    if (_cooldownLeft > 0) return;
    // 同一URLはFlutterのメモリ内画像キャッシュに残るため、明示的に追い出して
    // 再取得させる（キーの付け替えだけではネットワークへ行かない）
    final url = app.imageUrlFor(camera);
    if (url != null) NetworkImage(url).evict();
    // status.json も鮮度切れ(5分)なら再取得し、取得時刻表示を最新化する
    app.refresh();
    setState(() {
      _lastManualRefresh = DateTime.now();
      _imageLoadedAt = DateTime.now();
      _refreshTick++;
    });
    // クールダウン表示の更新
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownLeft == 0) t.cancel();
      if (mounted) setState(() {});
    });
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final st = app.repository.status[camera.id];
    final pageUrl = camera.sourcePageUrl ?? camera.fallbackUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(camera.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(app.isFavorite(camera) ? Icons.star : Icons.star_border),
            onPressed: () => app
                .toggleFavorite(camera)
                .then((_) => mounted ? setState(() {}) : null),
          ),
          if (pageUrl != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              // 共有は画像ではなく元ページのURL（SPEC 9.2③。画像の再配布はしない）
              onPressed: () => SharePlus.instance.share(
                  ShareParams(text: '${camera.name}\n$pageUrl')),
            ),
        ],
      ),
      body: ListView(children: [
        _MediaView(camera: camera, app: app, refreshTick: _refreshTick),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _timeAndRefreshRow(st),
            const SizedBox(height: 8),
            _badges(st),
            const Divider(height: 24),
            _sourceSection(pageUrl),
            const Divider(height: 24),
            // AdMob導入時はこの位置にバナー広告を置く（出典セクションと近隣カメラの間）。
            // AdBannerPlaceholder の build をAdMobバナーに差し替えて以下2行を戻す。
            // const AdBannerPlaceholder(),
            // const Divider(height: 24),
            _nearbySection(),
            const Divider(height: 24),
            Text(disclaimerText,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 16),
          ]),
        ),
      ]),
    );
  }

  /// 取得時刻を大きく表示 + 手動更新（60秒クールダウン）。
  /// 更新ボタンは静止画の再取得用のため、常時流れ続けるYouTube系では出さない
  Widget _timeAndRefreshRow(CameraStatus? st) {
    // 静止画はアプリがいま配信元から直接取得した画像なので、アプリの読込時刻を出す。
    // 都度解決型(roadinfo)はURL自体に撮影時刻が入っており status の image_time が正
    final time = camera.feed.type == FeedType.stillImage
        ? _imageLoadedAt.toIso8601String()
        : (st?.imageTime ?? st?.lastOkAt);
    final left = _cooldownLeft;
    if (camera.isVideo) {
      return const Row(children: [
        Icon(Icons.sensors, size: 18, color: Color(0xFFE53935)),
        SizedBox(width: 6),
        Text('ライブ配信中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]);
    }
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(time != null ? formatTakenTime(time) : '取得時刻不明',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${camera.feed.refreshSec ?? 600}秒ごとに更新',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      ),
      FilledButton.icon(
        onPressed: left > 0 ? null : _manualRefresh,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(left > 0 ? '$left秒' : '更新'),
      ),
    ]);
  }

  Widget _badges(CameraStatus? st) {
    final chips = <Widget>[];
    if (camera.coordAccuracy == CoordAccuracy.area) {
      chips.add(const _InfoChip(
          text: '位置は広域の代表点', color: uncertainBorderColor));
    } else if (camera.coordAccuracy.isUncertain) {
      chips.add(const _InfoChip(text: '位置はおおよそ', color: uncertainBorderColor));
    }
    if (st?.state == CameraState.frozen) {
      chips.add(const _InfoChip(text: '画像が更新されていません', color: Colors.grey));
    }
    if (camera.riverOrRoute != null) {
      chips.add(_InfoChip(
          text: camera.riverOrRoute!, color: categoryColor(camera.category)));
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _sourceSection(String? pageUrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出典', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(camera.attribution.isNotEmpty ? camera.attribution : camera.operator),
      if (pageUrl != null)
        TextButton(
          onPressed: () => _open(pageUrl),
          child: const Text('出典サイトを見る'),
        ),
      if (camera.feed.type == FeedType.youtubeChannel) ...[
        TextButton(
          onPressed: () =>
              _open('https://www.youtube.com/channel/${camera.feed.url}/live'),
          child: const Text('YouTubeで見る'),
        ),
        TextButton(
          onPressed: () =>
              _open('https://www.youtube.com/channel/${camera.feed.url}'),
          child: const Text('チャンネルページを見る'),
        ),
      ],
      if (camera.feed.type == FeedType.youtubeVideo)
        TextButton(
          onPressed: () =>
              _open('https://www.youtube.com/watch?v=${camera.feed.url}'),
          child: const Text('YouTubeで見る'),
        ),
      TextButton.icon(
        onPressed: _openReportForm,
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: const Text('このカメラの不具合を報告'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
      ),
    ]);
  }

  /// 不具合報告: 依頼フォームをカメラ名・URL入りで開く（ログイン不要）
  void _openReportForm() {
    const base = 'https://docs.google.com/forms/d/e/'
        '1FAIpQLScRz0Enqfrq-lrbuDVBdFD1jwSyl4GJEZtgTJxAoZfYo-QWJw/viewform';
    final ref = camera.sourcePageUrl ?? camera.fallbackUrl ?? '';
    final uri = Uri.parse(base).replace(queryParameters: {
      'usp': 'pp_url',
      'entry.803872053': '不具合の報告',
      'entry.285662317': '${camera.name}（ID: ${camera.id}）',
      'entry.1884263750': ref,
      'entry.799104956': '【不具合報告】症状: ',
    });
    _open(uri.toString());
  }

  Widget _nearbySection() {
    final nearby = nearbyCameras(camera, app.displayableCameras);
    if (nearby.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('周辺のカメラ', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: nearby.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (c, dist) = nearby[i];
            return GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => DetailScreen(camera: c, app: app))),
              child: SizedBox(
                width: 120,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.videocam,
                              color: categoryColor(c.category)),
                        ),
                      ),
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      Text('約${(dist / 1000).toStringAsFixed(1)}km',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600])),
                    ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// feed.type による表示分岐（SPEC 9.2③）。
class _MediaView extends StatelessWidget {
  const _MediaView(
      {required this.camera, required this.app, required this.refreshTick});

  final Camera camera;
  final AppState app;
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    switch (camera.feed.type) {
      case FeedType.stillImage:
      case FeedType.mlitRoadinfo:
      case FeedType.jmaVolcam:
      case FeedType.thrCamxml:
      case FeedType.camidxLatest:
      case FeedType.saitamaFlood:
      case FeedType.kochiSuibo:
        final url = app.imageUrlFor(camera);
        if (url == null) {
          return _MediaFallback(
              text: app.imagesBlockedByWifiSetting
                  ? '設定により、画像の取得はWi-Fi接続時のみです'
                  : '現在映像を取得できません');
        }
        // refreshTick をキーに含めて手動更新時に再取得する
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            url,
            key: ValueKey('$url#$refreshTick'),
            fit: BoxFit.contain,
            headers: camera.feed.requiresReferer &&
                    camera.sourcePageUrl != null
                ? {'Referer': camera.sourcePageUrl!}
                : null,
            errorBuilder: (_, _, _) =>
                const _MediaFallback(text: '現在映像を取得できません'),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
          ),
        );
      case FeedType.mieDouro:
        // 三重県道路規制情報: 画像はAPI応答内のbase64のみ（直URLなし）
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: _MieDouroView(
            apiUrl: camera.feed.url,
            cameraRef: camera.feed.cameraRef ?? '',
            refreshTick: refreshTick,
          ),
        );
      case FeedType.youtubeChannel:
        // IFrame Player（embed/live_stream）をWebViewで表示（SPEC C6遵守）
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: _YoutubeEmbedView(
              embedPath: 'live_stream?channel=${camera.feed.url}'),
        );
      case FeedType.youtubeVideo:
        // 動画ID固定のIFrame埋め込み（1チャンネル多配信のライブ用）
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: _YoutubeEmbedView(embedPath: camera.feed.url),
        );
      default:
        // iHighway(NEXCO)は個別ページが無いため、公式地図をアプリ内で開き
        // 該当カメラ位置へ自動ズームする（画像の転載はしない）
        final feedUri = Uri.tryParse(camera.feed.url);
        if (feedUri != null &&
            feedUri.host == 'ihighway.jp' &&
            feedUri.queryParameters.containsKey('x') &&
            feedUri.queryParameters.containsKey('y')) {
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: _IHighwayMapView(
              url: camera.feed.url,
              x: feedUri.queryParameters['x']!,
              y: feedUri.queryParameters['y']!,
              camId: feedUri.queryParameters['cam'] ?? '',
            ),
          );
        }
        // YouTube誘導型（埋め込み不可のライブ）は文言とボタンをYouTube向けにする
        final url = camera.fallbackUrl ?? camera.sourcePageUrl;
        final isYoutube = url != null && url.contains('youtube.com');
        return _MediaFallback(
          text: isYoutube
              ? '提供者の設定により、この映像は\nアプリ内で再生できません'
              : 'アプリ内再生非対応のカメラです',
          action: url,
          actionLabel: isYoutube ? 'YouTubeで見る' : '元ページで見る',
          icon: isYoutube ? Icons.play_circle_outline : Icons.videocam_off,
        );
    }
  }
}

class _YoutubeEmbedView extends StatefulWidget {
  const _YoutubeEmbedView({required this.embedPath});

  /// youtube.com/embed/ 以降のパス（動画ID or live_stream?channel=...）
  final String embedPath;

  @override
  State<_YoutubeEmbedView> createState() => _YoutubeEmbedViewState();
}

class _YoutubeEmbedViewState extends State<_YoutubeEmbedView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // embed URLを直接開くとYouTubeが「設定エラー」を返すため、
    // iframeを含むHTMLをbaseUrl付きで読み込む（IFrame Player APIの正規の使い方）
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    final sep = widget.embedPath.contains('?') ? '&' : '?';
    // controls=0: 再生バー・設定・全画面等を非表示（映像を遮らない）。
    // 音声はプレーヤー上で解除できなくなるため「YouTubeで見る」導線で補う
    final src = 'https://www.youtube.com/embed/${widget.embedPath}'
        '${sep}playsinline=1&autoplay=1&mute=1&rel=0'
        '&controls=0&fs=0&iv_load_policy=3&disablekb=1';
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString('''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
iframe{width:100%;height:100%;border:0}</style></head>
<body><iframe src="$src"
 allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
</body></html>
''', baseUrl: 'https://livecam-jp.local');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

/// iHighway(NEXCO)の交通情報地図をアプリ内で開き、該当カメラの
/// デフォルメ地図座標(x,y)へ自動センタリング+最大ズームする。
/// ページ内容は改変せず、地図操作(ユーザー操作相当)のみを自動化する。
class _IHighwayMapView extends StatefulWidget {
  const _IHighwayMapView(
      {required this.url,
      required this.x,
      required this.y,
      required this.camId});

  final String url;
  final String x;
  final String y;
  final String camId;

  @override
  State<_IHighwayMapView> createState() => _IHighwayMapViewState();
}

class _IHighwayMapViewState extends State<_IHighwayMapView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final js = '''
(function(){
  var tries = 0;
  function go(){
    tries++;
    try {
      if (window.MP_OL && MP_OL.ol) {
        var v = MP_OL.ol.getView();
        v.setCenter([${widget.x}, ${widget.y}]);
        v.setZoom(4);
        // カメラ映像モーダルを直接開く(サイト内のクリック処理と同一のAPI)
        setTimeout(function(){
          try {
            CM_POPUP.CAMERA.showPopup(
                '#mp_pop_area', '#mp_pop_camhlayer', 1, '${widget.camId}');
          } catch(e) {}
        }, 800);
        return;
      }
    } catch(e) {}
    if (tries < 40) setTimeout(go, 500);
  }
  go();
})();
''';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _controller.runJavaScript(js),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _controller);
}

/// 三重県道路規制情報のカメラ表示。
/// 画像は camera_get_api.php の応答内にbase64でのみ含まれる（直URLなし）ため、
/// アプリが提供元APIを直接取得してデコード表示する（自前中継はしない）。
class _MieDouroView extends StatefulWidget {
  const _MieDouroView(
      {required this.apiUrl,
      required this.cameraRef,
      required this.refreshTick});

  final String apiUrl;
  final String cameraRef;
  final int refreshTick;

  @override
  State<_MieDouroView> createState() => _MieDouroViewState();
}

class _MieDouroViewState extends State<_MieDouroView> {
  Uint8List? _bytes;
  bool _error = false;
  int _loadedTick = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MieDouroView old) {
    super.didUpdateWidget(old);
    if (old.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    if (_loadedTick == widget.refreshTick) return;
    _loadedTick = widget.refreshTick;
    setState(() => _error = false);
    try {
      final resp = await http
          .get(Uri.parse(widget.apiUrl))
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final ent = data[widget.cameraRef] as Map<String, dynamic>?;
      final pic = ent?['picture'] as String? ?? '';
      final i = pic.indexOf('base64,');
      if (i < 0) throw const FormatException('no image');
      final bytes = base64Decode(pic.substring(i + 7));
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = _bytes == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const _MediaFallback(text: '現在映像を取得できません');
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true);
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({
    required this.text,
    this.action,
    this.actionLabel = '元ページで見る',
    this.icon = Icons.videocam_off,
  });

  final String text;
  final String? action;
  final String actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: Colors.grey[200],
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          if (action != null)
            FilledButton.tonal(
              onPressed: () => launchUrl(Uri.parse(action!),
                  mode: LaunchMode.externalApplication),
              child: Text(actionLabel),
            ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
