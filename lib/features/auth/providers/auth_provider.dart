import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connection_monitor.dart';
import '../data/auth_session_store.dart';
import '../../spots/repositories/spots_cache_repository.dart';
import '../models/user_model.dart';

class _ConnectionMonitorObserver implements ApiObserver {
  _ConnectionMonitorObserver(this._monitor);

  final ConnectionMonitor _monitor;

  @override
  void onFailure(ApiFailure failure) => _monitor.reportApiFailure(failure);

  @override
  void onSuccess(Duration elapsed) => _monitor.reportApiSuccess(elapsed);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  final monitor = ref.watch(connectionMonitorProvider.notifier);
  client.observer = _ConnectionMonitorObserver(monitor);
  client.isOffline = () =>
      ref.read(connectionMonitorProvider) == ConnectionStatus.offline;
  return client;
});

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

/// Plan 67: a wallet signs straight in only when its account already has an
/// email and password. Otherwise the traveler finishes the account first.
sealed class WalletLoginResult {
  const WalletLoginResult();
}

class WalletLoginAuthenticated extends WalletLoginResult {
  const WalletLoginAuthenticated();
}

class WalletLoginNeedsAccount extends WalletLoginResult {
  const WalletLoginNeedsAccount({
    required this.walletAddress,
    required this.grant,
    this.existingDisplayName,
  });

  final String walletAddress;
  final String grant;
  final String? existingDisplayName;
}

class WalletLoginFailed extends WalletLoginResult {
  const WalletLoginFailed(this.message);

  final String message;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final AuthRefreshNotifier _refreshNotifier;
  final SpotsCacheRepository? _cacheRepo;
  final AuthSessionStore _sessionStore;
  int _sessionGeneration = 0;

  AuthNotifier(
    this._apiClient,
    this._refreshNotifier, [
    this._cacheRepo,
    AuthSessionStore? sessionStore,
  ])  : _sessionStore = sessionStore ?? SecureAuthSessionStore(),
        super(AuthState(isRestoringSession: true));

  Future<void> restoreSession() async {
    final gen = _sessionGeneration;
    try {
      final stored = await _sessionStore.read();
      if (gen != _sessionGeneration) return;

      if (stored == null) {
        state = AuthState();
        _refreshNotifier.notify();
        return;
      }

      final user = UserModel.fromJson(stored.user);
      if (user.id.isEmpty) {
        await _sessionStore.clear();
        if (gen != _sessionGeneration) return;
        state = AuthState();
        _refreshNotifier.notify();
        return;
      }
      _apiClient.setAuthToken(stored.token);
      state = AuthState(user: user, token: stored.token);
      _refreshNotifier.notify();
      unawaited(refreshProfile());
    } catch (error) {
      if (gen != _sessionGeneration) return;
      debugPrint('[auth] secure session restore failed: $error');
      _apiClient.setAuthToken(null);
      state = AuthState();
      _refreshNotifier.notify();
    }
  }

  Future<bool> _completeLogin(String token, UserModel user) async {
    _sessionGeneration++;
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
    return true;
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

        return await _completeLogin(token, user);
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

        return await _completeLogin(token, user);
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

  Future<WalletLoginResult> loginWithWallet(
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
        final data = response.data['data'] as Map<String, dynamic>;
        if (data['account_completion_required'] == true) {
          state = AuthState();
          return WalletLoginNeedsAccount(
            walletAddress: data['wallet_address'] as String,
            grant: data['wallet_onboarding_grant'] as String,
            existingDisplayName: data['existing_display_name'] as String?,
          );
        }
        await _completeLogin(
            data['token'] as String, UserModel.fromJson(data['user']));
        return const WalletLoginAuthenticated();
      } else {
        final msg =
            response.data['error']?['message'] ?? 'Wallet sign-in failed.';
        state = AuthState(error: msg);
        return WalletLoginFailed(msg);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ??
          'Network connection error (${e.message}).';
      state = AuthState(error: msg);
      return WalletLoginFailed(msg);
    } catch (e) {
      const msg = 'An unexpected error occurred during wallet sign-in.';
      state = AuthState(error: msg);
      return const WalletLoginFailed(msg);
    }
  }

  /// Plan 67: finish a wallet sign-up/sign-in with an email and password.
  Future<bool> completeWalletRegistration({
    required String grant,
    required String walletAddress,
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/wallet/complete-registration',
        data: {
          'wallet_onboarding_grant': grant,
          'wallet_address': walletAddress,
          'email': email.trim().toLowerCase(),
          'password': password,
          if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
          'age_eligibility_declared': true,
          'terms_accepted': true,
          'remember_me': true,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return await _completeLogin(
            data['token'] as String, UserModel.fromJson(data['user']));
      }
      state = AuthState(
          error: response.data['error']?['message'] ??
              'We could not finish your account.');
      return false;
    } on DioException catch (e) {
      state = AuthState(
          error: e.response?.data['error']?['message'] ??
              'Network connection error (${e.message}).');
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  /// Plan 67: exchange a Google ID token for a session. A first sign-in creates
  /// the account, so [acceptTerms] carries the two sign-up declarations.
  Future<bool> loginWithGoogle(
      {required String credential, bool acceptTerms = false}) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/google',
        data: {
          'credential': credential,
          'remember_me': true,
          if (acceptTerms) 'terms_accepted': true,
          if (acceptTerms) 'age_eligibility_declared': true,
        },
      );
      if (response.data['success'] == true) {
        final data = response.data['data'];
        return await _completeLogin(
            data['token'] as String, UserModel.fromJson(data['user']));
      }
      state = AuthState(
          error: response.data['error']?['message'] ?? 'Google sign-in failed.');
      return false;
    } on DioException catch (e) {
      state = AuthState(
          error: e.response?.data['error']?['message'] ??
              'Network connection error (${e.message}).');
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
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
        if (state.token != null) {
          unawaited(_sessionStore.write(StoredAuthSession(token: state.token!, user: updatedUser.toJson())));
        }
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
        if (state.token != null) {
          unawaited(_sessionStore.write(StoredAuthSession(token: state.token!, user: updatedUser.toJson())));
        }
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
    final gen = _sessionGeneration;
    try {
      final response = await _apiClient.dio.get('/auth/me');
      if (gen != _sessionGeneration) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        state = AuthState(user: user, token: state.token);
        if (state.token != null) {
          unawaited(_sessionStore.write(StoredAuthSession(token: state.token!, user: user.toJson())));
        }
      }
    } on DioException catch (e) {
      // A single 401 handler lives in the API client interceptor: it emits
      // onSessionExpired once, which clears the session and prompts re-sign-in.
      // This refresh must not log the traveler out silently on its own.
      if (e.response?.statusCode != 401) {
        debugPrint('Failed to refresh profile: ${e.message}');
      }
    } catch (e) {
      debugPrint('Failed to refresh profile: $e');
    }
  }

  /// Session expired (401 on an authenticated call): clear credentials but
  /// keep cached data and unsent drafts; the app shell prompts re-sign-in.
  void handleSessionExpired() {
    _sessionGeneration++;
    _apiClient.setAuthToken(null);
    unawaited(_sessionStore.clear().catchError((Object error) {
      debugPrint('[auth] secure session removal failed: $error');
    }));
    state = AuthState();
    _refreshNotifier.notify();
  }

  void logout() {
    _sessionGeneration++;
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
  final sessionSubscription = apiClient.onSessionExpired.listen((_) {
    notifier.handleSessionExpired();
  });
  ref.onDispose(sessionSubscription.cancel);
  return notifier;
});
