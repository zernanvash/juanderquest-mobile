import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/navigation/widgets/trail_offer_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
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
import 'package:juanderquest_app/features/cultural_quizzes/screens/nearby_quizzes_screen.dart';
import 'package:juanderquest_app/core/widgets/in_app_banner.dart';
import 'package:juanderquest_app/core/widgets/town_picker.dart';
import 'package:juanderquest_app/features/spots/screens/spot_explore_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_search_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/models/hidden_gem_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/notifications/screens/notifications_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/quests/screens/sponsor_request_screen.dart';
import 'package:juanderquest_app/features/quests/widgets/sponsorship_conditions_widgets.dart';
import 'package:juanderquest_app/features/spots/theater/theater_title_block.dart';
import 'package:juanderquest_app/features/trail/trail_catalog_screen.dart';
import 'package:juanderquest_app/features/trail_vlog/models/vlog_manifest.dart';
import 'package:juanderquest_app/features/trail_vlog/services/trail_vlog_vault.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_camera_adapter.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_compiler_service.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/pixel_vlog_recorder_sheet.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/trail_vlog_studio_sheet.dart';
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
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_arrive_overlay.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_bottom_bar.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_top_banner.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
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
import 'package:juanderquest_app/features/dashboard/screens/almanac_screen.dart';
import 'package:juanderquest_app/features/dashboard/data/home_events.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_dashboard_providers.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/onboarding/page_tutorials.dart';
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
import 'package:juanderquest_app/features/merchant/models/merchant_models.dart';
import 'package:juanderquest_app/features/merchant/providers/merchant_hub_provider.dart';
import 'package:juanderquest_app/features/merchant/screens/affiliate_pending_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_page_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_vouchers_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_staff_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_counter_history_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_analytics_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_directory_screen.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/suki/screens/suki_card_screen.dart';
import 'package:juanderquest_app/features/suki/screens/suki_cards_screen.dart';
import 'package:juanderquest_app/features/suki/widgets/shop_suki_section.dart';
import 'package:juanderquest_app/features/suki/widgets/spot_suki_row.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_pass_sheet.dart';

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
  Future<void> loadFeed({bool reset = false, bool quiet = false}) async {}
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
    List<Override> extraOverrides = const [],
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
        // Plan 83c: the widest catalog card (long title, Hiyas, locked).
        if (options.path == '/trails') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 't-long',
                    'title':
                        'The Long Pilgrimage Road from Manaoag Basilica to the Hundred Islands Wharf',
                    'tagline':
                        'Churches, bagoong stalls, river crossings and a sunset boat ride at the end of the day',
                    'tier': 'legendary',
                    'stop_count': 12,
                    'total_minutes': 600,
                    'total_km': 148.4,
                    'unlock_rule': {'type': 'points', 'price_points': 1500},
                    'is_unlocked': false,
                  },
                  {
                    'id': 't-free',
                    'title': 'Dagupan Bangus Walk',
                    'tier': 'starter',
                    'stop_count': 4,
                    'total_minutes': 120,
                    'total_km': 3.2,
                    'unlock_rule': {'type': 'free'},
                    'is_unlocked': true,
                  },
                ],
                'total': 2,
                'personal_generation': null,
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
          // Plan 95: the widest status (long reviewer note) and dashboard.
          if (child is AffiliatePendingScreen)
            merchantHubStatusProvider.overrideWith(
              (ref) async => MerchantHubStatus.fromResponse(const {
                'data': {
                  'id': 'app-1',
                  'status': 'needs_changes',
                  'business_name':
                      'Bonuan Waterfront Bangus Grill and Pasalubong Center',
                  'category': 'dining',
                  'municipality': 'Dagupan City',
                  'business_province': 'Pangasinan',
                  'gps_lat': 16.0754,
                  'gps_lng': 120.3421,
                  'contact_name': 'Maria Santos',
                  'contact_email': 'maria.santos@bonuan-grill.example',
                  'contact_phone': '09170000000',
                  'sponsorship_goals': [
                    'quest_stop',
                    'voucher_perk',
                    'map_pin'
                  ],
                  'applicant_feedback':
                      'Please move the map pin to the exact storefront along Tondaligan Road and include a working contact phone.',
                },
              }),
            ),
          if (child is MerchantDashboardScreen)
            merchantApiProvider.overrideWithValue(_OverflowMerchantApi()),
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
          ...extraOverrides,
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
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('AffiliatePendingScreen does not overflow at $size',
          (tester) async {
        await testScreenOverflow(
            tester, const AffiliatePendingScreen(), size, 2.0);
      });
      testWidgets('MerchantDashboardScreen does not overflow at $size',
          (tester) async {
        await testScreenOverflow(
            tester, const MerchantDashboardScreen(), size, 2.0);
      });
    }
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

    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
          'DashboardScreen with active HomePromoPanel does not overflow at ${size.width}x${size.height} 2x text',
          (tester) async {
        final versionWithPromo = AppVersionInfo(
          versionCode: 227,
          versionName: '0.4.0',
          downloadUrl: 'https://example.test/app.apk',
          changelog: 'Beta promo test',
          promoPanel: HomePromoPanelConfig(
            campaignId: 'overflow-wave-1',
            title: 'Share Your Beta Feedback With the Pangasinan Team!',
            body:
                'Take our short 2-minute traveler survey and help us improve quests and maps.',
            ctaLabel: 'Open Feedback Form',
            url: 'https://forms.gle/overflowTest123',
          ),
        );
        await testScreenOverflow(
          tester,
          const DashboardScreen(),
          size,
          2.0,
          clampScale: false,
          extraOverrides: [
            startupUpdateControllerProvider.overrideWith(
              (ref) => InertStartupUpdateController(
                InertUpdateRepository(versionInfo: versionWithPromo),
                StartupGateState(
                  phase: GatePhase.ready,
                  latestVersion: versionWithPromo,
                ),
              ),
            ),
          ],
        );
      });
    }

    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
          'AlmanacScreen week & month modes do not overflow at ${size.width}x${size.height} 2x text',
          (tester) async {
        // The Almanac moved to its own page (owner 2026-11-16).
        await testScreenOverflow(tester, const AlmanacScreen(), size, 2.0);
        await tester.ensureVisible(
          find.byKey(const ValueKey('home_calendar_mode_toggle')),
        );
        await tester.tap(
          find.byKey(const ValueKey('home_calendar_mode_toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('WK'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

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
      testWidgets(
          'AdventureTopBanner (collapsed) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: AdventureTopBanner(
                  currentManeuver: const RouteManeuver(
                    instruction:
                        'Turn right onto Lingayen-Dagupan Diversion Rd',
                    distanceMeters: 4500,
                    timeSeconds: 300,
                    streetName: 'Diversion Rd',
                  ),
                  distanceToManeuverM: 250,
                  upcomingManeuvers: const [],
                  onOpenSteps: () {},
                ),
              ),
            ),
          ),
          size,
          2.0,
        );
      });

      testWidgets(
          'AdventureTopBanner (expanded) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: AdventureTopBanner(
                  currentManeuver: const RouteManeuver(
                    instruction:
                        'Turn right onto Lingayen-Dagupan Diversion Rd',
                    distanceMeters: 4500,
                    timeSeconds: 300,
                    streetName: 'Diversion Rd',
                  ),
                  distanceToManeuverM: 250,
                  upcomingManeuvers: const [
                    RouteManeuver(
                      instruction: 'Continue straight for 3 km',
                      distanceMeters: 3000,
                      timeSeconds: 240,
                    ),
                    RouteManeuver(
                      instruction: 'Turn left onto Capitol Blvd',
                      distanceMeters: 800,
                      timeSeconds: 90,
                    ),
                    RouteManeuver(
                      instruction: 'Arrive at Provincial Capitol',
                      distanceMeters: 100,
                      timeSeconds: 15,
                    ),
                  ],
                  onOpenSteps: () {},
                ),
              ),
            ),
          ),
          size,
          2.0,
        );
      });

      testWidgets(
          'AdventureBottomBar (with CHECK IN) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: AdventureBottomBar(
                  summary: const RouteSummary(
                    distanceKm: 18.5,
                    durationSeconds: 1200,
                    durationFormatted: '20 min',
                    costing: TravelCosting.auto,
                    hasCrowdDiversion: false,
                    engine: 'valhalla',
                  ),
                  selectedTrail: const TrailDetail(
                    id: 't-1',
                    slug: 'trail-1',
                    title: 'Heritage Trail',
                    tagline: 'Coastal historic monuments',
                    tier: TrailTier.starter,
                    theme: 'history',
                    intro: 'Heritage walk',
                    rewardPoints: 50,
                    totalMinutes: 60,
                    totalKm: 10.0,
                    stopCount: 3,
                    municipalities: ['Lingayen'],
                    unlockRule: UnlockRule(type: 'free'),
                    isUnlocked: true,
                    stops: [],
                    preview: [],
                  ),
                  nextStop: const TrailStop(
                    position: 2,
                    spotId: 's-2',
                    name: 'Veterans Memorial Beach',
                    municipality: 'Lingayen',
                    category: 'history',
                    lat: 16.03,
                    lng: 120.24,
                    narration: '',
                    arriveOffsetMin: 20,
                    dwellMin: 15,
                    legMinutes: 10,
                    legKm: 3.0,
                    checkinRadiusM: 50.0,
                    checkedIn: false,
                  ),
                  totalStops: 3,
                  currentStopNumber: 2,
                  isWithinCheckinRadius: true,
                  currentSpeedMs: 1.2,
                  isCheckingIn: false,
                  onCheckIn: () {},
                  onOpenSteps: () {},
                  onEnd: () {},
                ),
              ),
            ),
          ),
          size,
          2.0,
        );
      });

      testWidgets(
          '83d RoutePreviewSheet (4 trails) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        const dest = NavTarget(
          name: 'Patar White Beach Destination Resort',
          lat: 16.3,
          lng: 119.8,
          address: 'Bolinao, Pangasinan',
        );
        const navState = NavigationState(
          destination: dest,
          route: RouteModel(
            summary: RouteSummary(
              distanceKm: 18.5,
              durationSeconds: 1200,
              durationFormatted: '20 min',
              costing: TravelCosting.auto,
              hasCrowdDiversion: false,
              engine: 'valhalla',
            ),
            coordinates: [],
            maneuvers: [
              RouteManeuver(
                instruction: 'Head north',
                distanceMeters: 200,
                timeSeconds: 30,
              ),
            ],
          ),
          nearbyTrails: [
            NearbyTrail(
              id: 't1',
              slug: 't1',
              title: 'Lingayen Historic Coastal Walk',
              tagline: '',
              tier: TrailTier.starter,
              theme: 'heritage',
              municipalities: ['Lingayen'],
              stopCount: 3,
              totalMinutes: 45,
              totalKm: 5.0,
              nearestKm: 1.2,
              unlockRule: UnlockRule(type: 'free'),
              isUnlocked: true,
              rewardPoints: 50,
              passesHere: true,
            ),
            NearbyTrail(
              id: 't2',
              slug: 't2',
              title: 'Dagupan Bangus Culinary Trail',
              tagline: '',
              tier: TrailTier.signature,
              theme: 'food',
              municipalities: ['Dagupan'],
              stopCount: 4,
              totalMinutes: 60,
              totalKm: 8.0,
              nearestKm: 2.0,
              unlockRule: UnlockRule(type: 'points', pricePoints: 100),
              isUnlocked: false,
              rewardPoints: 100,
              passesHere: false,
            ),
            NearbyTrail(
              id: 't3',
              slug: 't3',
              title: 'Bolinao Lighthouse Sunset Loop',
              tagline: '',
              tier: TrailTier.signature,
              theme: 'nature',
              municipalities: ['Bolinao'],
              stopCount: 3,
              totalMinutes: 50,
              totalKm: 12.0,
              nearestKm: 3.0,
              unlockRule: UnlockRule(type: 'points', pricePoints: 150),
              isUnlocked: false,
              rewardPoints: 150,
              passesHere: false,
            ),
            NearbyTrail(
              id: 't4',
              slug: 't4',
              title: 'Extra Fourth Trail',
              tagline: '',
              tier: TrailTier.starter,
              theme: 'culture',
              municipalities: ['San Carlos'],
              stopCount: 2,
              totalMinutes: 25,
              totalKm: 3.0,
              nearestKm: 4.0,
              unlockRule: UnlockRule(type: 'free'),
              isUnlocked: false,
              rewardPoints: 40,
              passesHere: false,
            ),
          ],
        );

        await testScreenOverflow(
          tester,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: navState,
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
          size,
          2.0,
        );
      });

      testWidgets(
          '83d AdventureTopBanner + BottomBar (60-char stop & street) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        const longName =
            'Very Long Heritage Landmark Stop Name Along Capitol Boulevard';
        await testScreenOverflow(
          tester,
          Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdventureTopBanner(
                      currentManeuver: const RouteManeuver(
                        instruction: 'Turn right onto $longName',
                        distanceMeters: 4500,
                        timeSeconds: 300,
                        streetName: longName,
                      ),
                      distanceToManeuverM: 300,
                      upcomingManeuvers: const [
                        RouteManeuver(
                          instruction: 'Continue straight onto Coastal Highway',
                          distanceMeters: 1200,
                          timeSeconds: 90,
                        ),
                      ],
                      onOpenSteps: () {},
                    ),
                  ),
                ),
                AdventureBottomBar(
                  summary: const RouteSummary(
                    distanceKm: 18.5,
                    durationSeconds: 1200,
                    durationFormatted: '20 min',
                    costing: TravelCosting.auto,
                    hasCrowdDiversion: false,
                    engine: 'valhalla',
                  ),
                  selectedTrail: const TrailDetail(
                    id: 't-1',
                    slug: 'trail-1',
                    title: 'Heritage Trail',
                    tagline: 'Coastal historic monuments',
                    tier: TrailTier.starter,
                    theme: 'history',
                    intro: 'Heritage walk',
                    rewardPoints: 50,
                    totalMinutes: 60,
                    totalKm: 10.0,
                    stopCount: 3,
                    municipalities: ['Lingayen'],
                    unlockRule: UnlockRule(type: 'free'),
                    isUnlocked: true,
                    stops: [],
                    preview: [],
                  ),
                  nextStop: const TrailStop(
                    position: 2,
                    spotId: 's-2',
                    name: longName,
                    municipality: 'Lingayen',
                    category: 'history',
                    lat: 16.03,
                    lng: 120.24,
                    narration: '',
                    arriveOffsetMin: 20,
                    dwellMin: 15,
                    legMinutes: 10,
                    legKm: 3.0,
                    checkinRadiusM: 50.0,
                    checkedIn: false,
                  ),
                  totalStops: 3,
                  currentStopNumber: 2,
                  distanceToStopMeters: 450,
                  onCheckIn: () {},
                  onOpenSteps: () {},
                  onEnd: () {},
                ),
              ],
            ),
          ),
          size,
          2.0,
        );
      });

      testWidgets(
          '83d AdventureArriveOverlay (check-in & complete) does not overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        await testScreenOverflow(
          tester,
          Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Coastal Heritage & Bangus Culinary Loop Trail',
              trailRewardPoints: 150,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
          size,
          2.0,
        );
      });
    }

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

    testWidgets(
        'CulturalQuizPlayScreen Plan 91b true_false, photo_clue, sequence_order do not overflow at 2.0x',
        (tester) async {
      final session = (
        attempt: CulturalQuizAttemptModel(
          id: 'att-91b',
          quizId: 'quiz-91b',
          versionId: 'v-1',
          rewardScopeId: 'scope-1',
          userId: 'u1',
          status: 'in_progress',
          startedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 20)),
          totalQuestions: 3,
          xpAwarded: 0,
        ),
        questions: const [
          CulturalQuizQuestionModel(
            id: 'q-tf',
            versionId: 'v-1',
            ordinal: 1,
            questionType: 'true_false',
            questionText: 'Cape Bolinao Lighthouse was lit in 1905.',
            explanation: 'Fact.',
            options: [
              CulturalQuizOptionModel(
                  id: 'tf-1',
                  questionId: 'q-tf',
                  ordinal: 1,
                  optionText: 'Fact'),
              CulturalQuizOptionModel(
                  id: 'tf-2',
                  questionId: 'q-tf',
                  ordinal: 2,
                  optionText: 'Myth'),
            ],
          ),
          CulturalQuizQuestionModel(
            id: 'q-photo',
            versionId: 'v-1',
            ordinal: 2,
            questionType: 'photo_clue',
            mediaUrl: 'https://juanderquest.app/media/bolinao.jpg',
            questionText: 'Identify this coastal landmark in Pangasinan.',
            explanation: 'Cape Bolinao.',
            options: [
              CulturalQuizOptionModel(
                  id: 'p-1',
                  questionId: 'q-photo',
                  ordinal: 1,
                  optionText: 'Lighthouse'),
              CulturalQuizOptionModel(
                  id: 'p-2',
                  questionId: 'q-photo',
                  ordinal: 2,
                  optionText: 'Cathedral'),
              CulturalQuizOptionModel(
                  id: 'p-3',
                  questionId: 'q-photo',
                  ordinal: 3,
                  optionText: 'Plaza'),
              CulturalQuizOptionModel(
                  id: 'p-4',
                  questionId: 'q-photo',
                  ordinal: 4,
                  optionText: 'Bridge'),
            ],
          ),
          CulturalQuizQuestionModel(
            id: 'q-seq',
            versionId: 'v-1',
            ordinal: 3,
            questionType: 'sequence_order',
            questionText: 'Order the route stops from Dagupan to Bolinao.',
            explanation: 'Westward coast.',
            options: [
              CulturalQuizOptionModel(
                  id: 's-1', questionId: 'q-seq', optionText: 'Lingayen'),
              CulturalQuizOptionModel(
                  id: 's-2', questionId: 'q-seq', optionText: 'Alaminos'),
              CulturalQuizOptionModel(
                  id: 's-3', questionId: 'q-seq', optionText: 'Bolinao'),
            ],
          ),
        ],
      );

      await testScreenOverflow(
        tester,
        CulturalQuizPlayScreen(quizId: 'quiz-91b', session: session),
        const Size(320, 568),
        2.0,
      );
      await testScreenOverflow(
        tester,
        CulturalQuizPlayScreen(quizId: 'quiz-91b', session: session),
        const Size(568, 320),
        2.0,
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

    // v0.3.10 quests: funding management page (overview + history) and the
    // author's action bar on their own quest, at 2.0x text.
    for (final entry in const {
      'small portrait': Size(320, 568),
      'small landscape': Size(568, 320),
    }.entries) {
      testWidgets(
          'v0.3.10 QuestFundingScreen overview does not overflow in ${entry.key} at 2.0x text scale',
          (tester) async {
        final client = ApiClient(enableRetries: false);
        client.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'plan': {
                  'id': 'plan-1',
                  'status': 'pending_sponsors',
                  'mode': 'budget',
                  'reward_points': 100,
                  'fee_points': 6,
                  'planned_completions': 10000,
                  'target_points': '1060000',
                  'ends_at': '2026-12-01T00:00:00Z',
                  'contributions': [
                    {
                      'funder_kind': 'author',
                      'committed_points': '1000000',
                      'remaining_points': '999894',
                      'held_points': '106',
                      'created_at': '2026-11-18T11:12:14.000Z',
                    },
                  ],
                  'holds': [
                    {
                      'status': 'released',
                      'release_reason': 'idle_expired',
                      'reward_points': 100,
                      'created_at': '2026-11-18T13:00:00.000Z',
                      'released_at': '2026-11-19T13:00:00.000Z',
                    },
                  ],
                  'sponsorships': [
                    {
                      'id': 'sp-1',
                      'merchant_name':
                          'Dagupan Seaside Heritage Grill & Local Pasalubong Empanada Store',
                      'status': 'countered',
                      'points': 5000,
                      'created_at': '2026-11-19T02:00:00.000Z',
                    },
                  ],
                  'summary': {
                    'committed_points': 1000000,
                    'remaining_points': 999894,
                    'held_points': 106,
                    'paid_points': 0,
                    'completions_left': 9433,
                    'holds': {
                      'active': 1,
                      'pending_review': 0,
                      'paid': 0,
                      'released': 1,
                    },
                  },
                },
              },
            },
          )),
        ));
        await testScreenOverflow(
          tester,
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(client)],
            child: const QuestFundingScreen(questId: 'quest-1'),
          ),
          entry.value,
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'v0.3.10 QuestDetailScreen author bar does not overflow in ${entry.key} at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          QuestDetailScreen(
            quest: QuestModel(
              id: 'q1',
              title: dummyQuest.title,
              description: dummyQuest.description,
              category: dummyQuest.category,
              locationName: dummyQuest.locationName,
              gpsLat: dummyQuest.gpsLat,
              gpsLng: dummyQuest.gpsLng,
              radiusMeters: dummyQuest.radiusMeters,
              rewardPoints: dummyQuest.rewardPoints,
              markerImageUrl: dummyQuest.markerImageUrl,
              authorId: dummyUser.id,
            ),
          ),
          entry.value,
          2.0,
          clampScale: false,
        );
      });
    }

    for (final entry in const {
      'small portrait': Size(320, 568),
      'small landscape': Size(568, 320),
    }.entries) {
      testWidgets(
          'Plan 108 SponsorRequestScreen does not overflow in ${entry.key} at 2.0x text scale',
          (tester) async {
        final client = ApiClient(enableRetries: false);
        client.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'm-long',
                    'name':
                        'Dagupan Seaside Heritage Grill & Local Pasalubong Empanada Store',
                    'municipality': 'Dagupan City',
                    'category': 'dining',
                    'description':
                        'Supporting coastal cleanups and eco heritage quests across Pangasinan.',
                    'same_municipality': true,
                    'vouchers': [
                      {
                        'id': 'v1',
                        'title': 'Free coastal refreshment drink voucher',
                        'description': ''
                      },
                    ],
                  },
                ],
                'page': 1,
              },
            },
          )),
        ));
        await testScreenOverflow(
          tester,
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(client)],
            child: const SponsorRequestScreen(
              questId: 'quest-1',
              planId: 'plan-1',
            ),
          ),
          entry.value,
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          'Plan 108 SetConditionsSheet & SponsoredBy title block do not overflow in ${entry.key} at 2.0x text scale',
          (tester) async {
        final longSpot = dummySpot.copyWith(
          sponsors: const [
            SpotSponsor(
              name:
                  'Dagupan Waterfront Heritage Grill and Pasalubong Artisan Roastery',
              questId: 'q1',
            ),
            SpotSponsor(name: 'Bolinao Eco Tour Co-op', questId: 'q1'),
            SpotSponsor(name: 'Alaminos Island Guides', questId: 'q1'),
          ],
        );
        await testScreenOverflow(
          tester,
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (ctx) => PixelButton(
                    label: 'Open Conditions',
                    onPressed: () => showSetConditionsSheet(ctx),
                  ),
                ),
                const SizedBox(height: 12),
                TheaterFirstViewport(
                  spot: longSpot,
                  scrollOffset: 0,
                  hasPhoto: false,
                  onDirections: () {},
                  onPlayQuest: () {},
                ),
              ],
            ),
          ),
          entry.value,
          2.0,
          clampScale: false,
        );
        await tester.tap(find.text('Open Conditions'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('cond_sheet_save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Plan 108 QuestDetailScreen long sponsor does not overflow in ${entry.key} at 2.0x text scale',
          (tester) async {
        await testScreenOverflow(
          tester,
          QuestDetailScreen(quest: dummyQuest),
          entry.value,
          2.0,
          clampScale: false,
        );
      });
    }

    testWidgets('TrailCatalogScreen does not overflow in small portrait',
        (tester) async {
      await testScreenOverflow(
          tester, const TrailCatalogScreen(), const Size(320, 568), 2.0,
          clampScale: false);
    });

    testWidgets('TrailCatalogScreen does not overflow in small landscape',
        (tester) async {
      await testScreenOverflow(
          tester, const TrailCatalogScreen(), const Size(568, 320), 2.0,
          clampScale: false);
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

    group('Plan 83e: 2.0x Text Scale Navigation Polish Overflow Gates', () {
      const target = NavTarget(
        name: 'Patar Beach Long Destination Title',
        lat: 16.3228,
        lng: 119.7844,
        address: 'Bolinao, Pangasinan',
      );
      const sampleRoute = RouteModel(
        coordinates: [LatLng(16.0218, 120.2319), LatLng(16.3228, 119.7844)],
        summary: RouteSummary(
          distanceKm: 48.2,
          durationSeconds: 3120,
          durationFormatted: '52 mins',
          costing: TravelCosting.auto,
          hasCrowdDiversion: false,
          engine: 'valhalla',
        ),
        maneuvers: [
          RouteManeuver(
            instruction: 'Turn right onto Romulo Highway',
            distanceMeters: 300,
            timeSeconds: 40,
            streetName: 'Romulo Highway',
          ),
        ],
      );
      final twelveTrails40Char = List.generate(
        12,
        (i) => NearbyTrail(
          id: 't-$i',
          slug: 't-$i',
          title: 'Very Long Forty Character Trail Title $i',
          tagline: 'Explore scenic towns',
          tier: i.isEven ? TrailTier.starter : TrailTier.signature,
          theme: 'heritage',
          municipalities: const ['Lingayen'],
          stopCount: 4,
          totalMinutes: 351,
          totalKm: 61.4,
          unlockRule: UnlockRule(
            type: i.isEven ? 'free' : 'points',
            pricePoints: i.isEven ? 0 : 150,
          ),
          isUnlocked: i == 0,
          rewardPoints: 50,
          passesHere: i == 0,
          nearestKm: i.toDouble(),
        ),
      );

      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        final label = size.width < size.height ? 'portrait' : 'landscape';

        testWidgets(
            '83e RoutePreviewSheet 12 trails + 40-char title does not overflow in $label at 2.0x text',
            (tester) async {
          await testScreenOverflow(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RoutePreviewSheet(
                  navState: NavigationState(
                    destination: target,
                    route: sampleRoute,
                    nearbyTrails: twelveTrails40Char,
                  ),
                  onSelectCosting: (_) {},
                  onChangeOrigin: () {},
                  onSelectDirect: () {},
                  onSelectTrail: (_) {},
                  onInspectTrail: (_) {},
                  onOpenSteps: () {},
                  onGo: () {},
                  onRetry: () {},
                ),
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
        });

        testWidgets(
            '83e Arrive cards (CHECKED IN / TRAIL COMPLETE / ARRIVED) do not overflow in $label at 2.0x text',
            (tester) async {
          const stop1 = TrailStop(
            position: 1,
            spotId: 's1',
            name: 'Capitol Building',
            municipality: 'Lingayen',
            category: 'Heritage',
            lat: 16.0218,
            lng: 120.2319,
            arriveOffsetMin: 10,
            dwellMin: 15,
            legMinutes: 10,
            legKm: 4.0,
            checkinRadiusM: 60,
            checkedIn: true,
            narration: 'Stop 1',
          );
          await testScreenOverflow(
            tester,
            Scaffold(
              body: AdventureArriveOverlay(
                checkedInStop: stop1,
                stops: const [stop1],
                totalStops: 2,
                destinationName: target.name,
                onContinueCheckIn: () {},
                onDone: () {},
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
          await testScreenOverflow(
            tester,
            Scaffold(
              body: AdventureArriveOverlay(
                isTrailCompleted: true,
                trailTitle: 'Very Long Forty Character Trail Title 1',
                trailRewardPoints: 150,
                destinationName: target.name,
                onContinueCheckIn: () {},
                onDone: () {},
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
          await testScreenOverflow(
            tester,
            Scaffold(
              body: AdventureArriveOverlay(
                hasArrivedDirect: true,
                destinationName: target.name,
                tripMinutes: 52,
                tripKm: 48.2,
                onContinueCheckIn: () {},
                onDone: () {},
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
        });

        testWidgets(
            '83e TrailOfferSheet does not overflow in $label at 2.0x text',
            (tester) async {
          await testScreenOverflow(
            tester,
            Scaffold(
              body: TrailOfferSheet(
                trail: twelveTrails40Char.first,
                onChoose: (_) {},
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
        });

        testWidgets(
            '87 RoutePreviewSheet closed + open does not overflow in $label at 2.0x text and GO stays visible',
            (tester) async {
          const dest = NavTarget(
            name: 'Patar White Beach Destination Resort',
            lat: 16.3,
            lng: 119.8,
            address: 'Bolinao, Pangasinan',
          );
          final navState = NavigationState(
            destination: dest,
            route: const RouteModel(
              summary: RouteSummary(
                distanceKm: 18.5,
                durationSeconds: 1200,
                durationFormatted: '20 min',
                costing: TravelCosting.auto,
                hasCrowdDiversion: false,
                engine: 'valhalla',
              ),
              coordinates: [],
              maneuvers: [
                RouteManeuver(
                  instruction: 'Head north',
                  distanceMeters: 200,
                  timeSeconds: 30,
                ),
              ],
            ),
            nearbyTrails: twelveTrails40Char,
          );

          await testScreenOverflow(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RoutePreviewSheet(
                  navState: navState,
                  onSelectCosting: (_) {},
                  onChangeOrigin: () {},
                  onSelectDirect: () {},
                  onSelectTrail: (_) {},
                  onInspectTrail: (_) {},
                  onOpenSteps: () {},
                  onGo: () {},
                  onRetry: () {},
                ),
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );

          final goFinder = find.byKey(const ValueKey('nav_start_adventure'));
          expect(goFinder, findsOneWidget);
          expect(
              tester.getRect(goFinder).bottom, lessThanOrEqualTo(size.height));

          // Open the panel and verify no overflow and GO remains visible
          await tester.tap(find.byKey(const ValueKey('nav_sheet_handle')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(goFinder, findsOneWidget);
          expect(
              tester.getRect(goFinder).bottom, lessThanOrEqualTo(size.height));
        });
      }
    });
  });

  group('Plan 91a Cultural Quiz Radar & Hub zero-overflow', () {
    const sampleRadarState = QuizRadarState(
      origin: 'Lingayen Capitol Anchor (16.0209, 120.2317)',
      items: [
        NearbyQuizInvitationModel(
          quizId: 'q-ready-1',
          destinationId: 'dest-1',
          destinationName: 'Pangasinan Provincial Capitol',
          municipality: 'Lingayen',
          title: 'Capitol Heritage & Architecture Challenge',
          description: 'Explore Lingayen heritage.',
          radiusMeters: 250,
          distanceMeters: 64,
          inRange: true,
          xpReward: 75,
          timeLimitMinutes: 5,
          language: 'en',
          isCompleted: false,
        ),
        NearbyQuizInvitationModel(
          quizId: 'q-walk-1',
          destinationId: 'dest-2',
          destinationName: 'Lingayen Beach Boardwalk',
          municipality: 'Lingayen',
          title: 'Gulf Breeze & WW2 Landing Quiz',
          description: 'Walk closer to unlock.',
          radiusMeters: 200,
          distanceMeters: 420,
          inRange: false,
          xpReward: 60,
          timeLimitMinutes: 5,
          language: 'en',
          isCompleted: false,
        ),
        NearbyQuizInvitationModel(
          quizId: 'q-done-1',
          destinationId: 'dest-3',
          destinationName: 'Urduja House Museum',
          municipality: 'Lingayen',
          title: 'Princess Urduja Folklore Trivia',
          description: 'Completed earlier.',
          radiusMeters: 250,
          distanceMeters: 90,
          inRange: true,
          xpReward: 50,
          timeLimitMinutes: 5,
          language: 'en',
          isCompleted: true,
        ),
      ],
    );

    for (final entry in {
      'portrait_320x568': const Size(320, 568),
      'landscape_568x320': const Size(568, 320),
    }.entries) {
      testWidgets('NearbyQuizzesScreen 2.0x textScale ${entry.key}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              quizRadarProvider.overrideWith(
                (ref) => _FixedQuizRadarNotifier(ref, sampleRadarState),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.0)),
                child: child!,
              ),
              home: const NearbyQuizzesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('InAppBanner 2.0x textScale ${entry.key}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(
              body: InAppBanner(
                item: const InAppBannerItem(
                  id: 'local:quiz:q1:today',
                  title: 'Quiz unlocked: Bolinao Heritage of the Lighthouse',
                  message: 'You are at Cape Bolinao Lighthouse. Play it now.',
                ),
                onTap: () {},
                onDismiss: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      // Team review v0.3.10: home town province -> town combobox.
      testWidgets('TownPicker 2.0x textScale ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.pixel,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TownPicker(
                  towns: const ['San Fabian', 'San Carlos City'],
                  value: 'San Carlos City',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Plan 107 Suki Cards zero-overflow (2.0x text)', () {
    const longShop = 'Bonuan Waterfront Bangus Grill and Pasalubong Center';
    Map<String, dynamic> program(String id, {String mode = 'standee'}) => {
          'id': id,
          'title': 'Bangus Lovers Suki Card for Regulars',
          'reward_kind': 'amount_off',
          'reward_value': '5000',
          'reward_text':
              'Five thousand pesos off a family bilao of grilled bangus and pancit',
          'reward_tag': '₱5000 OFF',
          'visits_required': 20,
          'mode': mode,
          'status': 'active',
          'distance_m': 120,
          'merchant': {
            'id': 'm1',
            'name': longShop,
            'municipality': 'San Carlos City',
          },
        };
    final reward = {
      'id': 'r1',
      'code': 'SUKI-ABC123-DEF456',
      'reward_text':
          'Five thousand pesos off a family bilao of grilled bangus and pancit',
      'reward_tag': '₱5000 OFF',
      'status': 'issued',
      'expires_at': '2027-01-17T00:00:00Z',
      'expired': false,
    };
    final card = {
      'card_id': 'c1',
      'cycle': 2,
      'visits': 19,
      'required': 20,
      'total_visits': 39,
      'visited_today': true,
    };

    ApiClient sukiClient() {
      final client = ApiClient(enableRetries: false);
      client.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? data;
          if (path == '/me/suki-cards') {
            data = {
              'cards': [
                {
                  ...card,
                  'program': program('suki_long'),
                  'rewards': [reward]
                },
                {
                  ...card,
                  'card_id': 'c2',
                  'program': program('suki_two', mode: 'staff_scan'),
                },
              ],
            };
          } else if (path == '/suki/programs') {
            data = {
              'programs': [program('suki_near'), program('suki_long')]
            };
          } else if (path.startsWith('/suki/programs/')) {
            data = {
              'program': program('suki_long'),
              'my_card': card,
              'rewards': [reward],
            };
          } else if (path == '/suki/pass') {
            data = {
              'pass': 'JDQSUKIPASS:${'a' * 300}',
              'expires_at': DateTime.now()
                  .add(const Duration(seconds: 120))
                  .toIso8601String(),
            };
          } else if (path == '/suki/pass/status') {
            data = {'visited_today': false, 'card': card};
          }
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ));
        },
      ));
      return client;
    }

    Future<void> pumpSuki(WidgetTester tester, Widget child, Size size) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      final overflowErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
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
      final client = sukiClient();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser)),
          sukiQuickFixProvider
              .overrideWithValue(() async => (lat: null, lng: null)),
        ],
        child: MaterialApp(theme: AppTheme.pixel, home: child),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();
      expect(overflowErrors, isEmpty,
          reason: overflowErrors.map((e) => e.toString()).join('\n'));
    }

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('SukiCardsScreen $label', (tester) async {
        await pumpSuki(tester, const SukiCardsScreen(), size);
        expect(find.byKey(const ValueKey('suki_my_cards')), findsOneWidget);
      });
      testWidgets('SukiCardScreen with a reward $label', (tester) async {
        await pumpSuki(
            tester, const SukiCardScreen(programId: 'suki_long'), size);
        expect(find.byKey(const ValueKey('suki_reward_r1')), findsOneWidget);
        // The rest of the page (grid, buttons) lays out without overflow too.
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
      testWidgets('SukiPassSheet $label', (tester) async {
        await pumpSuki(
            tester,
            const Scaffold(
                body:
                    SukiPassSheet(programId: 'suki_long', shopName: longShop)),
            size);
        expect(
            find.byKey(const ValueKey('suki_pass_countdown')), findsOneWidget);
      });
      testWidgets('Shop Suki section $label', (tester) async {
        await pumpSuki(
            tester,
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [ShopSukiSection()],
              ),
            ),
            size);
        expect(find.byKey(const ValueKey('shop_suki_section')), findsOneWidget);
      });
      testWidgets('Spot "Suki cards here" row $label', (tester) async {
        await pumpSuki(
            tester,
            Scaffold(
              backgroundColor: PixelPalette.ink,
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [SpotSukiRow(lat: 15.93, lng: 120.35)],
              ),
            ),
            size);
        expect(find.byKey(const ValueKey('spot_suki_row')), findsOneWidget);
      });
    }
  });

  // v0.3.10 Shop track: the public merchant page, the hub's counter, catalog
  // pins and cover upload, and a Shop category, at 2.0x text.
  group('v0.3.10 Shop zero-overflow (2.0x text)', () {
    const longShop = 'Bonuan Waterfront Bangus Grill and Pasalubong Center';
    const longItem =
        'Inihaw na Bangus Belly with Atchara and Garlic Rice Platter';
    final routes = <String, Object?>{
      '/merchants/m1': {
        'merchant': {
          'id': 'm1',
          'name': longShop,
          'category': 'dining and pasalubong',
          'municipality': 'San Fabian, Pangasinan',
          'location': 'Purok 3, Barangay Bonuan Gueset, beside the river',
          'description': 'Grilled bangus, halo-halo and pasalubong. ' * 4,
          'logo_url': null,
          'banner_url': null,
          'contact_phone': '0917 000 0000',
          'contact_email': 'hello.bonuan.waterfront.grill@example.com',
          'gps_lat': 16.04,
          'gps_lng': 120.33,
          'is_published': false,
        },
        'specialties': [
          {
            'id': 'p1',
            'name': longItem,
            'price': '1250.00',
            'is_specialty': true
          },
        ],
        'products': [
          {
            'id': 'p2',
            'name': longItem,
            'price': null,
            'description': 'x ' * 40
          },
        ],
        'vouchers': [
          {
            'id': 'v1',
            'title': 'Free halo-halo with any family platter order',
            'cost_points': '12000'
          },
        ],
        'suki': {
          'enabled': true,
          'program': {
            'id': 'suki_1',
            'title': 'Bangus Lovers Suki Card for Regulars',
            'reward_text': 'Free large halo-halo with leche flan',
            'reward_tag': '₱250 OFF',
            'visits_required': 12,
          },
          'my_card': {'visits': 7, 'required': 12},
        },
        'viewer': {'is_member': false},
      },
      '/merchant/dashboard': {
        'merchant': {
          'id': 'm1',
          'name': longShop,
          'category': 'dining',
          'municipality': 'Dagupan City',
          'is_published': true,
        },
        'counts': {'active_products': 3},
        'checklist': {'items': []},
        'truthful_notice': {'statement': ''},
      },
      '/merchant/profile': {'name': longShop, 'banner_url': '', 'logo_url': ''},
      '/merchant/products': [
        {
          'id': 'p1',
          'name': longItem,
          'price': '1250.00',
          'specialty_at': '2026-11-19T00:00:00Z'
        },
        {'id': 'p2', 'name': longItem, 'price': null, 'description': 'x ' * 40},
      ],
      '/merchant/suki': {'role': 'owner', 'program': null},
      '/merchant/vouchers/manage': {
        'merchant_id': 'm1',
        'role': 'owner',
        'items': [
          {
            'id': 'v1',
            'title': 'Unlimited Pancit & Halo-Halo Family Bundle',
            'description': 'Show your redeemed code at the Bonuan Waterfront counter daily.',
            'cost_points': 250,
            'availability': 'live',
            'is_active': true,
            'stock_limit': 50,
            'valid_days': 30,
            'redeemed_count': 18,
            'used_count': 12,
          },
          {
            'id': 'v2',
            'title': 'Archived Holiday Treat Voucher',
            'description': 'Expired seasonal promo.',
            'cost_points': 100,
            'availability': 'preview',
            'is_active': false,
            'redeemed_count': 0,
            'used_count': 0,
          },
        ],
      },
      '/merchant/staff': {
        'merchant_id': 'm1',
        'items': [
          {
            'id': 'mm-1',
            'user_id': 'u1',
            'display_name': 'Bonuan Waterfront Owner Account',
            'email': 'owner.bonuan.grill@juanderquest.example',
            'role': 'owner',
            'status': 'active',
          },
          {
            'id': 'mm-2',
            'user_id': 'u2',
            'display_name': 'Front Counter Cashier One',
            'email': 'cashier.counter@juanderquest.example',
            'role': 'staff',
            'status': 'active',
          },
        ],
      },
      '/merchant/counter/history': {
        'merchant_id': 'm1',
        'items': [
          {
            'kind': 'voucher',
            'customer': 'Suki #ABCDEF12',
            'code': 'JDQ-AB12CD-EF34GH',
            'method': 'purchase',
            'detail': 'Unlimited Pancit & Halo-Halo Family Bundle',
            'staff_name': 'Front Counter Cashier One',
            'at': '2026-11-19T02:00:00Z',
          },
          {
            'kind': 'suki_reward',
            'customer': 'Suki #99887766',
            'code': 'JDQ-SUKI11-REWARD',
            'method': 'counter',
            'detail': 'Free Large Halo-Halo with Leche Flan',
            'staff_name': 'Bonuan Waterfront Owner Account',
            'at': '2026-11-18T11:30:00Z',
          },
        ],
      },
      '/merchant/analytics': {
        'merchant_id': 'm1',
        'days': 30,
        'funding': {
          'active_sponsorships': 3,
          'total_points_committed': 12500,
          'total_points_paid': 8400,
          'funded_completions': 64,
        },
        'vouchers': {
          'active_catalog_count': 8,
          'shop_redeemed_in_window': 142,
          'perks_granted_in_window': 39,
          'confirmed_at_counter_in_window': 115,
        },
        'suki': {
          'visits_in_window': 320,
          'unique_customers': 185,
          'repeat_customers': 74,
          'rewards_issued': 29,
          'rewards_claimed': 21,
        },
      },
      '/merchants': {
        'items': [
          {
            'id': 'm1',
            'name': longShop,
            'category': 'dining',
            'municipality': 'Dagupan City',
            'description': 'Freshly grilled Bonuan bangus and halo-halo by the waterfront.',
            'distance_m': 1450,
            'active_voucher_count': 4,
            'has_active_suki': true,
          },
        ],
        'page': 1,
        'limit': 20,
        'total': 30,
      },
    };

    Future<void> pumpShop(WidgetTester tester, Widget child, Size size) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      final overflowErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
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
      final client = ApiClient(enableRetries: false);
      client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': routes[options.path] ?? const {}},
            )),
          ));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser)),
        ],
        child: MaterialApp(theme: AppTheme.pixel, home: child),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      // Scroll to the end so every section lays out.
      final list = find.byType(ListView);
      if (list.evaluate().isNotEmpty) {
        await tester.drag(list.first, const Offset(0, -4000));
        await tester.pump();
      }
      // Let late requests and toasts finish.
      await tester.pump(const Duration(seconds: 5));
      tester.takeException();
      expect(overflowErrors, isEmpty,
          reason: overflowErrors.map((e) => e.toString()).join('\n'));
    }

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('MerchantPageScreen $label', (tester) async {
        await pumpShop(
            tester, const MerchantPageScreen(merchantId: 'm1'), size);
        expect(find.byType(MerchantPageScreen), findsOneWidget);
      });
      for (final tab in const ['overview', 'profile', 'catalog']) {
        testWidgets('MerchantDashboardScreen $tab $label', (tester) async {
          await pumpShop(
              tester, MerchantDashboardScreen(initialTab: tab), size);
          expect(find.byType(MerchantDashboardScreen), findsOneWidget);
        });
      }
      testWidgets('MerchantVouchersScreen $label', (tester) async {
        await pumpShop(tester, const MerchantVouchersScreen(), size);
        expect(find.byType(MerchantVouchersScreen), findsOneWidget);
      });
      testWidgets('MerchantStaffScreen $label', (tester) async {
        await pumpShop(tester, const MerchantStaffScreen(), size);
        expect(find.byType(MerchantStaffScreen), findsOneWidget);
      });
      testWidgets('MerchantCounterHistoryScreen $label', (tester) async {
        await pumpShop(tester, const MerchantCounterHistoryScreen(), size);
        expect(find.byType(MerchantCounterHistoryScreen), findsOneWidget);
      });
      testWidgets('MerchantAnalyticsScreen $label', (tester) async {
        await pumpShop(tester, const MerchantAnalyticsScreen(), size);
        expect(find.byType(MerchantAnalyticsScreen), findsOneWidget);
      });
      testWidgets('MerchantDirectoryScreen $label', (tester) async {
        await pumpShop(tester, const MerchantDirectoryScreen(), size);
        expect(find.byType(MerchantDirectoryScreen), findsOneWidget);
      });
    }
  });

  group('Plan 115: Trail Vlog 2.0x Text Scale Overflow Gates', () {
    for (final entry in {
      'portrait 320x568': const Size(320, 568),
      'landscape 568x320': const Size(568, 320),
    }.entries) {
      final label = entry.key;
      final size = entry.value;

      testWidgets(
          '115 AdventureArriveOverlay with vlog CTAs does not overflow in $label at 2.0x text',
          (tester) async {
        const stop1 = TrailStop(
          position: 1,
          spotId: 's1',
          name: 'Capitol Building of Pangasinan Province',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.0218,
          lng: 120.2319,
          arriveOffsetMin: 10,
          dwellMin: 15,
          legMinutes: 10,
          legKm: 4.0,
          checkinRadiusM: 60,
          checkedIn: true,
          narration: 'Stop 1',
        );
        await testScreenOverflow(
          tester,
          Scaffold(
            body: AdventureArriveOverlay(
              checkedInStop: stop1,
              stops: const [stop1],
              totalStops: 4,
              destinationName: 'Bolinao',
              onRecordStopVlog: () {},
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
          size,
          2.0,
          clampScale: false,
        );
        await testScreenOverflow(
          tester,
          Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Pangasinan Coastal Heritage Forty Char Trail',
              trailRewardPoints: 150,
              destinationName: 'Bolinao',
              vlogClipCount: 3,
              hasFinalStopVlogClip: false,
              onRecordFinalStopVlog: () {},
              onOpenTrailVlogStudio: () {},
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
          size,
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          '115 PixelVlogRecorderSheet does not overflow in $label at 2.0x text',
          (tester) async {
        await testScreenOverflow(
          tester,
          ProviderScope(
            overrides: [
              vlogCameraAdapterFactoryProvider
                  .overrideWithValue(() => _OverflowVlogCam()),
            ],
            child: const Scaffold(
              body: PixelVlogRecorderSheet(
                trailId: 't1',
                trailTitle: 'Pangasinan Heritage Trail',
                totalStops: 4,
                totalKm: 42.5,
                kind: VlogClipKind.stop,
                stopPosition: 2,
                spotName: 'Hundred Islands National Park Alaminos',
                municipality: 'Alaminos City',
              ),
            ),
          ),
          size,
          2.0,
          clampScale: false,
        );
      });

      testWidgets(
          '115 TrailVlogStudioSheet does not overflow in $label at 2.0x text',
          (tester) async {
        final vault = TrailVlogVault();
        const manifest = TrailVlogManifest(
          trailId: 't-studio',
          trailTitle: 'Pangasinan Coastal Heritage Wonders Trail',
          totalStops: 4,
          totalKm: 42.5,
          rewardPoints: 150,
          clips: [
            VlogClipEntry(
              id: 'stop_1',
              kind: VlogClipKind.stop,
              stopPosition: 1,
              spotName: 'Lingayen Capitol Building',
              municipality: 'Lingayen',
              capturedAtIso: '2026-11-19T02:00:00Z',
              filePath: '/tmp/stop_1.mp4',
            ),
          ],
        );
        await testScreenOverflow(
          tester,
          ProviderScope(
            overrides: [
              trailVlogVaultProvider.overrideWithValue(vault),
              vlogCompilerServiceProvider.overrideWithValue(
                _OverflowVlogCompiler(vault),
              ),
            ],
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const Scaffold(
                  body: TrailVlogStudioSheet(
                    manifest: manifest,
                    hasVipFramesOverride: true,
                  ),
                ),
              ),
            ),
          ),
          size,
          2.0,
          clampScale: false,
        );
      });
    }

    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      for (final page in TutorialPage.values) {
        testWidgets(
            'Plan 116 tutorial overlay (${page.key}) fits $size @ 2.0x text',
            (tester) async {
          await testScreenOverflow(
            tester,
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.pixel,
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) => PixelTutorialOverlay(
                      steps: buildPageTutorialSteps(ctx, page),
                      onDone: () {},
                    ),
                  ),
                ),
              ),
            ),
            size,
            2.0,
            clampScale: false,
          );
        });
      }
    }
  });
}

