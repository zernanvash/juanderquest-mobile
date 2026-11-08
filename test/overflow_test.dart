import 'package:flutter/material.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';

import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/pixel/daily_mission.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/providers/voucher_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/screens/submission_history_screen.dart';
import 'package:juanderquest_app/features/spots/screens/saved_spots_screen.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/vote/models/governance_config_model.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';
import 'package:juanderquest_app/features/vote/providers/governance_provider.dart';
import 'package:juanderquest_app/features/wallet/models/wallet_model.dart';
import 'package:juanderquest_app/features/wallet/providers/wallet_provider.dart';

import 'package:juanderquest_app/features/quests/screens/quest_list_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/campaign_detail_screen.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';
import 'package:juanderquest_app/features/wallet/screens/wallet_connect_screen.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/profile/screens/badges_screen.dart';
import 'package:juanderquest_app/features/vote/screens/vote_screen.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_explore_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_search_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/models/hidden_gem_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:juanderquest_app/features/notifications/screens/notifications_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/trail/trail_coming_soon_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/providers/cultural_quiz_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_detail_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_play_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';
import 'package:juanderquest_app/features/vote/screens/proposal_list_screen.dart';
import 'package:juanderquest_app/features/plaza/plaza_screen.dart';
import 'package:juanderquest_app/features/plaza/plaza_provider.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/features/about/screens/about_screen.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_hunt.dart';
import 'package:juanderquest_app/features/ar_experience/core/heading_fusion.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_diagnostics_screen.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_quest_screen.dart';
import 'package:juanderquest_app/features/ar_experience/widgets/ar_overlay.dart';
import 'package:juanderquest_app/features/quests/screens/qr_scan_screen.dart';
import 'package:juanderquest_app/features/auth/screens/forgot_password_screen.dart';
import 'package:juanderquest_app/features/auth/screens/login_screen.dart';
import 'package:juanderquest_app/features/spots/screens/interests_screen.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_community_section.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';
import 'package:juanderquest_app/features/app_update/widgets/startup_update_gate.dart';
import 'package:juanderquest_app/features/app_update/widgets/update_dialog.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_posting_sheet.dart';
import 'package:juanderquest_app/features/spots/screens/spot_discovery_studio_screen.dart';
import 'package:juanderquest_app/features/spots/utils/spot_location_handoff.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';
import 'package:juanderquest_app/features/pixel_lab/home_options.dart';
import 'package:juanderquest_app/features/settings/screens/settings_updates_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_developer_screen.dart';
import 'package:juanderquest_app/features/pixel_lab/pixel_lab_screen.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_nav.dart';
import 'package:juanderquest_app/core/pixel/placeholder_art.dart';
import 'package:juanderquest_app/features/dashboard/data/home_events.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_dashboard_providers.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/onboarding/pixel_tutorial.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/screens/juanchoice_screen.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/cosmetics/screens/appearance_screen.dart';
import 'package:juanderquest_app/features/shop/providers/cosmetics_provider.dart';
import 'package:juanderquest_app/features/shop/models/cosmetic_item.dart';
import 'package:juanderquest_app/features/quests/screens/quest_builder_screen.dart';
import 'package:juanderquest_app/features/quests/screens/qr_sheet_screen.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';

// Inert Subclasses to prevent Dio/network calls and pending timers
class _MockQuestBuilderRepo extends QuestBuilderRepository {
  _MockQuestBuilderRepo(super.client);

  @override
  Future<QrSheetData> getQrSheet(String questId) async {
    return const QrSheetData(
      questId: 'test-quest-1',
      questTitle: 'Hundred Islands Discovery',
      locationName: 'Hundred Islands National Park',
      qrTasks: [
        QrSheetTask(
          taskKey: 'task_1',
          stepOrder: 1,
          title: 'Governor Island Checkpoint',
          markerCode: 'JDQ-GOV-101',
          qrPayload: 'https://juanderquest.app/verify/101',
          scanMode: 'traveler_scans',
        ),
      ],
    );
  }
}

