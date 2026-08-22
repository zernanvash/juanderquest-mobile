class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String changelog;
  final DateTime? publishedAt;
  final bool forceUpdate;
  final int minSupportedVersionCode;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.changelog,
    this.publishedAt,
    this.forceUpdate = false,
    this.minSupportedVersionCode = 1,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: json['versionCode'] as int? ?? 1,
      versionName: json['versionName'] as String? ?? '1.0.0',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      minSupportedVersionCode: json['minSupportedVersionCode'] as int? ?? 1,
    );
  }
}
