import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/plaza/activity_text.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';

void main() {
  group('humanizeSlug (Plan 79a)', () {
    test('converts UPPER_SNAKE_CASE and lower_snake_case slugs to Title Case', () {
      expect(humanizeSlug('BALLOT_BOX'), 'Ballot Box');
      expect(humanizeSlug('FIRST_VOICE'), 'First Voice');
      expect(humanizeSlug('ECO_PIONEER'), 'Eco Pioneer');
      expect(humanizeSlug('ballot_box'), 'Ballot Box');
      expect(humanizeSlug('first_voice'), 'First Voice');
      expect(humanizeSlug('town_scout'), 'Town Scout');
      expect(humanizeSlug('civic_first_voice'), 'Civic First Voice');
    });

    test('leaves non-snake_case strings completely unchanged', () {
      expect(humanizeSlug('SM City'), 'SM City');
      expect(humanizeSlug("McDonald's"), "McDonald's");
      expect(humanizeSlug('2026-W45'), '2026-W45');
      expect(humanizeSlug('Pangasinan Eco Escapes & Cascades'),
          'Pangasinan Eco Escapes & Cascades');
      expect(humanizeSlug('Hundred Islands'), 'Hundred Islands');
      expect(humanizeSlug(''), '');
      expect(humanizeSlug('   '), '   ');
    });
  });

  group('formatActivityText (Plan 79a - no raw enums in feed)', () {
    test('leaves "SM City", "McDonald\'s" and "2026-W45" unchanged through formatActivityText', () {
      final smCityActivity = ActivityItemModel(
        id: 'act-sm',
        verb: 'quest_completed',
        actorName: 'Scout Franco',
        subjectType: 'quest',
        subjectTitle: 'SM City',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'points': 50},
      );
      expect(
        formatActivityText(smCityActivity).sentence,
        'Scout Franco completed SM City',
      );

      final mcdActivity = ActivityItemModel(
        id: 'act-mcd',
        verb: 'spot_posted',
        actorName: 'Scout Ella',
        subjectType: 'spot',
        subjectTitle: "McDonald's",
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {},
      );
      expect(
        formatActivityText(mcdActivity).sentence,
        "Scout Ella shared a new spot: McDonald's",
      );

      final weekActivity = ActivityItemModel(
        id: 'act-w45',
        verb: 'weekly_champion',
        actorName: 'Scout Juan',
        subjectType: 'champion',
        subjectTitle: 'Champion',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'place': 1, 'week_id': '2026-W45'},
      );
      expect(
        formatActivityText(weekActivity).sentence,
        'Scout Juan is the Weekly Champion of 2026-W45 🏆',
      );
    });

    test('badge_earned omits slug icon from sentence and humanizes snake_case badge subject', () {
      final slugIconBadge = ActivityItemModel(
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

      final formatted = formatActivityText(slugIconBadge);
      expect(formatted.sentence, 'Scout Ella earned the First Voice badge');
      expect(formatted.sentence.contains('BALLOT_BOX'), isFalse);
      expect(formatted.sentence.contains('Ballot Box'), isFalse);
      expect(formatted.sentence.contains('first_voice'), isFalse);
      expect(formatted.badgeIcon, isNull);
    });

    test('badge_earned omits single-word ASCII slug icon from sentence', () {
      final compassIconBadge = ActivityItemModel(
        id: 'act-1a',
        verb: 'badge_earned',
        actorName: 'Scout Franco',
        subjectType: 'badge',
        subjectTitle: 'First Footstep',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'icon': 'compass'},
      );

      final formatted = formatActivityText(compassIconBadge);
      expect(formatted.sentence, 'Scout Franco earned the First Footstep badge');
      expect(formatted.sentence.contains('compass'), isFalse);
      expect(formatted.badgeIcon, isNull);
    });

    test('badge_earned keeps emoji icon in sentence as is', () {
      final emojiIconBadge = ActivityItemModel(
        id: 'act-1b',
        verb: 'badge_earned',
        actorName: 'Scout Ella',
        subjectType: 'badge',
        subjectTitle: 'Island Hopper',
        reason: 'everyone',
        cheerCount: 0,
        cheeredByMe: false,
        commentCount: 0,
        createdAt: DateTime(2026, 11, 8),
        payload: const {'icon': '🏝️'},
      );

      final formatted = formatActivityText(emojiIconBadge);
      expect(formatted.sentence, 'Scout Ella earned the Island Hopper badge 🏝️');
      expect(formatted.badgeIcon, '🏝️');
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

    test('humanizes weekly_champion with snake_case week id', () {
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
