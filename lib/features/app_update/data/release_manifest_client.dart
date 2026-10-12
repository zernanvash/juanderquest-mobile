import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/app_version_info.dart';

class ReleaseManifestClient {
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://api.juanderquest.app/api/v1/app/version',
  );
  static const expectedPackageName = 'dev.zernanvash.juanderquest';

  final Dio _dio;

  ReleaseManifestClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              followRedirects: true,
              maxRedirects: 5,
              headers: const {'Accept': 'application/json'},
            ));

  Future<AppVersionInfo?> fetch({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final uri = Uri.tryParse(manifestUrl);
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException('Update manifest must use HTTPS');
      }
      final response = await _dio.get<Object?>(
        manifestUrl,
        options: Options(sendTimeout: timeout, receiveTimeout: timeout),
      );
      final raw = response.data;
      if (response.statusCode != 200 || raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      // Support backend { success: true, data: { ... } } envelope
      if (map.containsKey('data') && map['data'] is Map) {
        return parse(Map<String, dynamic>.from(map['data'] as Map));
      }
      return parse(map);
    } catch (error) {
      debugPrint('[ReleaseManifestClient] Update check failed: $error');
      return null;
    }
  }

  static AppVersionInfo parse(Map<String, dynamic> json) {
    if ((json['schemaVersion'] != null && json['schemaVersion'] != 1) ||
        (json['packageName'] != null && json['packageName'] != expectedPackageName)) {
      throw const FormatException('Unsupported update manifest');
    }
    final result = AppVersionInfo.fromJson(json);
    final downloadUri = Uri.tryParse(result.downloadUrl);
    if (result.versionCode < 1 ||
        downloadUri == null ||
        downloadUri.scheme != 'https' ||
        (result.sha256 != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(result.sha256!)) ||
        (result.sizeBytes != null && result.sizeBytes! < 1024 * 1024)) {
      throw const FormatException('Invalid update manifest fields');
    }
    return result;
  }
}
