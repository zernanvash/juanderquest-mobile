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
  @override
  Future<StoredAuthSession?> read() async => stored;
  @override
  Future<void> write(StoredAuthSession session) async {}
  @override
  Future<void> clear() async => clears++;
}

class _AdminLoginAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        '{"success":true,"data":{"token":"admin-token","user":{"id":"admin-1","role":"admin","display_name":"Admin"}}}',
        200,
        headers: {
          'content-type': ['application/json']
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('mobile rejects admin credentials and never persists an admin session',
      () async {
    final api = ApiClient(enableRetries: false);
    api.dio.httpClientAdapter = _AdminLoginAdapter();
    final store = _Store();
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    final accepted = await notifier.loginWithEmail(
        email: 'admin@example.com', password: 'password123');

    expect(accepted, isFalse);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.error, contains('web dashboard'));
    expect(api.isAuthenticated, isFalse);
    expect(store.clears, 1);
  });

  test('mobile clears an existing admin session on restore', () async {
    final api = ApiClient(enableRetries: false);
    final store = _Store(
      stored: const StoredAuthSession(
        token: 'old-admin-token',
        user: {'id': 'admin-1', 'role': 'admin', 'display_name': 'Admin'},
      ),
    );
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);

    await notifier.restoreSession();

    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.error, contains('web dashboard'));
    expect(api.isAuthenticated, isFalse);
    expect(store.clears, 1);
  });
}
