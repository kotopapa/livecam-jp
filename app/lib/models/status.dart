/// 死活監視結果（SPEC 5.2）。
enum CameraState {
  ok('ok'),
  frozen('frozen'),
  error('error'),
  unknown('unknown');

  const CameraState(this.wire);
  final String wire;

  static CameraState parse(String? v) => CameraState.values
      .firstWhere((s) => s.wire == v, orElse: () => CameraState.unknown);
}

class CameraStatus {
  const CameraStatus({
    required this.state,
    this.lastOkAt,
    this.frozenSince,
    this.avgIntervalSec,
    this.imageUrl,
    this.imageTime,
    this.videoId,
    this.live,
  });

  final CameraState state;
  final String? lastOkAt;
  final String? frozenSince;

  /// 実測の更新間隔。再取得間隔の下限決定に使う（SPEC 9.4）
  final int? avgIntervalSec;

  /// 都度解決型feed（mlit_roadinfo）の最新静止画URL（monitorが30分ごとに更新）
  final String? imageUrl;
  final String? imageTime;

  /// youtube_channel の、いま配信中の動画ID（monitorが30分ごとに解決。配信が無ければ null）。
  /// `embed/live_stream?channel=` は配信中でも再生できないことがあるため、あれば動画IDで埋め込む
  final String? videoId;

  /// youtube_channel の配信状況（monitor が解決。true=配信中、false=配信なし、null=未判定）
  final bool? live;

  factory CameraStatus.fromJson(Map<String, dynamic> json) => CameraStatus(
        state: CameraState.parse(json['state'] as String?),
        lastOkAt: json['last_ok_at'] as String?,
        frozenSince: json['frozen_since'] as String?,
        avgIntervalSec: (json['avg_interval_sec'] as num?)?.toInt(),
        imageUrl: json['image_url'] as String?,
        imageTime: json['image_time'] as String?,
        videoId: json['video_id'] as String?,
        live: json['live'] as bool?,
      );
}

class StatusFile {
  const StatusFile(
      {required this.generatedAt, required this.statuses, this.defaultState});

  final String? generatedAt;
  final Map<String, CameraStatus> statuses;

  /// 軽量版 status（status_lite.json）の既定状態。statuses に無いカメラはこの状態として
  /// 扱う（配信側は ok 以外と追加情報を持つものだけを載せるため）。
  /// null（従来の status.json）なら、載っていないカメラは「不明」のまま
  final CameraState? defaultState;

  factory StatusFile.fromJson(Map<String, dynamic> json) => StatusFile(
        generatedAt: json['generated_at'] as String?,
        defaultState: json['default_state'] is String
            ? CameraState.parse(json['default_state'] as String)
            : null,
        statuses: (json['statuses'] as Map<String, dynamic>? ?? const {}).map(
            (k, v) => MapEntry(
                k, CameraStatus.fromJson(v as Map<String, dynamic>? ?? const {}))),
      );

  /// 載っていれば実体、無ければ defaultState の既定値（defaultState も無ければ null）
  CameraStatus? operator [](String cameraId) =>
      statuses[cameraId] ??
      (defaultState == null ? null : CameraStatus(state: defaultState!));

  CameraStatus? statusOf(String cameraId) => this[cameraId];
}
