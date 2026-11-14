import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
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

const _daily = HomeDailyState(
  stamps: 5,
  streak: 4,
  nominalStamps: 5,
  claimToday: false,
  claimDay: 1,
  missions: [
    HomeDailyMission(
      id: 'm1',
      kind: 'check_in',
      title: 'Check in at Patar Beach',
      stamps: 5,
      progress: 0,
      target: 1,
      completed: false,
    ),
    HomeDailyMission(
      id: 'm2',
      kind: 'cheer_post',
      title: 'Cheer an explorer',
      stamps: 3,
      progress: 1,
      target: 1,
      completed: true,
    ),
  ],
  calendar: [
    HomeStampDay(day: 1, stamps: 5, claimed: false),
    HomeStampDay(day: 2, stamps: 5, claimed: false),
    HomeStampDay(day: 3, stamps: 5, claimed: false),
    HomeStampDay(day: 4, stamps: 10, claimed: false),
    HomeStampDay(day: 5, stamps: 10, claimed: false),
    HomeStampDay(day: 6, stamps: 10, claimed: false),
    HomeStampDay(day: 7, stamps: 25, claimed: false),
  ],
);

const _qotd = HomeQotdState(
  date: '2026-11-05',
  questionId: 'q-1',
  questionText:
      'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
  quizTitle: 'Pangasinan Religious Heritage',
  options: [
    HomeQotdOption(id: 'o1', ordinal: 1, text: 'Manaoag'),
    HomeQotdOption(id: 'o2', ordinal: 2, text: 'San Fabian'),
  ],
);

