// Regression tests for mobile session race conditions and stale 401 handling.
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/data/auth_session_store.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

const _user = <String, dynamic>{'id': 'audit-user', 'display_name': 'Audit'};

class _Store implements AuthSessionStore {
  final pendingRead = Completer<StoredAuthSession?>();
  @override
  Future<StoredAuthSession?> read() => pendingRead.future;
  @override
  Future<void> write(StoredAuthSession session) async {}
  @override
  Future<void> clear() async {}
}

class _Adapter implements HttpClientAdapter {
  final sent = Completer<void>();
  final response = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    sent.complete();
    return response.future;
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('logout wins over a slow startup restore', () async {
    final api = ApiClient(enableRetries: false);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) => h.resolve(
      Response(requestOptions: o, statusCode: 200,
        data: {'success': true, 'data': _user}),
    )));
    final store = _Store();
    final notifier = AuthNotifier(api, AuthRefreshNotifier(), null, store);
    var authenticated = false;
    notifier.addListener((state) => authenticated = state.isAuthenticated);
    final restoring = notifier.restoreSession();
    notifier.logout();
    store.pendingRead.complete(const StoredAuthSession(token: 'old-token', user: _user));
    await restoring;
    await Future<void>.delayed(Duration.zero);
    expect(authenticated, isFalse);
  });

  test('a delayed old-token 401 does not erase a newer login', () async {
    final api = ApiClient(enableRetries: false);
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    api.setAuthToken('old-token');
    final request = api.dio.get('/auth/me');
    final rejection = expectLater(request, throwsA(isA<DioException>()));
    await adapter.sent.future;
    api.setAuthToken('new-token');
    adapter.response.complete(ResponseBody.fromString(
        '{"success":false,"error":{"code":"UNAUTHORIZED"}}', 401,
        headers: {'content-type': ['application/json']}));
    await rejection;
    expect(api.isAuthenticated, isTrue);
  });
}
