import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/data/auth_session_store.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

void main() {
  const userJson = <String, dynamic>{
    'id': 'traveler-1',
    'seed_id': 'scout-1',
    'display_name': 'Test Scout',
    'email': 'scout@example.test',
    'avatar_url': '',
    'role': 'user',
    'demo_points': 10,
    'wallet_address': null,
    'mjdq_balance': 10000,
    'jdq_governance_balance': 0,
    'scout_reputation': 0,
  };

  test('restores a persisted session immediately and refreshes its profile',
      () async {
    final store = _MemoryAuthSessionStore(
      const StoredAuthSession(token: 'persisted-jwt', user: userJson),
    );
    final api = ApiClient();
    api.dio.interceptors.add(_successAdapter((options) {
      expect(options.headers['Authorization'], 'Bearer persisted-jwt');
      return userJson;
    }));
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    await notifier.restoreSession();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isRestoringSession, isFalse);
    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.user?.id, 'traveler-1');
    expect(store.session?.token, 'persisted-jwt');
  });

  test('persists the new token and profile after email login', () async {
    final store = _MemoryAuthSessionStore();
    final api = ApiClient();
    api.dio.interceptors.add(_successAdapter((_) => {
          'token': 'new-jwt',
          'user': userJson,
        }));
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    final success = await notifier.loginWithEmail(
      email: 'scout@example.test',
      password: 'password',
    );

    expect(success, isTrue);
    expect(store.session?.token, 'new-jwt');
    expect(store.session?.user['id'], 'traveler-1');
    expect(notifier.state.isAuthenticated, isTrue);
  });

  test('logout removes the persisted session', () async {
    final store = _MemoryAuthSessionStore(
      const StoredAuthSession(token: 'persisted-jwt', user: userJson),
    );
    final notifier = AuthNotifier(
      ApiClient(),
      AuthRefreshNotifier(),
      null,
      store,
    );

    notifier.logout();
    await Future<void>.delayed(Duration.zero);

    expect(store.session, isNull);
    expect(notifier.state.isAuthenticated, isFalse);
  });
}

InterceptorsWrapper _successAdapter(
  Map<String, dynamic> Function(RequestOptions options) responseFor,
) =>
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': responseFor(options),
          },
        ),
      ),
    );

class _MemoryAuthSessionStore implements AuthSessionStore {
  StoredAuthSession? session;

  _MemoryAuthSessionStore([this.session]);

  @override
  Future<StoredAuthSession?> read() async => session;

  @override
  Future<void> write(StoredAuthSession value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
