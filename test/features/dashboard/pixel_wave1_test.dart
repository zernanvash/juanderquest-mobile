import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/main_shell.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/pixel/pixel_feedback.dart';
import 'package:juanderquest_app/core/pixel/pixel_nav.dart';
import 'package:juanderquest_app/core/pixel/placeholder_art.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/onboarding/pixel_tutorial.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _MemoryHomeTipsStore implements HomeTipsStore {
  _MemoryHomeTipsStore(this.seenValue);

  bool seenValue;
  int resetCount = 0;

  @override
  Future<bool> seen() async => seenValue;

  @override
  Future<void> markSeen() async {
    seenValue = true;
  }

  @override
  Future<void> reset() async {
    seenValue = false;
    resetCount++;
  }
}

class _AuthNotifier extends AuthNotifier {
  _AuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'wave1_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _QuestFixture extends QuestNotifier {
  _QuestFixture(super.apiClient, QuestState initial) {
    state = initial;
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _SpotFixture extends SpotDiscoveryNotifier {
  _SpotFixture(super.ref, SpotDiscoveryState initial) {
    state = initial;
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

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient, SubmissionState initial) {
    state = initial;
  }

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _CampaignFixture extends CampaignNotifier {
  _CampaignFixture(super.apiClient) {
    state = const CampaignState(campaigns: [], hasLoaded: true);
  }

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.path);

  final String path;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$path')));
}

class _BranchProbe extends StatelessWidget {
  const _BranchProbe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

final _user = UserModel(
  id: 'u1',
  seedId: 'wave1',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 125,
);

const _summary = ChoiceEngagementSummary(
  currentStreak: 3,
  longestStreak: 5,
  nextMilestone: 7,
  verifiedVisits: 2,
  uniqueDestinations: 4,
  municipalities: 2,
  participations: 1,
  challenges: [],
);

const _overview = ChoiceOverview(
  current: null,
  nextOpensAt: null,
  nextClosesAt: null,
  nextTheme: null,
  previous: null,
  notice: null,
  votingEnabled: false,
);

const _spot = SpotModel(
  id: 'spot-1',
  slug: 'hundred-islands',
  name: 'Hundred Islands National Park',
  description: 'A protected archipelago.',
  category: 'nature_outdoors',
  subcategory: 'islands',
  municipality: 'Alaminos',
  address: 'Lucap Wharf',
  sourceName: 'Alaminos Tourism',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2,
  gpsLng: 120.0,
  tags: ['islands'],
  reasons: ['LGU verified'],
  crowdStatus: 'quiet',
  distanceKm: 12.5,
  saved: true,
);

final _quest = QuestModel(
  id: 'q1',
  title: 'Hundred Islands Eco Trek',
  description: 'Explore the islands.',
  category: 'eco',
  locationName: 'Alaminos',
  gpsLat: 16.2,
  gpsLng: 120.0,
  radiusMeters: 100,
  rewardPoints: 75,
  markerImageUrl: '',
  steps: const [
    QuestStepModel(
      order: 1,
      title: 'Check in',
      description: 'Arrive',
      checkpointType: 'location',
      required: true,
      status: 'verified',
    ),
    QuestStepModel(
      order: 2,
      title: 'Take a photo',
      description: 'Photograph the view',
      checkpointType: 'photo',
      required: true,
    ),
  ],
);

final _submission = SubmissionModel(
  id: 'sub-1',
  questTitle: 'Mangatarem Community Forest and River Cleanup',
  category: 'eco',
  status: 'pending',
  rewardPoints: 25,
  createdAt: '2026-11-02T01:00:00Z',
);

ApiClient _api() {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': options.path == '/me/discovery-preferences'
                  ? {'categories': [], 'onboarding_state': 'answered'}
                  : [],
            },
          ),
        );
      },
    ),
  );
  return api;
}

