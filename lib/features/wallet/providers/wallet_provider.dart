import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';

class WalletNotifier extends StateNotifier<AsyncValue<WalletModel>> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchWallet();
  }

  Future<void> fetchWallet() async {
    final apiClient = _ref.read(apiClientProvider);
    final authState = _ref.read(authProvider);

    if (!authState.isAuthenticated) {
      state = AsyncValue.data(
        WalletModel(
          settlement: 'off-chain prototype',
          unit: 'mJDQ',
          balanceMjdq: 1000,
          balanceJdq: 1.0,
        ),
      );
      return;
    }

    try {
      final response = await apiClient.dio.get('/wallet');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final wallet = WalletModel.fromJson(response.data['data']);
        state = AsyncValue.data(wallet);
      } else {
        state = AsyncValue.data(
          WalletModel(
            settlement: 'off-chain prototype',
            unit: 'mJDQ',
            balanceMjdq: 1000,
            balanceJdq: 1.0,
          ),
        );
      }
    } catch (e) {
      // Fallback for offline or network delay in prototype
      state = AsyncValue.data(
        WalletModel(
          settlement: 'off-chain prototype',
          unit: 'mJDQ',
          balanceMjdq: 1000,
          balanceJdq: 1.0,
        ),
      );
    }
  }

  void updateBalanceLocally(int newBalanceMjdq) {
    state.whenData((current) {
      state = AsyncValue.data(
        WalletModel(
          settlement: current.settlement,
          unit: current.unit,
          balanceMjdq: newBalanceMjdq,
          balanceJdq: newBalanceMjdq / 1000.0,
        ),
      );
    });
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, AsyncValue<WalletModel>>((ref) {
  return WalletNotifier(ref);
});
