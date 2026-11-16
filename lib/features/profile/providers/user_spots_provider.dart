import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../spots/models/spot_model.dart';

final userSpotsProvider =
    FutureProvider.autoDispose.family<List<SpotModel>, String>((ref, handle) async {
  final trimmed = handle.trim();
  if (trimmed.isEmpty) return const [];
  final cleanHandle = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;

  final response = await ref.read(apiClientProvider).dio.get('/users/$cleanHandle/spots');
  final data = response.data;
  // The API answers {success, data: {spots: [...]}} (Plan 100 WP-1: the old
  // parser only looked at the top level and always showed an empty list).
  final inner = data is Map ? data['data'] : null;
  final rawList = (inner is Map && inner['spots'] is List)
      ? inner['spots'] as List
      : (inner is List)
          ? inner
          : (data is Map && data['spots'] is List)
              ? data['spots'] as List
              : const [];

  return rawList
      .whereType<Map>()
      .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});