List<Override> _overrides({
  ApiClient? api,
  Future<ChoiceEngagementSummary> Function()? engagement,
  Future<ChoiceOverview> Function()? overview,
  QuestState? quests,
  SpotDiscoveryState? spots,
  SubmissionState? submissions,
  HomeTipsStore? tipsStore,
}) {
  final client = api ?? _api();
  return [
    apiClientProvider.overrideWithValue(client),
    authProvider.overrideWith(
      (ref) => _AuthNotifier(
        client,
        ref.watch(authRefreshProvider.notifier),
        _user,
      ),
    ),
    questProvider.overrideWith(
      (ref) => _QuestFixture(
        client,
        quests ?? QuestState(quests: [_quest], isLoading: false),
      ),
    ),
    spotDiscoveryProvider.overrideWith(
      (ref) => _SpotFixture(
        ref,
        spots ??
            const SpotDiscoveryState(
              spots: [_spot],
              isInitialLoading: false,
            ),
      ),
    ),
    submissionProvider.overrideWith(
      (ref) => _SubmissionFixture(
        client,
        submissions ??
            SubmissionState(submissions: [_submission], isLoading: false),
      ),
    ),
    choiceEngagementProvider.overrideWith(
      (ref) => (engagement ?? () => Future.value(_summary))(),
    ),
    choiceOverviewProvider.overrideWith(
      (ref) => (overview ?? () => Future.value(_overview))(),
    ),
    hiddenGemProvider.overrideWith((ref) async => const []),
    homeTipsStoreProvider.overrideWithValue(
      tipsStore ?? _MemoryHomeTipsStore(true),
    ),
  ];
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const _RouteProbe('/explore'),
        ),
        GoRoute(
          path: '/explore/:id',
          builder: (_, state) =>
              _RouteProbe('/explore/${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/map', builder: (_, __) => const _RouteProbe('/map')),
        GoRoute(
          path: '/quests',
          builder: (_, __) => const _RouteProbe('/quests'),
        ),
        GoRoute(
          path: '/choice',
          builder: (_, __) => const _RouteProbe('/choice'),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const _RouteProbe('/profile'),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const _RouteProbe('/history'),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const _RouteProbe('/notifications'),
        ),
      ],
    );

