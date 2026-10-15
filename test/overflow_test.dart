import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';

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
import 'package:juanderquest_app/features/quests/screens/campaign_detail_screen.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/vote/screens/vote_screen.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_explore_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_search_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/models/hidden_gem_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:juanderquest_app/features/about/screens/about_screen.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_playground_screen.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_test_screen.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_calibration_screen.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';
import 'package:juanderquest_app/features/app_update/widgets/startup_update_gate.dart';
import 'package:juanderquest_app/features/app_update/widgets/update_dialog.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';

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
  InertSubmissionNotifier(
      super.apiClient, List<SubmissionModel> fixtureSubmissions) {
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
  InertGovernanceNotifier(
      super.ref, List<GovernanceProposalModel> fixtureProposals) {
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

class InertCampaignNotifier extends CampaignNotifier {
  InertCampaignNotifier(super.apiClient, List<CampaignModel> fixtureCampaigns) {
    state = CampaignState(campaigns: fixtureCampaigns, isLoading: false);
  }

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}

class InertWalletNotifier extends WalletNotifier {
  InertWalletNotifier(super.ref, WalletModel fixtureWallet) {
    state = AsyncValue.data(fixtureWallet);
  }

  @override
  Future<void> fetchWallet() async {}
}

class InertSpotDiscoveryNotifier extends SpotDiscoveryNotifier {
  InertSpotDiscoveryNotifier(super.ref, List<SpotModel> fixtureSpots) {
    state = SpotDiscoveryState(
      spots: fixtureSpots,
      categories: const ['nature_outdoors', 'eat_drink', 'culture_heritage'],
      isInitialLoading: false,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load(
      {String query = '',
      String category = '',
      String intent = '',
      bool refresh = false}) async {}
}

class InertUpdateRepository implements IUpdateRepository {
  final AppVersionInfo? versionInfo;
  InertUpdateRepository({this.versionInfo});

  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      versionInfo;

  @override
  Future<bool> isDartPatchAvailable() async => false;

  @override
  Future<bool> downloadAndInstallDartPatch(
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<bool> syncContentBundle(ContentManifestMetadata metadata,
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<void> restartApp() async {}
}

class InertStartupUpdateController extends StartupUpdateController {
  InertStartupUpdateController(super.repository, StartupGateState fixedState) {
    state = fixedState;
  }

  @override
  Future<void> initStartupGate() async {}
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
    markerImageUrl: 'https://example.com/marker.png',
  );

  const dummyCampaign = CampaignModel(
    id: 'bangus-festival-2026',
    hostId: 'dagupan-lgu',
    hostName: 'Dagupan City Tourism Office',
    title: 'Bangus Festival 2026: Gilon-Gilon Street Dance & Grill Quest',
    category: 'cultural',
    locationName: 'Dagupan City Plaza, AB Fernandez Ave',
    municipality: 'Dagupan City',
    bannerImageUrl: 'https://example.com/bangus.jpg',
    description: 'Participate in the legendary Dagupan Bangus street dance.',
    eventDate: '2026-09-15T08:00:00Z',
    startDate: '2026-09-01T00:00:00Z',
    endDate: '2026-09-15T22:00:00Z',
    totalBudgetMjdq: 250000,
    rewardPerParticipantMjdq: 1500,
    referralBountyMjdq: 250,
    maxParticipants: 500,
    reservedParticipants: 342,
    completedParticipants: 120,
    preQuestRequirements: ['Complete Dagupan Bangus Market Check-in'],
    gpsLat: 16.0433,
    gpsLng: 120.3340,
    gpsRadiusMeters: 250,
    status: 'active',
    createdAt: '2026-08-01T00:00:00Z',
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

  const dummySpot = SpotModel(
    id: 's1',
    slug: 'hundred-islands-national-park',
    name: 'Hundred Islands National Park',
    description:
        'A protected archipelago of 124 pristine limestone islands and coral reefs.',
    category: 'nature_outdoors',
    subcategory: 'islands',
    municipality: 'Alaminos City',
    address: 'Lucap Wharf, Alaminos City',
    sourceName: 'Alaminos Tourism',
    trustLevel: 'lgu_verified',
    gpsLat: 16.2044,
    gpsLng: 120.0406,
    tags: ['beaches', 'island_hopping', 'snorkeling'],
    reasons: ['LGU Verified', 'Scenic Views'],
    crowdStatus: 'quiet',
    questId: 'q1',
    imageUrl: 'https://example.com/hundred_islands.jpg',
  );

  Future<void> testScreenOverflow(
    WidgetTester tester,
    Widget child,
    Size size,
    double textScale,
  ) async {
    final affiliateApi = ApiClient();
    affiliateApi.dio.interceptors.insert(0, InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/affiliate/applications/me') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ));
          return;
        }
        handler.next(options);
      },
    ));
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;

    final List<FlutterErrorDetails> overflowErrors = [];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.toString();
      if (msg.contains('RenderFlex overflowed') ||
          msg.contains('A RenderFlex overflowed')) {
        overflowErrors.add(details);
      }
      originalOnError?.call(details);
    };

    addTearDown(() {
      FlutterError.onError = originalOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (child is AffiliateApplicationScreen)
            apiClientProvider.overrideWithValue(affiliateApi),
          authProvider.overrideWith((ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser)),
          questProvider.overrideWith((ref) =>
              InertQuestNotifier(ref.watch(apiClientProvider), [dummyQuest])),
          campaignProvider.overrideWith((ref) => InertCampaignNotifier(
              ref.watch(apiClientProvider), [dummyCampaign])),
          submissionProvider.overrideWith((ref) =>
              InertSubmissionNotifier(ref.watch(apiClientProvider), [])),
          voucherProvider
              .overrideWith((ref) => InertVoucherNotifier(ref, [dummyVoucher])),
          governanceProvider.overrideWith(
              (ref) => InertGovernanceNotifier(ref, [dummyProposal])),
          walletProvider
              .overrideWith((ref) => InertWalletNotifier(ref, dummyWallet)),
          spotDiscoveryProvider.overrideWith(
              (ref) => InertSpotDiscoveryNotifier(ref, [dummySpot])),
          choiceSpotlightProvider.overrideWith((ref) async => null),
          choiceEngagementProvider
              .overrideWith((ref) async => const ChoiceEngagementSummary(
                    currentStreak: 3,
                    longestStreak: 4,
                    nextMilestone: 5,
                    verifiedVisits: 2,
                    uniqueDestinations: 2,
                    municipalities: 1,
                    participations: 1,
                    challenges: [],
                  )),
          choiceOverviewProvider
              .overrideWith((ref) async => const ChoiceOverview(
                    current: null,
                    nextOpensAt: null,
                    nextClosesAt: null,
                    nextTheme: null,
                    previous: null,
                    notice: null,
                    votingEnabled: false,
                  )),
          hiddenGemProvider.overrideWith((ref) async => const [
                HiddenGemModel(
                  id: 'spot-mangatarem-citrus-trail',
                  name: 'Mangatarem Calamansi & Citrus Orchard Heritage Trail',
                  municipality: 'Mangatarem, Pangasinan',
                  reason: 'Inspired by places you saved or liked',
                  crowdStatus: 'unknown',
                ),
              ]),
          startupUpdateControllerProvider
              .overrideWith((ref) => InertStartupUpdateController(
                    InertUpdateRepository(),
                    const StartupGateState(phase: GatePhase.ready),
                  )),
        ],
        child: MaterialApp(
          home: child,
        ),
      ),
    );

    await tester.pump();
    if (child is AffiliateApplicationScreen) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.scrollUntilVisible(find.text('Business location'), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Business location'), findsOneWidget);
    }

    // Verify no RenderFlex overflow exceptions occurred during layout
    tester.takeException();

    expect(
      overflowErrors,
      isEmpty,
      reason:
          'RenderFlex overflowed in test (${overflowErrors.length} errors):\n'
          '${overflowErrors.map((e) => e.toString()).join('\n')}',
    );
  }

  group(
      'Screen Overflow Tests (320x568 portrait & 568x320 landscape, 2.0 text scale)',
      () {
    testWidgets(
        'AffiliateApplicationScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(tester, const AffiliateApplicationScreen(),
          const Size(320, 568), 2.0);
    });

    testWidgets(
        'AffiliateApplicationScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(tester, const AffiliateApplicationScreen(),
          const Size(568, 320), 2.0);
    });
    testWidgets('DashboardScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const DashboardScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('DashboardScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const DashboardScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('SpotExploreScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotExploreScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('SpotExploreScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotExploreScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('SpotSearchScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotSearchScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('SpotSearchScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotSearchScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('QuestListScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const QuestListScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('QuestListScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const QuestListScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('CampaignDetailScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester,
          const CampaignDetailScreen(
              campaignId: 'bangus-festival-2026',
              initialCampaign: dummyCampaign),
          const Size(320, 568),
          2.0);
    });

    testWidgets('LeaderboardScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const LeaderboardScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('AboutScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const AboutScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ShopScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ShopScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ProfileScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ProfileScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('VoteScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const VoteScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('MapViewScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const MapViewScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('NavigationScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        const NavigationScreen(
          destination: NavTarget(
            name: 'Hundred Islands National Park',
            lat: 16.2045,
            lng: 120.0435,
            address: 'Alaminos City, Pangasinan',
          ),
        ),
        const Size(320, 568),
        2.0,
      );
    });

    testWidgets('ArPlaygroundScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ArPlaygroundScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ArTestScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ArTestScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ArTestScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const ArTestScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('ArCalibrationScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ArCalibrationScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('ArCalibrationScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const ArCalibrationScreen(), const Size(568, 320), 2.0);
    });

    testWidgets(
        'StartupUpdateGate checking view does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        const StartupUpdateGate(child: SizedBox()),
        const Size(320, 568),
        2.0,
      );
    });

    testWidgets(
        'StartupUpdateGate checking view does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const StartupUpdateGate(child: SizedBox()),
        const Size(568, 320),
        2.0,
      );
    });

    testWidgets('SettingsScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsScreen(), const Size(320, 568), 2.0);
    });

    testWidgets('SettingsScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsScreen(), const Size(568, 320), 2.0);
    });

    testWidgets('UpdateDialog does not overflow in small portrait',
        (tester) async {
      const info = AppVersionInfo(
        versionCode: 151,
        versionName: '1.0.1',
        downloadUrl: 'https://api.juanderquest.app/api/v1/app/download',
        changelog: 'New release notes and features.',
      );
      await testScreenOverflow(
        tester,
        const Scaffold(body: Center(child: UpdateDialog(versionInfo: info))),
        const Size(320, 568),
        2.0,
      );
    });
  });
}
