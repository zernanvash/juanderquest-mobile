import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/realtime/realtime_provider.dart';
import 'package:juanderquest_app/features/auth/data/auth_session_store.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

import 'fake_realtime_channel.dart';

const _user = <String, dynamic>{'id': 'rt-user', 'display_name': 'Realtime'};

class _Store implements AuthSessionStore {
  @override
  Future<StoredAuthSession?> read() async =>
      const StoredAuthSession(token: 'tok-1', user: _user);
  @override
  Future<void> write(StoredAuthSession session) async {}
  @override
  Future<void> clear() async {}
}

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late List<String> paths;
  late FakeConnector connector;
  late ProviderContainer container;
  late AuthNotifier auth;

  setUp(() async {
    paths = [];
    connector = FakeConnector();
    final api = ApiClient(enableRetries: false);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      paths.add(o.path);
      final data = switch (o.path) {
        '/auth/me' => _user,
        '/submissions' || '/quests' => <dynamic>[],
        _ => <String, dynamic>{},
      };
      h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {'success': true, 'data': data}));
    }));
    auth = AuthNotifier(api, AuthRefreshNotifier(), null, _Store());
    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => auth),
      realtimeConnectorProvider.overrideWithValue(connector.call),
      realtimeDebounceProvider
          .overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    container.read(realtimeProvider);
    await auth.restoreSession();
    await until(() => paths.contains('/auth/me')); // restore's own refresh
    paths.clear();
  });

  tearDown(() => container.dispose());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  test('connects with the signed-in token', () {
    expect(connector.channels, hasLength(1));
    expect(connector.last.sent.single, {'type': 'auth', 'token': 'tok-1'});
  });

  test('maps events to refreshes and collapses bursts', () async {
    connector.last
      ..emit({'type': 'points', 'balance': 1})
      ..emit({'type': 'points', 'balance': 2})
      ..emit({
        'type': 'submission',
        'id': 's1',
        'quest_id': 'q1',
        'status': 'approved'
      })
      ..emit({
        'type': 'notification',
        'id': 'n1',
        'kind': 'follow',
        'title': 'Hi',
        'href': '/'
      })
      ..emit({
        'type': 'notification',
        'id': 'n2',
        'kind': 'follow',
        'title': 'Hi',
        'href': '/'
      })
      ..emit({'type': 'funding', 'plan_id': 'p1', 'quest_id': 'q1'})
      ..emit(
          {'type': 'quest_published', 'id': 'q2', 'title': 'New', 'town': null})
      ..emit({'type': 'plaza_activity', 'id': 'a1'})
      ..emit({'type': 'something_else'});
    await until(
        () => ['/auth/me', '/submissions', '/quests'].every(paths.contains));
    await settle();
    expect(paths.where((p) => p == '/auth/me'), hasLength(1));
    expect(paths.where((p) => p == '/submissions'), hasLength(1));
    expect(paths.where((p) => p == '/quests'), hasLength(1));
    // Plaza is not open, so its feed is not fetched.
    expect(paths.where((p) => p == '/plaza/feed'), isEmpty);
    expect(container.read(notificationsChangedProvider), 1);
    expect(container.read(fundingChangedProvider), 1);
  });

  test('disconnects on sign-out', () async {
    auth.logout();
    await settle();
    expect(connector.last.closed, isTrue);
    expect(connector.channels, hasLength(1));
  });
}
