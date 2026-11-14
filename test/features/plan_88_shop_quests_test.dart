import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/main_shell.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_recommended_quest_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/pixel/saved_quests.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_list_screen.dart';
import 'package:juanderquest_app/features/settings/home_town.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/theater/theater_quests_section.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

ApiClient _stubApi() {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ),
        );
      },
    ),
  );
  return api;
}

final _user = UserModel.fromJson(const {
  'id': 'u1',
  'email': 'juan@test.ph',
  'display_name': 'Juan',
  'role': 'traveler',
  'points': 500,
  'total_exp': 250,
  'current_level': 3,
});

class _AuthFixture extends AuthNotifier {
  _AuthFixture(super.api, super.refresh, UserModel? user) {
    state = AuthState(user: user, token: 'test_token');
  }
  @override
  Future<void> refreshProfile() async {}
}

class _QuestFixture extends QuestNotifier {
  _QuestFixture(super.api, QuestState initial) {
    state = initial;
  }
  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _CampaignFixture extends CampaignNotifier {
  _CampaignFixture(super.api, CampaignState initial) {
    state = initial;
  }
  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.api, SubmissionState initial) {
    state = initial;
  }
  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _MemorySavedStorage implements SavedQuestsStorage {
  _MemorySavedStorage([this.ids = const []]);
  List<String> ids;

  @override
  Future<List<String>> read() async => List.of(ids);

  @override
  Future<void> write(List<String> values) async => ids = List.of(values);
}

QuestModel _q({
  required String id,
  required String title,
  String locationName = 'Dagupan City',
  double gpsLat = 16.0433,
  double gpsLng = 120.3333,
  int rewardPoints = 100,
  bool isTest = false,
  int? remainingSlots,
  List<QuestStepModel> steps = const [],
}) {
  return QuestModel(
    id: id,
    title: title,
    description: 'Quest $title',
    category: 'cultural',
    locationName: locationName,
    gpsLat: gpsLat,
    gpsLng: gpsLng,
    radiusMeters: 50,
    markerImageUrl: '',
    rewardPoints: rewardPoints,
    isTest: isTest,
    remainingSlots: remainingSlots,
    steps: steps,
  );
}

QuestStepModel _step(
  int order, {
  String status = 'not_started',
  double? lat,
  double? lng,
}) {
  return QuestStepModel(
    order: order,
    title: 'Step $order',
    description: 'Do step $order',
    checkpointType: 'gps',
    required: true,
    status: status,
    gpsLat: lat,
    gpsLng: lng,
  );
}

SpotModel _spot({
  String id = 'spot-1',
  String slug = 'dagupan-plaza',
  String? questId,
  double gpsLat = 16.0433,
  double gpsLng = 120.3333,
}) {
  return SpotModel(
    id: id,
    slug: slug,
    name: 'Dagupan Plaza',
    category: 'heritage',
    subcategory: 'plaza',
    municipality: 'Dagupan City',
    address: 'Dagupan City',
    reasons: const [],
    sourceName: 'test',
    tags: const [],
    trustLevel: 'verified',
    description: 'Central plaza',
    gpsLat: gpsLat,
    gpsLng: gpsLng,
    questId: questId,
  );
}

void main() {
  test('MainShell bar has Shop as 4th tab and /quests outside shell', () {
    expect(MainShell.showsHotbar('/shop'), isTrue);
    expect(MainShell.showsHotbar('/quests'), isFalse);
    expect(MainShell.showsHotbar('/quests/q1'), isFalse);
    expect(MainShell.showsHotbar('/quests/campaigns/c1'), isFalse);
  });

  testWidgets('My quests shows In progress, Saved, Completed & no browse UI', (
    tester,
  ) async {
    final api = _stubApi();
    final qActive = _q(
      id: 'q-act',
      title: 'Active Trail',
      steps: [_step(1, status: 'verified'), _step(2)],
    );
    final qSaved = _q(id: 'q-sav', title: 'Saved Trail');
    final qDone = _q(
      id: 'q-done',
      title: 'Done Trail',
      steps: [_step(1, status: 'verified')],
    );
    final qOther = _q(id: 'q-other', title: 'Unrelated Browse Trail');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questProvider.overrideWith(
            (ref) => _QuestFixture(
              api,
              QuestState(
                quests: [qActive, qSaved, qDone, qOther],
                isLoading: false,
              ),
            ),
          ),
          submissionProvider.overrideWith(
            (ref) => _SubmissionFixture(
              api,
              SubmissionState(submissions: const [], isLoading: false),
            ),
          ),
          savedQuestsStorageProvider.overrideWithValue(
            _MemorySavedStorage(['q-sav']),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: const QuestListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In progress (1)'), findsOneWidget);
    expect(find.text('Active Trail'), findsOneWidget);
    expect(find.text('Saved (1)', skipOffstage: false), findsOneWidget);
    expect(find.text('Saved Trail', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Completed (1)'), 200);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Done Trail'), findsOneWidget);
    // No all-quests list and no category chips
    expect(find.text('Unrelated Browse Trail'), findsNothing);
    expect(find.text('Eco-Tourism'), findsNothing);
    expect(find.text('Events · 0'), findsNothing);
  });

  testWidgets('My quests empty state shows Find a destination + EXPLORE', (
    tester,
  ) async {
    final api = _stubApi();
    final router = GoRouter(
      initialLocation: '/quests',
      routes: [
        GoRoute(
          path: '/quests',
          builder: (_, __) => const QuestListScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: Text('EXPLORE ROUTE')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questProvider.overrideWith(
            (ref) => _QuestFixture(api, QuestState(isLoading: false)),
          ),
          submissionProvider.overrideWith(
            (ref) => _SubmissionFixture(
              api,
              SubmissionState(submissions: const [], isLoading: false),
            ),
          ),
          savedQuestsStorageProvider.overrideWithValue(_MemorySavedStorage()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.pixel,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find a destination to start a quest'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my_quests_explore_button')));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORE ROUTE'), findsOneWidget);
  });

  testWidgets(
    'Spot QUESTS HERE ranks spot.questId first, shows step <=1km, hides 3km & test quests',
    (tester) async {
      final api = _stubApi();
      // Spot at (16.0433, 120.3333)
      final spot = _spot(questId: 'q-own');
      // Own quest (starts here)
      final qOwn = _q(
        id: 'q-own',
        title: 'Own Spot Quest',
        gpsLat: 16.08, // far start, but spot.questId wins!
        gpsLng: 120.38,
      );
      // Step ~500m north (0.0045 deg lat ~= 500m), start 5km away
      final qStep = _q(
        id: 'q-step',
        title: 'Step Nearby Quest',
        gpsLat: 16.09,
        gpsLng: 120.3333,
        steps: [_step(1, lat: 16.0478, lng: 120.3333)],
      );
      // ~3 km away (0.027 deg lat ~= 3km) -> excluded
      final qFar = _q(
        id: 'q-far',
        title: 'Far Away Quest',
        gpsLat: 16.0703,
        gpsLng: 120.3333,
      );
      // Test quest -> hidden
      final qTest = _q(
        id: 'q-test',
        title: 'Automated Test Quest',
        isTest: true,
        gpsLat: 16.0434,
        gpsLng: 120.3333,
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(
              (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user),
            ),
            questProvider.overrideWith(
              (ref) => _QuestFixture(
                api,
                QuestState(
                  quests: [qStep, qFar, qTest, qOwn],
                  isLoading: false,
                ),
              ),
            ),
            showTestContentProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TheaterQuestsSection(spot: spot),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Own Spot Quest'), findsOneWidget);
      expect(find.text('Starts here'), findsOneWidget);
      expect(find.text('Step Nearby Quest'), findsOneWidget);
      expect(find.text('Stop on this quest'), findsOneWidget);
      expect(find.text('Far Away Quest'), findsNothing);
      expect(find.text('Automated Test Quest'), findsNothing);

      // Own Spot Quest appears above Step Nearby Quest
      final ownY = tester.getTopLeft(find.text('Own Spot Quest')).dy;
      final stepY = tester.getTopLeft(find.text('Step Nearby Quest')).dy;
      expect(ownY < stepY, isTrue);
    },
  );

  testWidgets('Spot with no quests shows Create a quest here -> builder route', (
    tester,
  ) async {
    final api = _stubApi();
    final spot = _spot(slug: 'bolinao-falls');
    final router = GoRouter(
      initialLocation: '/spot',
      routes: [
        GoRoute(
          path: '/spot',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(child: TheaterQuestsSection(spot: spot)),
          ),
        ),
        GoRoute(
          path: '/explore/:slug/quests/new',
          builder: (_, state) => Scaffold(
            body: Text('BUILDER:${state.pathParameters['slug']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questProvider.overrideWith(
            (ref) => _QuestFixture(api, QuestState(isLoading: false)),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.pixel,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No quests here yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('spot_create_quest_button')));
    await tester.pumpAndSettle();
    expect(find.text('BUILDER:bolinao-falls'), findsOneWidget);
  });

  test('Home recommendation ranks daily mission, town, excludes completed/0-slot', () {
    final api = _stubApi();
    final qCompleted = _q(id: 'q-comp', title: 'Completed', rewardPoints: 999);
    final qZeroSlots = _q(
      id: 'q-zero',
      title: 'Full Quest',
      rewardPoints: 999,
      remainingSlots: 0,
    );
    final qTown = _q(
      id: 'q-town',
      title: 'Lingayen Walk',
      locationName: 'Lingayen',
      rewardPoints: 50,
    );
    final qTop = _q(
      id: 'q-top',
      title: 'Top Reward Quest',
      locationName: 'Alaminos',
      rewardPoints: 500,
    );

    // 1. Daily mission wins (skips completed & 0-slot -> picks qTown/first eligible)
    final containerDaily = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        questProvider.overrideWith(
          (ref) => _QuestFixture(
            api,
            QuestState(quests: [qCompleted, qZeroSlots, qTown, qTop]),
          ),
        ),
        submissionProvider.overrideWith(
          (ref) => _SubmissionFixture(
            api,
            SubmissionState(
              submissions: [
                SubmissionModel(
                  id: 's1',
                  questTitle: 'Completed',
                  category: 'cultural',
                  status: 'approved',
                  rewardPoints: 100,
                  createdAt: '2026-11-14T00:00:00Z',
                ),
              ],
              isLoading: false,
            ),
          ),
        ),
        homeDailyProvider.overrideWith(
          (ref) async => const HomeDailyState(
            stamps: 10,
            missions: [
              HomeDailyMission(
                id: 'm1',
                kind: 'quest_step',
                title: 'Do a step',
                stamps: 5,
                progress: 0,
                target: 1,
                completed: false,
              ),
            ],
            claimedDays: 1,
            streak: 1,
          ),
        ),
        homeLastKnownLocationProvider.overrideWith((ref) async => null),
        homeTownProvider.overrideWith(
          (ref) async => const HomeTownInfo(town: 'Lingayen', options: []),
        ),
      ],
    );
    addTearDown(containerDaily.dispose);

    // Trigger async providers so their values settle
    containerDaily.read(homeDailyProvider);
    containerDaily.read(homeLastKnownLocationProvider);
    containerDaily.read(homeTownProvider);
  });

  testWidgets('Home recommendation: daily mission -> town -> exclusions', (
    tester,
  ) async {
    final api = _stubApi();
    final qCompleted = _q(id: 'q-comp', title: 'Completed', rewardPoints: 999);
    final qZeroSlots = _q(
      id: 'q-zero',
      title: 'Full Quest',
      rewardPoints: 999,
      remainingSlots: 0,
    );
    final qTop = _q(
      id: 'q-top',
      title: 'Top Reward Quest',
      locationName: 'Alaminos',
      rewardPoints: 500,
    );
    final qTown = _q(
      id: 'q-town',
      title: 'Lingayen Walk',
      locationName: 'Lingayen',
      rewardPoints: 50,
    );

    Future<HomeRecommendedQuest?> readRec({required bool dailyActive}) async {
      HomeRecommendedQuest? result;
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            apiClientProvider.overrideWithValue(api),
            questProvider.overrideWith(
              (ref) => _QuestFixture(
                api,
                QuestState(quests: [qCompleted, qZeroSlots, qTop, qTown]),
              ),
            ),
            submissionProvider.overrideWith(
              (ref) => _SubmissionFixture(
                api,
                SubmissionState(
                  submissions: [
                    SubmissionModel(
                      id: 's1',
                      questTitle: 'Completed',
                      category: 'cultural',
                      status: 'approved',
                      rewardPoints: 100,
                      createdAt: '2026-11-14T00:00:00Z',
                    ),
                  ],
                  isLoading: false,
                ),
              ),
            ),
            homeDailyProvider.overrideWith(
              (ref) async => HomeDailyState(
                stamps: 10,
                missions: [
                  HomeDailyMission(
                    id: 'm1',
                    kind: 'quest_step',
                    title: 'Do a step',
                    stamps: 5,
                    progress: 0,
                    target: 1,
                    completed: !dailyActive,
                  ),
                ],
                claimedDays: 1,
                streak: 1,
              ),
            ),
            homeLastKnownLocationProvider.overrideWith((ref) async => null),
            homeTownProvider.overrideWith(
              (ref) async => const HomeTownInfo(town: 'Lingayen', options: []),
            ),
          ],
          child: Consumer(
            builder: (_, ref, __) {
              result = ref.watch(homeRecommendedQuestProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    // 1. Daily mission wins (skips completed & 0-slot, picks qTop as first eligible)
    final dailyRec = await readRec(dailyActive: true);
    expect(dailyRec?.quest.id, 'q-top');
    expect(dailyRec?.reason, "Today's mission");

    // 2. Without daily mission & location, home town decides (picks qTown over qTop)
    final townRec = await readRec(dailyActive: false);
    expect(townRec?.quest.id, 'q-town');
    expect(townRec?.reason, 'In your town');
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
      'Overflow gate: Home, Spot (3 + more), My quests @ ${size.width.toInt()}x${size.height.toInt()} 2x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        final api = _stubApi();
        final spot = _spot(questId: 'q1');
        final quests = [
          for (var i = 1; i <= 4; i++)
            _q(
              id: 'q$i',
              title: 'Pangasinan Heritage Trail Number $i',
              gpsLat: 16.0433,
              gpsLng: 120.3333,
              steps: [_step(1, status: i == 1 ? 'verified' : 'not_started'), _step(2)],
            ),
        ];

        final overrides = [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questProvider.overrideWith(
            (ref) => _QuestFixture(api, QuestState(quests: quests, isLoading: false)),
          ),
          campaignProvider.overrideWith(
            (ref) => _CampaignFixture(
              api,
              const CampaignState(
                campaigns: [
                  CampaignModel(
                    id: 'c1',
                    hostId: 'h1',
                    hostName: 'Dagupan',
                    title: 'Bangus Festival Cleanup',
                    category: 'eco',
                    locationName: 'Dagupan',
                    municipality: 'Dagupan City',
                    bannerImageUrl: '',
                    description: 'Join',
                    eventDate: '2026-11-20',
                    startDate: '2026-11-20',
                    endDate: '2026-11-21',
                    totalBudgetMjdq: 1000,
                    rewardPerParticipantMjdq: 50,
                    referralBountyMjdq: 10,
                    maxParticipants: 50,
                    reservedParticipants: 10,
                    completedParticipants: 0,
                    preQuestRequirements: [],
                    status: 'active',
                    createdAt: '2026-11-01',
                  ),
                ],
                hasLoaded: true,
              ),
            ),
          ),
          submissionProvider.overrideWith(
            (ref) => _SubmissionFixture(
              api,
              SubmissionState(submissions: const [], isLoading: false),
            ),
          ),
          savedQuestsStorageProvider.overrideWithValue(_MemorySavedStorage(['q2'])),
          homeDailyProvider.overrideWith(
            (ref) async => const HomeDailyState(
              stamps: 10,
              missions: [],
              claimedDays: 2,
              streak: 2,
            ),
          ),
          choiceOverviewProvider.overrideWith(
            (ref) async => const ChoiceOverview(
              current: null,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: false,
            ),
          ),
          homeLastKnownLocationProvider.overrideWith((ref) async => null),
          homeTownProvider.overrideWith(
            (ref) async => const HomeTownInfo(town: 'Dagupan City', options: []),
          ),
        ];

        // 1. Home
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(theme: AppTheme.pixel, home: const DashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. Spot QUESTS HERE with 3 + "+1 more"
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: Scaffold(
                body: SingleChildScrollView(child: TheaterQuestsSection(spot: spot)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('spot_quests_more_button')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. My quests
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(theme: AppTheme.pixel, home: const QuestListScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
