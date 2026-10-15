import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/app_version_info.dart';

class ReleaseManifestClient {
  static const apiManifestUrl =
      'https://api.juanderquest.app/api/v1/app/version';
  static const githubManifestUrl =
      'https://github.com/zernanvash/juanderquest-mobile/releases/latest/download/version.json';
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: apiManifestUrl,
  );
  static const expectedPackageName = 'dev.zernanvash.juanderquest';

  final Dio _dio;
  final List<String> _manifestUrls;

  ReleaseManifestClient({
    Dio? dio,
    String? primaryManifestUrl,
    List<String>? fallbackManifestUrls,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: true,
              maxRedirects: 5,
              headers: const {'Accept': 'application/json'},
            )),
        _manifestUrls = List.unmodifiable({
          primaryManifestUrl ?? manifestUrl,
          ...(fallbackManifestUrls ?? const <String>[]),
          apiManifestUrl,
          githubManifestUrl,
        });

  Future<AppVersionInfo?> fetch({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    for (final candidate in _manifestUrls) {
      try {
        final uri = Uri.tryParse(candidate);
        if (uri == null || uri.scheme != 'https') {
          throw const FormatException('Update manifest must use HTTPS');
        }
        final response = await _dio.get<Object?>(
          candidate,
          options: Options(sendTimeout: timeout, receiveTimeout: timeout),
        );
        final raw = response.data;
        if (response.statusCode != 200 || raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        // Support backend { success: true, data: { ... } } envelope
        if (map.containsKey('data') && map['data'] is Map) {
          return parse(Map<String, dynamic>.from(map['data'] as Map));
        }
        return parse(map);
      } catch (error) {
        debugPrint(
            '[ReleaseManifestClient] Update check failed for $candidate: $error');
      }
    }
    return null;
  }

  static AppVersionInfo parse(Map<String, dynamic> json) {
    if ((json['schemaVersion'] != null && json['schemaVersion'] != 1) ||
        (json['packageName'] != null &&
            json['packageName'] != expectedPackageName)) {
      throw const FormatException('Unsupported update manifest');
    }
    final result = AppVersionInfo.fromJson(json);
    final downloadUri = Uri.tryParse(result.downloadUrl);
    if (result.versionCode < 1 ||
        downloadUri == null ||
        downloadUri.scheme != 'https' ||
        (result.sha256 != null &&
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(result.sha256!)) ||
        (result.sizeBytes != null && result.sizeBytes! < 1024 * 1024)) {
      throw const FormatException('Invalid update manifest fields');
    }
    return result;
  }
}
