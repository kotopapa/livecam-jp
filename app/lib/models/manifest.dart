/// 配信マニフェスト（SPEC 8.1）。
class Manifest {
  const Manifest({
    required this.schemaVersion,
    required this.camerasVersion,
    required this.camerasUrl,
    required this.camerasCount,
    required this.statusUrl,
    this.minAppVersion,
    this.storeUrl,
    this.notice,
    this.apps = const [],
  });

  final int schemaVersion;
  final String? camerasVersion;
  final String camerasUrl;
  final int camerasCount;
  final String statusUrl;
  final String? minAppVersion;

  /// App Store のURL（強制アップデートダイアログの誘導先。未公開の間はnull）
  final String? storeUrl;

  /// 緊急告知（あればアプリ上部にバナー表示。SPEC 8.1）
  final String? notice;

  /// 開発者の他のアプリ（設定画面の下部に表示。配信側 data/recommended_apps.json）
  final List<RecommendedApp> apps;

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
      storeUrl: json['store_url'] as String?,
      notice: json['notice'] as String?,
      apps: [
        for (final a in (json['apps'] as List? ?? const []))
          if (a is Map<String, dynamic>) RecommendedApp.fromJson(a),
      ],
    );
  }
}

/// 設定画面「開発者の他のアプリ」の1件
class RecommendedApp {
  const RecommendedApp({
    required this.id,
    required this.name,
    required this.tagline,
    required this.storeUrl,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String tagline;
  final String storeUrl;
  final String? iconUrl;

  factory RecommendedApp.fromJson(Map<String, dynamic> j) => RecommendedApp(
        id: j['id']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String? ?? '',
        storeUrl: j['store_url'] as String? ?? '',
        iconUrl: j['icon_url'] as String?,
      );
}
