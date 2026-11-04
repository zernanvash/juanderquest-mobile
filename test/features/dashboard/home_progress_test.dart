import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _MemoryHomeTipsStore implements HomeTipsStore {
  @override
  Future<bool> seen() async => true;

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> reset() async {}
}

class _AuthNotifier extends AuthNotifier {
  _AuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'home_token');
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

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.path);

  final String path;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$path')));
}

final _user = UserModel(
  id: 'u1',
  seedId: 'juan_demo',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 125,
  mjdqBalance: 125400,
  jdqGovernanceBalance: 12,
  scoutReputation: 350,
  cosmetics: const {
    'title': {
      'asset': {'text': 'Heritage Keeper'},
    },
    'nameColor': {
      'asset': {'color': '#2D6A4F'},
    },
  },
);

const _summary = ChoiceEngagementSummary(
  currentStreak: 4,
  longestStreak: 7,
  nextMilestone: 10,
  verifiedVisits: 18,
  uniqueDestinations: 7,
  municipalities: 5,
  participations: 3,
  challenges: [],
);

final _quests = [
  QuestModel(
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
  ),
  QuestModel(
    id: 'q2',
    title: 'Patar Beach Cleanup',
    description: 'Keep the beach clean.',
    category: 'eco',
    locationName: 'Bolinao',
    gpsLat: 16.3,
    gpsLng: 119.8,
    radiusMeters: 100,
    rewardPoints: 50,
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
        title: 'Collect litter',
        description: 'Clean the shore',
        checkpointType: 'photo',
        required: true,
        status: 'verified',
      ),
    ],
  ),
];

final _submissions = [
  SubmissionModel(
    id: 'sub-pending',
    questTitle: 'Mangatarem Forest Cleanup',
    category: 'eco',
    status: 'pending',
    rewardPoints: 25,
    createdAt: '2026-11-05T01:00:00Z',
  ),
  SubmissionModel(
    id: 'sub-approved-eco',
    questTitle: 'Patar Beach Cleanup',
    category: 'eco',
    status: 'approved',
    rewardPoints: 50,
    createdAt: '2026-11-03T01:00:00Z',
  ),
  SubmissionModel(
    id: 'sub-approved-heritage',
    questTitle: 'Manaoag Heritage Walk',
    category: 'cultural',
    status: 'approved',
    rewardPoints: 50,
    createdAt: '2026-11-02T01:00:00Z',
  ),
  SubmissionModel(
    id: 'sub-rejected',
    questTitle: 'Dagupan Food Crawl',
    category: 'food',
    status: 'rejected',
    rewardPoints: 0,
    createdAt: '2026-11-01T01:00:00Z',
  ),
];

const _spots = [
  SpotModel(
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
  ),
  SpotModel(
    id: 'spot-2',
    slug: 'patar-beach',
    name: 'Patar White Beach',
    description: 'A broad public beach.',
    category: 'nature_outdoors',
    subcategory: 'beach',
    municipality: 'Bolinao',
    address: 'Patar',
    sourceName: 'Bolinao Tourism',
    trustLevel: 'lgu_verified',
    gpsLat: 16.3,
    gpsLng: 119.8,
    tags: ['beach'],
    reasons: ['LGU verified'],
    crowdStatus: 'quiet',
  ),
];

const _daily = HomeDailyState(
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
);

const _previous = ChoicePreviousResult(
  periodLabel: 'Week 44',
  validBallots: 128,
  coWinnerIds: {'cand-1'},
  standings: [
    ChoiceStanding(
      candidateId: 'cand-1',
      spotName: 'Patar White Beach',
      votes: 74,
    ),
    ChoiceStanding(
      candidateId: 'cand-2',
      spotName: 'Hundred Islands',
      votes: 54,
    ),
  ],
);

const _resultsOverview = ChoiceOverview(
  current: null,
  nextOpensAt: null,
  nextClosesAt: null,
  nextTheme: null,
  previous: _previous,
  notice: null,
  votingEnabled: false,
);

