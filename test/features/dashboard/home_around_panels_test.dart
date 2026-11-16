import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/models/home_calendar_entry.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_calendar_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_recommended_quest_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_around_panels.dart';

HomeCalendarEntry _e(
  String id,
  DateTime start, {
  CalendarEntryKind kind = CalendarEntryKind.festival,
  bool monthOnly = false,
  DateTime? end,
}) =>
    HomeCalendarEntry(
      id: id,
      title: 'Event $id',
      shortBadge: 'F',
      kind: kind,
      startDate: start,
      endDate: end ?? start,
      route: '/almanac',
      municipality: 'Dagupan',
      monthOnly: monthOnly,
    );

void main() {
  final today = DateTime(2026, 11, 17);

  test('next event: earliest that has not ended, never a streak day', () {
    final next = HomeNextEventPanel.pick([
      _e('past', DateTime(2026, 11, 10)),
      _e('streak', DateTime(2026, 11, 17), kind: CalendarEntryKind.stampStreak),
      _e('later', DateTime(2026, 12, 5)),
      _e('soon', DateTime(2026, 11, 20)),
    ], today);
    expect(next?.id, 'soon');
    expect(HomeNextEventPanel.pick([_e('past', DateTime(2026, 1, 1))], today),
        isNull);
  });

  test('next event: how soon it is', () {
    expect(HomeNextEventPanel.when(_e('a', DateTime(2026, 11, 20)), today),
        'IN 3 DAYS');
    expect(HomeNextEventPanel.when(_e('a', DateTime(2026, 11, 18)), today),
        'TOMORROW');
    expect(
        HomeNextEventPanel.when(
            _e('a', DateTime(2026, 11, 15), end: DateTime(2026, 11, 19)),
            today),
        'NOW');
    expect(
        HomeNextEventPanel.when(
            _e('a', DateTime(2026, 11, 1), monthOnly: true), today),
        'THIS MONTH');
    expect(
        HomeNextEventPanel.when(
            _e('a', DateTime(2026, 12, 1), monthOnly: true), today),
        'DECEMBER');
  });

  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets('panels fit at $size with 2x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          homeLastKnownLocationProvider.overrideWith((ref) async => null),
          homeCalendarEntriesProvider.overrideWith(
            (ref, year) => year == 2026
                ? [_e('soon', DateTime(2026, 11, 20))]
                : const <HomeCalendarEntry>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const HomeNearbyPanel(),
                  HomeNextEventPanel(now: today),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // No location: Home never asks; it points to the Map instead.
      expect(find.byKey(const ValueKey('home_nearby_empty')), findsOneWidget);
      expect(find.text('Event soon'), findsOneWidget);
      expect(find.text('IN 3 DAYS'), findsOneWidget);
    });
  }
}
