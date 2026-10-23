import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cosmetic_item.dart';
import '../models/shop_teaser.dart';

class CosmeticsState {
  const CosmeticsState(
      {this.items = const [],
      this.owned = const [],
      this.teasers = const [],
      this.loadout = const {},
      this.isLoading = false,
      this.error});
  final List<CosmeticItem> items;
  final List<OwnedCosmetic> owned;
  final List<ShopTeaser> teasers;
  final Map<String, dynamic> loadout;
  final bool isLoading;
  final String? error;
  CosmeticsState copyWith(
          {List<CosmeticItem>? items,
          List<OwnedCosmetic>? owned,
          List<ShopTeaser>? teasers,
          Map<String, dynamic>? loadout,
          bool? isLoading,
          String? error}) =>
      CosmeticsState(
          items: items ?? this.items,
          owned: owned ?? this.owned,
          teasers: teasers ?? this.teasers,
          loadout: loadout ?? this.loadout,
          isLoading: isLoading ?? this.isLoading,
          error: error);
}

class CosmeticsNotifier extends StateNotifier<CosmeticsState> {
  CosmeticsNotifier(this.ref) : super(const CosmeticsState());
  final Ref ref;
  final _uuid = const Uuid();
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(apiClientProvider).dio;
      final catalog = await dio.get('/shop/cosmetics');
      final teaserResponse = await dio.get('/shop/teasers');
      Map<String, dynamic> me = {};
      try {
        final response = await dio.get('/me/cosmetics');
        me = Map<String, dynamic>.from(response.data['data'] ?? {});
      } catch (_) {}
      final list = catalog.data['data'] as List;
      final t = teaserResponse.data['data'] as List;
      state = state.copyWith(
          items: list
              .map((e) => CosmeticItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          teasers: t
              .map((e) => ShopTeaser.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          owned: (me['owned'] as List? ?? [])
              .map((e) => OwnedCosmetic.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          loadout: Map<String, dynamic>.from(me['loadout'] ?? {}),
          isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['error']?['message']?.toString() ??
              'Shop could not be loaded.');
    } catch (_) {
      state =
          state.copyWith(isLoading: false, error: 'Shop could not be loaded.');
    }
  }

  Future<String?> purchase(CosmeticItem item) async {
    try {
      await ref.read(apiClientProvider).dio.post(
          '/shop/cosmetics/${item.id}/purchase',
          data: {'idempotency_key': _uuid.v4()});
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error']?['message']?.toString() ??
          'Purchase failed.';
    }
  }

  Future<String?> equip(CosmeticItem item, {bool clear = false}) async {
    final key = {
      'banner': 'banner_id',
      'frame': 'frame_id',
      'title': 'title_id',
      'name_color': 'name_color_id'
    }[item.kind]!;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put('/me/cosmetics/loadout', data: {key: clear ? null : item.id});
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error']?['message']?.toString() ??
          'Appearance could not be updated.';
    }
  }
}

final cosmeticsProvider =
    StateNotifierProvider<CosmeticsNotifier, CosmeticsState>(
        (ref) => CosmeticsNotifier(ref));
