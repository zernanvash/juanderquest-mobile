import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/data/auth_session_store.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

class _Store implements AuthSessionStore {
  _Store({this.stored});
  final StoredAuthSession? stored;
  var clears = 0;
  final writes = <StoredAuthSession>[];
  @override
  Future<StoredAuthSession?> read() async => stored;
  @override
  Future<void> write(StoredAuthSession session) async => writes.add(session);
  @override
  Future<void> clear() async => clears++;
}

class _AdminLoginAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        options.path.endsWith('/auth/me')
            ? '{"success":true,"data":{"id":"admin-1","role":"admin","display_name":"Admin"}}'
            : '{"success":true,"data":{"token":"admin-token","user":{"id":"admin-1","role":"admin","display_name":"Admin"}}}',
        200,
        headers: {
          'content-type': ['application/json']
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('admin account can sign in to the traveler mobile app',
      () async {
    final api = ApiClient(enableRetries: false);
    api.dio.httpClientAdapter = _AdminLoginAdapter();
    final store = _Store();
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    final accepted = await notifier.loginWithEmail(
        email: 'admin@example.com', password: 'password123');

    expect(accepted, isTrue);
    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.user?.role, 'admin');
    expect(api.isAuthenticated, isTrue);
    expect(store.writes, hasLength(1));
    expect(store.clears, 0);
  });

  test('mobile restores an existing admin session into traveler app view',
      () async {
    final api = ApiClient(enableRetries: false);
    api.dio.httpClientAdapter = _AdminLoginAdapter();
    final store = _Store(
      stored: const StoredAuthSession(
        token: 'old-admin-token',
        user: {'id': 'admin-1', 'role': 'admin', 'display_name': 'Admin'},
      ),
    );
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    await notifier.restoreSession();

    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.user?.role, 'admin');
    expect(api.isAuthenticated, isTrue);
    expect(store.clears, 0);
  });
}
