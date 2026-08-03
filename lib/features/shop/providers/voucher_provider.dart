import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/voucher_model.dart';

class VoucherState {
  final List<VoucherModel> vouchers;
  final bool isLoading;
  final bool isRedeeming;
  final String? error;

  VoucherState({
    this.vouchers = const [],
    this.isLoading = false,
    this.isRedeeming = false,
    this.error,
  });

  VoucherState copyWith({
    List<VoucherModel>? vouchers,
    bool? isLoading,
    bool? isRedeeming,
    String? error,
  }) {
    return VoucherState(
      vouchers: vouchers ?? this.vouchers,
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

  Future<({bool success, String? code, String? error})> redeemVoucher(String voucherId) async {
    state = state.copyWith(isRedeeming: true, error: null);
    final apiClient = _ref.read(apiClientProvider);
    final idempotencyKey = _uuid.v4();

    try {
      final response = await apiClient.dio.post(
        '/vouchers/$voucherId/redeem',
        data: {
          'idempotency_key': idempotencyKey,
        },
      );

      state = state.copyWith(isRedeeming: false);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final String code = response.data['data']['redemption_code'] as String? ??
            response.data['data']['code'] as String? ??
            'JDQ-REDEEMED';
        
        await _ref.read(authProvider.notifier).refreshProfile();
        return (success: true, code: code as String?, error: null as String?);
      } else {
        final String msg = response.data['error']?['message'] ?? 'Redemption failed.';
        state = state.copyWith(error: msg);
        return (success: false, code: null as String?, error: msg as String?);
      }
    } on DioException catch (e) {
      final String msg = e.response?.data['error']?['message'] ?? 'Network error during redemption.';
      state = state.copyWith(isRedeeming: false, error: msg);
      return (success: false, code: null as String?, error: msg as String?);
    } catch (e) {
      const String msg = 'Unexpected error processing redemption.';
      state = state.copyWith(isRedeeming: false, error: msg);
      return (success: false, code: null as String?, error: msg as String?);
    }
  }
}

final voucherProvider = StateNotifierProvider<VoucherNotifier, VoucherState>((ref) {
  return VoucherNotifier(ref);
});
