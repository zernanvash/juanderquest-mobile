import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trail_models.dart';

final trailsApiProvider = Provider<TrailsApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TrailsApi(apiClient);
});

class TrailsApi {
  final ApiClient _apiClient;
  static const _uuid = Uuid();

  const TrailsApi(this._apiClient);

  static String extractErrorMessage(dynamic e) {
    if (e == null) return 'Something went wrong';
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final error = data['error'];
        if (error is Map) {
          final code = error['code']?.toString();
          final message = error['message']?.toString();
          if (code == 'UNAUTHORIZED') return 'Log in to start a trail';
          if (code == 'INSUFFICIENT_POINTS') {
            return 'Not enough points yet. Complete quests to earn points.';
          }
          if (message != null && message.isNotEmpty) return message;
        }
        if (data['message'] != null) return data['message'].toString();
      }
      return ApiFailure.from(e).message;
    }
    if (e is Error || e is FormatException) {
      return "Couldn't load this. Try again.";
    }
    final s = e.toString();
    if (s.startsWith('Exception: ')) {
      final msg = s.substring('Exception: '.length).trim();
      if (msg.isNotEmpty) return msg;
    }
    return "Couldn't load this. Try again.";
  }

  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    String? spotId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/trails/near',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          if (spotId != null && spotId.isNotEmpty) 'spot_id': spotId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final items = (response.data['data']?['items'] as List<dynamic>?) ?? [];
        return items
            .map((item) => NearbyTrail.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<TrailDetail> fetchTrail(String id) async {
    try {
      final response = await _apiClient.dio.get('/trails/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return TrailDetail.fromJson(data);
      }
      throw Exception(
        response.data['error']?['message'] ?? 'Could not load trail detail',
      );
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> unlockTrail(String id) async {
    final idempotencyKey = _uuid.v4();
    try {
      final response = await _apiClient.dio.post(
        '/trails/$id/unlock',
        options: Options(
          headers: {
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? {};
      }
      final code = response.data['error']?['code']?.toString();
      final message = response.data['error']?['message']?.toString();
      if (code == 'INSUFFICIENT_POINTS') {
        throw Exception(
            'Not enough points yet. Complete quests to earn points.');
      }
      if (code == 'ALREADY_UNLOCKED') {
        return {'already_unlocked': true};
      }
      if (code == 'UNAUTHORIZED') {
        throw Exception('Log in to start a trail');
      }
      throw Exception(message ?? 'Failed to unlock trail. Please try again.');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final code = data['error']['code']?.toString();
        final message = data['error']['message']?.toString();
        if (code == 'ALREADY_UNLOCKED') {
          return {'already_unlocked': true};
        }
        if (code == 'INSUFFICIENT_POINTS') {
          throw Exception(
              'Not enough points yet. Complete quests to earn points.');
        }
        if (code == 'UNAUTHORIZED') {
          throw Exception('Log in to start a trail');
        }
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> checkInTrailStop(
    String id,
    int position, {
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/trails/$id/stops/$position/checkin',
        data: {
          'lat': lat,
          'lng': lng,
          // The real accuracy: the server rejects fixes worse than 100 m.
          'accuracy_m': accuracyM,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? {};
      }
      final message = response.data['error']?['message']?.toString();
      throw Exception(message ?? 'Check-in failed. Please try again.');
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<TripPlan> planTrip({
    required LatLng start,
    required LatLng end,
    List<LatLng> via = const [],
    String costing = 'auto',
    bool avoidCongested = true,
  }) async {
    final payload = {
      'start': {
        'lat': start.latitude,
        'lng': start.longitude,
      },
      'end': {
        'lat': end.latitude,
        'lng': end.longitude,
      },
      'costing': costing,
      'avoid_congested': avoidCongested,
      if (via.isNotEmpty)
        'via': [
          for (final v in via) {'lat': v.latitude, 'lng': v.longitude},
        ],
    };

    try {
      final response = await _apiClient.dio.post(
        '/trail/plan',
        data: payload,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return TripPlan.fromJson(data);
      }
      throw Exception(
        response.data['error']?['message'] ?? 'Could not plan trip corridor',
      );
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }
}