ChoiceOverview _openOverview() {
  final now = DateTime.now();
  final campaign = ChoiceCampaign(
    id: 'camp-1',
    theme: 'Best Sunset Spot',
    region: 'Pangasinan',
    status: 'voting',
    opensAt: now.subtract(const Duration(days: 1)),
    closesAt: now.add(const Duration(days: 2)),
  );
  return ChoiceOverview(
    current: campaign,
    nextOpensAt: null,
    nextClosesAt: null,
    nextTheme: null,
    previous: _previous,
    notice: null,
    votingEnabled: true,
    serverTime: now,
    receivedAt: now,
    monotonicClock: Stopwatch()..start(),
  );
}

ChoiceDetail _voteDetail({required bool voted}) {
  final now = DateTime.now();
  return ChoiceDetail(
    campaign: ChoiceCampaign(
      id: 'camp-1',
      theme: 'Best Sunset Spot',
      region: 'Pangasinan',
      status: 'voting',
      opensAt: now.subtract(const Duration(days: 1)),
      closesAt: now.add(const Duration(days: 2)),
    ),
    standings: const [],
    ballot:
        voted ? const ChoiceBallot(candidateId: 'cand-1', version: 1) : null,
  );
}

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
              'data': {'categories': [], 'onboarding_state': 'answered'},
            },
          ),
        );
      },
    ),
  );
  return api;
}

List<Override> _overrides({
  Future<ChoiceEngagementSummary> Function()? engagement,
  Future<ChoiceOverview> Function()? overview,
  Future<ChoiceDetail> Function(String id)? detail,
  QuestState? quests,
  SpotDiscoveryState? spots,
  SubmissionState? submissions,
  Future<HomeDailyState> Function()? daily,
}) {
  final client = _api();
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
        quests ?? QuestState(quests: _quests, isLoading: false),
      ),
    ),
    spotDiscoveryProvider.overrideWith(
      (ref) => _SpotFixture(
        ref,
        spots ??
            const SpotDiscoveryState(
              spots: _spots,
              isInitialLoading: false,
            ),
      ),
    ),
    submissionProvider.overrideWith(
      (ref) => _SubmissionFixture(
        client,
        submissions ??
            SubmissionState(submissions: _submissions, isLoading: false),
      ),
    ),
    choiceEngagementProvider.overrideWith(
      (ref) => (engagement ?? () async => _summary)(),
    ),
    choiceOverviewProvider.overrideWith(
      (ref) => (overview ?? () async => _resultsOverview)(),
    ),
    choiceDetailProvider.overrideWith(
      (ref, id) => (detail ?? (id) async => _voteDetail(voted: false))(id),
    ),
    homeDailyProvider.overrideWith(
      (ref) => (daily ?? () async => _daily)(),
    ),
    homeTipsStoreProvider.overrideWithValue(_MemoryHomeTipsStore()),
  ];
}

