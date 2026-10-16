import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_session_store.dart';
import '../../spots/repositories/spots_cache_repository.dart';
import '../models/user_model.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final authRefreshProvider =
    ChangeNotifierProvider<AuthRefreshNotifier>((ref) => AuthRefreshNotifier());

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final bool isRestoringSession;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isRestoringSession = false,
    this.error,
  });

  bool get isAuthenticated => user != null && token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final AuthRefreshNotifier _refreshNotifier;
  final SpotsCacheRepository? _cacheRepo;
  final AuthSessionStore _sessionStore;

  AuthNotifier(
    this._apiClient,
    this._refreshNotifier, [
    this._cacheRepo,
    AuthSessionStore? sessionStore,
  ])  : _sessionStore = sessionStore ?? SecureAuthSessionStore(),
        super(AuthState(isRestoringSession: true));

  Future<void> restoreSession() async {
    try {
      final stored = await _sessionStore.read();
      if (stored == null) {
        state = AuthState();
        _refreshNotifier.notify();
        return;
      }

      final user = UserModel.fromJson(stored.user);
      if (user.id.isEmpty) {
        await _sessionStore.clear();
        state = AuthState();
        _refreshNotifier.notify();
        return;
      }

      _apiClient.setAuthToken(stored.token);
      state = AuthState(user: user, token: stored.token);
      _refreshNotifier.notify();
      unawaited(refreshProfile());
    } catch (error) {
      debugPrint('[auth] secure session restore failed: $error');
      _apiClient.setAuthToken(null);
      state = AuthState();
      _refreshNotifier.notify();
    }
  }

  Future<void> _completeLogin(String token, UserModel user) async {
    _apiClient.setAuthToken(token);
    try {
      await _sessionStore.write(
        StoredAuthSession(token: token, user: user.toJson()),
      );
    } catch (error) {
      // Keep the current login usable even if the device secure store is unavailable.
      debugPrint('[auth] secure session persistence failed: $error');
    }
    state = AuthState(user: user, token: token);
    _refreshNotifier.notify();
  }

  Future<bool> loginWithEmail(
      {required String email, required String password}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'remember_me': true,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        await _completeLogin(token, user);
        return true;
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Invalid email or password.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'display_name': displayName.trim(),
          'age_eligibility_declared': true,
          'terms_accepted': true,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        state = AuthState(isLoading: false);
        return {
          'success': true,
          'dev_code': response.data['data']?['dev_code'],
        };
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Registration failed.';
        state = AuthState(error: msg);
        return {'success': false, 'error': msg};
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Registration error (${e.message}).';
      state = AuthState(error: msg);
      return {'success': false, 'error': msg};
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return {'success': false, 'error': 'Unexpected error'};
    }
  }

  Future<bool> verifyEmailOtp(
      {required String email, required String code}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/email/verify',
        data: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'remember_me': true,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        await _completeLogin(token, user);
        return true;
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Invalid verification code.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Verification failed (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

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

        await _completeLogin(token, user);
        return true;
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Authentication failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> loginWithSimulatedWallet(
      {required String username, required String password}) async {
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

        await _completeLogin(token, user);
        return true;
      } else {
        final error = response.data['error'];
        final code = error is Map ? error['code'] : null;
        final msg = code == 'SIMULATED_LOGIN_DISABLED' || code == 'SIMULATED_LOGIN_RESERVED'
            ? 'Simulated login is unavailable on this server. Connect a wallet instead.'
            : (error is Map ? error['message'] : null) ?? 'Simulated wallet login failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final error = e.response?.data is Map ? e.response?.data['error'] : null;
      final code = error is Map ? error['code'] : null;
      final msg = code == 'SIMULATED_LOGIN_DISABLED' || code == 'SIMULATED_LOGIN_RESERVED'
          ? 'Simulated login is unavailable on this server. Connect a wallet instead.'
          : (error is Map ? error['message'] : null) ?? 'Network connection error (${e.message}).';
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

  Future<bool> loginWithWallet(
      {required String address, required String signature}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/wallet/login',
        data: {
          'address': address.trim(),
          'signature': signature.trim(),
          'remember_me': true,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final userJson = response.data['data']['user'];
        final user = UserModel.fromJson(userJson);

        await _completeLogin(token, user);
        return true;
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Wallet sign-in failed.';
        state = AuthState(error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return false;
    } catch (e) {
      state = AuthState(
          error: 'An unexpected error occurred during wallet sign-in.');
      return false;
    }
  }

  Future<bool> bindWallet(
      {required String address, required String signature}) async {
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
        final msg =
            response.data['error']?['message'] ?? 'Wallet binding failed.';
        state = AuthState(user: state.user, token: state.token, error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Failed to bind wallet: ${e.message}';
      state = AuthState(user: state.user, token: state.token, error: msg);
      return false;
    } catch (e) {
      state = AuthState(
          user: state.user,
          token: state.token,
          error: 'Unexpected error linking wallet.');
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
        final msg =
            response.data['error']?['message'] ?? 'Wallet unbinding failed.';
        state = AuthState(user: state.user, token: state.token, error: msg);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Failed to unlink wallet: ${e.message}';
      state = AuthState(user: state.user, token: state.token, error: msg);
      return false;
    } catch (e) {
      state = AuthState(
          user: state.user,
          token: state.token,
          error: 'Unexpected error unlinking wallet.');
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        logout();
      }
      debugPrint('Failed to refresh profile: ${e.message}');
    } catch (e) {
      print('Failed to refresh profile: $e');
    }
  }

  void logout() {
    final userId = state.user?.id;
    if (userId != null && _cacheRepo != null) {
      _cacheRepo!.purgeUserPartition(userId);
    }
    _apiClient.setAuthToken(null);
    unawaited(_sessionStore.clear().catchError((Object error) {
      debugPrint('[auth] secure session removal failed: $error');
    }));
    state = AuthState();
    _refreshNotifier.notify();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final refreshNotifier = ref.watch(authRefreshProvider.notifier);
  final cacheRepo = ref.watch(spotsCacheRepositoryProvider);
  final notifier = AuthNotifier(apiClient, refreshNotifier, cacheRepo);
  unawaited(notifier.restoreSession());
  return notifier;
});
