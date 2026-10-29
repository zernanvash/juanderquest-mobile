import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../utils/spot_posting.dart';

/// Plan 66: `GET /spots/recognize` — what is at this map pin (town, barangay, POI name,
/// suggested category/details, story starters, nearby duplicates).
class SpotRecognitionApi {
  final Dio _dio;

  SpotRecognitionApi(this._dio);

  /// Never throws; a slow answer is cut at 4 s (8 s if the connection itself stalls) and falls back offline.
  Future<SpotRecognitionResult> recognizeLocation({required double lat, required double lng}) async {
    try {
      // Dio's own timeouts (no extra timer while an interceptor or cache answers).
      final response = await _dio.get<dynamic>(
        '/spots/recognize',
        queryParameters: {'lat': lat, 'lng': lng},
        options: Options(receiveTimeout: const Duration(seconds: 4), sendTimeout: const Duration(seconds: 4)),
      );
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        return SpotRecognitionResult.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      }
    } catch (_) {
      // Weak signal or an older API: fall through to the offline result.
    }
    return SpotRecognitionResult.offline();
  }
}

final spotRecognitionApiProvider = Provider<SpotRecognitionApi>(
  (ref) => SpotRecognitionApi(ref.read(apiClientProvider).dio),
);
