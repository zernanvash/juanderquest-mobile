import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../auth/providers/auth_provider.dart';
import 'plaza_models.dart';

final plazaStandingsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  // key is in format "board:period", e.g. "everyone:weekly"
  final parts = key.split(':');
  final board = parts.isNotEmpty ? parts[0] : 'everyone';
  final period = parts.length > 1 ? parts[1] : 'weekly';

  final res = await api.dio.get('/plaza/standings', queryParameters: {
    'board': board,
    'period': period,
    'limit': 20,
  });

  if (res.data != null && res.data['success'] == true) {
    return res.data['data'] as Map<String, dynamic>;
  }
  return {};
});

final plazaTownsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/plaza/towns');
  if (res.data != null && res.data['success'] == true) {
    final list = res.data['data']?['towns'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
  return [];
});

class PlazaFeedNotifier extends StateNotifier<AsyncValue<List<ActivityItemModel>>> {
  final ApiClient _api;
  String _scope = 'mixed';
  String? _nextCursor;
  bool _hasMore = true;

  PlazaFeedNotifier(this._api) : super(const AsyncValue.loading()) {
    loadFeed(reset: true);
  }

  bool get hasMore => _hasMore;
  String get scope => _scope;

  void setScope(String newScope) {
    if (_scope != newScope) {
      _scope = newScope;
      loadFeed(reset: true);
    }
  }

  Future<void> loadFeed({bool reset = false}) async {
    try {
      if (reset) {
        state = const AsyncValue.loading();
        _nextCursor = null;
        _hasMore = true;
      }

      final res = await _api.dio.get('/plaza/feed', queryParameters: {
        'scope': _scope,
        if (_nextCursor != null) 'cursor': _nextCursor,
        'limit': 20,
      });

      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>? ?? {};
        final itemsRaw = data['items'] as List<dynamic>? ?? [];
        final items = itemsRaw.map((e) => ActivityItemModel.fromJson(e as Map<String, dynamic>)).toList();

        _nextCursor = data['next_cursor'] as String?;
        _hasMore = _nextCursor != null;

        if (reset) {
          state = AsyncValue.data(items);
        } else {
          final existing = state.value ?? [];
          state = AsyncValue.data([...existing, ...items]);
        }
      } else {
        if (reset) state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleCheer(String activityId) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((a) => a.id == activityId);
    if (idx == -1) return;

    final item = list[idx];
    final nextCheered = !item.cheeredByMe;
    final nextCount = nextCheered ? item.cheerCount + 1 : (item.cheerCount > 0 ? item.cheerCount - 1 : 0);

    // Optimistic update
    final updatedList = List<ActivityItemModel>.from(list);
    updatedList[idx] = item.copyWith(cheeredByMe: nextCheered, cheerCount: nextCount);
    state = AsyncValue.data(updatedList);

    try {
      if (nextCheered) {
        await _api.dio.put('/plaza/activities/$activityId/cheer');
      } else {
        await _api.dio.delete('/plaza/activities/$activityId/cheer');
      }
    } catch (_) {
      // Rollback on failure
      final rolledBack = List<ActivityItemModel>.from(updatedList);
      rolledBack[idx] = item;
      state = AsyncValue.data(rolledBack);
    }
  }
}

final plazaFeedProvider = StateNotifierProvider.autoDispose<PlazaFeedNotifier, AsyncValue<List<ActivityItemModel>>>((ref) {
  final api = ref.watch(apiClientProvider);
  return PlazaFeedNotifier(api);
});
