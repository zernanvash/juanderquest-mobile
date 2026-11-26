import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/home_recommended_quest_provider.dart';
import '../models/spot_model.dart';
import '../repositories/spots_cache_repository.dart';
import 'explore_impression_batcher.dart';

class SpotDiscoveryState {
  final List<SpotModel> spots;
  final List<SpotModel> trending;
  final List<String> categories;
  final List<String> intents;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isOfflineFallback;
  final DateTime? lastCachedAt;
  final Set<String> savingIds;
  final ApiFailure? failure;
  final int count;
  final int total;
  final String? nextCursor;
  final String activeQuery;
  final String activeCategory;
  final String activeIntent;
  final String activeMunicipality;
  final String? refreshSeed;

  const SpotDiscoveryState({
    this.spots = const [],
    this.trending = const [],
    this.categories = const [],
    this.intents = const [],
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isOfflineFallback = false,
    this.lastCachedAt,
    this.savingIds = const {},
    this.failure,
    this.count = 0,
    this.total = 0,
    this.nextCursor,
    this.activeQuery = '',
    this.activeCategory = '',
    this.activeIntent = '',
    this.activeMunicipality = '',
    this.refreshSeed,
  });

  SpotDiscoveryState copyWith({
    List<SpotModel>? spots,
    List<SpotModel>? trending,
    List<String>? categories,
    List<String>? intents,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isOfflineFallback,
    DateTime? lastCachedAt,
    bool clearLastCachedAt = false,
    Set<String>? savingIds,
    ApiFailure? failure,
    bool clearFailure = false,
    int? count,
    int? total,
    String? nextCursor,
    bool clearNextCursor = false,
    String? activeQuery,
    String? activeCategory,
    String? activeIntent,
    String? activeMunicipality,
    String? refreshSeed,
  }) =>
      SpotDiscoveryState(
        spots: spots ?? this.spots,
        trending: trending ?? this.trending,
        categories: categories ?? this.categories,
        intents: intents ?? this.intents,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
        lastCachedAt:
            clearLastCachedAt ? null : lastCachedAt ?? this.lastCachedAt,
        savingIds: savingIds ?? this.savingIds,
        failure: clearFailure ? null : failure ?? this.failure,
        count: count ?? this.count,
        total: total ?? this.total,
        nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
        activeQuery: activeQuery ?? this.activeQuery,
        activeCategory: activeCategory ?? this.activeCategory,
        activeIntent: activeIntent ?? this.activeIntent,
        activeMunicipality: activeMunicipality ?? this.activeMunicipality,
        refreshSeed: refreshSeed ?? this.refreshSeed,
      );
}

typedef PassiveLocationReader = Future<({double lat, double lng})?> Function();

class SpotDiscoveryNotifier extends StateNotifier<SpotDiscoveryState> {
  static const int defaultPageSize = 30;
  final Ref _ref;
  final SpotsCacheRepository _cacheRepo;
  final PassiveLocationReader? _customPassiveLocationReader;
  late final ExploreImpressionBatcher _impressionBatcher;
  ({double lat, double lng})? _cachedPassiveLocation;
  ({double lat, double lng})? _pageLocation;
  int _requestVersion = 0;

  SpotDiscoveryNotifier(
    this._ref, [
    SpotsCacheRepository? cacheRepo,
    PassiveLocationReader? passiveLocationReader,
  ])  : _cacheRepo = cacheRepo ?? SpotsCacheRepository(memoryFallback: {}),
        _customPassiveLocationReader = passiveLocationReader,
        super(const SpotDiscoveryState()) {
    _impressionBatcher = ExploreImpressionBatcher(
      isAuthenticated: () => _ref.read(authProvider).isAuthenticated,
      sendBatch: (spotIds) async {
        await _ref.read(apiClientProvider).dio.post(
          '/spots/impressions',
          data: <String, dynamic>{'spot_ids': spotIds},
        );
      },
    );
  }

  void _warmPassiveLocation() {
    if (_cachedPassiveLocation != null) return;
    unawaited(
      _defaultPassiveLocation().then((loc) {
        if (loc != null) _cachedPassiveLocation = loc;
      }),
    );
  }

  ({double lat, double lng})? _readSyncPassiveLocation() {
    if (_cachedPassiveLocation != null) return _cachedPassiveLocation;
    try {
      final homeLoc = _ref.read(homeLastKnownLocationProvider).valueOrNull;
      if (homeLoc != null) {
        return (
          lat: double.parse(homeLoc.lat.toStringAsFixed(2)),
          lng: double.parse(homeLoc.lng.toStringAsFixed(2)),
        );
      }
    } catch (_) {}
    _warmPassiveLocation();
    return null;
  }

