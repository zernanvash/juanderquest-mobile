import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/update_repository.dart';
import '../models/app_version_info.dart';
import 'content_manifest_service.dart';
import 'shorebird_update_service.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final ApiClient _apiClient;
  final ShorebirdUpdateService _shorebirdService;
  final ContentManifestService _contentService;

  UpdateRepositoryImpl({
    required ApiClient apiClient,
    ShorebirdUpdateService? shorebirdService,
    ContentManifestService? contentService,
  })  : _apiClient = apiClient,
        _shorebirdService = shorebirdService ?? ShorebirdUpdateService(),
        _contentService = contentService ?? ContentManifestService();

  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/app/version',
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );


      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          return AppVersionInfo.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[UpdateRepositoryImpl] Error fetching version metadata: $e');
    }
    return null;
  }

  @override
  Future<bool> isDartPatchAvailable() async {
    return _shorebirdService.checkForPatchUpdate();
  }

  @override
  Future<bool> downloadAndInstallDartPatch({
    void Function(double progress)? onProgress,
  }) async {
    return _shorebirdService.downloadPatch(onProgress: onProgress);
  }

  @override
  Future<bool> syncContentBundle(
    ContentManifestMetadata metadata, {
    void Function(double progress)? onProgress,
  }) async {
    return _contentService.syncContentBundle(metadata, onProgress: onProgress);
  }

  @override
  Future<void> restartApp() async {
    return _shorebirdService.restartApp();
  }
}
