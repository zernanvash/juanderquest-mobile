import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/vote/models/governance_config_model.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

void main() {
  group('Backend Contract Alignment Tests', () {
    test('VoucherModel.fromJson parses API response correctly', () {
      final json = {
        'id': 'v1111111-1111-1111-1111-111111111111',
        'merchant_name': 'Dagupan Bangus Grill',
        'offer_title': '₱100 Discount',
        'cost_points': 50,
        'category': 'FOOD & DINING',
        'location': 'Dagupan City',
        'description': 'Test voucher',
        'is_active': true,
      };

      final voucher = VoucherModel.fromJson(json);
      expect(voucher.id, 'v1111111-1111-1111-1111-111111111111');
      expect(voucher.merchantName, 'Dagupan Bangus Grill');
      expect(voucher.costPoints, 50);
      expect(voucher.isActive, isTrue);
    });

    test('QuestModel.fromJson parses API response & formats categoryDisplay', () {
      final json = {
        'id': 'q1',
        'title': 'Hundred Islands',
        'description': 'Eco trek',
        'category': 'eco',
        'location_name': 'Alaminos',
        'gps_lat': 16.2,
        'gps_lng': 119.9,
        'radius_meters': 150,
        'reward_points': 50,
        'marker_code': 'MARKER_01',
        'marker_image_url': 'http://example.com/img.png',
      };

      final quest = QuestModel.fromJson(json);
      expect(quest.id, 'q1');
      expect(quest.categoryDisplay, 'Eco-Tourism');
      expect(quest.rewardPoints, 50);
    });

    test('GovernanceConfigModel.fromJson parses API config response correctly', () {
      final json = {
        'vote_fee_mjdq': 10,
        'burn_bps': 2000,
        'escrow_bps': 8000,
        'organizer_bond_mjdq': 25000,
        'quorum_bps': 1500,
      };

      final config = GovernanceConfigModel.fromJson(json);
      expect(config.voteFeeMjdq, 10);
      expect(config.burnPercent, 20.0);
      expect(config.escrowPercent, 80.0);
    });

    test('GovernanceProposalModel.fromJson parses API proposal response', () {
      final json = {
        'id': 'p1',
        'title': 'Patar White Beach Trail',
        'location_name': 'Bolinao',
        'category': 'eco',
        'description': 'Eco proposal',
        'status': 'voting',
        'yes_votes': 15,
        'no_votes': 5,
        'total_votes': 20,
      };

      final prop = GovernanceProposalModel.fromJson(json);
      expect(prop.id, 'p1');
      expect(prop.yesPercentage, 75.0);
      expect(prop.noPercentage, 25.0);
    });
  });

  group('Profile Stats Logic Tests', () {
    test('profileStatsProvider sums approved reward points & computes eco badge correctly', () {
      final approvedEco = SubmissionModel(
        id: 's1',
        questTitle: 'Eco Quest',
        category: 'eco',
        status: 'approved',
        rewardPoints: 50,
        createdAt: '2026-08-01',
      );
      final approvedCultural = SubmissionModel(
        id: 's2',
        questTitle: 'Cultural Quest',
        category: 'cultural',
        status: 'approved',
        rewardPoints: 100,
        createdAt: '2026-08-01',
      );

      final container = ProviderContainer(
        overrides: [
          submissionProvider.overrideWith(
            (ref) => SubmissionNotifier(ref.watch(apiClientProvider))
              ..state = SubmissionState(submissions: [approvedEco, approvedCultural]),
          ),
        ],
      );

      final stats = container.read(profileStatsProvider);
      expect(stats.completedQuestsCount, 2);
      expect(stats.totalPointsEarned, 150);
      expect(stats.ecoPioneerState, BadgeState.earned);
      expect(stats.heritageKeeperState, BadgeState.earned);
      expect(stats.foodExplorerState, BadgeState.locked);
    });
  });
}