class _OverflowVlogCam implements VlogCameraAdapter {
  @override
  bool get isInitialized => true;
  @override
  bool get isAudioEnabled => true;
  @override
  bool get isFrontCamera => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> initialize({
    required bool frontCamera,
    required bool enableAudio,
  }) async {}
  @override
  Future<void> startRecording() async {}
  @override
  Future<String> stopRecording() async => '/tmp/mock.mp4';
  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: PixelPalette.wood);
  @override
  Future<void> dispose() async {}
}

class _OverflowVlogCompiler extends VlogCompilerService {
  _OverflowVlogCompiler(TrailVlogVault vault) : super(vault: vault);

  @override
  Future<Map<String, String>> extractThumbnails(List<String> clipPaths) async =>
      const {};
}

class _FixedQuizRadarNotifier extends QuizRadarNotifier {
  _FixedQuizRadarNotifier(super.ref, QuizRadarState initial) {
    state = initial;
  }

  @override
  Future<void> refreshFromHome({bool force = false}) async {}
}

/// Plan 95: a long-named merchant with an unfinished checklist.
class _OverflowMerchantApi extends MerchantApi {
  _OverflowMerchantApi() : super(ApiClient(enableRetries: false));

  @override
  Future<MerchantDashboardData> dashboard() async =>
      MerchantDashboardData.fromJson(const {
        'merchant': {
          'name': 'Bonuan Waterfront Bangus Grill and Pasalubong Center',
          'category': 'dining',
          'municipality': 'Dagupan City',
          'is_published': false,
        },
        'counts': {'active_products': 12},
        'checklist': {
          'items': [
            {
              'id': 'profile_info',
              'title': 'Review business info & address',
              'completed': true
            },
            {
              'id': 'profile_contact',
              'title': 'Confirm contact details',
              'completed': true
            },
            {
              'id': 'profile_photo',
              'title': 'Upload logo or banner photo',
              'completed': false
            },
            {
              'id': 'catalog_item',
              'title': 'Add your first product or specialty',
              'completed': false
            },
            {
              'id': 'publish_profile',
              'title': 'Publish merchant showcase profile',
              'completed': false
            },
          ],
        },
        'truthful_notice': {
          'statement':
              'Visitor engagement metrics, point staking, and live automated checkout are deferred.',
        },
      });
}
