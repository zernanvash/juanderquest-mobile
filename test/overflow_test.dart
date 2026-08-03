import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/providers/voucher_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/vote/models/governance_config_model.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';
import 'package:juanderquest_app/features/vote/providers/governance_provider.dart';
import 'package:juanderquest_app/features/wallet/models/wallet_model.dart';
import 'package:juanderquest_app/features/wallet/providers/wallet_provider.dart';

import 'package:juanderquest_app/features/quests/screens/quest_list_screen.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/vote/screens/vote_screen.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';

// Inert Subclasses to prevent Dio/network calls and pending timers
class InertAuthNotifier extends AuthNotifier {
  InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class InertQuestNotifier extends QuestNotifier {
  InertQuestNotifier(super.apiClient, List<QuestModel> fixtureQuests) {
    state = QuestState(quests: fixtureQuests, isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class InertSubmissionNotifier extends SubmissionNotifier {
  InertSubmissionNotifier(super.apiClient, List<SubmissionModel> fixtureSubmissions) {
    state = SubmissionState(submissions: fixtureSubmissions, isLoading: false);
  }

  @override
  Future<void> fetchSubmissions() async {}
}

class InertVoucherNotifier extends VoucherNotifier {
  InertVoucherNotifier(super.ref, List<VoucherModel> fixtureVouchers) {
    state = VoucherState(vouchers: fixtureVouchers, isLoading: false);
  }

  @override
  Future<void> fetchVouchers() async {}
}

class InertGovernanceNotifier extends GovernanceNotifier {
  InertGovernanceNotifier(super.ref, List<GovernanceProposalModel> fixtureProposals) {
    state = GovernanceState(
      proposals: fixtureProposals,
      config: GovernanceConfigModel(
        voteFeeMjdq: 10,
        burnBps: 2000,
        escrowBps: 8000,
        organizerBondMjdq: 25000,
        quorumBps: 1500,
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> loadGovernanceData() async {}
}

class InertWalletNotifier extends WalletNotifier {
  InertWalletNotifier(super.ref, WalletModel fixtureWallet) {
    state = AsyncValue.data(fixtureWallet);
  }

  @override
  Future<void> fetchWallet() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyUser = UserModel(
    id: 'u1',
    seedId: 'seed_01',
    displayName: 'Juan Dela Cruz',
    email: 'juan@juanderquest.ph',
    avatarUrl: 'https://example.com/avatar.png',
    role: 'explorer',
    demoPoints: 500,
  );

  final dummyQuest = QuestModel(
    id: 'q1',
    title: 'Hundred Islands Eco Trek',
    description: 'Explore the islands',
    category: 'eco',
    locationName: 'Alaminos, Pangasinan',
    gpsLat: 16.2,
    gpsLng: 119.9,
    radiusMeters: 150,
    rewardPoints: 50,
    markerCode: 'M01',
    markerImageUrl: 'https://example.com/marker.png',
  );

  final dummyVoucher = VoucherModel(
    id: 'v1',
    merchantName: 'Dagupan Bangus Grill',
    offerTitle: '₱100 Discount Voucher',
    costPoints: 50,
    category: 'food_trade',
    location: 'Dagupan City',
    description: 'Enjoy delicious grilled bangus.',
    isActive: true,
  );

  final dummyProposal = GovernanceProposalModel(
    id: 'p1',
    title: 'Patar White Beach Eco Trail',
    locationName: 'Bolinao, Pangasinan',
    category: 'eco',
    description: 'Community eco-tourism trail.',
    status: 'voting',
    submittedById: 'u1',
    submittedByName: 'Juan Dela Cruz',
    yesVotes: 15,
    noVotes: 5,
    yesWeightMjdq: 150,
    noWeightMjdq: 50,
    totalVoters: 20,
    bondMjdq: 25000,
    escrowedMjdq: 160,
  );

  final dummyWallet = WalletModel(
    settlement: 'off-chain prototype',
    unit: 'mJDQ',
    balanceMjdq: 1000,
    balanceJdq: 1.0,
  );

  Future<void> testScreenOverflow(
    WidgetTester tester,
    Widget child,
    Size size,
    double textScale,
  ) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyUser)),
          questProvider.overrideWith((ref) => InertQuestNotifier(ref.watch(apiClientProvider), [dummyQuest])),
          submissionProvider.overrideWith((ref) => InertSubmissionNotifier(ref.watch(apiClientProvider), [])),
          voucherProvider.overrideWith((ref) => InertVoucherNotifier(ref, [dummyVoucher])),
          governanceProvider.overrideWith((ref) => InertGovernanceNotifier(ref, [dummyProposal])),
          walletProvider.overrideWith((ref) => InertWalletNotifier(ref, dummyWallet)),
        ],
        child: MaterialApp(
          home: child,
        ),
      ),
    );
    await tester.pump();

    // Verify no RenderFlex overflow exceptions occurred during layout
    final exception = tester.takeException();
    if (exception != null) {
      expect(exception.toString().contains('RenderFlex overflowed'), isFalse,
          reason: 'Screen overflowed: $exception');
    }
  }

  group('Screen Overflow Tests (320x568 portrait & 568x320 landscape, 2.0 text scale)', () {
    testWidgets('QuestListScreen does not overflow in small portrait', (tester) async {
      await testScreenOverflow(tester, const QuestListScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('QuestListScreen does not overflow in small landscape', (tester) async {
      await testScreenOverflow(tester, const QuestListScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('ShopScreen does not overflow in small portrait', (tester) async {
      await testScreenOverflow(tester, const ShopScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ProfileScreen does not overflow in small portrait', (tester) async {
      await testScreenOverflow(tester, const ProfileScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('VoteScreen does not overflow in small portrait', (tester) async {
      await testScreenOverflow(tester, const VoteScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('MapViewScreen does not overflow in small portrait', (tester) async {
      await testScreenOverflow(tester, const MapViewScreen(), const Size(320, 568), 2.0);
    });
  });
}
