import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/explore/recommendation_reason.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

SpotModel _makeSpot({
  String? questId,
  String crowdStatus = 'unknown',
  String trustLevel = 'unverified',
  List<String> reasons = const [],
}) {
  return SpotModel(
    id: 'test-spot-1',
    slug: 'test-spot',
    name: 'Test Spot',
    description: 'A wonderful destination in Pangasinan.',
    category: 'nature_outdoors',
    subcategory: 'beach',
    municipality: 'Bolinao',
    address: 'Patar, Bolinao, Pangasinan',
    sourceName: 'Tourism Office',
    trustLevel: trustLevel,
    crowdStatus: crowdStatus,
    gpsLat: 16.3,
    gpsLng: 119.8,
    tags: const ['beach'],
    reasons: reasons,
    questId: questId,
  );
}

void main() {
  group('getTopRecommendationReason', () {
    test('returns "Quest available" when questId is present', () {
      final spot = _makeSpot(
        questId: 'quest-123',
        crowdStatus: 'quiet',
        trustLevel: 'lgu_verified',
      );
      expect(getTopRecommendationReason(spot), 'Quest available');
    });

    test('returns "Quest available" when reasons include quest mention', () {
      final spot = _makeSpot(reasons: ['Active quest available']);
      expect(getTopRecommendationReason(spot), 'Quest available');
    });

    test('returns "Quiet now" when crowdStatus is quiet and no quest', () {
      final spot = _makeSpot(crowdStatus: 'quiet', trustLevel: 'lgu_verified');
      expect(getTopRecommendationReason(spot), 'Quiet now');
    });

    test(
      'returns "Quiet now" when reasons include quiet mention and no quest',
      () {
        final spot = _makeSpot(reasons: ['Currently quiet']);
        expect(getTopRecommendationReason(spot), 'Quiet now');
      },
    );

    test(
      'returns "LGU verified" when trustLevel is lgu_verified and not quiet, no quest',
      () {
        final spot = _makeSpot(trustLevel: 'lgu_verified');
        expect(getTopRecommendationReason(spot), 'LGU verified');
      },
    );

    test(
      'returns "LGU verified" when reasons include verified and no quest/quiet',
      () {
        final spot = _makeSpot(reasons: ['LGU Verified']);
        expect(getTopRecommendationReason(spot), 'LGU verified');
      },
    );

    test('returns null when spot has no truthful reasons', () {
      final spot = _makeSpot(
        trustLevel: 'open_data',
        crowdStatus: 'unknown',
        reasons: ['Matches your interest', 'Recently added'],
      );
      expect(getTopRecommendationReason(spot), isNull);
    });

    test('prioritizes personalized ExploreRanker v2 reasons when present', () {
      expect(
        getTopRecommendationReason(
          _makeSpot(reasons: ['Saved in your wishlist', 'LGU verified']),
        ),
        'Saved in your wishlist',
      );
      expect(
        getTopRecommendationReason(
          _makeSpot(reasons: ['Visited by @aira_coast', 'LGU verified']),
        ),
        'Visited by @aira_coast',
      );
      expect(
        getTopRecommendationReason(
          _makeSpot(
            reasons: ['Because you liked Patar White Beach', 'Quiet now'],
          ),
        ),
        'Because you liked Patar White Beach',
      );
      expect(
        getTopRecommendationReason(
          _makeSpot(reasons: ['Matches your Nature & Outdoors interests']),
        ),
        'Matches your Nature & Outdoors interests',
      );
      expect(
        getTopRecommendationReason(
          _makeSpot(reasons: ['Quiet Hidden Gem in Bolinao']),
        ),
        'Quiet Hidden Gem in Bolinao',
      );
      expect(
        getTopRecommendationReason(
          _makeSpot(reasons: ['Popular · 3 likes', 'Quiet now']),
        ),
        'Popular · 3 likes',
      );
    });
  });
}
