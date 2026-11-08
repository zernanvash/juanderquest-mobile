import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/games/laro_board.dart';

// Plan 77 WP-4: the Laro (AR mini-game) boards.
void main() {
  final week = LaroBoard.fromJson(const {
    'entries': [
      {'rank': 1, 'handle': 'clara', 'display_name': 'Clara', 'score': 4200},
      {'rank': 2, 'display_name': 'Anonymous Explorer', 'score': 9000},
    ],
    'me': {
      'rank': 14,
      'display_name': 'A very long explorer display name for the board',
      'score': 15000,
      'is_self': true
    },
    'lower_is_better': true,
  });

  test('parses the board; Palayok scores are seconds', () {
    expect(week.entries.map((e) => e.name), ['@clara', 'Anonymous Explorer']);
    expect(week.me!.rank, 14);
    expect(week.show(4200), '4.2 s');
    expect(const LaroBoard().show(64), '64');
  });

  Widget app(LaroBoard board, Size size) => ProviderScope(
        overrides: [
          laroBoardProvider.overrideWith((ref, key) async => key.startsWith('week:') ? board : const LaroBoard())
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
            child: const LaroBoardScreen(initialGame: 'pabitin_palayok'),
          ),
        ),
      );

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('the weekly board fits at ${size.width.toInt()}x${size.height.toInt()} with 2x text and shows you',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(week, size));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('@clara'), findsOneWidget);
      expect(find.text('4.2 s'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('(you)'), 100,
          scrollable:
              find.descendant(of: find.byKey(const ValueKey('laro_board_list')), matching: find.byType(Scrollable)));
      expect(find.text('15.0 s'), findsOneWidget);
    });
  }

  testWidgets('an empty week invites a first game', (tester) async {
    await tester.pumpWidget(app(const LaroBoard(), const Size(400, 800)));
    await tester.pumpAndSettle();
    expect(find.textContaining('No games yet this week'), findsOneWidget);
  });
}
