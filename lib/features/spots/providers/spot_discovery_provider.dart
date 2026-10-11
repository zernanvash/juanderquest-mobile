import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../repositories/spots_cache_repository.dart';

class SpotDiscoveryState {
  final List<SpotModel> spots;
  final List<SpotModel> trending;
  final List<String> categories;
  final List<String> intents;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isOfflineFallback;
  final DateTime? lastCachedAt;
  final Set<String> savingIds;
  final ApiFailure? failure;
  final int count;

  const SpotDiscoveryState({
    this.spots = const [],
    this.trending = const [],
    this.categories = const [],
    this.intents = const [],
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.isOfflineFallback = false,
    this.lastCachedAt,
    this.savingIds = const {},
    this.failure,
    this.count = 0,
  });

  SpotDiscoveryState copyWith({
    List<SpotModel>? spots,
    List<SpotModel>? trending,
    List<String>? categories,
    List<String>? intents,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isOfflineFallback,
    DateTime? lastCachedAt,
    bool clearLastCachedAt = false,
    Set<String>? savingIds,
    ApiFailure? failure,
    bool clearFailure = false,
    int? count,
  }) =>
      SpotDiscoveryState(
        spots: spots ?? this.spots,
        trending: trending ?? this.trending,
        categories: categories ?? this.categories,
        intents: intents ?? this.intents,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
        lastCachedAt: clearLastCachedAt ? null : lastCachedAt ?? this.lastCachedAt,
        savingIds: savingIds ?? this.savingIds,
        failure: clearFailure ? null : failure ?? this.failure,
        count: count ?? this.count,
      );
}

class SpotDiscoveryNotifier extends StateNotifier<SpotDiscoveryState> {
  final Ref _ref;
  final SpotsCacheRepository _cacheRepo;
  int _requestVersion = 0;

  SpotDiscoveryNotifier(this._ref, [SpotsCacheRepository? cacheRepo])
      : _cacheRepo = cacheRepo ?? SpotsCacheRepository(memoryFallback: {}),
        super(const SpotDiscoveryState());

  Future<void> initialize() async {
    // 1. Stale-while-revalidate: hydrate immediately from local cache
    try {
      final cachedSpots = await _cacheRepo.loadSpots();
      if (cachedSpots != null && cachedSpots.spots.isNotEmpty) {
        state = state.copyWith(
          spots: cachedSpots.spots,
          count: cachedSpots.spots.length,
          isInitialLoading: false,
          isOfflineFallback: false,
          lastCachedAt: cachedSpots.cachedAt,
        );
      }
      final cachedTaxonomy = await _cacheRepo.loadTaxonomy();
      if (cachedTaxonomy != null) {
        state = state.copyWith(
          categories: cachedTaxonomy.categories,
          intents: cachedTaxonomy.tags,
        );
      }
    } catch (_) {}

    // 2. Fetch fresh data from network in foreground/background
    await Future.wait([load(), _loadTaxonomy(), _loadTrending()]);
  }

  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {
    final version = ++_requestVersion;
    state = state.copyWith(
      isInitialLoading: state.spots.isEmpty,
      isRefreshing: state.spots.isNotEmpty,
      clearFailure: true,
    );
    try {
      final response = await _ref
          .read(apiClientProvider)
          .dio
          .get('/spots', queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (category.isNotEmpty) 'categories': category,
        if (intent.isNotEmpty) 'intent': intent
      });
      if (version != _requestVersion) return;
      final items = (response.data['data'] as List)
          .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final meta = response.data['meta'];

      // Cache fresh catalog if this was an unfiltered base query
      if (query.isEmpty && category.isEmpty && intent.isEmpty) {
        await _cacheRepo.saveSpots(items);
      }

      state = state.copyWith(
        spots: items,
        count: meta is Map
            ? (meta['count'] as num?)?.toInt() ?? items.length
            : items.length,
        isInitialLoading: false,
        isRefreshing: false,
        isOfflineFallback: false,
        lastCachedAt: DateTime.now(),
        clearFailure: true,
      );
    } catch (error) {
      if (version != _requestVersion) return;
      // If we already have spots in memory, keep them and activate offline fallback banner
      if (state.spots.isNotEmpty) {
        state = state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          isOfflineFallback: true,
          clearFailure: true,
        );
      } else {
        // Try fallback to disk cache if memory was empty
        final cached = await _cacheRepo.loadSpots();
        if (cached != null && cached.spots.isNotEmpty) {
          state = state.copyWith(
            spots: cached.spots,
            count: cached.spots.length,
            isInitialLoading: false,
            isRefreshing: false,
            isOfflineFallback: true,
            lastCachedAt: cached.cachedAt,
            clearFailure: true,
          );
        } else {
          state = state.copyWith(
            isInitialLoading: false,
            isRefreshing: false,
            failure:
                ApiFailure.from(error, fallback: 'Could not load destinations.'),
          );
        }
      }
    }
  }

  Future<void> _loadTaxonomy() async {
    try {
      final response =
          await _ref.read(apiClientProvider).dio.get('/spot-taxonomy');
      final data = response.data['data'] as Map<String, dynamic>;
      final rawCategories = data['categories'];
      final categories = rawCategories is List
          ? rawCategories
              .map((item) => item is Map
                  ? (item['key'] ?? item['id'] ?? item['name']).toString()
                  : item.toString())
              .toList()
          : <String>[];
      final intents = (data['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();

      state = state.copyWith(
        categories: categories,
        intents: intents,
      );

      await _cacheRepo.saveTaxonomy(categories, intents);
    } catch (_) {
      if (state.categories.isEmpty) {
        final cached = await _cacheRepo.loadTaxonomy();
        if (cached != null) {
          state = state.copyWith(
            categories: cached.categories,
            intents: cached.tags,
          );
        }
      }
    }
  }

  Future<void> _loadTrending() async {
    try {
      final response =
          await _ref.read(apiClientProvider).dio.get('/spots/trending');
      state = state.copyWith(
          trending: (response.data['data'] as List)
              .map(
                  (item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
              .toList());
    } catch (_) {}
  }

  Future<ApiFailure?> toggleSaved(SpotModel spot) async {
    if (!_ref.read(authProvider).isAuthenticated) {
      return const ApiFailure(
          code: 'AUTH_REQUIRED', message: 'Sign in to save destinations.');
    }
    final next = !spot.saved;
    state = state.copyWith(
        spots: state.spots
            .map((item) =>
                item.id == spot.id ? item.copyWith(saved: next) : item)
            .toList(),
        savingIds: {...state.savingIds, spot.id});
    try {
      final dio = _ref.read(apiClientProvider).dio;
      if (next) {
        await dio.put('/spots/${spot.id}/save');
      } else {
        await dio.delete('/spots/${spot.id}/save');
      }
      state = state.copyWith(savingIds: {...state.savingIds}..remove(spot.id));
      return null;
    } catch (error) {
      state = state.copyWith(
          spots: state.spots
              .map((item) =>
                  item.id == spot.id ? item.copyWith(saved: spot.saved) : item)
              .toList(),
          savingIds: {...state.savingIds}..remove(spot.id));
      return ApiFailure.from(error,
          fallback: 'Could not update this saved destination.');
    }
  }
}

final spotDiscoveryProvider =
    StateNotifierProvider<SpotDiscoveryNotifier, SpotDiscoveryState>(
  (ref) {
    final cacheRepo = ref.watch(spotsCacheRepositoryProvider);
    return SpotDiscoveryNotifier(ref, cacheRepo);
  },
);
