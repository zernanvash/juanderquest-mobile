import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_daily_tasks_panel.dart';

const _missions = [
  HomeDailyMission(
    id: 'm1',
    kind: 'quest_step',
    title: 'Complete one step of any quest in Pangasinan today',
    stamps: 2,
    progress: 0,
    target: 1,
    completed: false,
  ),
  HomeDailyMission(
    id: 'm2',
    kind: 'qotd',
    title: 'Answer the question of the day',
    stamps: 1,
    progress: 1,
    target: 1,
    completed: true,
  ),
];

Widget _wrap(Widget child,
        {Size size = const Size(360, 640), double text = 1}) =>
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
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

void main() {
  testWidgets('Plan 100 WP-4: lists today\'s tasks and opens an open one',
      (tester) async {
    HomeDailyMission? opened;
    await tester.pumpWidget(_wrap(HomeDailyTasksPanel(
      missions: _missions,
      onOpen: (m) => opened = m,
    )));
    expect(find.text('DAILY TASKS'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_daily_task_m1')));
    expect(opened?.kind, 'quest_step');
    opened = null;
    await tester.tap(find.byKey(const ValueKey('home_daily_task_m2')));
    expect(opened, isNull, reason: 'done tasks are not tappable');
  });

  testWidgets('Plan 100 WP-4: hidden with no missions', (tester) async {
    await tester.pumpWidget(
      _wrap(HomeDailyTasksPanel(missions: const [], onOpen: (_) {})),
    );
    expect(find.byKey(const ValueKey('home_daily_tasks')), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('Plan 100 WP-4: no overflow at $size with 2.0x text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        HomeDailyTasksPanel(missions: _missions, onOpen: (_) {}),
        size: size,
        text: 2,
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