Future<void> _pumpDashboard(
  WidgetTester tester, {
  List<Override>? overrides,
  Size size = const Size(400, 2000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? _overrides(),
      child: MaterialApp.router(
        theme: AppTheme.pixel,
        routerConfig: _testRouter(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _expectDashboardTap(
  WidgetTester tester,
  Finder target,
  String route, {
  bool scroll = false,
}) async {
  await _pumpDashboard(tester);
  if (scroll) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('route:$route'), findsOneWidget, reason: 'expected $route');
}

class _TipsHarness extends ConsumerStatefulWidget {
  const _TipsHarness();

  @override
  ConsumerState<_TipsHarness> createState() => _TipsHarnessState();
}

class _TipsHarnessState extends ConsumerState<_TipsHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeTipsControllerProvider.notifier).maybeStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(homeTipsControllerProvider);
    final keys = ref.watch(homeTipsKeysProvider);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      key: keys.hero,
                      width: 200,
                      height: 90,
                      child: const ColoredBox(color: PixelPalette.mist),
                    ),
                  ),
                ),
                SizedBox(
                  key: keys.nextStop,
                  width: double.infinity,
                  height: 80,
                  child: const ColoredBox(color: PixelPalette.paperDim),
                ),
                SizedBox(
                  key: keys.hotbar,
                  width: double.infinity,
                  height: 64,
                  child: const ColoredBox(color: PixelPalette.ink),
                ),
              ],
            ),
          ),
          if (tips.showing)
            Positioned.fill(
              child: PixelTutorialOverlay(
                steps: firstRunSteps(
                  hero: keys.hero,
                  nextStop: keys.nextStop,
                  hotbar: keys.hotbar,
                ),
                onDone: () =>
                    ref.read(homeTipsControllerProvider.notifier).finish(),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _pumpTips(WidgetTester tester, HomeTipsStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [homeTipsStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(body: _TipsHarness()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  test('placeholder HOME and PROFILE art is 24x24 palette art', () {
    for (final art in [PlaceholderArt.home, PlaceholderArt.profile]) {
      expect(art.width, 24);
      expect(art.height, 24);
      for (final row in art.rows) {
        expect(row.length, 24);
        for (final key in row.split('')) {
          expect(
            key == '.' || PixelPalette.byKey.containsKey(key),
            isTrue,
            reason: '${art.name} has an unknown palette key "$key"',
          );
        }
      }
    }
  });

  testWidgets('hotbar has five items, selection semantics and 9+ badges', (
    tester,
  ) async {
    var index = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PixelHotbar(
                index: index,
                onTap: (value) => setState(() => index = value),
                items: const [
                  PixelHotbarItem(label: 'HOME', icon: PlaceholderArt.home),
                  PixelHotbarItem(label: 'MAP', icon: DesignerArt.navExplore),
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
                    badge: '!',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    for (final label in ['HOME', 'MAP', 'CHOICE']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.text('9+'), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
    expect(find.bySemanticsLabel('QUESTS, 12 new'), findsOneWidget);
    expect(find.bySemanticsLabel('PROFILE, new'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('HOME')),
      containsSemantics(isSelected: true),
    );
    await tester.tap(find.bySemanticsLabel('MAP'));
    await tester.pump();
    expect(index, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('MAP')),
      containsSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('HOME')),
      containsSemantics(isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('main shell hotbar switches branches instantly', (tester) async {
    final api = _api();
    final overrides = [
      ..._overrides(api: api, tipsStore: _MemoryHomeTipsStore(true)),
      campaignProvider.overrideWith((ref) => _CampaignFixture(api)),
      choiceSpotlightProvider.overrideWith((ref) async => null),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (_, __) => const _BranchProbe('HOME PAGE'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  builder: (_, __) => const _BranchProbe('EXPLORE PAGE'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/map',
                  builder: (_, __) => const _BranchProbe('MAP PAGE'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/shop',
                  builder: (_, __) => const _BranchProbe('SHOP PAGE'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, __) => const _BranchProbe('PROFILE PAGE'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.pixel,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final semantics = tester.ensureSemantics();
    expect(find.text('HOME PAGE'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      containsSemantics(isSelected: true),
    );
    await tester.tap(find.bySemanticsLabel('Map'));
    await tester.pump();
    expect(find.text('MAP PAGE'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Map')),
      containsSemantics(isSelected: true),
    );
    await tester.tap(find.bySemanticsLabel('Shop'));
    await tester.pump();
    expect(find.text('SHOP PAGE'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pump();
    expect(find.text('PROFILE PAGE'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('dashboard shows the real data state', (tester) async {
    await _pumpDashboard(tester);
    expect(find.text('Welcome back, Juan'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Level 3 · 125 Explorer XP')),
      findsOneWidget,
    );
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
    expect(find.text('Mangatarem Community Forest and River Cleanup'),
        findsOneWidget);
    expect(find.text('Cultural quizzes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows loading states', (tester) async {
    final neverSummary = Completer<ChoiceEngagementSummary>();
    final neverOverview = Completer<ChoiceOverview>();
    await _pumpDashboard(
      tester,
      overrides: _overrides(
        engagement: () => neverSummary.future,
        overview: () => neverOverview.future,
        quests: QuestState(isLoading: true),
        spots: const SpotDiscoveryState(isInitialLoading: true),
        submissions: SubmissionState(isLoading: true),
      ),
    );
    expect(find.byType(PixelLoader), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows every unavailable state with RETRY', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      overrides: _overrides(
        engagement: () => Future.error(Exception('engagement down')),
        overview: () => Future.error(Exception('overview down')),
        quests: QuestState(error: 'Quest list unavailable'),
        spots: const SpotDiscoveryState(
          isInitialLoading: false,
          failure: ApiFailure(
            code: ApiFailureCodes.serverUnavailable,
            message: 'destinations down',
          ),
        ),
        submissions: SubmissionState(error: 'submissions down'),
      ),
    );
    expect(
      find.text('Your travel stats are temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Destinations could not be loaded.'), findsOneWidget);
    expect(find.text('JuanChoice status is unavailable.'), findsOneWidget);
    expect(find.text('Quest list is unavailable.'), findsOneWidget);
    expect(find.text('Recent activity is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsWidgets);
    await tester.tap(find.text('Retry').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard keeps every navigation target', (tester) async {
    await _expectDashboardTap(
      tester,
      find.byTooltip('Notifications'),
      '/notifications',
    );
    await _expectDashboardTap(
      tester,
      find.byKey(const ValueKey('dashboard_quick_explore')),
      '/explore',
    );
    await _expectDashboardTap(
      tester,
      find.byKey(const ValueKey('dashboard_quick_map')),
      '/map',
    );
    await _expectDashboardTap(
      tester,
      find.byKey(const ValueKey('dashboard_quick_quests')),
      '/quests',
    );
    await _expectDashboardTap(
      tester,
      find.text('See all >'),
      '/quests',
      scroll: true,
    );
    await _expectDashboardTap(
      tester,
      find.text('Continue'),
      '/quests',
      scroll: true,
    );
    await _expectDashboardTap(
      tester,
      find.text('Hundred Islands National Park'),
      '/explore/spot-1',
      scroll: true,
    );
    await _expectDashboardTap(
      tester,
      find.byKey(const ValueKey('dashboard_cultural_quizzes')),
      '/explore',
      scroll: true,
    );
  });

  testWidgets('tutorial shows once, SKIP stores the flag', (tester) async {
    final store = _MemoryHomeTipsStore(false);
    await _pumpTips(tester, store);
    expect(find.byType(PixelTutorialOverlay), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
    await tester.pump();
    expect(find.byType(PixelTutorialOverlay), findsNothing);
    expect(store.seenValue, isTrue);
  });

  testWidgets('tutorial stays hidden when the flag is already set',
      (tester) async {
    final store = _MemoryHomeTipsStore(true);
    await _pumpTips(tester, store);
    expect(find.byType(PixelTutorialOverlay), findsNothing);
  });

  testWidgets('tutorial walks all lines and stores the flag at the end',
      (tester) async {
    final store = _MemoryHomeTipsStore(false);
    await _pumpTips(tester, store);
    await tester.tap(find.byKey(const ValueKey('tutorial-choice-0')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(PixelTutorialOverlay));
      await tester.pump();
    }
    expect(find.byType(PixelTutorialOverlay), findsNothing);
    expect(store.seenValue, isTrue);
  });

  testWidgets('"No, I\'ll explore" ends it and stores the flag',
      (tester) async {
    final store = _MemoryHomeTipsStore(false);
    await _pumpTips(tester, store);
    await tester.tap(find.byKey(const ValueKey('tutorial-choice-1')));
    await tester.pump();
    expect(find.byType(PixelTutorialOverlay), findsNothing);
    expect(store.seenValue, isTrue);
  });

  testWidgets('replay clears the tips flag', (tester) async {
    final store = _MemoryHomeTipsStore(true);
    final container = ProviderContainer(overrides: [
      homeTipsStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    await container.read(homeTipsControllerProvider.notifier).resetForReplay();
    expect(store.seenValue, isFalse);
    expect(store.resetCount, 1);
    expect(container.read(homeTipsControllerProvider).showing, isTrue);
  });

  testWidgets('app bar back arrow is 24 px with a 48 px target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(880, 1562);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: PixelAppBar(
              title: 'Back test',
              onBack: () {},
              actions: [
                PixelIconButton(
                  icon: DesignerArt.search,
                  semanticLabel: 'Search',
                  iconHeight: 36,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final backButton = find.byType(PixelIconButton).first;
    final sprite = tester.getSize(
      find.descendant(of: backButton, matching: find.byType(PixelSprite)),
    );
    expect(sprite.height, greaterThan(20));
    expect(sprite.height, lessThan(28));
    final target = tester.getSize(backButton);
    expect(target.height, greaterThanOrEqualTo(48));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  test('new wave 1 code uses only the pixel palette', () {
    final files = [
      'lib/app/main_shell.dart',
      'lib/core/pixel/pixel_nav.dart',
      'lib/core/pixel/pixel_controls.dart',
      'lib/core/pixel/pixel_feedback.dart',
      'lib/core/pixel/placeholder_art.dart',
      'lib/features/dashboard/home_tips.dart',
      'lib/features/dashboard/screens/dashboard_screen.dart',
      'lib/features/spots/widgets/hidden_gem_card.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('Color(0x'),
        isFalse,
        reason: '$path contains a raw colour',
      );
    }
  });
}
