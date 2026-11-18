import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/realtime/realtime_service.dart';

import 'fake_realtime_channel.dart';

void main() {
  test('backoff doubles from 1 s and caps at 30 s', () {
    expect([for (var i = 0; i < 8; i++) realtimeBackoff(i).inSeconds],
        [1, 2, 4, 8, 16, 30, 30, 30]);
  });

  test('realtime URI follows the API base URL scheme', () {
    expect(realtimeUriFor('https://api.juanderquest.app/api/v1').toString(),
        'wss://api.juanderquest.app/api/v1/realtime');
    expect(realtimeUriFor('http://127.0.0.1:4100/api/v1/').toString(),
        'ws://127.0.0.1:4100/api/v1/realtime');
  });

  RealtimeService service(
          FakeConnector connector, List<Map<String, dynamic>> events) =>
      RealtimeService(
        uriBuilder: () => Uri.parse('wss://api.example/api/v1/realtime'),
        onEvent: events.add,
        connector: connector.call,
      );

  test('authenticates first and forwards events but not ready/pong', () {
    fakeAsync((async) {
      final connector = FakeConnector();
      final events = <Map<String, dynamic>>[];
      final s = service(connector, events)..start('tok');
      expect(connector.last.sent, [
        {'type': 'auth', 'token': 'tok'}
      ]);
      connector.last
        ..emit({'type': 'ready'})
        ..emit({'type': 'pong'})
        ..emit({'type': 'points', 'balance': 5});
      async.flushMicrotasks();
      expect(events, [
        {'type': 'points', 'balance': 5}
      ]);
      s.dispose();
    });
  });

  test('reconnects with exponential backoff and resets after ready', () {
    fakeAsync((async) {
      final connector = FakeConnector();
      final s = service(connector, []);
      s.start('tok');
      connector.last.drop(1006);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 999));
      expect(connector.channels.length, 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(connector.channels.length, 2);

      connector.last.drop(1006);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 1999));
      expect(connector.channels.length, 2);
      async.elapse(const Duration(milliseconds: 1));
      expect(connector.channels.length, 3);

      connector.last.emit({'type': 'ready'});
      async.flushMicrotasks();
      expect(s.attempt, 0);
      connector.last.drop(1006);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      expect(connector.channels.length, 4);
      s.dispose();
    });
  });

  test('a rejected token stops retrying until a new sign-in', () {
    fakeAsync((async) {
      final connector = FakeConnector();
      final s = service(connector, []);
      s.start('bad');
      connector.last.drop(realtimeUnauthorizedCode);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      expect(connector.channels.length, 1);
      expect(s.isRetryScheduled, isFalse);
      s.start('good');
      expect(connector.channels.length, 2);
      expect(connector.last.sent.single['token'], 'good');
      s.dispose();
    });
  });

  test('pause closes the socket, resume reconnects, stop ends retries', () {
    fakeAsync((async) {
      final connector = FakeConnector();
      final s = service(connector, []);
      s.start('tok');
      s.pause();
      async.flushMicrotasks();
      expect(connector.last.closed, isTrue);
      async.elapse(const Duration(minutes: 1));
      expect(connector.channels.length, 1);
      s.resume();
      expect(connector.channels.length, 2);

      connector.last.drop(1006);
      async.flushMicrotasks();
      s.stop();
      async.elapse(const Duration(minutes: 1));
      expect(connector.channels.length, 2);
      expect(s.isConnected, isFalse);
    });
  });
}
