import 'package:flutter/foundation.dart';

import '../models/app_version_info.dart';
import 'content_bundle_store.dart';

/// Tracks content versions; bundle installation remains unavailable.
class ContentManifestService {
  final ContentBundleStore _store;

  ContentManifestService({
    ContentBundleStore? store,
  }) : _store = store ?? ContentBundleStore();

  /// Checks if a newer content version is published in the manifest.
  Future<bool> isNewContentAvailable(ContentManifestMetadata metadata) async {
    final activeVersion = await _store.getActiveVersion();
    if (activeVersion == null) return true;
    return metadata.version.isNotEmpty && metadata.version != activeVersion;
  }

  /// Content installation is not yet implemented. A manifest response alone
  /// cannot be treated as a verified, downloaded bundle.
  Future<bool> syncContentBundle(
    ContentManifestMetadata metadata, {
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[ContentManifestService] Content bundle installation is under development.');
    return false;
  }
}
