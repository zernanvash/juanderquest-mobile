import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final authRefreshProvider = ChangeNotifierProvider<AuthRefreshNotifier>((ref) => AuthRefreshNotifier());

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final AuthRefreshNotifier _refreshNotifier;

  AuthNotifier(this._apiClient, this._refreshNotifier) : super(AuthState());

  Future<bool> loginWithSeed(String seedId) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/demo-login',
        data: {'seed_id': seedId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        _apiClient.setAuthToken(token);
        state = AuthState(user: user, token: token);
        _refreshNotifier.notify();
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Authentication failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> loginWithSimulatedWallet({required String username, required String password}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/simulated-wallet-login',
        data: {
          'username': username.trim(),
          'password': password.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        _apiClient.setAuthToken(token);
        state = AuthState(user: user, token: token);
        _refreshNotifier.notify();
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Simulated wallet login failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<String?> requestWalletChallenge(String address) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/wallet/challenge',
        data: {'address': address.trim()},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['message'] as String?;
      }
    } catch (e) {
      debugPrint('[auth] requestWalletChallenge failed: $e');
    }
    return null;
  }

  Future<bool> loginWithWallet({required String address, required String signature}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/wallet/login',
        data: {
          'address': address.trim(),
          'signature': signature.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        _apiClient.setAuthToken(token);
        state = AuthState(user: user, token: token);
        _refreshNotifier.notify();
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Wallet sign-in failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred during wallet sign-in.');
      return false;
    }
  }

  Future<bool> bindWallet({required String address, required String signature}) async {
    if (state.token == null) return false;
    try {
      final response = await _apiClient.dio.post(
        '/auth/wallet/bind',
        data: {
          'address': address.trim(),
          'signature': signature.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final userJson = response.data['data']['user'];
        final updatedUser = UserModel.fromJson(userJson);
        state = AuthState(user: updatedUser, token: state.token);
        _refreshNotifier.notify();
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Wallet binding failed.';
        state = AuthState(user: state.user, token: state.token, error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Failed to bind wallet: ${e.message}';
      state = AuthState(user: state.user, token: state.token, error: msg);
      return false;
    } catch (e) {
      state = AuthState(user: state.user, token: state.token, error: 'Unexpected error linking wallet.');
      return false;
    }
  }

  Future<bool> unbindWallet() async {
    if (state.token == null) return false;
    try {
      final response = await _apiClient.dio.delete('/auth/wallet/unbind');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final userJson = response.data['data']['user'];
        final updatedUser = UserModel.fromJson(userJson);
        state = AuthState(user: updatedUser, token: state.token);
        _refreshNotifier.notify();
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Wallet unbinding failed.';
        state = AuthState(user: state.user, token: state.token, error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Failed to unlink wallet: ${e.message}';
      state = AuthState(user: state.user, token: state.token, error: msg);
      return false;
    } catch (e) {
      state = AuthState(user: state.user, token: state.token, error: 'Unexpected error unlinking wallet.');
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (state.token == null) return;
    try {
      final response = await _apiClient.dio.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        state = AuthState(user: user, token: state.token);
      }
    } catch (e) {
      print('Failed to refresh profile: $e');
    }
  }

  void logout() {
    _apiClient.setAuthToken(null);
    state = AuthState();
    _refreshNotifier.notify();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final refreshNotifier = ref.watch(authRefreshProvider.notifier);
  return AuthNotifier(apiClient, refreshNotifier);
});
