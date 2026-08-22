import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';

class SpotDiscoveryState {
  final List<SpotModel> spots;
  final List<SpotModel> trending;
  final List<String> categories;
  final List<String> intents;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Set<String> savingIds;
  final ApiFailure? failure;
  final int count;

  const SpotDiscoveryState(
      {this.spots = const [],
      this.trending = const [],
      this.categories = const [],
      this.intents = const [],
      this.isInitialLoading = true,
      this.isRefreshing = false,
      this.savingIds = const {},
      this.failure,
      this.count = 0});

  SpotDiscoveryState copyWith(
          {List<SpotModel>? spots,
          List<SpotModel>? trending,
          List<String>? categories,
          List<String>? intents,
          bool? isInitialLoading,
          bool? isRefreshing,
          Set<String>? savingIds,
          ApiFailure? failure,
          bool clearFailure = false,
          int? count}) =>
      SpotDiscoveryState(
          spots: spots ?? this.spots,
          trending: trending ?? this.trending,
          categories: categories ?? this.categories,
          intents: intents ?? this.intents,
          isInitialLoading: isInitialLoading ?? this.isInitialLoading,
          isRefreshing: isRefreshing ?? this.isRefreshing,
          savingIds: savingIds ?? this.savingIds,
          failure: clearFailure ? null : failure ?? this.failure,
          count: count ?? this.count);
}

class SpotDiscoveryNotifier extends StateNotifier<SpotDiscoveryState> {
  final Ref _ref;
  int _requestVersion = 0;
  SpotDiscoveryNotifier(this._ref) : super(const SpotDiscoveryState());

  Future<void> initialize() async {
    await Future.wait([load(), _loadTaxonomy(), _loadTrending()]);
  }

  Future<void> load(
      {String query = '',
      String category = '',
      String intent = '',
      bool refresh = false}) async {
    final version = ++_requestVersion;
    state = state.copyWith(
        isInitialLoading: state.spots.isEmpty,
        isRefreshing: state.spots.isNotEmpty,
        clearFailure: true);
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
      state = state.copyWith(
          spots: items,
          count: meta is Map
              ? (meta['count'] as num?)?.toInt() ?? items.length
              : items.length,
          isInitialLoading: false,
          isRefreshing: false,
          clearFailure: true);
    } catch (error) {
      if (version != _requestVersion) return;
      state = state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          failure:
              ApiFailure.from(error, fallback: 'Could not load destinations.'));
    }
  }

  Future<void> _loadTaxonomy() async {
    try {
      final response =
          await _ref.read(apiClientProvider).dio.get('/spot-taxonomy');
      final data = response.data['data'] as Map<String, dynamic>;
      final rawCategories = data['categories'];
      state = state.copyWith(
          categories: rawCategories is List
              ? rawCategories
                  .map((item) => item is Map
                      ? (item['key'] ?? item['id'] ?? item['name']).toString()
                      : item.toString())
                  .toList()
              : const [],
          intents: (data['tags'] as List? ?? const [])
              .map((item) => item.toString())
              .toList());
    } catch (_) {}
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
        (ref) => SpotDiscoveryNotifier(ref));
