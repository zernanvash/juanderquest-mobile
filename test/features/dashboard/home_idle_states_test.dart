import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_idle.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_daily_tasks_panel.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_dual_bento_row.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );

HomeDailyMission _m(String id, {bool done = false}) => HomeDailyMission(
      id: id,
      kind: 'visit',
      title: 'Task $id',
      stamps: 2,
      progress: done ? 1 : 0,
      target: 1,
      completed: done,
    );

void main() {
  testWidgets('claimed stamp and answered QOTD explain why nothing happens',
      (tester) async {
    var claims = 0;
    var qotd = 0;
    await tester.pumpWidget(_wrap(HomeDualBentoRow(
      dailyState: const HomeDailyState(
        stamps: 5,
        missions: [],
        claimToday: true,
        nominalStamps: 5,
      ),
      onClaimDaily: () => claims++,
      qotdDone: true,
      onTapQotd: () => qotd++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_daily_claim_button')));
    await tester.pump();
    expect(claims, 0);
    expect(find.textContaining('already claimed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home_qotd_pill')));
    await tester.tap(find.byKey(const ValueKey('home_qotd_pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(qotd, 0);
    expect(find.textContaining('Already answered'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('daily tasks: next reward pulses; all done says so',
      (tester) async {
    await tester.pumpWidget(_wrap(HomeDailyTasksPanel(
      missions: [_m('a', done: true), _m('b'), _m('c')],
      onOpen: (_) {},
    )));
    final pulses = tester.widgetList<PixelPulse>(find.byType(PixelPulse));
    expect(pulses.where((p) => p.enabled).length, 1);
    expect(find.byKey(const ValueKey('home_daily_all_done')), findsNothing);

    await tester.pumpWidget(_wrap(HomeDailyTasksPanel(
      missions: [_m('a', done: true), _m('b', done: true)],
      onOpen: (_) {},
    )));
    expect(find.byKey(const ValueKey('home_daily_all_done')), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('PixelWiggle steps when loops run, rests otherwise',
      (tester) async {
    PixelLoop.debugRunInTests = true;
    addTearDown(() => PixelLoop.debugRunInTests = false);
    await tester.pumpWidget(_wrap(const PixelWiggle(
      restMs: 0,
      child: SizedBox(width: 10, height: 10),
    )));
    Offset dx() => tester
        .widget<Transform>(find.descendant(
            of: find.byType(PixelWiggle), matching: find.byType(Transform)))
        .transform
        .getTranslation()
        .x
        .let((x) => Offset(x, 0));
    expect(dx(), Offset.zero);
    await tester.pump(const Duration(milliseconds: 95));
    expect(dx(), isNot(Offset.zero));
    // Unmount so the periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
