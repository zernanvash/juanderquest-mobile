import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
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

  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    String? spotId,
  }) async {
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
  }

  Future<TrailDetail> fetchTrail(String id) async {
    final response = await _apiClient.dio.get('/trails/$id');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return TrailDetail.fromJson(data);
    }
    throw Exception(
      response.data['error']?['message'] ?? 'Could not load trail detail',
    );
  }

  Future<Map<String, dynamic>> unlockTrail(String id) async {
    final idempotencyKey = _uuid.v4();
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
      throw Exception('Not enough points yet. Complete quests to earn points.');
    }
    if (code == 'ALREADY_UNLOCKED') {
      return {'already_unlocked': true};
    }
    throw Exception(message ?? 'Failed to unlock trail. Please try again.');
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
  }
}
