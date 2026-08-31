class ContentManifestMetadata {
  final String version;
  final String manifestUrl;
  final String? signature;
  final DateTime? publishedAt;

  const ContentManifestMetadata({
    required this.version,
    required this.manifestUrl,
    this.signature,
    this.publishedAt,
  });

  factory ContentManifestMetadata.fromJson(Map<String, dynamic> json) {
    return ContentManifestMetadata(
      version: json['version'] as String? ?? '',
      manifestUrl: json['manifestUrl'] as String? ?? '',
      signature: json['signature'] as String?,
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
    );
  }
}

enum UpdatePolicy {
  optional,
  mandatory,
  silent,
}

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String changelog;
  final DateTime? publishedAt;
  final bool forceUpdate;
  final int minSupportedVersionCode;
  final int minimumBaseVersionCode;
  final bool baseReleaseRequired;
  final UpdatePolicy updatePolicy;
  final ContentManifestMetadata? content;
  final String? commitHash;
  final String? fileName;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.changelog,
    this.publishedAt,
    this.forceUpdate = false,
    this.minSupportedVersionCode = 1,
    this.minimumBaseVersionCode = 1,
    this.baseReleaseRequired = false,
    this.updatePolicy = UpdatePolicy.optional,
    this.content,
    this.commitHash,
    this.fileName,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final force = json['forceUpdate'] as bool? ?? false;
    final minSupported = json['minSupportedVersionCode'] as int? ?? 1;
    final minBase = json['minimumBaseVersionCode'] as int? ?? minSupported;
    final policyStr = json['updatePolicy'] as String?;
    UpdatePolicy policy;
    if (policyStr == 'mandatory' || force) {
      policy = UpdatePolicy.mandatory;
    } else if (policyStr == 'silent') {
      policy = UpdatePolicy.silent;
    } else {
      policy = UpdatePolicy.optional;
    }

    return AppVersionInfo(
      versionCode: json['versionCode'] as int? ?? 1,
      versionName: json['versionName'] as String? ?? '1.0.0',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
      forceUpdate: force,
      minSupportedVersionCode: minSupported,
      minimumBaseVersionCode: minBase,
      baseReleaseRequired: json['baseReleaseRequired'] as bool? ?? false,
      updatePolicy: policy,
      content: json['content'] != null && json['content'] is Map<String, dynamic>
          ? ContentManifestMetadata.fromJson(json['content'] as Map<String, dynamic>)
          : null,
      commitHash: json['commitHash'] as String?,
      fileName: json['fileName'] as String?,
    );
  }
}


