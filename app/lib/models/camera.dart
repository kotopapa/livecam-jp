/// カメラ台帳のレコード（SPEC 5.1）。
///
/// 将来のスキーマ拡張（後方互換）で落ちないよう、未知の値は寛容に扱う。
enum FeedType {
  stillImage('still_image'),
  youtubeChannel('youtube_channel'),
  youtubeVideo('youtube_video'),
  hls('hls'),
  webPage('web_page'),

  /// 道路情報提供システム（都度解決型）。静止画URLは status.json の image_url を使う
  mlitRoadinfo('mlit_roadinfo'),

  /// 気象庁 火山監視カメラ（都度解決型）。静止画URLは status.json の image_url を使う
  jmaVolcam('jma_volcam'),

  /// 東北地整カメラXML（都度解決型）。静止画URLは status.json の image_url を使う
  thrCamxml('thr_camxml'),

  /// idxファイル参照型（横浜市水防災など・都度解決型）
  camidxLatest('camidx_latest'),

  /// さいたま市水位情報システム（都度解決型）
  saitamaFlood('saitama_flood'),
  kochiSuibo('kochi_suibo'),
  sizenken('sizenken'),
  shimantoKasen('shimanto_kasen'),
  mieDouro('mie_douro'),

  /// 未知のtype。地図に出すが再生は fallback ページへ誘導する
  unknown('unknown');

  const FeedType(this.wire);
  final String wire;

  static FeedType parse(String? v) =>
      FeedType.values.firstWhere((t) => t.wire == v, orElse: () => FeedType.unknown);
}

enum CoordAccuracy {
  exact('exact'),
  approx('approx'),
  townLevel('town_level'),

  /// 河川・路線単位の広域代表点（位置未確定として表示する。SPEC 9.2）
  area('area'),
  none('none');

  const CoordAccuracy(this.wire);
  final String wire;

  static CoordAccuracy parse(String? v) => CoordAccuracy.values
      .firstWhere((a) => a.wire == v, orElse: () => CoordAccuracy.none);

  /// 位置未確定色（黄縁取り等）で表示すべきか
  bool get isUncertain => this != CoordAccuracy.exact;
}

class Feed {
  const Feed({
    required this.type,
    required this.url,
    this.refreshSec,
    this.requiresReferer = false,
    this.headers = const {},
    this.cameraRef,
  });

  final FeedType type;
  final String url;
  final int? refreshSec;
  final bool requiresReferer;
  final Map<String, String> headers;

  /// 都度解決型feedのカメラ管理ID（mlit_roadinfo）
  final String? cameraRef;

  factory Feed.fromJson(Map<String, dynamic> json) => Feed(
        type: FeedType.parse(json['type'] as String?),
        url: json['url'] as String? ?? '',
        refreshSec: (json['refresh_sec'] as num?)?.toInt(),
        requiresReferer: json['requires_referer'] as bool? ?? false,
        headers: (json['headers'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        cameraRef: json['camera_ref'] as String?,
      );
}

class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.category,
    required this.prefecture,
    this.country,
    required this.feed,
    required this.operator,
    required this.attribution,
    this.nameKana,
    this.lat,
    this.lng,
    this.coordAccuracy = CoordAccuracy.none,
    this.municipality,
    this.riverOrRoute,
    this.fallbackUrl,
    this.sourcePageUrl,
    this.termsUrl,
    this.license,
  });

  final String id;
  final String name;
  final String? nameKana;
  final double? lat;
  final double? lng;
  final CoordAccuracy coordAccuracy;
  final String category;
  final String prefecture;
  final String? country; // 海外カメラのISO 3166-1 alpha-2（国内はnull）
  final String? municipality;
  final String? riverOrRoute;
  final Feed feed;
  final String? fallbackUrl;
  final String operator;
  final String attribution;
  final String? sourcePageUrl;
  final String? termsUrl;
  final String? license;

  bool get hasLocation => lat != null && lng != null;

  /// 動画で見られるカメラか（ピンのアイコン分け等に使う）
  /// 海外カメラか（prefecture=99）
  bool get isWorld => prefecture == '99';

  bool get isVideo =>
      feed.type == FeedType.youtubeChannel ||
      feed.type == FeedType.youtubeVideo ||
      feed.type == FeedType.hls;

  /// レコードとして最低限成立しているか（欠損データで地図を壊さない）
  bool get isDisplayable => id.isNotEmpty && name.isNotEmpty && hasLocation;

  static Camera? tryParse(Map<String, dynamic> json) {
    try {
      final source = json['source'] as Map<String, dynamic>? ?? const {};
      return Camera(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameKana: json['name_kana'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        coordAccuracy: CoordAccuracy.parse(json['coord_accuracy'] as String?),
        category: json['category'] as String? ?? 'other',
        prefecture: json['prefecture'] as String? ?? '00',
        country: json['country'] as String?,
        municipality: json['municipality'] as String?,
        riverOrRoute: json['river_or_route'] as String?,
        feed: Feed.fromJson(json['feed'] as Map<String, dynamic>? ?? const {}),
        fallbackUrl: (json['fallback'] as Map<String, dynamic>?)?['url'] as String?,
        operator: json['operator'] as String? ?? '',
        attribution: source['attribution'] as String? ?? '',
        sourcePageUrl: source['page_url'] as String?,
        termsUrl: source['terms_url'] as String?,
        license: source['license'] as String?,
      );
    } catch (_) {
      return null; // 1件の不正データで全体を落とさない
    }
  }

  static List<Camera> listFromJson(Map<String, dynamic> json) =>
      (json['cameras'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Camera.tryParse)
          .whereType<Camera>()
          .toList();
}
