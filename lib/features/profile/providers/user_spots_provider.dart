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
  final rawList = (data is Map && data['spots'] is List)
      ? data['spots'] as List
      : (data is Map && data['data'] is List)
          ? data['data'] as List
          : const [];

  return rawList
      .whereType<Map>()
      .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});