class InertAuthNotifier extends AuthNotifier {
  InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class InertCosmeticsNotifier extends CosmeticsNotifier {
  InertCosmeticsNotifier(super.ref) {
    const banner = CosmeticItem(
      id: 'banner-lingayen-sunset',
      kind: 'banner',
      name: 'Lingayen Sunset',
      rarity: 'common',
      asset: {
        'style': 'procedural',
        'generator': 'sunset',
        'palette': 'golden',
        'colors': ['#2b2a5c', '#c8577a', '#f6a85a', '#ffe2a0'],
      },
      seed: 2503267308,
      owned: true,
      equipped: true,
      buyable: false,
    );
    state = const CosmeticsState(
      items: [banner],
      owned: [OwnedCosmetic(item: banner, source: 'purchase')],
      loadout: {'banner_id': 'banner-lingayen-sunset'},
    );
  }

  @override
  Future<void> load() async {}
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
  Future<void> fetchSubmissions({bool force = false}) async {}
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

class InertPushService extends PushService {
  InertPushService(super.apiClient);

  @override
  Future<void> init() async {}

  @override
  Future<bool> hasAskedPermission() async => true;

  @override
  Future<bool> requestPermissionAndRegister() async => false;
}

class InertPlazaFeedNotifier extends PlazaFeedNotifier {
  InertPlazaFeedNotifier(super.api) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> loadFeed({bool reset = false}) async {}
}

class _PixelWave1ShellPreview extends StatelessWidget {
  const _PixelWave1ShellPreview({required this.showTips});

  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final keys = HomeTipsKeys();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: ProviderScope(
        overrides: [homeTipsKeysProvider.overrideWithValue(keys)],
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const Expanded(child: DashboardScreen()),
                  PixelHotbar(
                    key: keys.hotbar,
                    index: 0,
                    onTap: (_) {},
                    items: const [
                      PixelHotbarItem(
                        label: 'HOME',
                        icon: PlaceholderArt.home,
                      ),
                      PixelHotbarItem(
                        label: 'MAP',
                        icon: DesignerArt.navExplore,
                      ),
                      PixelHotbarItem(
                        label: 'QUESTS',
                        icon: DesignerArt.questMarker,
                        badge: '12',
                      ),
                      PixelHotbarItem(
                        label: 'CHOICE',
                        icon: DesignerArt.juanChoice,
                        pressedIcon: DesignerArt.juanChoiceHover,
                      ),
                      PixelHotbarItem(
                        label: 'PROFILE',
                        icon: PlaceholderArt.profile,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showTips)
              Positioned.fill(
                child: PixelTutorialOverlay(
                  steps: firstRunSteps(
                    hero: keys.hero,
                    nextStop: keys.nextStop,
                    hotbar: keys.hotbar,
                  ),
                  onDone: () {},
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    funding: const QuestFundingSummary(
      status: 'active',
      mode: 'budget',
      rewardPoints: 50,
      completionsLeftEstimate: 4,
      sponsors: [
        {'name': 'A Very Long Local Tourism Merchant Name'},
      ],
      perk: {'title': 'A Community Visit Reward', 'remaining': 3},
    ),
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
    double textScale, {
    bool clampScale = true,
  }) async {
    final affiliateApi = ApiClient();
    affiliateApi.dio.interceptors.insert(0, InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/comments')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
          return;
        }
        if (options.path.contains('/alternatives')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
          return;
        }
        if (options.path.contains('/interactions')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': {}},
          ));
          return;
        }
        if (options.path == '/affiliate/applications/me') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ));
          return;
        }
        if (options.path == '/me/daily') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'missions': []},
            },
          ));
          return;
        }
        // Plan 66: a fully pre-filled recognition is the widest posting sheet.
        if (options.path == '/spots/recognize') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'recognized': true,
                'place_name':
                    'Minor Basilica of Our Lady of the Rosary of Manaoag Pilgrim Center',
                'name_suggestions': [
                  'Manaoag Pilgrim Center',
                  'Brgy. Poblacion Church',
                  'Manaoag Church'
                ],
                'formatted_address':
                    'Milo Street, Brgy. Poblacion, Manaoag, Pangasinan',
                'municipality': 'Manaoag',
                'barangay': 'Brgy. Poblacion',
                'outside_pangasinan': true,
                'suggested_category': 'culture_heritage',
                'suggested_subcategory': 'church',
                'suggested_details': {
                  'good_for': ['families', 'seniors_access', 'solo'],
                  'best_time': ['early_morning', 'daytime'],
                  'amenities': ['parking', 'restrooms'],
                  'daily_hours': '06:00 AM - 07:00 PM',
                },
                'story_starters': [
                  'A meaningful church in Brgy. Poblacion, Manaoag with a story worth learning about.',
                  'Please dress modestly and keep voices low, especially during masses and events.',
                ],
                'nearby_duplicates': [
                  {
                    'id': 'spot-manaoag',
                    'name': 'Minor Basilica of Manaoag',
                    'distance_meters': 35
                  },
                ],
              },
            },
          ));
          return;
        }
        if (options.path == '/areas') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': [
                {
                  'id': 'dagupan',
                  'level': 'city',
                  'name': 'Dagupan',
                  'display_name': 'Dagupan City',
                  'label_lat': 16.04,
                  'label_lng': 120.34,
                  'has_boundary': true,
                  'published_spot_count': 3
                },
              ]
            },
          ));
          return;
        }
        if (options.path == '/me/discovery-preferences') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'categories': ['nature_outdoors'],
                'onboarding_state': 'pending'
              }
            },
          ));
          return;
        }
        if (options.path == '/quests/q1/progress') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'has_completed': false, 'active_attempt': null}
            },
          ));
          return;
        }
        handler.next(options);
      },
    ));
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    final effectiveScale = clampScale ? textScale.clamp(0.85, 1.4) : textScale;
    tester.platformDispatcher.textScaleFactorTestValue = effectiveScale;

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
          if (child is AffiliateApplicationScreen ||
              child is QuestDetailScreen ||
              child is QuestListScreen ||
              child is InterestsScreen ||
              child is MapViewScreen ||
              child is BadgesScreen ||
              child is SpotDetailScreen)
            apiClientProvider.overrideWithValue(affiliateApi),
          dailyMissionFetcherProvider.overrideWithValue(() async => false),
          homeDailyProvider.overrideWith(
            (ref) async => const HomeDailyState(
              stamps: 12,
              missions: [
                HomeDailyMission(
                  id: 'daily-1',
                  kind: 'quest_step',
                  title: 'Check in at Patar Beach',
                  stamps: 5,
                  progress: 0,
                  target: 1,
                  completed: false,
                ),
              ],
              claimDay: 3,
              nominalStamps: 5,
              calendar: [
                HomeStampDay(day: 1, stamps: 5, claimed: true),
                HomeStampDay(day: 2, stamps: 5, claimed: true),
                HomeStampDay(day: 3, stamps: 5, claimed: false),
                HomeStampDay(day: 4, stamps: 5, claimed: false),
                HomeStampDay(day: 5, stamps: 5, claimed: false),
                HomeStampDay(day: 6, stamps: 5, claimed: false),
                HomeStampDay(day: 7, stamps: 10, claimed: false),
              ],
              streak: 4,
              bestStreak: 6,
              weekUsed: 20,
              weekCap: 250,
            ),
          ),
          homeQotdProvider.overrideWith((ref) {
            final notifier = HomeQotdNotifier(ref, autoLoad: false);
            notifier.state = const AsyncValue.data(
              HomeQotdState(
                date: '2026-11-05',
                questionId: 'q1',
                questionText:
                    'Which Pangasinan town is home to the Minor Basilica?',
                quizTitle: 'Pangasinan 101',
                options: [
                  HomeQotdOption(id: 'o1', ordinal: 1, text: 'Manaoag'),
                  HomeQotdOption(id: 'o2', ordinal: 2, text: 'Alaminos'),
                  HomeQotdOption(id: 'o3', ordinal: 3, text: 'Bolinao'),
                  HomeQotdOption(id: 'o4', ordinal: 4, text: 'Dagupan'),
                ],
              ),
            );
            return notifier;
          }),
          homeProposalsProvider.overrideWith((ref) async => [dummyProposal]),
          homeNearbyQuizProvider.overrideWith(
            (ref) async => const HomeNearbyQuizzes(
              origin: 'gps',
              items: [
                NearbyQuizInvitationModel(
                  quizId: 'quiz-1',
                  destinationId: 'spot-1',
                  destinationName: 'Hundred Islands National Park',
                  municipality: 'Alaminos',
                  title: 'Islands and Legends',
                  description: 'Learn the stories of the islands.',
                  radiusMeters: 200,
                  distanceMeters: 125,
                  xpReward: 25,
                  timeLimitMinutes: 10,
                  language: 'en',
                  isCompleted: false,
                ),
              ],
            ),
          ),
          homeEventsProvider.overrideWithValue(const []),
          authProvider.overrideWith((ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser)),
          cosmeticsProvider.overrideWith((ref) => InertCosmeticsNotifier(ref)),
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
          jdqMapFactoryProvider.overrideWithValue(FakeJdqMap.new),
          mapStyleProvider.overrideWith((ref) async => '{}'),
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
          choiceSupporterQuestProvider.overrideWith((ref) async => null),
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
          pushServiceProvider.overrideWith(
              (ref) => InertPushService(ref.watch(apiClientProvider))),
          plazaFeedProvider.overrideWith(
              (ref) => InertPlazaFeedNotifier(ref.watch(apiClientProvider))),
          plazaStandingsProvider.overrideWith((ref, key) async => {
                'entries': [
                  {
                    'rank': 1,
                    'user_id': 'u1',
                    'display_name': 'Juan Dela Cruz',
                    'score': 1500,
                    'quests': 5,
                    'home_town': 'Dagupan City',
                    'is_self': true,
                  },
                ],
                'me': {
                  'rank': 1,
                  'user_id': 'u1',
                  'display_name': 'Juan Dela Cruz',
                  'score': 1500,
                  'quests': 5,
                  'home_town': 'Dagupan City',
                  'is_self': true,
                  'delta': 1,
                },
              }),
          questBuilderRepositoryProvider.overrideWithValue(
            _MockQuestBuilderRepo(ApiClient(enableRetries: false)),
          ),
        ],
        child: MaterialApp(
          home: child,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    if (child is QuestDetailScreen ||
        child is InterestsScreen ||
        child is SpotPostingSheet) {
      await tester.pumpAndSettle();
    }
    if (child is SpotDiscoveryStudioScreen) {
      // Recognition (stubbed) and the 300 ms draft save finish.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }
    if (child is MapViewScreen) {
      // Let the area-label request (stubbed) and its debounce finish.
      await tester.pump(const Duration(milliseconds: 600));
    }
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
      'Screen Overflow Tests (320x568 portrait & 568x320 landscape, 1.4 text scale (clamp max))',
      () {
    testWidgets(
        'AffiliateApplicationScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(tester, const AffiliateApplicationScreen(),
          const Size(320, 568), 1.4);
    });

    testWidgets(
        'AffiliateApplicationScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(tester, const AffiliateApplicationScreen(),
          const Size(568, 320), 1.4);
    });
    testWidgets('DashboardScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const DashboardScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('DashboardScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const DashboardScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SpotExploreScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotExploreScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('SpotExploreScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotExploreScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SpotSearchScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotSearchScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('SpotSearchScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SpotSearchScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('QuestListScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const QuestListScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('QuestListScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const QuestListScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('QuestDetailScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(tester, QuestDetailScreen(quest: dummyQuest),
          const Size(320, 568), 1.4);
    });

    testWidgets('QuestDetailScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(tester, QuestDetailScreen(quest: dummyQuest),
          const Size(568, 320), 1.4);
    });

    testWidgets('CampaignDetailScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester,
          const CampaignDetailScreen(
              campaignId: 'bangus-festival-2026',
              initialCampaign: dummyCampaign),
          const Size(320, 568),
          1.4);
    });

    testWidgets('LeaderboardScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const LeaderboardScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('PlazaScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const PlazaScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('PlazaScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const PlazaScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('AboutScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const AboutScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('ShopScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ShopScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('ShopScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const ShopScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('WalletConnectScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const WalletConnectScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('WalletConnectScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const WalletConnectScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('AppearanceScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const AppearanceScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('AppearanceScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const AppearanceScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('ProfileScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ProfileScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('VoteScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const VoteScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('MapViewScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const MapViewScreen(), const Size(320, 568), 1.4);
    });

    testWidgets(
        'MapViewScreen with FakeJdqMap does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const MapViewScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SpotDiscoveryStudioScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        const SpotDiscoveryStudioScreen(
            routePin: StudioPin(16.0294, 120.2289, 15)),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets(
        'SpotDiscoveryStudioScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const SpotDiscoveryStudioScreen(
            routePin: StudioPin(16.0294, 120.2289, 15)),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('SpotPostingSheet does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        const SpotPostingSheet(initialLat: 14.5995, initialLng: 120.9842),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('SpotPostingSheet does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const SpotPostingSheet(initialLat: 14.5995, initialLng: 120.9842),
        const Size(568, 320),
        1.4,
      );
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
        1.4,
      );
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      for (final phase in ArHuntPhase.values) {
        testWidgets(
            'ArStatusCard (${phase.name}) does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
            (tester) async {
          await testScreenOverflow(
            tester,
            Scaffold(
              backgroundColor: Colors.black,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ArStatusCard(
                    phase: phase,
                    error:
                        'You are 240m away from this AR checkpoint. Must be within 50m.',
                    onCollect: () {},
                    onDone: () {},
                    onRetry: () {},
                  ),
                ),
              ),
            ),
            size,
            1.4,
          );
        });
      }

      testWidgets(
          'ArFinder does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: ArFinder(
                pose: ValueNotifier(ArPose.unknown),
                bearingToTarget: 45,
                distanceMeters: 12840,
                radiusMeters: 50,
              ),
            ),
          ),
          size,
          1.4,
        );
      });

      testWidgets(
          'ArDiagnosticsScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
            tester, const ArDiagnosticsScreen(), size, 1.4);
      });

      testWidgets(
          'ForgotPasswordScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
            tester,
            const ForgotPasswordScreen(initialEmail: 'juan@example.com'),
            size,
            1.4);
      });

      testWidgets(
          'LoginScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(tester, const LoginScreen(), size, 1.4);
      });

      testWidgets(
          'InterestsScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(tester, const InterestsScreen(), size, 1.4);
      });

      testWidgets(
          'SpotReportSheet does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            body: SpotReportSheet(
              spotName: 'Hundred Islands National Park',
              onSubmit: (_, __) async {},
            ),
          ),
          size,
          1.4,
        );
      });

      testWidgets(
          'QrScanScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(tester, const QrScanScreen(), size, 1.4);
      });

      testWidgets(
          'QuestBuilderScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
          tester,
          const QuestBuilderScreen(initialSpot: dummySpot),
          size,
          1.4,
        );
      });

      testWidgets(
          'QrSheetScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await testScreenOverflow(
          tester,
          const QrSheetScreen(questId: 'test-quest-1'),
          size,
          1.4,
        );
      });
    }

    testWidgets(
        'StartupUpdateGate checking view does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        const StartupUpdateGate(child: SizedBox()),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets(
        'StartupUpdateGate checking view does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const StartupUpdateGate(child: SizedBox()),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('SettingsScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('SettingsScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SettingsUpdatesScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsUpdatesScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('SettingsUpdatesScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsUpdatesScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SettingsDeveloperScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsDeveloperScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('SettingsDeveloperScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const SettingsDeveloperScreen(), const Size(568, 320), 1.4);
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
        1.4,
      );
    });

    testWidgets('UpdateDialog does not overflow in small landscape',
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
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('Pixel wave 1 shell does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester,
          const _PixelWave1ShellPreview(showTips: false),
          const Size(320, 568),
          1.4);
    });

    testWidgets('Pixel wave 1 shell does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester,
          const _PixelWave1ShellPreview(showTips: false),
          const Size(568, 320),
          1.4);
    });

    testWidgets('Pixel wave 1 tips overlay fits small portrait',
        (tester) async {
      await testScreenOverflow(
          tester,
          const _PixelWave1ShellPreview(showTips: true),
          const Size(320, 568),
          1.4);
    });

    testWidgets('Pixel wave 1 tips overlay fits small landscape',
        (tester) async {
      await testScreenOverflow(
          tester,
          const _PixelWave1ShellPreview(showTips: true),
          const Size(568, 320),
          1.4);
    });

    testWidgets('PixelLabScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const PixelLabScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('PixelLabScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const PixelLabScreen(), const Size(568, 320), 1.4);
    });
    testWidgets('ProfileScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const ProfileScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('SubmissionHistoryScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            submissionProvider.overrideWith(
              (ref) => InertSubmissionNotifier(
                ref.watch(apiClientProvider),
                [
                  SubmissionModel(
                    id: 'sub-1',
                    questTitle: 'Hundred Islands Eco Trek',
                    category: 'eco',
                    status: 'approved',
                    rewardPoints: 50,
                    createdAt: '2026-11-02T09:30:00Z',
                  ),
                  SubmissionModel(
                    id: 'sub-2',
                    questTitle: 'Patar Beach Cleanup',
                    category: 'eco',
                    status: 'rejected',
                    rewardPoints: 40,
                    rejectionReason: 'Photo does not show the checkpoint.',
                    createdAt: '2026-11-01T08:00:00Z',
                  ),
                ],
              ),
            ),
          ],
          child: const SubmissionHistoryScreen(),
        ),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('SubmissionHistoryScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            submissionProvider.overrideWith(
              (ref) => InertSubmissionNotifier(
                ref.watch(apiClientProvider),
                [
                  SubmissionModel(
                    id: 'sub-1',
                    questTitle: 'Hundred Islands Eco Trek',
                    category: 'eco',
                    status: 'pending',
                    rewardPoints: 50,
                    createdAt: '2026-11-02T09:30:00Z',
                  ),
                ],
              ),
            ),
          ],
          child: const SubmissionHistoryScreen(),
        ),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('SavedSpotsScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            spotDiscoveryProvider.overrideWith(
              (ref) => InertSpotDiscoveryNotifier(
                ref,
                [dummySpot.copyWith(saved: true)],
              ),
            ),
          ],
          child: const SavedSpotsScreen(),
        ),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('SavedSpotsScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            spotDiscoveryProvider.overrideWith(
              (ref) => InertSpotDiscoveryNotifier(
                ref,
                [dummySpot.copyWith(saved: true)],
              ),
            ),
          ],
          child: const SavedSpotsScreen(),
        ),
        const Size(568, 320),
        1.4,
      );
    });
    testWidgets('LeaderboardScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const LeaderboardScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('VoteScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const VoteScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('ProposalListScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const ProposalListScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('ProposalListScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const ProposalListScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('JuanChoiceScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const JuanChoiceScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('JuanChoiceScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const JuanChoiceScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('CampaignDetailScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const CampaignDetailScreen(
            campaignId: 'bangus-festival-2026', initialCampaign: dummyCampaign),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('CulturalQuizDetailScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            culturalQuizDetailProvider('quiz-1').overrideWith(
              (ref) async => const CulturalQuizModel(
                id: 'quiz-1',
                destinationId: 'spot-1',
                destinationName: 'Patar Beach',
                municipality: 'Bolinao',
                gpsLat: 16.2,
                gpsLng: 119.9,
                title: 'Bolinao Coastal Heritage',
                description:
                    'Explore Cape Bolinao historical landmarks and culture.',
                language: 'en',
                radiusMeters: 200,
                xpReward: 25,
                timeLimitMinutes: 30,
                cooldownHours: 24,
                status: 'published',
                version: 1,
                isCompleted: false,
              ),
            ),
          ],
          child: const CulturalQuizDetailScreen(quizId: 'quiz-1'),
        ),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('CulturalQuizDetailScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [
            culturalQuizDetailProvider('quiz-1').overrideWith(
              (ref) async => const CulturalQuizModel(
                id: 'quiz-1',
                destinationId: 'spot-1',
                destinationName: 'Patar Beach',
                municipality: 'Bolinao',
                gpsLat: 16.2,
                gpsLng: 119.9,
                title: 'Bolinao Coastal Heritage',
                description:
                    'Explore Cape Bolinao historical landmarks and culture.',
                language: 'en',
                radiusMeters: 200,
                xpReward: 25,
                timeLimitMinutes: 30,
                cooldownHours: 24,
                status: 'published',
                version: 1,
                isCompleted: false,
              ),
            ),
          ],
          child: const CulturalQuizDetailScreen(quizId: 'quiz-1'),
        ),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('CulturalQuizPlayScreen does not overflow in small portrait',
        (tester) async {
      final session = (
        attempt: CulturalQuizAttemptModel(
          id: 'att-1',
          quizId: 'quiz-1',
          versionId: 'v-1',
          rewardScopeId: 'scope-1',
          userId: 'u1',
          status: 'in_progress',
          startedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
          completedAt: null,
          score: null,
          totalQuestions: 2,
          xpAwarded: 0,
        ),
        questions: const [
          CulturalQuizQuestionModel(
            id: 'q-1',
            versionId: 'v-1',
            ordinal: 1,
            questionText: 'When was Cape Bolinao Lighthouse built?',
            explanation: 'Constructed in 1905.',
            options: [
              CulturalQuizOptionModel(
                  id: 'a', questionId: 'q-1', ordinal: 1, optionText: '1905'),
              CulturalQuizOptionModel(
                  id: 'b', questionId: 'q-1', ordinal: 2, optionText: '1898'),
            ],
          ),
          CulturalQuizQuestionModel(
            id: 'q-2',
            versionId: 'v-1',
            ordinal: 2,
            questionText: 'Which sea borders Bolinao?',
            explanation: 'The South China Sea.',
            options: [
              CulturalQuizOptionModel(
                  id: 'e',
                  questionId: 'q-2',
                  ordinal: 1,
                  optionText: 'South China Sea'),
              CulturalQuizOptionModel(
                  id: 'f',
                  questionId: 'q-2',
                  ordinal: 2,
                  optionText: 'Sulu Sea'),
            ],
          ),
        ],
      );
      await testScreenOverflow(
        tester,
        CulturalQuizPlayScreen(quizId: 'quiz-1', session: session),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('CulturalQuizResultScreen does not overflow in small landscape',
        (tester) async {
      final result = CulturalQuizGradedResultModel(
        attempt: CulturalQuizAttemptModel(
          id: 'att-1',
          quizId: 'quiz-1',
          versionId: 'v-1',
          rewardScopeId: 'scope-1',
          userId: 'u1',
          status: 'passed',
          startedAt: DateTime.now(),
          expiresAt: DateTime.now(),
          completedAt: DateTime.now(),
          score: 2,
          totalQuestions: 2,
          xpAwarded: 25,
        ),
        passed: true,
        score: 2,
        totalQuestions: 2,
        xpAwarded: 25,
        alreadyCompletedPrior: false,
        breakdown: const [
          CulturalQuizGradeBreakdownItem(
            questionId: 'q-1',
            questionText: 'When was Cape Bolinao Lighthouse built?',
            selectedOptionId: 'a',
            correctOptionId: 'a',
            isCorrect: true,
            explanation: 'Constructed in 1905.',
          ),
        ],
      );
      await testScreenOverflow(
        tester,
        CulturalQuizResultScreen(result: result),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('AboutScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const AboutScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('NotificationsScreen does not overflow in small portrait',
        (tester) async {
      final client = ApiClient();
      client.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 1,
                    'title': 'Quest funding ready',
                    'message': 'Your round is ready.',
                    'kind': 'quest_reward',
                    'href': '/notifications/1',
                    'read': false,
                  },
                ],
              },
            },
          ));
        },
      ));
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const NotificationsScreen(),
        ),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('NotificationsScreen does not overflow in small landscape',
        (tester) async {
      final client = ApiClient();
      client.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 1,
                    'title': 'Quest funding ready',
                    'message': 'Your round is ready.',
                    'kind': 'quest_reward',
                    'href': '/notifications/1',
                    'read': false,
                  },
                ],
              },
            },
          ));
        },
      ));
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const NotificationsScreen(),
        ),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('QuestFundingScreen does not overflow in small portrait',
        (tester) async {
      final client = ApiClient();
      client.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'plan': {
                  'id': 'plan-1',
                  'status': 'draft',
                  'reward_points': 50,
                  'mode': 'budget',
                  'target_points': 500,
                  'contributions': [
                    {'committed_points': 100, 'held_points': 20},
                  ],
                  'ends_at': '2026-12-01T00:00:00Z',
                },
              },
            },
          ));
        },
      ));
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const QuestFundingScreen(questId: 'quest-1'),
        ),
        const Size(320, 568),
        1.4,
      );
    });

    testWidgets('QuestFundingScreen does not overflow in small landscape',
        (tester) async {
      final client = ApiClient();
      client.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'plan': null},
            },
          ));
        },
      ));
      await testScreenOverflow(
        tester,
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const QuestFundingScreen(questId: 'quest-1'),
        ),
        const Size(568, 320),
        1.4,
      );
    });

    testWidgets('TrailComingSoonScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const TrailComingSoonScreen(), const Size(320, 568), 1.4);
    });

    testWidgets('TrailComingSoonScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const TrailComingSoonScreen(), const Size(568, 320), 1.4);
    });

    testWidgets('NavigationScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
        tester,
        const NavigationScreen(
          destination: NavTarget(
            name: 'Hundred Islands National Park',
            lat: 16.2045,
            lng: 120.0435,
            address: 'Lucap Wharf, Alaminos City, Pangasinan',
          ),
        ),
        const Size(568, 320),
        1.4,
      );
    });

    for (final layout in HomeOptionLayout.values) {
      testWidgets('Home ${layout.name} preview does not overflow in portrait',
          (tester) async {
        await testScreenOverflow(
          tester,
          HomeOptionPreview(layout: layout),
          const Size(320, 568),
          2.0,
        );
      });

      testWidgets('Home ${layout.name} preview does not overflow in landscape',
          (tester) async {
        await testScreenOverflow(
          tester,
          HomeOptionPreview(layout: layout),
          const Size(568, 320),
          2.0,
        );
      });
    }

    group('Plan 79a: 2.0x Text Scale Overflow Gates', () {
      testWidgets(
          'BadgesScreen does not overflow in small portrait at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const BadgesScreen(),
          const Size(320, 568),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'BadgesScreen does not overflow in small landscape at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const BadgesScreen(),
          const Size(568, 320),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'PlazaScreen does not overflow in small portrait at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const PlazaScreen(),
          const Size(320, 568),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'PlazaScreen does not overflow in small landscape at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const PlazaScreen(),
          const Size(568, 320),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'MapViewScreen does not overflow in small portrait at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const MapViewScreen(),
          const Size(320, 568),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'MapViewScreen with open Quest Dossier card does not overflow in small portrait at 2.0x text scale (Plan 82 Option A)',
          (tester) async {
        await testScreenOverflow(
          tester,
          const MapViewScreen(initialQuestId: 'q1'),
          const Size(320, 568),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'MapViewScreen does not overflow in small landscape at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const MapViewScreen(),
          const Size(568, 320),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'SpotDetailScreen does not overflow in small portrait at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const SpotDetailScreen(spot: dummySpot),
          const Size(320, 568),
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'SpotDetailScreen does not overflow in small landscape at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          const SpotDetailScreen(spot: dummySpot),
          const Size(568, 320),
          2.0,
          clampScale: false,
        );
      });
    });
  });
}
