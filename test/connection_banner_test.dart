import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/connection_monitor.dart';
import 'package:juanderquest_app/core/widgets/connection_banner.dart';

class _TestMonitor extends ConnectionMonitor {
  _TestMonitor()
      : super(
          probe: () async {
            probeCount += 1;
            return ServerProbeResult.ready;
          },
          connectivityStream: const Stream.empty(),
        );

  static int probeCount = 0;

  void emit(ConnectionStatus status) => state = status;
}

Widget _wrap(_TestMonitor monitor) {
  return ProviderScope(
    overrides: [connectionMonitorProvider.overrideWith((ref) => monitor)],
    child: const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ConnectionBanner(),
            Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => _TestMonitor.probeCount = 0);

  testWidgets('hides while online and shows the offline copy', (tester) async {
    final monitor = _TestMonitor();
    await tester.pumpWidget(_wrap(monitor));
    expect(find.textContaining("You're offline"), findsNothing);

    monitor.emit(ConnectionStatus.offline);
    await tester.pump();
    expect(find.textContaining("You're offline. Showing saved info."), findsOneWidget);
  });

  testWidgets('shows the restarting state with a spinner and no actions', (tester) async {
    final monitor = _TestMonitor();
    await tester.pumpWidget(_wrap(monitor));
    monitor.emit(ConnectionStatus.serverRestarting);
    await tester.pump();

    expect(find.textContaining('restarting… reconnecting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Retry now'), findsNothing);
  });

  testWidgets('unreachable state offers Retry now and triggers a probe', (tester) async {
    final monitor = _TestMonitor();
    await tester.pumpWidget(_wrap(monitor));
    monitor.emit(ConnectionStatus.serverUnreachable);
    await tester.pump();

    expect(find.textContaining("Can't reach JuanDerQuest right now"), findsOneWidget);
    final probesBefore = _TestMonitor.probeCount;
    await tester.tap(find.text('Retry now'));
    await tester.pump();
    expect(_TestMonitor.probeCount, greaterThan(probesBefore));
    monitor.emit(ConnectionStatus.online);
    await tester.pump();
  });

  testWidgets('degraded state is dismissible', (tester) async {
    final monitor = _TestMonitor();
    await tester.pumpWidget(_wrap(monitor));
    monitor.emit(ConnectionStatus.degraded);
    await tester.pump();
    expect(find.textContaining('Slow connection'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.textContaining('Slow connection'), findsNothing);
  });

  testWidgets('no overflow at 320x568 with 2.0x text in the unreachable state', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final monitor = _TestMonitor();
    await tester.pumpWidget(_wrap(monitor));
    monitor.emit(ConnectionStatus.serverUnreachable);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining("Can't reach JuanDerQuest right now"), findsOneWidget);
    monitor.emit(ConnectionStatus.online);
    await tester.pump();
  });
}
