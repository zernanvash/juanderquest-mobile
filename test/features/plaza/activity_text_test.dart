import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/plaza/activity_text.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';

void main() {
  group('humanizeSlug (Plan 79a)', () {
    test('converts UPPER_SNAKE_CASE to Title Case', () {
      expect(humanizeSlug('BALLOT_BOX'), 'Ballot Box');
      expect(humanizeSlug('FIRST_VOICE'), 'First Voice');
      expect(humanizeSlug('ECO_PIONEER'), 'Eco Pioneer');
    });

    test('converts lower_snake_case to Title Case', () {
      expect(humanizeSlug('ballot_box'), 'Ballot Box');
      expect(humanizeSlug('first_voice'), 'First Voice');
      expect(humanizeSlug('town_scout'), 'Town Scout');
      expect(humanizeSlug('civic_first_voice'), 'Civic First Voice');
    });

    test('handles multiple consecutive underscores and whitespace', () {
      expect(humanizeSlug('__multiple__underscores__'), 'Multiple Underscores');
      expect(humanizeSlug('  spaced_out_slug  '), 'Spaced Out Slug');
    });

    test('preserves already-humanized words and mixed strings', () {
      expect(humanizeSlug('Pangasinan Eco Escapes & Cascades'),
          'Pangasinan Eco Escapes & Cascades');
      expect(humanizeSlug('Hundred Islands'), 'Hundred Islands');
    });

    test('handles empty and whitespace-only strings gracefully', () {
      expect(humanizeSlug(''), '');
      expect(humanizeSlug('   '), '');
    });
  });

  group('formatActivityText (Plan 79a - no raw enums in feed)', () {
    test('humanizes badge_earned with uppercase slug in payload icon', () {
      final activity = ActivityItemModel(
        id: 'act-1',
        verb: 'badge_earned',
        actorName: 'Scout Ella',
        subjectType: 'badge',
        subjectTitle: 'first_voice',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'icon': 'BALLOT_BOX'},
      );

      final formatted = formatActivityText(activity);
      expect(formatted.sentence, 'Scout Ella earned the First Voice badge Ballot Box');
      expect(formatted.sentence.contains('BALLOT_BOX'), isFalse);
      expect(formatted.sentence.contains('first_voice'), isFalse);
      expect(formatted.badgeIcon, 'Ballot Box');
    });

    test('humanizes level_up with slug title', () {
      final activity = ActivityItemModel(
        id: 'act-2',
        verb: 'level_up',
        actorName: 'Scout Franco',
        subjectType: 'level',
        subjectTitle: 'Level 5',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'level': 5, 'title': 'master_scout'},
      );

      final formatted = formatActivityText(activity);
      expect(formatted.sentence, 'Scout Franco reached Level 5 · Master Scout');
      expect(formatted.sentence.contains('master_scout'), isFalse);
    });

    test('humanizes weekly_champion with slug week id', () {
      final activity = ActivityItemModel(
        id: 'act-3',
        verb: 'weekly_champion',
        actorName: 'Scout Juan',
        subjectType: 'champion',
        subjectTitle: 'Champion',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'place': 1, 'week_id': 'week_45_2026'},
      );

      final formatted = formatActivityText(activity);
      expect(formatted.sentence, 'Scout Juan is the Weekly Champion of Week 45 2026 🏆');
      expect(formatted.sentence.contains('week_45_2026'), isFalse);
    });
  });
}
