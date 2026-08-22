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
      state = AsyncValue.error(
          StateError('Sign in to view your confirmed wallet balance.'),
          StackTrace.current);
      return;
    }

    try {
      final response = await apiClient.dio.get('/wallet');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final wallet = WalletModel.fromJson(response.data['data']);
        state = AsyncValue.data(wallet);
      } else {
        state = AsyncValue.error(
            StateError('The wallet response could not be verified.'),
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
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

final walletProvider =
    StateNotifierProvider<WalletNotifier, AsyncValue<WalletModel>>((ref) {
  return WalletNotifier(ref);
});