  static Future<({double lat, double lng})?> _defaultPassiveLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return null;
      }
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return (
        lat: double.parse(pos.latitude.toStringAsFixed(2)),
        lng: double.parse(pos.longitude.toStringAsFixed(2)),
      );
    } catch (_) {
      return null;
    }
  }

  static String _newRefreshSeed() =>
      'rs_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  void reportCardVisibility(String spotId, double visibleFraction) =>
      _impressionBatcher.onVisibilityChanged(spotId, visibleFraction);

  void flushImpressions() => _impressionBatcher.onAppPaused();

  @override
  void dispose() {
    _impressionBatcher.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    // 1. Stale-while-revalidate: hydrate first page from local cache
    try {
      final cachedSpots = await _cacheRepo.loadSpots(
        partition: SpotsCacheRepository.partitionForFilter(),
      );
      if (cachedSpots != null && cachedSpots.spots.isNotEmpty) {
        state = state.copyWith(
          spots: cachedSpots.spots,
          count: cachedSpots.spots.length,
          total: cachedSpots.spots.length,
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

    // 2. Fetch fresh first page from network in foreground/background
    await Future.wait([load(), _loadTaxonomy(), _loadTrending()]);
  }

  /// Preserves the legacy override signature for existing widget test stubs
  /// while enforcing bounded `limit=30` first-page loading via [loadFiltered].
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) =>
      loadFiltered(
        query: query,
        category: category,
        intent: intent,
        refresh: refresh,
      );

  /// Loads page 1 (`cursor = null`, bounded by [limit]) for the requested
  /// filter set, resetting the Explore list when filters or search change.
  Future<void> loadFiltered({
    String query = '',
    String category = '',
    String intent = '',
    String municipality = '',
    int limit = defaultPageSize,
    bool refresh = false,
  }) async {
    final qClean = query.trim();
    final cClean = category.trim();
    final iClean = intent.trim();
    final mClean = municipality.trim();
    final pageLimit = limit.clamp(1, 100);
    final filterChanged = qClean != state.activeQuery ||
        cClean != state.activeCategory ||
        iClean != state.activeIntent ||
        mClean != state.activeMunicipality;
    final partition = SpotsCacheRepository.partitionForFilter(
      query: qClean,
      category: cClean,
      intent: iClean,
      municipality: mClean,
    );

    final seed = refresh || state.refreshSeed == null || state.refreshSeed!.isEmpty
        ? _newRefreshSeed()
        : state.refreshSeed!;
    final version = ++_requestVersion;
    state = state.copyWith(
      spots: filterChanged ? const <SpotModel>[] : state.spots,
      isInitialLoading: filterChanged || state.spots.isEmpty,
      isRefreshing: !filterChanged && state.spots.isNotEmpty,
      isLoadingMore: false,
      clearNextCursor: filterChanged,
      activeQuery: qClean,
      activeCategory: cClean,
      activeIntent: iClean,
      activeMunicipality: mClean,
      refreshSeed: seed,
      clearFailure: true,
    );
    try {
      final loc = _customPassiveLocationReader != null
          ? await _customPassiveLocationReader?.call()
          : _readSyncPassiveLocation();
      if (version != _requestVersion) return;
      _pageLocation = loc;
      final response = await _ref.read(apiClientProvider).dio.get(
        '/spots',
        queryParameters: <String, dynamic>{
          'limit': pageLimit,
          'refresh_seed': seed,
          if (loc != null) ...<String, dynamic>{
            'lat': double.parse(loc.lat.toStringAsFixed(2)),
            'lng': double.parse(loc.lng.toStringAsFixed(2)),
          },
          if (qClean.isNotEmpty) 'q': qClean,
          if (cClean.isNotEmpty) 'categories': cClean,
          if (iClean.isNotEmpty) 'intent': iClean,
          if (mClean.isNotEmpty) 'municipality': mClean,
        },
      );
      if (version != _requestVersion) return;
      final items = (response.data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final meta = response.data['meta'];
      final nextCursor = meta is Map ? meta['next_cursor']?.toString() : null;
      final total = meta is Map
          ? ((meta['total'] as num?)?.toInt() ?? items.length)
          : items.length;
      final count = meta is Map
          ? ((meta['count'] as num?)?.toInt() ?? items.length)
          : items.length;

      // Cache ONLY the first page per filter set (never the full national catalog).
      await _cacheRepo.saveSpots(items, partition: partition);

      state = state.copyWith(
        spots: items,
        count: count,
        total: total,
        nextCursor: nextCursor != null && nextCursor.isNotEmpty ? nextCursor : null,
        clearNextCursor: nextCursor == null || nextCursor.isEmpty,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        isOfflineFallback: false,
        lastCachedAt: DateTime.now(),
        clearFailure: true,
      );
    } catch (error) {
      if (version != _requestVersion) return;
      if (!filterChanged && state.spots.isNotEmpty) {
        state = state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          isOfflineFallback: true,
          clearFailure: true,
        );
      } else {
        final cached = await _cacheRepo.loadSpots(partition: partition);
        if (version != _requestVersion) return;
        if (cached != null && cached.spots.isNotEmpty) {
          state = state.copyWith(
            spots: cached.spots,
            count: cached.spots.length,
            total: cached.spots.length,
            clearNextCursor: true,
            isInitialLoading: false,
            isRefreshing: false,
            isLoadingMore: false,
            isOfflineFallback: true,
            lastCachedAt: cached.cachedAt,
            clearFailure: true,
          );
        } else {
          state = state.copyWith(
            isInitialLoading: false,
            isRefreshing: false,
            isLoadingMore: false,
            clearNextCursor: true,
            failure:
                ApiFailure.from(error, fallback: 'Could not load destinations.'),
          );
        }
      }
    }
  }

  /// Appends the next server page using `meta.next_cursor` until null,
  /// deduplicating by spot ID.
  Future<void> loadMore({int limit = defaultPageSize}) async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        cursor.isEmpty ||
        state.isLoadingMore ||
        state.isInitialLoading) {
      return;
    }
    final version = _requestVersion;
    state = state.copyWith(isLoadingMore: true, clearFailure: true);
    try {
      // Reuse the first page's location so every page ranks the same list.
      final loc = _pageLocation;
      if (version != _requestVersion) return;
      final response = await _ref.read(apiClientProvider).dio.get(
        '/spots',
        queryParameters: <String, dynamic>{
          'limit': limit.clamp(1, 100),
          'cursor': cursor,
          if (state.refreshSeed != null && state.refreshSeed!.isNotEmpty)
            'refresh_seed': state.refreshSeed,
          if (loc != null) ...<String, dynamic>{
            'lat': double.parse(loc.lat.toStringAsFixed(2)),
            'lng': double.parse(loc.lng.toStringAsFixed(2)),
          },
          if (state.activeQuery.isNotEmpty) 'q': state.activeQuery,
          if (state.activeCategory.isNotEmpty)
            'categories': state.activeCategory,
          if (state.activeIntent.isNotEmpty) 'intent': state.activeIntent,
          if (state.activeMunicipality.isNotEmpty)
            'municipality': state.activeMunicipality,
        },
      );
      if (version != _requestVersion) return;
      final incoming = (response.data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final meta = response.data['meta'];
      final nextCursor = meta is Map ? meta['next_cursor']?.toString() : null;
      final total = meta is Map
          ? ((meta['total'] as num?)?.toInt() ?? state.total)
          : state.total;

      final seenIds = <String>{for (final s in state.spots) s.id};
      final merged = <SpotModel>[
        ...state.spots,
        for (final s in incoming)
          if (seenIds.add(s.id)) s,
      ];

      state = state.copyWith(
        spots: merged,
        count: merged.length,
        total: math.max(total, merged.length),
        nextCursor: nextCursor != null && nextCursor.isNotEmpty ? nextCursor : null,
        clearNextCursor: nextCursor == null || nextCursor.isEmpty,
        isLoadingMore: false,
        clearFailure: true,
      );
    } catch (error) {
      if (version != _requestVersion) return;
      state = state.copyWith(
        isLoadingMore: false,
        failure: ApiFailure.from(
          error,
          fallback: 'Could not load more destinations.',
        ),
      );
    }
  }

  /// Server-backed typeahead using `GET /spots/search` (q 2..80 chars, limit <= 20).
  Future<List<SpotSearchHit>> searchTypeahead(
    String query, {
    int limit = 15,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <SpotSearchHit>[];
    final capped = trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
    final response = await _ref.read(apiClientProvider).dio.get(
      '/spots/search',
      queryParameters: <String, dynamic>{
        'q': capped,
        'limit': limit.clamp(1, 20),
      },
      cancelToken: cancelToken,
    );
    final raw = response.data is Map ? response.data['data'] : null;
    if (raw is! List) return const <SpotSearchHit>[];
    return raw
        .whereType<Map>()
        .map((item) => SpotSearchHit.fromJson(Map<String, dynamic>.from(item)))
        .where((hit) => hit.id.isNotEmpty)
        .toList();
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

  /// Plan 93b WP-13: one like state for Explore, Search and the detail page.
  Future<ApiFailure?> toggleLiked(SpotModel spot) =>
      setLiked(spot, liked: !current(spot).liked);

  /// The latest copy of [spot] in state (the caller's copy may be stale).
  SpotModel current(SpotModel spot) {
    for (final item in [...state.spots, ...state.trending]) {
      if (item.id == spot.id) return item;
    }
    return spot;
  }

  /// Idempotent: liking an already liked spot (double-tap) sends nothing.
  Future<ApiFailure?> setLiked(SpotModel spot, {required bool liked}) async {
    final before = current(spot);
    if (before.liked == liked) return null;
    final optimistic = before.copyWith(
      liked: liked,
      likeCount: math.max(0, before.likeCount + (liked ? 1 : -1)),
    );
    _replaceSpot(optimistic);
    try {
      final dio = _ref.read(apiClientProvider).dio;
      final response = liked
          ? await dio.put('/spots/${spot.id}/like')
          : await dio.delete('/spots/${spot.id}/like');
      final data = response.data is Map ? response.data['data'] : null;
      final count = data is Map ? (data['like_count'] as num?)?.toInt() : null;
      if (count != null) _replaceSpot(optimistic.copyWith(likeCount: count));
      return null;
    } catch (error) {
      _replaceSpot(before);
      return ApiFailure.from(error, fallback: 'Could not update this like.');
    }
  }

  void _replaceSpot(SpotModel next) {
    SpotModel swap(SpotModel item) => item.id == next.id
        ? item.copyWith(liked: next.liked, likeCount: next.likeCount)
        : item;
    state = state.copyWith(
      spots: state.spots.map(swap).toList(),
      trending: state.trending.map(swap).toList(),
    );
  }
}

final spotDiscoveryProvider =
    StateNotifierProvider<SpotDiscoveryNotifier, SpotDiscoveryState>(
  (ref) {
    final cacheRepo = ref.watch(spotsCacheRepositoryProvider);
    return SpotDiscoveryNotifier(ref, cacheRepo);
  },
);

/// Plan 116b Part 2 Step 4: bounded caller for Home's Nearby panel
/// (`GET /spots?lat=&lng=&radius_km=25&limit=10&sort=nearest`). Returns empty
/// without making any network call if [homeLastKnownLocationProvider] is null.
final homeNearbySpotsProvider = FutureProvider<List<SpotModel>>((ref) async {
  final loc = ref.watch(homeLastKnownLocationProvider).valueOrNull;
  if (loc == null) return const <SpotModel>[];
  try {
    final response = await ref.read(apiClientProvider).dio.get(
      '/spots',
      queryParameters: <String, dynamic>{
        'lat': loc.lat,
        'lng': loc.lng,
        'radius_km': 25,
        'limit': 10,
        'sort': 'nearest',
      },
    );
    final raw = response.data is Map ? response.data['data'] : null;
    if (raw is! List) return const <SpotModel>[];
    return raw
        .whereType<Map>()
        .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return const <SpotModel>[];
  }
});

/// Plan 116b Part 2 Step 4: bounded caller for Companion busy-spot guidance
/// (`GET /spots?limit=10`).
final companionBusySpotsProvider = FutureProvider<List<SpotModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  if (!client.isAuthenticated) return const <SpotModel>[];
  try {
    final response = await client.dio.get(
      '/spots',
      queryParameters: const <String, dynamic>{'limit': 10},
    );
    final raw = response.data is Map ? response.data['data'] : null;
    if (raw is! List) return const <SpotModel>[];
    return raw
        .whereType<Map>()
        .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return const <SpotModel>[];
  }
});