final List<QuestModel> _quests = [
  QuestModel(
    id: 'q1',
    title: 'Hundred Islands Eco Trek',
    description: 'Explore the islands.',
    category: 'eco',
    locationName: 'Alaminos City',
    gpsLat: 16.2,
    gpsLng: 120.0,
    radiusMeters: 100,
    rewardPoints: 50,
    markerImageUrl: '',
    steps: const [
      QuestStepModel(
        order: 1,
        title: 'Check in at Lucap',
        description: 'Arrive at the wharf',
        checkpointType: 'location',
        required: true,
        status: 'verified',
      ),
      QuestStepModel(
        order: 2,
        title: 'Clean Governor Island',
        description: 'Pick up litter',
        checkpointType: 'photo',
        required: true,
        status: 'pending',
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
];

const _emptyQotd = HomeQotdState(
  date: '',
  questionId: '',
  questionText: '',
  quizTitle: '',
  options: [],
);

Map<String, dynamic> _qotdJson() => {
      'date': '2026-11-05',
      'question': {
        'id': 'q1',
        'text':
            'Which town is home to the Minor Basilica of Our Lady of Manaoag?',
        'quiz_title': 'Pangasinan 101',
        'options': [
          {'id': 'o1', 'ordinal': 1, 'text': 'Manaoag'},
          {'id': 'o2', 'ordinal': 2, 'text': 'San Fabian'},
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

List<Override> _overrides({
  _FakeApi? api,
  UserModel? user,
  HomeDailyState? daily,
  AsyncValue<HomeDailyState>? dailyState,
  AsyncValue<HomeQotdState>? qotd,
  bool realQotd = false,
  AsyncValue<ChoiceOverview>? choiceOverview,
  QuestState? quests,
  SubmissionState? submissions,
}) {
  final fake = api ?? _FakeApi();
  return [
    apiClientProvider.overrideWithValue(fake.client),
    authProvider.overrideWith(
      (ref) => _AuthNotifier(
        ref.read(apiClientProvider),
        ref.watch(authRefreshProvider.notifier),
        user ?? _user,
      ),
    ),
    choiceEngagementProvider.overrideWith((ref) async => _summary),
    choiceOverviewProvider.overrideWith(
      (ref) => choiceOverview != null
          ? (choiceOverview.hasError
              ? Future.error(choiceOverview.error!, choiceOverview.stackTrace)
              : Future.value(choiceOverview.value!))
          : Future.value(
              ChoiceOverview(
                current: ChoiceCampaign(
                  id: 'camp-1',
                  theme: 'Bangus Festival Spotlight',
                  region: 'Pangasinan',
                  status: 'voting',
                  opensAt: DateTime.now().subtract(const Duration(days: 1)),
                  closesAt: DateTime.now().add(const Duration(days: 5)),
                ),
                nextOpensAt: null,
                nextClosesAt: null,
                nextTheme: null,
                previous: null,
                notice: null,
                votingEnabled: true,
              ),
            ),
    ),
    homeDailyProvider.overrideWith(
      (ref) => dailyState != null
          ? (dailyState.hasError
              ? Future.error(dailyState.error!, dailyState.stackTrace)
              : Future.value(dailyState.value!))
          : Future.value(daily ?? _daily),
    ),
    if (!realQotd)
      homeQotdProvider.overrideWith(
        (ref) => _FixedQotdNotifier(ref, qotd ?? const AsyncValue.data(_qotd)),
      ),
    questProvider.overrideWith(
      (ref) => _QuestFixture(
        ref.read(apiClientProvider),
        quests ?? QuestState(quests: _quests, isLoading: false),
      ),
    ),
    spotDiscoveryProvider.overrideWith(
      (ref) => _SpotFixture(ref, const SpotDiscoveryState(isInitialLoading: false)),
    ),
    submissionProvider.overrideWith(
      (ref) => _SubmissionFixture(
        ref.read(apiClientProvider),
        submissions ?? SubmissionState(submissions: _submissions),
      ),
    ),
    hiddenGemProvider.overrideWith((ref) async => const []),
    homeTipsStoreProvider.overrideWithValue(_MemoryHomeTipsStore()),
  ];
}

class _FixedQotdNotifier extends HomeQotdNotifier {
  _FixedQotdNotifier(super.ref, AsyncValue<HomeQotdState> initial)
      : super(autoLoad: false) {
    state = initial;
  }

  @override
  Future<void> answer(String optionId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        answered: true,
        selectedOptionId: optionId,
        correct: optionId == 'o1',
        explanation: 'Manaoag is home to the Minor Basilica.',
      ),
    );
  }
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
          routes: [
            GoRoute(
              path: 'badges',
              builder: (_, __) => const _RouteProbe('/profile/badges'),
            ),
          ],
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
          path: '/plaza',
          builder: (_, __) => const _RouteProbe('/plaza'),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const _RouteProbe('/history'),
        ),
        GoRoute(
          path: '/shop',
          builder: (_, __) => const _RouteProbe('/shop'),
        ),
        GoRoute(
          path: '/wallet/connect',
          builder: (_, __) => const _RouteProbe('/wallet/connect'),
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
  Size size = const Size(400, 1600),
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
  group('Dashboard RPG Menu Layout', () {
    testWidgets('Hero renders identity, Level, XP bar, 3-slot Purse and numbers strip',
        (tester) async {
      await _pump(tester);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Heritage Keeper'), findsOneWidget);
      expect(find.text('Level 3'), findsOneWidget);
      expect(_textContaining('25 / 50 XP'), findsOneWidget);

      // 3-slot Purse
      expect(find.byKey(const ValueKey('home_purse_mjdq')), findsOneWidget);
      expect(find.text('125 MJDQ'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_purse_stamps')), findsOneWidget);
      expect(find.text('5 STAMPS'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_purse_rep')), findsOneWidget);
      expect(find.text('350 REP'), findsOneWidget);

      // 4-stat Numbers strip
      expect(find.byKey(const ValueKey('home_hero_stats_strip')), findsOneWidget);
      expect(find.text('VISITS: 18'), findsOneWidget);
      expect(find.text('TOWNS: 5'), findsOneWidget);
      expect(find.text('STREAK: 4D'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Purse slots and stats strip navigate to their pages', (tester) async {
      await _pump(tester);
      await _tapRoute(tester, find.byKey(const ValueKey('home_purse_mjdq')), '/shop');

      await _pump(tester);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_purse_stamps')),
        '/profile/badges',
      );

      await _pump(tester);
      await _tapRoute(tester, find.byKey(const ValueKey('home_purse_rep')), '/plaza');

      await _pump(tester);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_hero_stats_strip')),
        '/profile',
      );
    });

    testWidgets('Today\'s Pulse renders 3 action rows', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('home_todays_pulse')), findsOneWidget);
      expect(find.byKey(const ValueKey('pulse_row_daily_stamp')), findsOneWidget);
      expect(find.byKey(const ValueKey('pulse_row_qotd')), findsOneWidget);
      expect(find.byKey(const ValueKey('pulse_row_active_quest')), findsOneWidget);

      expect(find.text('DAILY STAMP: +5 READY'), findsOneWidget);
      expect(find.text('QUESTION OF THE DAY'), findsOneWidget);
      expect(find.text('ACTIVE: Hundred Islands Eco Trek'), findsOneWidget);
    });

    testWidgets('Active Quest button continues to quest detail', (tester) async {
      await _pump(tester);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_active_quest_continue')),
        '/quests/q1',
      );
    });

    testWidgets('Daily check-in claims reward and opens calendar', (tester) async {
      final fake = _FakeApi(
        claim: {
          'balance': 10,
          'claim': {
            'claimed_today': true,
            'cycle_day': 1,
            'nominal_stamps': 5,
            'awarded': 5,
            'calendar': [
              {'day': 1, 'stamps': 5, 'claimed': true},
              {'day': 2, 'stamps': 5, 'claimed': false},
            ],
          },
          'streak': {'current': 5, 'best': 7},
        },
      );
      await _pump(tester, overrides: _overrides(api: fake));
      await tester.tap(find.byKey(const ValueKey('home_daily_claim')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.calls['/me/daily/claim'], 1);
      expect(find.text('STAMP CLAIMED · DAY 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_daily_details')), findsOneWidget);

      // Open calendar sheet
      await tester.tap(find.byKey(const ValueKey('home_daily_details')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('7-DAY PASSPORT STAMPS'), findsOneWidget);
    });

    testWidgets('QOTD sheet opens and submits answer', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('home_qotd_answer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('home_qotd_panel')), findsOneWidget);
      expect(
        find.text('Which town is home to the Minor Basilica of Our Lady of Manaoag?'),
        findsOneWidget,
      );

      // Tap option o1
      await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Manaoag is home to the Minor Basilica.'), findsOneWidget);
    });

    testWidgets('Explorer Menu 2×3 launcher grid renders all 6 destinations',
        (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('home_explorer_menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_choice')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_plaza')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_quizzes_fiestas')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_history')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_menu_wallet')), findsOneWidget);

      await _tapRoute(tester, find.byKey(const ValueKey('home_menu_quests')), '/quests');
      await _pump(tester);
      await _tapRoute(tester, find.byKey(const ValueKey('home_menu_choice')), '/choice/camp-1');
      await _pump(tester);
      await _tapRoute(tester, find.byKey(const ValueKey('home_menu_plaza')), '/plaza');
      await _pump(tester);
      await _tapRoute(tester, find.byKey(const ValueKey('home_menu_history')), '/history');
      await _pump(tester);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_menu_wallet')),
        '/wallet/connect',
      );
    });

    testWidgets('Notifications button opens notifications route', (tester) async {
      await _pump(tester);
      await _tapRoute(
        tester,
        find.bySemanticsLabel('Notifications'),
        '/notifications',
      );
    });

    testWidgets('QOTD answer posts once using real API and shows result',
        (tester) async {
      final fake = _FakeApi(qotd: _qotdJson(), answer: _answerJson());
      await _pump(tester, overrides: _overrides(api: fake, realQotd: true));
      await tester.tap(find.byKey(const ValueKey('home_qotd_answer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('home_qotd_panel')), findsOneWidget);
      expect(
        find.text('Which town is home to the Minor Basilica of Our Lady of Manaoag?'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home_qotd_option_o1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.calls['/qotd/answer'], 1);
      expect(find.text('Manaoag is home to the Minor Basilica.'), findsOneWidget);
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

    testWidgets('daily claim empty and error states', (tester) async {
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
          dailyState: AsyncValue.error(Exception('daily down'), StackTrace.empty),
        ),
      );
      expect(find.text('Daily missions unavailable.'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_daily_retry')), findsOneWidget);
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
        steps: const [
          QuestStepModel(
            order: 1,
            title: 'Step 1',
            description: 'Check in',
            checkpointType: 'location',
            required: true,
            status: 'verified',
          ),
          QuestStepModel(
            order: 2,
            title: 'Step 2',
            description: 'Photo',
            checkpointType: 'photo',
            required: true,
            status: 'pending',
          ),
        ],
      );
      final state = QuestState(quests: [_quests.first, testQuest], isLoading: false);
      await _pump(tester, overrides: _overrides(quests: state));
      expect(find.text('1 active · 0 saved'), findsOneWidget);

      await _pump(
        tester,
        overrides: [
          ..._overrides(quests: state),
          showTestContentProvider.overrideWith((ref) => true),
        ],
      );
      expect(find.text('2 active · 0 saved'), findsOneWidget);
    });

    testWidgets('JuanChoice launcher reflects active campaign, results, and error states',
        (tester) async {
      // 1. Active voting campaign
      await _pump(tester);
      expect(find.text('Voting now: Bangus Festival Spotlight'), findsOneWidget);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_menu_choice')),
        '/choice/camp-1',
      );

      // 2. Closed / previous results state
      await _pump(
        tester,
        overrides: _overrides(
          choiceOverview: const AsyncValue.data(
            ChoiceOverview(
              current: null,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: ChoicePreviousResult(
                periodLabel: 'Week 44',
                validBallots: 70,
                coWinnerIds: {'cand-1'},
                standings: [],
              ),
              notice: null,
              votingEnabled: true,
            ),
          ),
        ),
      );
      expect(find.text('Last results: Week 44'), findsOneWidget);
      await _tapRoute(
        tester,
        find.byKey(const ValueKey('home_menu_choice')),
        '/choice',
      );

      // 3. Error state
      await _pump(
        tester,
        overrides: _overrides(
          choiceOverview: AsyncValue.error(Exception('choice down'), StackTrace.empty),
        ),
      );
      expect(find.text('JuanChoice is unavailable.'), findsOneWidget);
    });
  });
}
