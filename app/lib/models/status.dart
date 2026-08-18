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
  });

  final CameraState state;
  final String? lastOkAt;
  final String? frozenSince;

  /// 実測の更新間隔。再取得間隔の下限決定に使う（SPEC 9.4）
  final int? avgIntervalSec;

  /// 都度解決型feed（mlit_roadinfo）の最新静止画URL（monitorが30分ごとに更新）
  final String? imageUrl;
  final String? imageTime;

  factory CameraStatus.fromJson(Map<String, dynamic> json) => CameraStatus(
        state: CameraState.parse(json['state'] as String?),
        lastOkAt: json['last_ok_at'] as String?,
        frozenSince: json['frozen_since'] as String?,
        avgIntervalSec: (json['avg_interval_sec'] as num?)?.toInt(),
        imageUrl: json['image_url'] as String?,
        imageTime: json['image_time'] as String?,
      );
}

class StatusFile {
  const StatusFile({required this.generatedAt, required this.statuses});

  final String? generatedAt;
  final Map<String, CameraStatus> statuses;

  factory StatusFile.fromJson(Map<String, dynamic> json) => StatusFile(
        generatedAt: json['generated_at'] as String?,
        statuses: (json['statuses'] as Map<String, dynamic>? ?? const {}).map(
            (k, v) => MapEntry(
                k, CameraStatus.fromJson(v as Map<String, dynamic>? ?? const {}))),
      );

  CameraStatus? operator [](String cameraId) => statuses[cameraId];
}
