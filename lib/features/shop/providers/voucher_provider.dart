import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/voucher_model.dart';
import '../../suki/providers/suki_provider.dart';

class VoucherState {
  final List<VoucherModel> vouchers;
  final List<RedeemedVoucherModel> redeemedVouchers;
  final bool isLoading;
  final bool isRedeeming;
  final String? error;

  VoucherState({
    this.vouchers = const [],
    this.redeemedVouchers = const [],
    this.isLoading = false,
    this.isRedeeming = false,
    this.error,
  });

  VoucherState copyWith({
    List<VoucherModel>? vouchers,
    List<RedeemedVoucherModel>? redeemedVouchers,
    bool? isLoading,
    bool? isRedeeming,
    String? error,
  }) {
    return VoucherState(
      vouchers: vouchers ?? this.vouchers,
      redeemedVouchers: redeemedVouchers ?? this.redeemedVouchers,
      isLoading: isLoading ?? this.isLoading,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      error: error,
    );
  }
}

class VoucherNotifier extends StateNotifier<VoucherState> {
  final Ref _ref;
  final _uuid = const Uuid();

  VoucherNotifier(this._ref) : super(VoucherState());

  Future<void> fetchVouchers() async {
    state = state.copyWith(isLoading: true, error: null);
    final apiClient = _ref.read(apiClientProvider);

    try {
      final response = await apiClient.dio.get('/vouchers');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = (response.data['data'] as List)
            .map((item) => VoucherModel.fromJson(item))
            .toList();
        state = state.copyWith(vouchers: list, isLoading: false);
        await fetchRedeemed();
      } else {
        state = state.copyWith(
          error: 'Failed to fetch vouchers.',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Could not connect to voucher store.',
        isLoading: false,
      );
    }
  }

  /// Plan 107: the traveler's codes come from the server (`GET /me/redemptions`),
  /// so they survive restarts and show when a shop has confirmed them.
  Future<void> fetchRedeemed() async {
    if (_ref.read(authProvider).user == null) return;
    try {
      final items = await _ref.read(sukiApiProvider).myRedemptions();
      state = state.copyWith(redeemedVouchers: [
        for (final r in items)
          if (r.code.isNotEmpty)
            RedeemedVoucherModel(
              voucherId: r.voucherId,
              merchantName: r.merchantName,
              offerTitle: r.title,
              code: r.code,
              redeemedAt: r.createdAt ?? DateTime.now(),
              expiresAt: r.expiresAt,
              usedAt: r.usedAt,
              costPoints: r.costPoints,
            ),
      ]);
    } catch (_) {
      // Keep the list we have; the next load retries.
    }
  }

  Future<({bool success, String? code, String? error, RedeemedVoucherModel? redeemed})> redeemVoucher(VoucherModel voucher) async {
    state = state.copyWith(isRedeeming: true, error: null);
    final apiClient = _ref.read(apiClientProvider);
    final idempotencyKey = _uuid.v4();

    try {
      final response = await apiClient.dio.post(
        '/vouchers/${voucher.id}/redeem',
        data: {
          'idempotency_key': idempotencyKey,
        },
      );

      state = state.copyWith(isRedeeming: false);

      // A new redemption answers 201, a replay 200.
      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok && response.data['success'] == true) {
        final data = response.data['data'];
        final raw = data is Map ? (data['redemption_code'] ?? data['code']) : null;
        final code = raw is String ? raw : '';
        await _ref.read(authProvider.notifier).refreshProfile();
        // The server's list is the source of truth for codes and used state.
        await fetchRedeemed();
        if (code.isEmpty) {
          // Never invent a code the shop cannot confirm.
          const msg = 'Redeemed, but the code did not arrive. Check My vouchers.';
          state = state.copyWith(error: msg);
          return (success: false, code: null, error: msg, redeemed: null);
        }
        final expiresRaw = data is Map ? data['expires_at'] : null;
        final redeemed = state.redeemedVouchers
                .where((r) => r.code == code)
                .firstOrNull ??
            RedeemedVoucherModel(
              voucherId: voucher.id,
              merchantName: voucher.merchantName,
              offerTitle: voucher.offerTitle,
              code: code,
              redeemedAt: DateTime.now(),
              expiresAt: expiresRaw is String
                  ? DateTime.tryParse(expiresRaw)
                  : null,
              costPoints: voucher.costPoints,
            );
        if (!state.redeemedVouchers.any((r) => r.code == code)) {
          state = state.copyWith(
              redeemedVouchers: [redeemed, ...state.redeemedVouchers]);
        }
        return (success: true, code: code, error: null, redeemed: redeemed);
      } else {
        final String msg = response.data['error']?['message'] ?? 'Redemption failed.';
        state = state.copyWith(error: msg);
        return (success: false, code: null, error: msg, redeemed: null);
      }
    } on DioException catch (e) {
      final String msg = e.response?.data['error']?['message'] ?? 'Network error during redemption.';
      state = state.copyWith(isRedeeming: false, error: msg);
      return (success: false, code: null, error: msg, redeemed: null);
    } catch (e) {
      const String msg = 'Unexpected error processing redemption.';
      state = state.copyWith(isRedeeming: false, error: msg);
      return (success: false, code: null, error: msg, redeemed: null);
    }
  }
}

final voucherProvider = StateNotifierProvider<VoucherNotifier, VoucherState>((ref) {
  return VoucherNotifier(ref);
});
