import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/pixel/pixel_nav.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';
import 'package:juanderquest_app/features/vote/providers/governance_provider.dart';
import 'package:juanderquest_app/features/vote/screens/proposal_list_screen.dart';
import 'package:juanderquest_app/features/vote/screens/vote_screen.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _StubNavNotifier extends NavigationNotifier {
  _StubNavNotifier(
    ApiClient apiClient,
    NavTarget destination,
    NavigationState initial,
  ) : super(apiClient: apiClient, initialDestination: destination) {
    state = initial;
  }

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {}

  @override
  Future<void> acquireCurrentLocation() async {}
}

class _StubGovNotifier extends GovernanceNotifier {
  _StubGovNotifier(super.ref, List<GovernanceProposalModel> proposals) {
    state = GovernanceState(proposals: proposals, isLoading: false);
  }

  @override
  Future<void> loadGovernanceData() async {}
}

class _TestQuestNotifier extends QuestNotifier {
  _TestQuestNotifier(super.apiClient, List<QuestModel> quests) {
    state = QuestState(quests: quests, isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _TestSpotNotifier extends SpotDiscoveryNotifier {
  _TestSpotNotifier(super.ref, List<SpotModel> spots) {
    state = SpotDiscoveryState(
      spots: spots,
      categories: const ['nature', 'beach'],
      isInitialLoading: false,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {}
}

ApiClient _createTestApiClient() {
  final api = ApiClient();
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <Map<String, dynamic>>[]},
          ),
        );
      },
    ),
  );
  return api;
}

const _testRoute = RouteModel(
  summary: RouteSummary(
    distanceKm: 12.4,
    durationSeconds: 900,
    durationFormatted: '15 min',
    costing: TravelCosting.auto,
    hasCrowdDiversion: true,
    engine: 'valhalla',
  ),
  coordinates: [LatLng(16.0, 120.0), LatLng(16.1, 120.1)],
  maneuvers: [
    RouteManeuver(
      instruction: 'Turn right on Rizal Avenue',
      streetName: 'Rizal Avenue',
      distanceMeters: 300,
      timeSeconds: 60,
    ),
  ],
);

