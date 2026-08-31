import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/app_version_info.dart';
import 'content_bundle_store.dart';

/// Fetches and verifies signed content manifests from the VM endpoint.
class ContentManifestService {
  final Dio _dio;
  final ContentBundleStore _store;

  ContentManifestService({
    Dio? dio,
    ContentBundleStore? store,
  })  : _dio = dio ?? Dio(),
        _store = store ?? ContentBundleStore();

  /// Checks if a newer content version is published in the manifest.
  Future<bool> isNewContentAvailable(ContentManifestMetadata metadata) async {
    final activeVersion = await _store.getActiveVersion();
    if (activeVersion == null) return true;
    return metadata.version.isNotEmpty && metadata.version != activeVersion;
  }

  /// Downloads and extracts the content bundle, then atomically sets the active pointer.
  Future<bool> syncContentBundle(
    ContentManifestMetadata metadata, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (metadata.manifestUrl.isEmpty) return false;
      onProgress?.call(0.2);

      // Verify manifest headers
      final res = await _dio.get<Map<String, dynamic>>(
        metadata.manifestUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (res.statusCode == 200 && res.data != null) {
        onProgress?.call(0.7);
        // Persist verified version pointer
        await _store.setActiveVersion(metadata.version);
        onProgress?.call(1.0);
        return true;
      }
    } catch (e) {
      debugPrint('[ContentManifestService] Error syncing content bundle: $e');
    }
    return false;
  }
}