GoRouter _router() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const _RouteProbe('/profile'),
        ),
        GoRoute(
          path: '/quests',
          builder: (_, __) => const _RouteProbe('/quests'),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  _RouteProbe('/quests/${state.pathParameters['id']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/choice',
          builder: (_, __) => const _RouteProbe('/choice'),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  _RouteProbe('/choice/${state.pathParameters['id']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const _RouteProbe('/history'),
        ),
        GoRoute(
          path: '/saved',
          builder: (_, __) => const _RouteProbe('/saved'),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const _RouteProbe('/notifications'),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Override>? overrides,
  Size size = const Size(400, 2400),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? _overrides(),
      child: MaterialApp.router(
        theme: AppTheme.pixel,
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _textContaining(String text) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
  await tester.pump();
}

Future<void> _tapRoute(
  WidgetTester tester,
  Finder target,
  String route,
) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('route:$route'), findsOneWidget, reason: 'expected $route');
}

void main() {
  testWidgets('hero shows identity, cosmetics, level, XP and wallet', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('@juan_demo'), findsOneWidget);
    expect(find.text('Heritage Keeper'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(_textContaining('25 / 50 XP'), findsOneWidget);
    expect(_textContaining('125 total XP'), findsOneWidget);
    expect(find.text('125,400'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero targets open the profile', (tester) async {
    for (final key in [
      'home_hero_profile',
      'home_hero_level',
      'home_wallet_mjdq',
      'home_wallet_jdq',
      'home_wallet_rep',
    ]) {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/profile');
    }
  });

  testWidgets('progress tab shows travel stats, proofs and the daily mission',
      (tester) async {
    await _pump(tester);
    expect(_textContaining('Visit streak: 4 days'), findsOneWidget);
    expect(_textContaining('Verified visits: 18'), findsOneWidget);
    expect(_textContaining('Destinations: 7'), findsOneWidget);
    expect(_textContaining('Municipalities: 5'), findsOneWidget);
    expect(_textContaining('Pending proofs: 1'), findsOneWidget);
    expect(_textContaining('Approved proofs: 2'), findsOneWidget);
    expect(_textContaining('Rejected proofs: 1'), findsOneWidget);
    expect(find.text('Mangatarem Forest Cleanup'), findsOneWidget);
    expect(_textContaining('Check in at Patar Beach'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress targets open their pages', (tester) async {
    for (final key in [
      'home_stat_streak',
      'home_stat_visits',
      'home_stat_destinations',
      'home_stat_municipalities',
    ]) {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/profile');
    }
    for (final key in [
      'home_proof_pending',
      'home_proof_approved',
      'home_proof_rejected',
      'home_latest_proof',
    ]) {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/history');
    }
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_daily_mission')),
      '/quests',
    );
  });

  testWidgets(
      'quests tab shows in-progress quests, completed count and see all',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
    expect(find.text('1 / 2 tasks done'), findsOneWidget);
    expect(find.text('Patar Beach Cleanup'), findsNothing);
    expect(_textContaining('Completed quests: 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_see_all_quests')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quests targets open their pages', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_quest_q1')),
      '/quests/q1',
    );
    await _pump(tester);
    await _openTab(tester, 'quests');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_completed_quests')),
      '/quests',
    );
    await _pump(tester);
    await _openTab(tester, 'quests');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_see_all_quests')),
      '/quests',
    );
  });

  testWidgets('collection tab shows stamps, badges and saved spots', (
    tester,
  ) async {
    await _pump(tester);
    await _openTab(tester, 'collection');
    expect(_textContaining('Passport stamps: 12'), findsOneWidget);
    expect(_textContaining('Badges earned: 2 of 3'), findsOneWidget);
    expect(_textContaining('Saved spots: 1'), findsOneWidget);
    expect(find.text('Eco Pioneer'), findsOneWidget);
    expect(find.text('Heritage Keeper'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection targets open their pages', (tester) async {
    for (final key in ['home_collection_stamps', 'home_collection_badges']) {
      await _pump(tester);
      await _openTab(tester, 'collection');
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/profile');
    }
    await _pump(tester);
    await _openTab(tester, 'collection');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_collection_saved')),
      '/saved',
    );
    await _pump(tester);
    await _openTab(tester, 'collection');
    await _tapRoute(
        tester, find.byKey(const ValueKey('home_badge_eco')), '/profile');
  });

  testWidgets('empty states render without invented data', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        engagement: () async => const ChoiceEngagementSummary(
          currentStreak: 0,
          longestStreak: 0,
          nextMilestone: 1,
          verifiedVisits: 0,
          uniqueDestinations: 0,
          municipalities: 0,
          participations: 0,
          challenges: [],
        ),
        quests: QuestState(quests: const [], isLoading: false),
        spots: const SpotDiscoveryState(spots: [], isInitialLoading: false),
        submissions: SubmissionState(submissions: const []),
        daily: () async => const HomeDailyState(stamps: 0, missions: []),
      ),
    );
    expect(_textContaining('Visit streak: 0 days'), findsOneWidget);
    expect(find.text('No proofs submitted yet.'), findsOneWidget);
    expect(find.text('No daily mission today.'), findsOneWidget);
    await _openTab(tester, 'quests');
    expect(find.text('No quests in progress yet.'), findsOneWidget);
    expect(_textContaining('Completed quests: 0'), findsOneWidget);
    await _openTab(tester, 'collection');
    expect(_textContaining('Passport stamps: 0'), findsOneWidget);
    expect(_textContaining('Badges earned: 0 of 3'), findsOneWidget);
    expect(find.text('No saved spots yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error states render with retries', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        engagement: () async => throw Exception('engagement down'),
        overview: () async => throw Exception('overview down'),
        quests: QuestState(error: 'Quest list unavailable'),
        spots: const SpotDiscoveryState(
          isInitialLoading: false,
          failure: ApiFailure(
            code: ApiFailureCodes.serverUnavailable,
            message: 'spots down',
          ),
        ),
        submissions: SubmissionState(error: 'submissions down'),
        daily: () async => throw Exception('daily down'),
      ),
    );
    expect(find.text('Travel stats are unavailable.'), findsOneWidget);
    expect(find.text('Proof submissions are unavailable.'), findsOneWidget);
    expect(find.text('Daily mission is unavailable.'), findsOneWidget);
    expect(find.text('JuanChoice is unavailable.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_progress_stats_retry')));
    await tester.pump();
    await _openTab(tester, 'quests');
    expect(find.text('Quests are unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_quests_retry')), findsOneWidget);
    await _openTab(tester, 'collection');
    expect(find.text('Stamps are unavailable.'), findsOneWidget);
    expect(find.text('Saved spots are unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JuanChoice shows an open vote and the voter status', (
    tester,
  ) async {
    await _pump(
      tester,
      overrides: _overrides(
        overview: () async => _openOverview(),
        detail: (id) async => _voteDetail(voted: true),
      ),
    );
    expect(_textContaining('Voting now: Best Sunset Spot'), findsOneWidget);
    expect(_textContaining('2 days left'), findsOneWidget);
    expect(_textContaining('you voted'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_juanchoice_card')),
      '/choice/camp-1',
    );
  });

  testWidgets('JuanChoice says when the traveler has not voted yet', (
    tester,
  ) async {
    await _pump(
      tester,
      overrides: _overrides(
        overview: () async => _openOverview(),
        detail: (id) async => _voteDetail(voted: false),
      ),
    );
    expect(_textContaining('you have not voted yet'), findsOneWidget);
  });

  testWidgets('JuanChoice shows the last winner and votes', (tester) async {
    await _pump(tester);
    expect(_textContaining('Last results: Week 44'), findsOneWidget);
    expect(_textContaining('Patar White Beach'), findsOneWidget);
    expect(_textContaining('74 votes'), findsOneWidget);
    expect(_textContaining('128 ballots counted'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_juanchoice_card')),
      '/choice',
    );
  });

  testWidgets('notifications and next-stop targets open their pages', (
    tester,
  ) async {
    await _pump(tester);
    await _tapRoute(tester, find.byTooltip('Notifications'), '/notifications');
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_next_stop_quests')),
      '/quests',
    );
  });

  testWidgets('tutorial targets point at the hero and the quests tab', (
    tester,
  ) async {
    final keys = HomeTipsKeys();
    await _pump(
      tester,
      overrides: [
        ..._overrides(),
        homeTipsKeysProvider.overrideWithValue(keys),
      ],
    );
    expect(keys.hero.currentContext, isNotNull);
    expect(keys.nextStop.currentContext, isNotNull);
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('home tabs fit ${size.width}x${size.height} at 1.4x text', (
      tester,
    ) async {
      await _pump(tester, size: size, textScale: 1.4);
      for (final tab in ['progress', 'quests', 'collection']) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('home_tab_$tab')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
