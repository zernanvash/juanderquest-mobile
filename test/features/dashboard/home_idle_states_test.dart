import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_idle.dart';
import 'package:juanderquest_app/core/pixel/pixel_poppers.dart';
import 'package:juanderquest_app/core/pixel/pixel_rpg.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_daily_tasks_panel.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_dual_bento_row.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_qotd_panel.dart';

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
  testWidgets('claimed stamp explains why nothing happens', (tester) async {
    var claims = 0;
    await tester.pumpWidget(_wrap(HomeDualBentoRow(
      dailyState: const HomeDailyState(
        stamps: 5,
        missions: [],
        claimToday: true,
        nominalStamps: 5,
      ),
      onClaimDaily: () => claims++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_daily_claim_button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(claims, 0);
    expect(find.textContaining('already claimed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('QOTD is open on Home; answered shows the result and explains',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeQotdProvider.overrideWith((ref) => _Qotd(ref, answered: false)),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(body: HomeQotdPanel()),
      ),
    ));
    expect(find.text('Where is Hundred Islands?'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_qotd_option_o1')), findsOneWidget);

    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        homeQotdProvider.overrideWith((ref) => _Qotd(ref, answered: true)),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(body: HomeQotdPanel()),
      ),
    ));
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('Alaminos City has them.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Already answered'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  // Team review v0.3.10: "add confetti when answer qotd right".
  for (final right in [true, false]) {
    testWidgets('QOTD answer ${right ? 'right fires' : 'wrong skips'} confetti',
        (tester) async {
      PixelPoppers.debugFired = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          homeQotdProvider.overrideWith((ref) => _Answering(ref, right)),
        ],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: const Scaffold(body: HomeQotdPanel()),
        ),
      ));
      expect(PixelPoppers.debugFired, 0);
      await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
      await tester.pump();
      expect(PixelPoppers.debugFired, right ? 1 : 0);
      // Tapping again (already answered) never fires a second time.
      await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(PixelPoppers.debugFired, right ? 1 : 0);
    });
  }

  testWidgets('an already-answered QOTD loading again fires no confetti',
      (tester) async {
    PixelPoppers.debugFired = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeQotdProvider.overrideWith((ref) => _Qotd(ref, answered: true)),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(body: HomeQotdPanel()),
      ),
    ));
    await tester.pump();
    expect(PixelPoppers.debugFired, 0);
  });

  // QA 2026-11-17: MISSED showed only the red pick, not the right answer.
  testWidgets('a missed QOTD marks the correct option green', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [homeQotdProvider.overrideWith((ref) => _Missed(ref))],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(body: HomeQotdPanel()),
      ),
    ));
    expect(find.text('MISSED'), findsOneWidget);
    PixelBoxStyle styleOf(String id) => tester
        .widget<PixelTappableSlot>(find.byKey(ValueKey('home_qotd_option_$id')))
        .style;
    expect(styleOf('o1'), PixelBoxStyle.red);
    expect(styleOf('o2'), PixelBoxStyle.green);
    expect(styleOf('o3'), PixelBoxStyle.parchment);
  });

  testWidgets('daily tasks panel shows with no tasks, plus the weekly chest',
      (tester) async {
    await tester.pumpWidget(_wrap(HomeDailyTasksPanel(
      missions: const [],
      daily: const HomeDailyState(
        stamps: 0,
        missions: [],
        chestCompleted: 2,
        chestRequired: 5,
        chestStamps: 10,
      ),
      onOpen: (_) {},
    )));
    expect(find.byKey(const ValueKey('home_daily_none')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_weekly_chest')), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
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

class _Qotd extends HomeQotdNotifier {
  _Qotd(super.ref, {required bool answered}) : super(autoLoad: false) {
    state = AsyncValue.data(
      HomeQotdState(
        date: '2026-11-17',
        quizTitle: 'Daily Lore',
        questionId: 'qq-1',
        questionText: 'Where is Hundred Islands?',
        options: const [
          HomeQotdOption(id: 'o1', ordinal: 1, text: 'Alaminos'),
        ],
        answered: answered,
        selectedOptionId: answered ? 'o1' : null,
        correct: answered,
        explanation: answered ? 'Alaminos City has them.' : null,
      ),
    );
  }
}

class _Answering extends HomeQotdNotifier {
  _Answering(super.ref, this.right) : super(autoLoad: false) {
    state = const AsyncValue.data(
      HomeQotdState(
        date: '2026-11-19',
        quizTitle: 'Daily Lore',
        questionId: 'qq-3',
        questionText: 'Where is Hundred Islands?',
        options: [HomeQotdOption(id: 'o1', ordinal: 1, text: 'Alaminos')],
      ),
    );
  }

  final bool right;

  @override
  Future<void> answer(String optionId) async {
    final current = state.value!;
    if (current.answered) return;
    state = AsyncValue.data(current.copyWith(
      answered: true,
      selectedOptionId: optionId,
      correct: right,
    ));
  }
}

class _Missed extends HomeQotdNotifier {
  _Missed(super.ref) : super(autoLoad: false) {
    state = const AsyncValue.data(
      HomeQotdState(
        date: '2026-11-17',
        quizTitle: 'Daily Lore',
        questionId: 'qq-2',
        questionText: 'Patar Beach is in which town?',
        options: [
          HomeQotdOption(id: 'o1', ordinal: 1, text: 'Anda'),
          HomeQotdOption(id: 'o2', ordinal: 2, text: 'Bolinao'),
          HomeQotdOption(id: 'o3', ordinal: 3, text: 'Sual'),
        ],
        answered: true,
        selectedOptionId: 'o1',
        correct: false,
        correctOptionId: 'o2',
      ),
    );
  }
}
