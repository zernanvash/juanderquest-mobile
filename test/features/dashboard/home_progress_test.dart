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
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/dashboard/data/home_events.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_dashboard_providers.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/models/hidden_gem_model.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';

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

class _FakeApi {
  _FakeApi({this.qotd, this.answer, this.claim});

  final Map<String, dynamic>? qotd;
  final Map<String, dynamic>? answer;
  final Map<String, dynamic>? claim;
  final Map<String, int> calls = {};

  late final ApiClient client = _build();

  ApiClient _build() {
    final api = ApiClient(enableRetries: false);
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls[options.path] = (calls[options.path] ?? 0) + 1;
          if (options.path == '/me/discovery-preferences') {
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
            return;
          }
          if (options.path == '/qotd' && qotd != null) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': qotd},
              ),
            );
            return;
          }
          if (options.path == '/qotd/answer' && answer != null) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': answer},
              ),
            );
            return;
          }
          if (options.path == '/me/daily/claim' && claim != null) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': claim},
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': const <String, dynamic>{}},
            ),
          );
        },
      ),
    );
    return api;
  }
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
    distanceKm: 1.2,
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
    distanceKm: 4.6,
  ),
];

const _daily = HomeDailyState(
  stamps: 12,
  missions: [
    HomeDailyMission(
      id: 'm1',
      kind: 'quest_step',
      title: 'Check in at Patar Beach',
      stamps: 5,
      progress: 0,
      target: 1,
      completed: false,
    ),
    HomeDailyMission(
      id: 'm2',
      kind: 'cheer_post',
      title: 'Cheer a Plaza post',
      stamps: 2,
      progress: 1,
      target: 1,
      completed: true,
    ),
  ],
  date: '2026-11-05',
  claimToday: false,
  claimDay: 3,
  nominalStamps: 5,
  claimedDays: 2,
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
  shieldsHeld: 1,
  shieldsMax: 3,
  weekUsed: 20,
  weekCap: 250,
  chestCompleted: 2,
  chestRequired: 9,
  chestStamps: 25,
);

const _qotd = HomeQotdState(
  date: '2026-11-05',
  questionId: 'q1',
  questionText:
      'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
  quizTitle: 'Pangasinan 101',
  options: [
    HomeQotdOption(id: 'o1', ordinal: 1, text: 'Manaoag'),
    HomeQotdOption(id: 'o2', ordinal: 2, text: 'Alaminos'),
    HomeQotdOption(id: 'o3', ordinal: 3, text: 'Bolinao'),
    HomeQotdOption(id: 'o4', ordinal: 4, text: 'Dagupan'),
  ],
);

const _emptyQotd = HomeQotdState(
  date: '2026-11-05',
  questionId: '',
  questionText: '',
  quizTitle: '',
  options: [],
);

final _proposals = [
  GovernanceProposalModel(
    id: 'p1',
    title: 'Patar White Beach Eco Trail',
    locationName: 'Bolinao',
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
  ),
];

const _quizzes = HomeNearbyQuizzes(
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
);

const _gems = [
  HiddenGemModel(
    id: 'gem-1',
    name: 'Bolinao Falls',
    municipality: 'Bolinao',
    reason: 'A quiet waterfall away from the crowds.',
    crowdStatus: 'quiet',
  ),
];

final _events = [
  HomeEvent(
    id: 'ev-test',
    title: 'Pista Test Festival',
    date: DateTime.now().add(const Duration(days: 3)),
    municipality: 'Lingayen',
    category: 'festival',
    description: 'A test festival.',
    route: '/quests',
    badge: 'Festival',
  ),
];

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

Map<String, dynamic> _qotdJson() => {
      'date': '2026-11-05',
      'question': {
        'id': 'q1',
        'text':
            'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
        'quiz_title': 'Pangasinan 101',
        'options': [
          {'id': 'o1', 'ordinal': 1, 'text': 'Manaoag'},
          {'id': 'o2', 'ordinal': 2, 'text': 'Alaminos'},
          {'id': 'o3', 'ordinal': 3, 'text': 'Bolinao'},
          {'id': 'o4', 'ordinal': 4, 'text': 'Dagupan'},
        ],
      },
      'answered': false,
      'answer': null,
    };

