import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/recap/recap_provider.dart';
import 'package:juanderquest_app/features/recap/recap_screen.dart';

const _recap = Recap(
  periodId: 'season:2026-S4',
  periodLabel: 'Oct - Dec 2026',
  questsCompleted: 3,
  towns: ['Alaminos City', 'Bolinao', 'Dagupan City'],
  townsTotal: 44,
  spotsPosted: 1,
  quizzesPassed: 2,
  stampsEarned: 9,
  bestStreak: 6,
  persona: 'Heritage Hunter',
  whereNext: 'San Fabian',
);

const _empty = Recap(
  periodId: 'season:2026-S4',
  periodLabel: 'Oct - Dec 2026',
  questsCompleted: 0,
  towns: [],
  townsTotal: 44,
  spotsPosted: 0,
  quizzesPassed: 0,
  stampsEarned: 0,
  bestStreak: 0,
);

Widget _app(Recap Function(String? period) recapFor) => ProviderScope(
      overrides: [
        recapProvider.overrideWith((ref, period) async => recapFor(period)),
      ],
      child: const MaterialApp(home: RecapScreen()),
    );

void main() {
  test('Recap.fromJson reads the API shape', () {
    final r = Recap.fromJson({
      'period': {'id': 'year:2026', 'kind': 'year', 'label': '2026'},
      'quests_completed': 4,
      'towns': ['Bolinao'],
      'towns_total': 44,
      'spots_posted': 1,
      'quizzes_passed': 2,
      'stamps_earned': 5,
      'best_streak': 3,
      'persona': 'Coastal Wanderer',
      'where_next': 'Lingayen',
    });
    expect(r.periodLabel, '2026');
    expect(r.towns, ['Bolinao']);
    expect(r.persona, 'Coastal Wanderer');
    expect(r.isEmpty, isFalse);
  });

  testWidgets('Plan 62: the story opens on the persona and swipes to the next slide', (tester) async {
    await tester.pumpWidget(_app((_) => _recap));
    await tester.pumpAndSettle();
    expect(find.text('Heritage Hunter'), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('recap_share')), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('recap_pages')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recap_slide_quests')), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);
  });

  testWidgets('Plan 62: "This year" asks for the year and starts again at slide 1', (tester) async {
    final asked = <String?>[];
    await tester.pumpWidget(_app((p) {
      asked.add(p);
      return _recap;
    }));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('recap_pages')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recap_period_year')));
    await tester.pumpAndSettle();
    expect(asked.last, 'year:${DateTime.now().year}');
    expect(find.text('1 / 6'), findsOneWidget);
  });

  testWidgets('Plan 62: an empty season points to the quests', (tester) async {
    await tester.pumpWidget(_app((_) => _empty));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recap_empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('recap_share')), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('Plan 62: no overflow at $size with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
        child: _app((_) => _recap),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byKey(const ValueKey('recap_pages')), Offset(-size.width, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
