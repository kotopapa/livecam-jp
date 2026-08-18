/// 配信マニフェスト（SPEC 8.1）。
class Manifest {
  const Manifest({
    required this.schemaVersion,
    required this.camerasVersion,
    required this.camerasUrl,
    required this.camerasCount,
    required this.statusUrl,
    this.minAppVersion,
    this.notice,
  });

  final int schemaVersion;
  final String? camerasVersion;
  final String camerasUrl;
  final int camerasCount;
  final String statusUrl;
  final String? minAppVersion;

  /// 緊急告知（あればアプリ上部にバナー表示。SPEC 8.1）
  final String? notice;

  factory Manifest.fromJson(Map<String, dynamic> json) {
    final cameras = (json['cameras'] as Map<String, dynamic>? ?? const {});
    final status = (json['status'] as Map<String, dynamic>? ?? const {});
    return Manifest(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      camerasVersion: cameras['version'] as String?,
      camerasUrl: cameras['url'] as String? ?? '/v1/cameras.json',
      camerasCount: (cameras['count'] as num?)?.toInt() ?? 0,
      statusUrl: status['url'] as String? ?? '/v1/status.json',
      minAppVersion: json['min_app_version'] as String?,
      notice: json['notice'] as String?,
    );
  }
}