Map<String, dynamic> _answerJson() => {
      'date': '2026-11-05',
      'correct': true,
      'correct_option_id': 'o1',
      'explanation': 'Manaoag is home to the Minor Basilica.',
      'source_url': null,
    };

Map<String, dynamic> _dailyJson({bool claimed = true}) => {
      'date': '2026-11-05',
      'next_reset_at':
          DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      'balance': claimed ? 17 : 12,
      'week': {'used': claimed ? 25 : 20, 'cap': 250},
      'claim': {
        'claimed_today': claimed,
        'cycle_day': 3,
        'claimed_days': claimed ? 3 : 2,
        'nominal_stamps': 5,
        'awarded': claimed ? 5 : 0,
        'capped': false,
        'calendar': [
          for (var day = 1; day <= 7; day++)
            {
              'day': day,
              'stamps': day == 7 ? 10 : 5,
              'claimed': claimed ? day <= 3 : day <= 2,
            },
        ],
      },
      'streak': {
        'current': 4,
        'best': 6,
        'shields_held': 1,
        'shields_max': 3,
        'shield_price': 25,
      },
      'chest': {
        'completed_missions': 2,
        'required': 9,
        'stamps': 25,
        'earned': false,
      },
      'missions': [
        {
          'id': 'm1',
          'kind': 'quest_step',
          'title': 'Check in at Patar Beach',
          'stamps': 5,
          'on_site': true,
          'progress': 0,
          'target': 1,
          'completed': false,
        },
      ],
    };

