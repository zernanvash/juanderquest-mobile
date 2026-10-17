import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/network/connection_monitor.dart';

void main() {
  group('ConnectionMonitor backoff and recovery', () {
    test('retries unreachable probes on the 2/4/8/15/30 s backoff schedule', () {
      fakeAsync((async) {
        final probeTimes = <Duration>[];
        final monitor = ConnectionMonitor(
          connectivityStream: const Stream.empty(),
          probe: () async {
            probeTimes.add(async.elapsed);
            return ServerProbeResult.unreachable;
          },
        );
        addTearDown(monitor.dispose);

        monitor.start();
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.serverUnreachable);

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 4));
        async.elapse(const Duration(seconds: 8));
        async.elapse(const Duration(seconds: 15));
        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 30));

        expect(probeTimes, [
          Duration.zero,
          const Duration(seconds: 2),
          const Duration(seconds: 6),
          const Duration(seconds: 14),
          const Duration(seconds: 29),
          const Duration(seconds: 59),
          const Duration(seconds: 89),
        ]);
      });
    });

    test('recovers to online and emits onRecovered when a probe succeeds', () {
      fakeAsync((async) {
        var attempt = 0;
        final monitor = ConnectionMonitor(
          connectivityStream: const Stream.empty(),
          probe: () async {
            attempt += 1;
            return attempt <= 2 ? ServerProbeResult.unreachable : ServerProbeResult.ready;
          },
        );
        addTearDown(monitor.dispose);

        var recoveredEvents = 0;
        monitor.onRecovered.listen((_) => recoveredEvents += 1);

        monitor.start();
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.serverUnreachable);

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 4));
        expect(monitor.state, ConnectionStatus.online);
        expect(recoveredEvents, 1);

        async.elapse(const Duration(seconds: 30));
        expect(monitor.state, ConnectionStatus.online);
      });
    });

    test('startingUp probes surface as serverRestarting', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(connectivityStream: const Stream.empty(),
          probe: () async => ServerProbeResult.startingUp);
        addTearDown(monitor.dispose);
        monitor.start();
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.serverRestarting);
      });
    });

    test('connectivity loss marks offline and stops the probe timer', () {
      fakeAsync((async) {
        final controller = StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(controller.close);
        var probes = 0;
        final monitor = ConnectionMonitor(
          probe: () async {
            probes += 1;
            return ServerProbeResult.unreachable;
          },
          connectivityStream: controller.stream,
        );
        addTearDown(monitor.dispose);

        monitor.start();
        async.flushMicrotasks();
        controller.add([ConnectivityResult.none]);
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.offline);
        final probesBefore = probes;

        async.elapse(const Duration(seconds: 40));
        expect(probes, probesBefore);

        controller.add([ConnectivityResult.wifi]);
        async.flushMicrotasks();
        expect(probes, greaterThan(probesBefore));
      });
    });

    test('degraded after three slow successes, reset by a fast one', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(connectivityStream: const Stream.empty(),
          probe: () async => ServerProbeResult.ready);
        addTearDown(monitor.dispose);
        monitor.start();
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.online);

        monitor.reportApiSuccess(const Duration(seconds: 5));
        monitor.reportApiSuccess(const Duration(seconds: 6));
        expect(monitor.state, ConnectionStatus.online);
        monitor.reportApiSuccess(const Duration(seconds: 7));
        expect(monitor.state, ConnectionStatus.degraded);

        monitor.reportApiSuccess(const Duration(seconds: 1));
        monitor.reportApiSuccess(const Duration(seconds: 5));
        monitor.reportApiSuccess(const Duration(seconds: 5));
        expect(monitor.state, ConnectionStatus.degraded);
      });
    });

    test('MAINTENANCE API failures schedule a recovery probe', () {
      fakeAsync((async) {
        var probes = 0;
        final monitor = ConnectionMonitor(
          connectivityStream: const Stream.empty(),
          probe: () async {
            probes += 1;
            return probes == 1 ? ServerProbeResult.ready : ServerProbeResult.ready;
          },
        );
        addTearDown(monitor.dispose);
        monitor.start();
        async.flushMicrotasks();

        monitor.reportApiFailure(
          const ApiFailure(code: ApiFailureCodes.maintenance, message: 'restarting'),
        );
        expect(monitor.state, ConnectionStatus.serverRestarting);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(monitor.state, ConnectionStatus.online);
      });
    });

    test('backgrounding pauses probes and resuming probes immediately', () {
      fakeAsync((async) {
        var probes = 0;
        final monitor = ConnectionMonitor(
          connectivityStream: const Stream.empty(),
          probe: () async {
            probes += 1;
            return ServerProbeResult.unreachable;
          },
        );
        addTearDown(monitor.dispose);
        monitor.start();
        async.flushMicrotasks();
        final probesAfterStart = probes;

        monitor.setBackgrounded(true);
        async.elapse(const Duration(minutes: 5));
        expect(probes, probesAfterStart);

        monitor.setBackgrounded(false);
        async.flushMicrotasks();
        expect(probes, greaterThan(probesAfterStart));
        monitor.setBackgrounded(true);
      });
    });
  });
}

