import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/spots/explore/juanchoice_placement.dart';

class _FakeSpot {
  const _FakeSpot(this.id, this.name);
  final String id;
  final String name;
}

void main() {
  group('planJuanChoicePlacement', () {
    final now = DateTime(2026, 11, 3, 12, 0);

    test('returns null spotlight and -1 index when spotlight is null', () {
      const spots = [
        _FakeSpot('s1', 'Spot 1'),
        _FakeSpot('s2', 'Spot 2'),
      ];

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: null,
        now: now,
      );

      expect(result.spotlight, isNull);
      expect(result.ordinary.length, 2);
      expect(result.insertionIndex, -1);
      expect(result.hasSpotlight, isFalse);
    });

    test('returns null spotlight when spotlight is expired', () {
      const spots = [
        _FakeSpot('s1', 'Spot 1'),
        _FakeSpot('s2', 'Spot 2'),
      ];

      final expiredSpotlight = ChoiceSpotlight(
        campaignId: 'c1',
        theme: 'Best Seafood',
        expiresAt: DateTime(2026, 11, 2, 12, 0), // yesterday
        winnerSpotIds: {'s1'},
      );

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: expiredSpotlight,
        now: now,
      );

      expect(result.spotlight, isNull);
      expect(result.ordinary.length, 2);
      expect(result.insertionIndex, -1);
    });

    test('returns null spotlight when winnerSpotIds is empty', () {
      const spots = [
        _FakeSpot('s1', 'Spot 1'),
      ];

      final emptyWinners = ChoiceSpotlight(
        campaignId: 'c1',
        theme: 'Best Seafood',
        expiresAt: DateTime(2026, 11, 4, 12, 0),
        winnerSpotIds: {},
      );

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: emptyWinners,
        now: now,
      );

      expect(result.spotlight, isNull);
      expect(result.ordinary.length, 1);
      expect(result.insertionIndex, -1);
    });

    test('filters out winner spots and inserts at min(3, ordinary.length)', () {
      const spots = [
        _FakeSpot('s1', 'Spot 1'),
        _FakeSpot('w1', 'Winner 1'),
        _FakeSpot('s2', 'Spot 2'),
        _FakeSpot('s3', 'Spot 3'),
        _FakeSpot('s4', 'Spot 4'),
        _FakeSpot('s5', 'Spot 5'),
      ];

      final spotlight = ChoiceSpotlight(
        campaignId: 'c1',
        theme: 'Best Heritage Sites',
        expiresAt: DateTime(2026, 11, 10, 0, 0),
        winnerSpotIds: {'w1'},
      );

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: spotlight,
        now: now,
      );

      expect(result.spotlight, isNotNull);
      expect(result.hasSpotlight, isTrue);
      // 'w1' should be removed from ordinary
      expect(result.ordinary.map((s) => s.id).toList(),
          ['s1', 's2', 's3', 's4', 's5']);
      // ordinary.length is 5, so min(3, 5) = 3
      expect(result.insertionIndex, 3);
    });

    test('clamps insertion index to ordinary.length when list has fewer than 3 items', () {
      const spots = [
        _FakeSpot('s1', 'Spot 1'),
        _FakeSpot('w1', 'Winner 1'),
      ];

      final spotlight = ChoiceSpotlight(
        campaignId: 'c1',
        theme: 'Best Beach',
        expiresAt: DateTime(2026, 11, 10, 0, 0),
        winnerSpotIds: {'w1'},
      );

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: spotlight,
        now: now,
      );

      expect(result.ordinary.length, 1);
      // min(3, 1) = 1
      expect(result.insertionIndex, 1);
    });

    test('sets insertion index to 0 when ordinary is empty', () {
      const spots = [
        _FakeSpot('w1', 'Winner 1'),
      ];

      final spotlight = ChoiceSpotlight(
        campaignId: 'c1',
        theme: 'Solo Winner',
        expiresAt: DateTime(2026, 11, 10, 0, 0),
        winnerSpotIds: {'w1'},
      );

      final result = planJuanChoicePlacement<_FakeSpot>(
        spots: spots,
        idOf: (s) => s.id,
        spotlight: spotlight,
        now: now,
      );

      expect(result.ordinary, isEmpty);
      // min(3, 0) = 0
      expect(result.insertionIndex, 0);
    });
  });
}