List<Override> _overrides({
  _FakeApi? api,
  Future<ChoiceEngagementSummary> Function()? engagement,
  Future<ChoiceOverview> Function()? overview,
  Future<ChoiceDetail> Function(String id)? detail,
  QuestState? quests,
  SpotDiscoveryState? spots,
  SubmissionState? submissions,
  HomeDailyState? daily,
  Future<HomeDailyState> Function()? dailyLoader,
  AsyncValue<HomeQotdState>? qotd,
  bool realQotd = false,
  Future<List<GovernanceProposalModel>> Function()? proposals,
  Future<HomeNearbyQuizzes> Function()? quizzes,
  Future<List<HiddenGemModel>> Function()? gems,
  List<HomeEvent>? events,
}) {
  final fake = api ?? _FakeApi();
  return [
    apiClientProvider.overrideWithValue(fake.client),
    authProvider.overrideWith(
      (ref) => _AuthNotifier(
        fake.client,
        ref.watch(authRefreshProvider.notifier),
        _user,
      ),
    ),
    questProvider.overrideWith(
      (ref) => _QuestFixture(
        fake.client,
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
        fake.client,
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
      (ref) => (dailyLoader ?? () async => daily ?? _daily)(),
    ),
    if (!realQotd)
      homeQotdProvider.overrideWith((ref) {
        final notifier = HomeQotdNotifier(ref, autoLoad: false);
        notifier.state = qotd ?? const AsyncValue.data(_qotd);
        return notifier;
      }),
    homeProposalsProvider.overrideWith(
      (ref) => (proposals ?? () async => _proposals)(),
    ),
    homeNearbyQuizProvider.overrideWith(
      (ref) => (quizzes ?? () async => _quizzes)(),
    ),
    hiddenGemProvider.overrideWith(
      (ref) => (gems ?? () async => _gems)(),
    ),
    homeEventsProvider.overrideWithValue(events ?? _events),
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
        GoRoute(
          path: '/map',
          builder: (_, __) => const _RouteProbe('/map'),
        ),
        GoRoute(
          path: '/vote',
          builder: (_, __) => const _RouteProbe('/vote'),
        ),
        GoRoute(
          path: '/plaza',
          builder: (_, __) => const _RouteProbe('/plaza'),
        ),
        GoRoute(
          path: '/affiliate',
          builder: (_, __) => const _RouteProbe('/affiliate'),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const _RouteProbe('/explore'),
          routes: [
            GoRoute(
              path: ':slug',
              builder: (_, state) =>
                  _RouteProbe('/explore/${state.pathParameters['slug']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/cultural-quizzes/:id',
          builder: (_, state) =>
              _RouteProbe('/cultural-quizzes/${state.pathParameters['id']}'),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Override>? overrides,
  Size size = const Size(400, 2600),
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
      key: UniqueKey(),
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
  await tester.pump(const Duration(milliseconds: 50));
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

void _expectSlot(String key, String label, String value) {
  final slot = find.byKey(ValueKey(key));
  expect(slot, findsOneWidget, reason: 'missing $key');
  expect(
    find.descendant(of: slot, matching: find.text(label)),
    findsOneWidget,
    reason: '$key label',
  );
  expect(
    find.descendant(of: slot, matching: find.text(value)),
    findsOneWidget,
    reason: '$key value',
  );
}

void main() {
  testWidgets(
      'hero is the compact layout B header and wallet lives in Progress',
      (tester) async {
    await _pump(tester);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Heritage Keeper'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(_textContaining('25 / 50 XP'), findsOneWidget);
    // The spendable balance Profile and Shop show (points), not mjdqBalance.
    _expectSlot('home_wallet_mjdq', 'mJDQ balance', '125');
    _expectSlot('home_wallet_jdq', 'JDQ governance', '12');
    _expectSlot('home_wallet_rep', 'Scout reputation', '350');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero and wallet targets open the profile', (tester) async {
    for (final key in [
      'home_hero_profile',
      'home_hero_level',
      'home_hero_level_chip',
      'home_hero_title_chip',
      'home_wallet_mjdq',
      'home_wallet_jdq',
      'home_wallet_rep',
    ]) {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/profile');
    }
  });

  testWidgets('Progress shows every web panel with data', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('home_qotd_panel')), findsOneWidget);
    expect(
      find.text(
        'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home_daily_panel')), findsOneWidget);
    expect(find.text('Claim +5 stamps'), findsOneWidget);
    expect(_textContaining('Check in at Patar Beach'), findsOneWidget);
    _expectSlot('home_stat_streak', 'Visit streak', '4 days');
    _expectSlot('home_stat_visits', 'Verified visits', '18');
    _expectSlot('home_stat_destinations', 'Destinations', '7');
    _expectSlot('home_stat_municipalities', 'Municipalities', '5');
    expect(find.text('Hundred Islands National Park'), findsOneWidget);
    _expectSlot('home_proof_pending', 'Pending proofs', '1');
    _expectSlot('home_proof_approved', 'Approved proofs', '2');
    _expectSlot('home_proof_rejected', 'Rejected proofs', '1');
    expect(find.text('Mangatarem Forest Cleanup'), findsOneWidget);
    expect(find.text('Patar White Beach Eco Trail'), findsNothing);
    expect(find.byKey(const ValueKey('home_affiliate')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QOTD answer posts once and shows the result', (tester) async {
    final fake = _FakeApi(qotd: _qotdJson(), answer: _answerJson());
    await _pump(tester, overrides: _overrides(api: fake, realQotd: true));
    expect(
      find.text(
        'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('home_qotd_option_o1')),
    );
    await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('home_qotd_option_o1')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls['/qotd/answer'], 1);
    expect(find.text('Correct!'), findsOneWidget);
    expect(_textContaining('Manaoag is home'), findsOneWidget);
    // Answered: only the chosen (here also correct) option stays.
    expect(find.byKey(const ValueKey('home_qotd_option_o1')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_qotd_option_o2')), findsNothing);
  });

  testWidgets('QOTD empty and error states', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        qotd: const AsyncValue.data(_emptyQotd),
      ),
    );
    expect(find.text('No question today.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        qotd: AsyncValue.error(Exception('qotd down'), StackTrace.empty),
      ),
    );
    expect(find.text('Question of the Day is unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_qotd_retry')), findsOneWidget);
  });

  testWidgets('daily claim posts once and shows the claimed state',
      (tester) async {
    final fake = _FakeApi(claim: _dailyJson());
    await _pump(tester, overrides: _overrides(api: fake));
    await tester.ensureVisible(
      find.byKey(const ValueKey('home_daily_claim')),
    );
    await tester.tap(find.byKey(const ValueKey('home_daily_claim')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('home_daily_claim')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls['/me/daily/claim'], 1);
    expect(_textContaining('Claimed today'), findsOneWidget);
    expect(_textContaining('17 stamps'), findsOneWidget);
  });

  testWidgets('daily stamps empty and error states', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        daily: const HomeDailyState(stamps: 0, missions: []),
      ),
    );
    expect(find.text('No daily missions today.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        dailyLoader: () async => throw Exception('daily down'),
      ),
    );
    expect(find.text('Daily stamps are unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_daily_retry')), findsOneWidget);
  });

  testWidgets('daily mission targets open their pages', (tester) async {
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_daily_mission_m1')),
      '/quests',
    );
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_daily_mission_m2')),
      '/plaza',
    );
  });

  testWidgets('travel stats and proof rows open their pages', (tester) async {
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
      'home_recent_sub-pending',
    ]) {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(ValueKey(key)), '/history');
    }
  });

  testWidgets('nearby radar data, empty and error states', (tester) async {
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_nearby_spot-1')),
      '/explore/spot-1',
    );
    await _pump(tester);
    await _tapRoute(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('home_radar_panel')),
        matching: find.text('Map'),
      ),
      '/map',
    );

    await _pump(
      tester,
      overrides: _overrides(
        spots: const SpotDiscoveryState(spots: [], isInitialLoading: false),
      ),
    );
    expect(find.text('No destinations nearby yet.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        spots: const SpotDiscoveryState(
          isInitialLoading: false,
          failure: ApiFailure(
            code: ApiFailureCodes.serverUnavailable,
            message: 'spots down',
          ),
        ),
      ),
    );
    expect(find.text('Nearby destinations are unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_radar_retry')), findsOneWidget);
  });

  testWidgets('proof empty and error states', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        submissions: SubmissionState(submissions: const []),
      ),
    );
    expect(find.text('No recent submissions yet.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        submissions: SubmissionState(error: 'submissions down'),
      ),
    );
    expect(find.text('Proof submissions are unavailable.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_progress_proof_retry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('home_progress_proof_retry')));
    await tester.pump();
  });

  testWidgets('quest progress panel data, empty and error states',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
    expect(_textContaining('Step 2 of 2'), findsOneWidget);
    _expectSlot('home_completed_quests', 'Completed quests', '2');

    await _pump(
      tester,
      overrides: _overrides(
        quests: QuestState(quests: const [], isLoading: false),
      ),
    );
    await _openTab(tester, 'quests');
    expect(find.text('No quests in progress yet.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(quests: QuestState(error: 'quests down')),
    );
    await _openTab(tester, 'quests');
    expect(find.text('Quests are unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_quests_retry')), findsOneWidget);
  });

  testWidgets('quest progress targets open their pages', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_quest_continue_q1')),
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

  testWidgets('nearby quiz data, empty and error states', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    expect(find.text('Islands and Legends'), findsOneWidget);
    expect(_textContaining('125 m away'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_quiz_quiz-1')),
      '/cultural-quizzes/quiz-1',
    );

    await _pump(
      tester,
      overrides: _overrides(
        quizzes: () async => const HomeNearbyQuizzes(items: [], origin: 'gps'),
      ),
    );
    await _openTab(tester, 'quests');
    expect(find.text('No quizzes near you yet.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        quizzes: () async => throw Exception('quiz down'),
      ),
    );
    await _openTab(tester, 'quests');
    expect(find.text('Nearby quizzes are unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_quiz_retry')), findsOneWidget);
  });

  testWidgets('events panel data and empty states', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    expect(find.text('Pista Test Festival'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_event_ev-test')),
      '/quests',
    );

    await _pump(
      tester,
      overrides: _overrides(events: const []),
    );
    await _openTab(tester, 'quests');
    expect(find.text('No upcoming events listed.'), findsOneWidget);
  });

  testWidgets('collection panel data and tap routes', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'collection');
    _expectSlot('home_collection_stamps', 'Passport stamps', '12');
    _expectSlot('home_collection_badges', 'Badges earned', '2 of 3');
    _expectSlot('home_collection_saved', 'Saved spots', '1');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_collection_stamps')),
      '/profile',
    );
    await _pump(tester);
    await _openTab(tester, 'collection');
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_collection_badges')),
      '/profile',
    );
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
      tester,
      find.byKey(const ValueKey('home_badge_eco')),
      '/profile',
    );
  });

  testWidgets('collection empty and error states', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        daily: const HomeDailyState(stamps: 0, missions: []),
        submissions: SubmissionState(submissions: const []),
        spots: const SpotDiscoveryState(spots: [], isInitialLoading: false),
      ),
    );
    await _openTab(tester, 'collection');
    _expectSlot('home_collection_stamps', 'Passport stamps', '0');
    _expectSlot('home_collection_badges', 'Badges earned', '0 of 3');
    expect(find.text('No saved spots yet.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        dailyLoader: () async => throw Exception('daily down'),
        spots: const SpotDiscoveryState(
          isInitialLoading: false,
          failure: ApiFailure(
            code: ApiFailureCodes.serverUnavailable,
            message: 'spots down',
          ),
        ),
      ),
    );
    await _openTab(tester, 'collection');
    expect(find.text('Stamps are unavailable.'), findsOneWidget);
    expect(find.text('Saved spots are unavailable.'), findsOneWidget);
  });

  testWidgets('hidden gems data, empty and error states', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'collection');
    expect(find.text('Bolinao Falls'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_hidden_gem_gem-1')),
      '/explore/gem-1',
    );

    await _pump(
      tester,
      overrides: _overrides(gems: () async => const []),
    );
    await _openTab(tester, 'collection');
    expect(find.text('No hidden gems today.'), findsOneWidget);

    await _pump(
      tester,
      overrides: _overrides(
        gems: () async => throw Exception('gems down'),
      ),
    );
    await _openTab(tester, 'collection');
    expect(
      find.text('Hidden gem highlights are unavailable.'),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('home_hidden_gems_retry')), findsOneWidget);
  });

  testWidgets('no community voting card: governance is a read-only archive',
      (tester) async {
    // Owner 2026-11-05 (Plan 75n §7): JuanChoice is the only live vote.
    await _pump(tester);
    expect(find.byKey(const ValueKey('home_proposals_panel')), findsNothing);
    expect(find.byKey(const ValueKey('home_vote_open')), findsNothing);
    expect(find.text('Patar White Beach Eco Trail'), findsNothing);
  });

  testWidgets('affiliate invite opens the partner hub', (tester) async {
    await _pump(tester);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_affiliate')),
      '/affiliate',
    );
  });

  testWidgets('JuanChoice open vote, results and error', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        overview: () async => _openOverview(),
        detail: (id) async => _voteDetail(voted: true),
      ),
    );
    expect(_textContaining('Voting now: Best Sunset Spot'), findsOneWidget);
    expect(_textContaining('you voted'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_juanchoice_card')),
      '/choice/camp-1',
    );

    await _pump(tester);
    expect(_textContaining('Last results: Week 44'), findsOneWidget);
    expect(_textContaining('74 votes'), findsOneWidget);
    await _tapRoute(
      tester,
      find.byKey(const ValueKey('home_juanchoice_card')),
      '/choice',
    );

    await _pump(
      tester,
      overrides: _overrides(
        overview: () async => throw Exception('choice down'),
      ),
    );
    expect(find.text('JuanChoice is unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_juanchoice_retry')), findsOneWidget);
  });

  testWidgets('notifications and next stop targets open their pages', (
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

  // ---------------------------------------------------------- Plan 75n WP-3
  testWidgets('events header says upcoming festivals; titles use full width',
      (tester) async {
    final event = HomeEvent(
      id: 'ev-long',
      title: 'Pista ng Dayat Sea Festival and Grand Street Dancing',
      date: DateTime.now().add(const Duration(days: 300)),
      municipality: 'Lingayen',
      category: 'festival',
      description: 'A long-named festival.',
      route: '/quests',
    );
    await _pump(tester, overrides: _overrides(events: [event]));
    await _openTab(tester, 'quests');
    expect(_textContaining('Upcoming festivals'), findsOneWidget);
    expect(_textContaining('This month in Pangasinan'), findsNothing);
    final title = tester.getSize(
      find.byKey(const ValueKey('home_event_title_ev-long')),
    );
    final row = tester.getSize(find.byKey(const ValueKey('home_event_ev-long')));
    // The countdown chip no longer sits beside the title.
    expect(title.width, greaterThan(row.width * 0.8));
  });

  testWidgets('hidden gems hide an unknown crowd level', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(
        gems: () async => const [
          HiddenGemModel(
            id: 'gem-unknown',
            name: 'Tondol White Sand Beach Cove',
            municipality: 'Anda',
            reason: 'Shallow water.',
          ),
          HiddenGemModel(
            id: 'gem-quiet',
            name: 'Bolinao Falls',
            municipality: 'Bolinao',
            reason: 'A quiet waterfall.',
            crowdStatus: 'quiet',
          ),
        ],
      ),
    );
    await _openTab(tester, 'collection');
    expect(find.text('Tondol White Sand Beach Cove'), findsOneWidget);
    expect(_textContaining('unknown'), findsNothing);
    expect(
      find.text(const HiddenGemModel(
        id: 'x',
        name: 'x',
        municipality: 'x',
        reason: 'x',
        crowdStatus: 'quiet',
      ).crowdLabel),
      findsOneWidget,
    );
  });

  testWidgets('test quests stay off Home unless Developer mode shows them',
      (tester) async {
    final testQuest = QuestModel(
      id: 'q-sim',
      title: 'SIM Lingayen heritage walk',
      description: 'QA sample.',
      category: 'heritage',
      locationName: 'Lingayen',
      gpsLat: 16.0,
      gpsLng: 120.2,
      radiusMeters: 100,
      rewardPoints: 10,
      markerImageUrl: '',
      isTest: true,
      steps: _quests.first.steps,
    );
    final state = QuestState(quests: [..._quests, testQuest], isLoading: false);
    await _pump(tester, overrides: _overrides(quests: state));
    await _openTab(tester, 'quests');
    expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
    expect(find.text('SIM Lingayen heritage walk'), findsNothing);

    await _pump(
      tester,
      overrides: [
        ..._overrides(quests: state),
        showTestContentProvider.overrideWith((ref) => true),
      ],
    );
    await _openTab(tester, 'quests');
    expect(find.text('SIM Lingayen heritage walk'), findsOneWidget);
  });

  testWidgets('quest progress has one See all (the button), not two',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, 'quests');
    expect(find.byKey(const ValueKey('home_see_all_quests')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home_quest_progress_panel')),
        matching: _textContaining('See all'),
      ),
      findsOneWidget,
    );
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final tab in ['progress', 'quests', 'collection']) {
      testWidgets(
          'home $tab tab fits ${size.width}x${size.height} at 1.4x text', (
        tester,
      ) async {
        await _pump(tester, size: size, textScale: 1.4);
        final tabFinder = find.byKey(ValueKey('home_tab_$tab'));
        await tester.ensureVisible(tabFinder);
        await tester.tap(tabFinder);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final bottom = switch (tab) {
          'progress' => 'home_affiliate_panel',
          'quests' => 'home_events_panel',
          _ => 'home_hidden_gems_panel',
        };
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(bottom)),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
