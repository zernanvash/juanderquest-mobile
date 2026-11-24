import 'dart:math' as math;

class AppAnnouncement {
  final String text;
  final String severity;
  final DateTime? until;

  const AppAnnouncement({
    required this.text,
    this.severity = 'info',
    this.until,
  });

  bool get isWarning => severity == 'warning';

  bool isExpiredAt(DateTime now) => until != null && !until!.isAfter(now);

  String get dismissalKey =>
      '$severity|$text|${until?.toUtc().toIso8601String() ?? ''}';

  static AppAnnouncement? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    final severity = raw['severity'] == 'warning' ? 'warning' : 'info';
    final untilRaw = raw['until'];
    final until = untilRaw is String && untilRaw.trim().isNotEmpty
        ? DateTime.tryParse(untilRaw.trim())
        : null;
    return AppAnnouncement(text: text, severity: severity, until: until);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppAnnouncement &&
          other.text == text &&
          other.severity == severity &&
          other.until == until;

  @override
  int get hashCode => Object.hash(text, severity, until);
}

class HomePromoPanelConfig {
  final String campaignId;
  final String title;
  final String body;
  final String ctaLabel;
  final String url;
  final DateTime? until;

  const HomePromoPanelConfig({
    required this.campaignId,
    required this.title,
    this.body = '',
    this.ctaLabel = 'Open Form',
    required this.url,
    this.until,
  });

  bool get hasValidHttpsUrl {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  bool isExpiredAt(DateTime now) => until != null && !until!.isAfter(now);

  static HomePromoPanelConfig? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = (raw['title'] as String? ?? '').trim();
    final url = (raw['url'] as String? ?? '').trim();
    final uri = Uri.tryParse(url);
    if (title.isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    final rawCampaignId = (raw['campaign_id'] as String? ?? '').trim();
    final campaignId = rawCampaignId.isNotEmpty ? rawCampaignId : '$title|$url';
    final body = (raw['body'] as String? ?? '').trim();
    final rawCta = (raw['cta_label'] as String? ?? '').trim();
    final ctaLabel = rawCta.isNotEmpty ? rawCta : 'Open Form';
    final untilRaw = raw['until'];
    final until = untilRaw is String && untilRaw.trim().isNotEmpty
        ? DateTime.tryParse(untilRaw.trim())
        : null;
    return HomePromoPanelConfig(
      campaignId: campaignId,
      title: title,
      body: body,
      ctaLabel: ctaLabel,
      url: url,
      until: until,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomePromoPanelConfig &&
          other.campaignId == campaignId &&
          other.title == title &&
          other.body == body &&
          other.ctaLabel == ctaLabel &&
          other.url == url &&
          other.until == until;

  @override
  int get hashCode => Object.hash(campaignId, title, body, ctaLabel, url, until);
}

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
  final String? packageName;
  final String? sha256;
  final int? sizeBytes;

  /// Manifest v2 fields (optional; absent in v1 manifests).
  final int? buildNumber;
  final int? minSupportedBuildNumber;
  final int? signingKeyGeneration;

  /// Plan 109 WP-5 server-controlled fields on GET /api/v1/app/version.
  final int? minSupportedBuild;
  final AppAnnouncement? announcement;
  final HomePromoPanelConfig? promoPanel;

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
    this.packageName,
    this.sha256,
    this.sizeBytes,
    this.buildNumber,
    this.minSupportedBuildNumber,
    this.signingKeyGeneration,
    this.minSupportedBuild,
    this.announcement,
    this.promoPanel,
  });

  int get effectiveMinSupportedBuild => [
        minSupportedVersionCode,
        minimumBaseVersionCode,
        minSupportedBuildNumber ?? 1,
        minSupportedBuild ?? 1,
      ].reduce(math.max);

  AppVersionInfo withControlMetadata({
    int? minSupportedBuild,
    AppAnnouncement? announcement,
    HomePromoPanelConfig? promoPanel,
  }) {
    final mergedMin = minSupportedBuild == null
        ? this.minSupportedBuild
        : math.max(this.minSupportedBuild ?? 1, minSupportedBuild);
    return AppVersionInfo(
      versionCode: versionCode,
      versionName: versionName,
      downloadUrl: downloadUrl,
      changelog: changelog,
      publishedAt: publishedAt,
      forceUpdate: forceUpdate,
      minSupportedVersionCode: minSupportedVersionCode,
      minimumBaseVersionCode: minimumBaseVersionCode,
      baseReleaseRequired: baseReleaseRequired,
      updatePolicy: updatePolicy,
      content: content,
      commitHash: commitHash,
      fileName: fileName,
      packageName: packageName,
      sha256: sha256,
      sizeBytes: sizeBytes,
      buildNumber: buildNumber,
      minSupportedBuildNumber: minSupportedBuildNumber,
      signingKeyGeneration: signingKeyGeneration,
      minSupportedBuild: mergedMin,
      announcement: announcement ?? this.announcement,
      promoPanel: promoPanel ?? this.promoPanel,
    );
  }

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
      packageName: json['packageName'] as String?,
      sha256: json['sha256'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      buildNumber: json['buildNumber'] as int?,
      minSupportedBuildNumber: json['minSupportedBuildNumber'] as int?,
      signingKeyGeneration: json['signingKeyGeneration'] as int?,
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt(),
      announcement: AppAnnouncement.tryFromJson(json['announcement']),
      promoPanel: HomePromoPanelConfig.tryFromJson(json['promo_panel']),
    );
  }
}