/// Plan 116b Part 2 Step 4: bounded caller for Profile saved count & favorite
/// picker (`GET /spots?limit=50`).
final boundedSavedSpotsProvider = FutureProvider<List<SpotModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  if (!client.isAuthenticated) return const <SpotModel>[];
  try {
    final response = await client.dio.get(
      '/spots',
      queryParameters: const <String, dynamic>{'limit': 50},
    );
    final raw = response.data is Map ? response.data['data'] : null;
    if (raw is! List) return const <SpotModel>[];
    return raw
        .whereType<Map>()
        .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
        .where((spot) => spot.saved)
        .toList();
  } catch (_) {
    return const <SpotModel>[];
  }
});

/// Plan 116b Part 2 Step 4: bounded single-spot caller for Pixel Lab backdrop
/// preview (`GET /spots?limit=1`).
final pixelLabSampleSpotProvider = FutureProvider<SpotModel?>((ref) async {
  final client = ref.read(apiClientProvider);
  if (!client.isAuthenticated) return null;
  try {
    final response = await client.dio.get(
      '/spots',
      queryParameters: const <String, dynamic>{'limit': 1},
    );
    final raw = response.data is Map ? response.data['data'] : null;
    if (raw is! List || raw.isEmpty || raw.first is! Map) return null;
    return SpotModel.fromJson(Map<String, dynamic>.from(raw.first as Map));
  } catch (_) {
    return null;
  }
});
