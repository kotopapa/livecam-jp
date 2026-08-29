import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdSize;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
import '../util/prefectures.dart';
import '../util/time_format.dart';
import 'ad_banner.dart';
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
      body: _buildBody(
        media: _MediaView(camera: camera, app: app, refreshTick: _refreshTick),
        details:
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // バナー広告（映像の直下。スクロールなしで見える位置。
            // 読み込み失敗時は区切り線ごと自動で消える）
            AdBannerPlaceholder(),
            _timeAndRefreshRow(st),
            const SizedBox(height: 8),
            _badges(st),
            const Divider(height: 24),
            _locationSection(),
            const Divider(height: 24),
            // 地図の下にレクタングル広告(300×250)。上部バナーがスクロールで
            // 見えなくなる位置まで来た利用者向け。失敗時は区切り線ごと消える
            AdBannerPlaceholder(size: AdSize.mediumRectangle, adUnitId: admobRectangleUnitId),
            _sourceSection(pageUrl),
            const Divider(height: 24),
            _nearbySection(),
            const Divider(height: 24),
            Text(disclaimerText,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 16),
          ]),
        )
      ),
    );
  }

  /// YouTube系は動画を画面上部に固定し、その下だけをスクロールさせる。
  /// ListView内に置くと画面外へスクロールした時点でiOSのWebViewが画面階層から
  /// 外れて再生が止まる（KeepAliveでは防げない）ため。静止画は従来どおり全体スクロール
  Widget _buildBody({required Widget media, required Widget details}) {
    final t = camera.feed.type;
    final pinned = t == FeedType.youtubeVideo || t == FeedType.youtubeChannel || t == FeedType.hls;
    if (!pinned) return ListView(children: [media, details]);
    return Column(children: [
      media,
      Expanded(child: ListView(children: [details])),
    ]);
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

  /// カテゴリと設置位置（ミニマップ）。ミニマップをタップすると地図タブへ移動する
  Widget _locationSection() {
    final cat = camera.category;
    final label = categoryLabels[cat] ?? cat;
    final pref = prefectureNames[camera.prefecture] ?? '';
    final chips = Wrap(spacing: 6, runSpacing: 4, children: [
      Chip(
        avatar: CircleAvatar(backgroundColor: categoryColor(cat), radius: 6),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      ),
      if (pref.isNotEmpty)
        Chip(label: Text(pref), visualDensity: VisualDensity.compact),
      if (camera.isWorld)
        const Chip(label: Text('海外'), visualDensity: VisualDensity.compact),
    ]);
    if (!camera.hasLocation) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('カテゴリ・位置', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        chips,
      ]);
    }
    final pos = LatLng(camera.lat!, camera.lng!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('カテゴリ・位置', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      chips,
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 170,
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: pos,
                initialZoom: 13,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: camera.isWorld
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                  userAgentPackageName: 'jp.livecam.livecam_jp',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: pos,
                    width: 26,
                    height: 26,
                    child: CameraPin(
                        camera: camera,
                        state: app.stateOf(camera),
                        favorite: app.isFavorite(camera)),
                  ),
                ]),
              ],
            ),
            Positioned(
              left: 4,
              bottom: 2,
              child: Text(
                camera.isWorld ? '© OpenStreetMap contributors' : '地理院タイル',
                style: const TextStyle(fontSize: 9, color: Colors.black87),
              ),
            ),
            // タップで地図タブへ（この位置を中心に表示）
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    app.navigationRequest.value = null;
                    app.navigationRequest.value =
                        'map/${pos.latitude},${pos.longitude}';
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('地図で見る', style: TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        ),
      ),
    ]);
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
      case FeedType.sizenken:
      case FeedType.shimantoKasen:
      case FeedType.takashimaRiver:
      case FeedType.higashiomiRiver:
      case FeedType.yamaguchiRomen:
      case FeedType.yamaguchiKasen:
      case FeedType.shimaneSuibo:
      case FeedType.fukuokaKasen:
        final url = app.imageUrlFor(camera);
        if (url == null) {
          return _MediaFallback(
              text: app.imagesBlockedByWifiSetting
                  ? '設定により、画像の取得はWi-Fi接続時のみです'
                  : '現在映像を取得できません');
        }
        // refreshTick をキーに含めて手動更新時に再取得する
        final headers = camera.feed.requiresReferer &&
                camera.sourcePageUrl != null
            ? {'Referer': camera.sourcePageUrl!}
            : null;
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: _ZoomableImage(
            title: camera.name,
            builder: (fullscreen) => Image.network(
              url,
              key: ValueKey('$url#$refreshTick#$fullscreen'),
              fit: BoxFit.contain,
              headers: headers,
              errorBuilder: (_, _, _) =>
                  const _MediaFallback(text: '現在映像を取得できません'),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
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
            aspectRatio: 16 / 9,
            child: Material(
              color: const Color(0xFF12306B),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _IHighwayBrowserScreen(
                          title: camera.name,
                          url: camera.feed.url,
                          x: feedUri.queryParameters['x']!,
                          y: feedUri.queryParameters['y']!,
                          camId: feedUri.queryParameters['cam'] ?? '',
                        ))),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new, color: Colors.white, size: 36),
                    SizedBox(height: 10),
                    Text('NEXCO公式「iHighway」で\nライブカメラを表示',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('タップするとアプリ内ブラウザで公式サイトを開き、\nこのカメラの位置まで自動で移動します',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          );
        }
        // YouTube誘導型（埋め込み不可のライブ）は文言とボタンをYouTube向けにする
        final url = camera.fallbackUrl ?? camera.sourcePageUrl;
        final isYoutube = url != null && url.contains('youtube.com');
        return _MediaFallback(
          text: isYoutube
              ? '提供者の設定により、この映像は\nアプリ内で再生できません'
              // 運営者の利用条件（転載・直リンク不可）で誘導型にしているものが大半。
              // 「非対応」だと不具合に見えるため理由を示す
              : '配信元の利用条件により\nアプリ内では表示できません',
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

class _YoutubeEmbedViewState extends State<_YoutubeEmbedView>
    with AutomaticKeepAliveClientMixin {
  // ListView内で画面外へスクロールしてもWebView(再生中の動画)を破棄しない
  @override
  bool get wantKeepAlive => true;

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
  Widget build(BuildContext context) {
    super.build(context);
    return WebViewWidget(controller: _controller);
  }
}

/// iHighway(NEXCO)の交通情報地図をアプリ内で開き、該当カメラの
/// デフォルメ地図座標(x,y)へ自動センタリング+最大ズームする。
/// ページ内容は改変せず、地図操作(ユーザー操作相当)のみを自動化する。
/// 埋め込みではなく「アプリ内ブラウザで公式サイトを開く」体裁の全画面表示
class _IHighwayBrowserScreen extends StatefulWidget {
  const _IHighwayBrowserScreen(
      {required this.title,
      required this.url,
      required this.x,
      required this.y,
      required this.camId});

  final String title;
  final String url;
  final String x;
  final String y;
  final String camId;

  @override
  State<_IHighwayBrowserScreen> createState() => _IHighwayBrowserScreenState();
}

class _IHighwayBrowserScreenState extends State<_IHighwayBrowserScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final js = '''
(function(){
  var tries = 0;
  function ready(){
    try {
      return window.MP_OL && MP_OL.ol
        && window.CM_POPUP && CM_POPUP.CAMERA
        && window.CM_COMMON && CM_COMMON.config
        && CM_COMMON.config.JSON && CM_COMMON.config.JSON.CAMERA_POINT
        && Object.keys(CM_COMMON.config.JSON.CAMERA_POINT).length > 0
        && document.querySelector('#mp_pop_camhlayer')
        && document.querySelector('#mp_pop_area');
    } catch(e){ return false; }
  }
  function opened(){
    var m = document.querySelector('#mp_pop_area');
    return m && !m.classList.contains('cm_display_none');
  }
  function go(){
    tries++;
    if (ready()) {
      try {
        var v = MP_OL.ol.getView();
        v.setCenter([${widget.x}, ${widget.y}]);
        v.setZoom(4);
        if (!opened()) {
          CM_POPUP.CAMERA.showPopup(
              '#mp_pop_area', '#mp_pop_camhlayer', 1, '${widget.camId}');
        }
        if (opened()) return;
      } catch(e) {}
    }
    if (tries < 60) setTimeout(go, 500);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis),
            const Text('ihighway.jp（NEXCO公式）',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Safariで開く',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
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
    final bytes = _bytes!;
    return _ZoomableImage(
      title: '',
      builder: (_) =>
          Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
    );
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


/// 静止画のピンチズーム。埋め込み表示ではピンチのみ（縦スクロールを妨げない
/// よう移動は無効）、タップで全画面ビューア（ピンチ＋ドラッグ移動）を開く
class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.builder, required this.title});

  /// fullscreen=true のとき全画面用に同じ画像を組み立てる
  final Widget Function(bool fullscreen) builder;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImage(title: title, child: builder(true)),
      )),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        panEnabled: false,
        clipBehavior: Clip.hardEdge,
        child: builder(false),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.child, required this.title});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: child,
        ),
      ),
    );
  }
}