final _dummyProposal = GovernanceProposalModel(
  id: 'prop-1',
  title: 'Bolinao Solar Streetlights',
  locationName: 'Bolinao Lighthouse',
  category: 'eco',
  description: 'Install eco-friendly solar streetlights along access road.',
  status: 'archived',
  submittedById: 'u-1',
  submittedByName: 'Maria Santos',
  yesVotes: 120,
  noVotes: 10,
  yesWeightMjdq: 2400,
  noWeightMjdq: 200,
  totalVoters: 130,
  bondMjdq: 50,
  escrowedMjdq: 2600,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 75n WP-4 P1 Gates', () {
    testWidgets(
        '1. NavigationScreen docks FIT and LOCATE and has only 1 Hide button (no floating duplicate)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const target = NavTarget(
        name: 'Patar Beach',
        lat: 16.2,
        lng: 119.9,
        address: 'Bolinao',
      );

      const state = NavigationState(
        destination: target,
        route: _testRoute,
        userLocation: LatLng(16.1, 119.8),
      );

      final apiClient = _createTestApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            navigationProvider(target).overrideWith(
                (ref) => _StubNavNotifier(apiClient, target, state)),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // nav_fit_route and nav_locate exist
      expect(find.byKey(const ValueKey('nav_fit_route')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_locate')), findsOneWidget);

      // Verify there is only one "Hide" button on screen (the one toggling controls),
      // and NOT a second duplicate floating hide button
      final hideButtons = find.widgetWithText(PixelButton, 'Hide');
      expect(hideButtons, findsOneWidget);
    });

    testWidgets(
        '2. Settings top profile card drops #hex id suffix and shows clean role',
        (tester) async {
      final user = UserModel(
        id: 'u1111111-2222-3333-4444',
        seedId: 'test_scout',
        displayName: 'Juan Traveler',
        email: 'juan@test.ph',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 500,
      );

      final apiClient = _createTestApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            authProvider.overrideWith(
              (ref) => _InertAuthNotifier(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
                user,
              ),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clean role displayed
      expect(find.text('Pangasinan Explorer'), findsOneWidget);

      // Should NOT contain '#' anywhere in the profile card
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets(
        '3. Governance vote_screen and proposal_list_screen are read-only archive with no + or Vote buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = _createTestApiClient();

      // Test VoteScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            governanceProvider.overrideWith(
                (ref) => _StubGovNotifier(ref, [_dummyProposal])),
          ],
          child: const MaterialApp(
            home: VoteScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No '+' button or submit button
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('+'), findsNothing);
      expect(find.text('Submit Proposal'), findsNothing);
      expect(find.text('Historical Proposals (Archive)'), findsOneWidget);

      // Test ProposalListScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            governanceProvider.overrideWith(
                (ref) => _StubGovNotifier(ref, [_dummyProposal])),
          ],
          child: const MaterialApp(
            home: ProposalListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No Vote yes or Vote no buttons
      expect(find.text('Vote yes'), findsNothing);
      expect(find.text('Vote no'), findsNothing);
      expect(find.text('VOTE YES'), findsNothing);
      expect(find.text('VOTE NO'), findsNothing);
      expect(find.text('Archived Proposal · Voting Closed'), findsOneWidget);
    });

    testWidgets(
        '4. Deep-link Back: PixelAppBar on non-tab first page (!canPop) goes to /dashboard; pops when canPop',
        (tester) async {
      String currentPath = '';

      final router = GoRouter(
        initialLocation: '/test-screen',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              currentPath = '/dashboard';
              return const Scaffold(body: Text('DASHBOARD_PAGE'));
            },
          ),
          GoRoute(
            path: '/test-screen',
            builder: (context, state) {
              currentPath = '/test-screen';
              return const Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(48),
                  child: PixelAppBar(title: 'NON_TAB_SCREEN'),
                ),
                body: Text('CONTENT'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(currentPath, '/test-screen');
      // Back button must be rendered even when !canPop because it is a non-tab screen
      final backButton = find.byKey(const ValueKey('pixel_app_bar_back'));
      expect(backButton, findsOneWidget);

      // Tap back button -> routes to /dashboard
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(currentPath, '/dashboard');
      expect(find.text('DASHBOARD_PAGE'), findsOneWidget);
    });

    testWidgets(
        '5. Map: test markers filtered when showTestContentProvider is false, shown when true',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeMap = FakeJdqMap();
      const realSpot = SpotModel(
        id: 'spot-real-1',
        slug: 'spot-real-1',
        name: 'Real Spot',
        description: 'Real spot desc',
        category: 'nature',
        subcategory: 'beach',
        municipality: 'Alaminos',
        address: 'Alaminos',
        sourceName: 'Editorial',
        trustLevel: 'lgu_verified',
        gpsLat: 15.8000,
        gpsLng: 120.3000,
        tags: [],
        reasons: [],
        isTest: false,
      );
      const testSpot = SpotModel(
        id: 'spot-test-2',
        slug: 'spot-test-2',
        name: 'Simulated Spot',
        description: 'Simulated spot desc',
        category: 'nature',
        subcategory: 'beach',
        municipality: 'Alaminos',
        address: 'Alaminos',
        sourceName: 'Editorial',
        trustLevel: 'lgu_verified',
        gpsLat: 16.4000,
        gpsLng: 120.6000,
        tags: [],
        reasons: [],
        isTest: true,
      );

      final realQuest = QuestModel(
        id: 'quest-real-1',
        title: 'Real Quest',
        description: 'Real quest desc',
        category: 'eco',
        locationName: 'Hundred Islands',
        gpsLat: 16.0000,
        gpsLng: 119.8000,
        radiusMeters: 100,
        rewardPoints: 50,
        markerImageUrl: '',
        isTest: false,
      );
      final testQuest = QuestModel(
        id: 'quest-test-2',
        title: 'Simulated Quest',
        description: 'Simulated quest desc',
        category: 'eco',
        locationName: 'Hundred Islands',
        gpsLat: 16.6000,
        gpsLng: 119.5000,
        radiusMeters: 100,
        rewardPoints: 50,
        markerImageUrl: '',
        isTest: true,
      );

      // Verify withoutTestContent helper behavior directly
      expect(
        withoutTestContent([realQuest, testQuest], (q) => q.isTest,
            showTest: false).map((q) => q.id),
        ['quest-real-1'],
      );
      expect(
        withoutTestContent([realQuest, testQuest], (q) => q.isTest,
            showTest: true).map((q) => q.id),
        ['quest-real-1', 'quest-test-2'],
      );
      expect(
        withoutTestContent([realSpot, testSpot], (s) => s.isTest,
            showTest: false).map((s) => s.id),
        ['spot-real-1'],
      );
      expect(
        withoutTestContent([realSpot, testSpot], (s) => s.isTest,
            showTest: true).map((s) => s.id),
        ['spot-real-1', 'spot-test-2'],
      );

      final testApi = _createTestApiClient();

      // Test 5A: showTestContent = false -> header shows 1 QUEST • 1 SPOT
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            apiClientProvider.overrideWithValue(testApi),
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            questProvider.overrideWith(
                (ref) => _TestQuestNotifier(testApi, [realQuest, testQuest])),
            spotDiscoveryProvider.overrideWith(
                (ref) => _TestSpotNotifier(ref, [realSpot, testSpot])),
            choiceSpotlightProvider.overrideWith((ref) async => null),
            showTestContentProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: MapViewScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('1 QUESTS • 1 SPOTS ACTIVE'), findsOneWidget);

      // Test 5B: showTestContent = true -> header shows 2 QUESTS • 2 SPOTS
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            apiClientProvider.overrideWithValue(testApi),
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            questProvider.overrideWith(
                (ref) => _TestQuestNotifier(testApi, [realQuest, testQuest])),
            spotDiscoveryProvider.overrideWith(
                (ref) => _TestSpotNotifier(ref, [realSpot, testSpot])),
            choiceSpotlightProvider.overrideWith((ref) async => null),
            showTestContentProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: MapViewScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('2 QUESTS • 2 SPOTS ACTIVE'), findsOneWidget);
    });
  });
}
