import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/widgets/quest_card.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/celebrations/celebration.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/pixel/daily_mission.dart';
import 'package:juanderquest_app/features/quests/pixel/quest_paging.dart';
import 'package:juanderquest_app/features/quests/pixel/saved_quests.dart';
import 'package:juanderquest_app/features/quests/pixel/task_icons.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_builder_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_list_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
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

  /// Lets a test deliver quests after the first build, like the network does.
  void emit(QuestState next) => state = next;
}

class _CampaignFixture extends CampaignNotifier {
  _CampaignFixture(super.apiClient, CampaignState initial) {
    state = initial;
  }

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient, SubmissionState initial) {
    state = initial;
  }

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _MemorySavedStorage implements SavedQuestsStorage {
  _MemorySavedStorage([List<String>? seed]) : ids = seed ?? <String>[];

  List<String> ids;

  @override
  Future<List<String>> read() async => List.of(ids);

  @override
  Future<void> write(List<String> values) async {
    ids = List.of(values);
  }
}

class _FakeBuilderRepo extends QuestBuilderRepository {
  _FakeBuilderRepo(super.client);

  Map<String, dynamic>? lastCreatedPayload;
  String? lastCreatedSpot;

  @override
  Future<String> createQuest({
    required String spotIdOrSlug,
    required Map<String, dynamic> payload,
  }) async {
    lastCreatedSpot = spotIdOrSlug;
    lastCreatedPayload = payload;
    return 'created-quest';
  }

  @override
  Future<Map<String, dynamic>> getQuestForEdit(String questId) async => {
        'id': questId,
        'title': 'Existing Edit Quest',
        'description': 'Existing description for edit',
        'category': 'eco',
        'reward_points': 75,
        'order_mode': 'sequential',
        'status': 'draft',
        'version': 1,
        'tasks': [
          {
            'title': 'Existing Task',
            'description': 'Description for task',
            'verification': {
              'type': 'location',
              'fence': {'lat': 16.2, 'lng': 120.0, 'radius_meters': 100},
            },
            'is_required': true,
          },
        ],
      };

  @override
  Future<int?> patchQuest({
    required String questId,
    required Map<String, dynamic> payload,
  }) async =>
      2;
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
  seedId: 'scale',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 125,
);

const _spot = SpotModel(
  id: 's1',
  slug: 'hundred-islands',
  name: 'Hundred Islands National Park',
  description: 'Beautiful islands.',
  category: 'nature_outdoors',
  subcategory: 'islands',
  municipality: 'Alaminos City',
  address: 'Lucap Wharf',
  sourceName: 'Tourism Office',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2,
  gpsLng: 120.0,
  tags: [],
  reasons: [],
);

QuestModel _quest(
  String id,
  String title, {
  String category = 'eco',
  String location = 'Alaminos City',
  String? authorId,
  QuestFundingSummary? funding,
  List<QuestStepModel> steps = const [],
}) =>
    QuestModel(
      id: id,
      title: title,
      description: 'Visit the site, verify on site and learn the local story.',
      category: category,
      locationName: location,
      gpsLat: 16.2,
      gpsLng: 120.0,
      radiusMeters: 100,
      rewardPoints: 75,
      markerImageUrl: '',
      authorId: authorId,
      funding: funding,
      baseRewardPhp: 25,
      difficultyFactor: 1.2,
      steps: steps,
      tags: const ['eco', 'heritage'],
    );

const _campaign = CampaignModel(
  id: 'c1',
  hostId: 'host',
  hostName: 'Dagupan Tourism',
  title: 'Bangus Festival 2026',
  category: 'cultural',
  locationName: 'Dagupan City',
  municipality: 'Dagupan City',
  bannerImageUrl: '',
  description: 'A community festival.',
  eventDate: '2026-09-15T08:00:00Z',
  startDate: '2026-09-01T00:00:00Z',
  endDate: '2026-09-15T22:00:00Z',
  totalBudgetMjdq: 100,
  rewardPerParticipantMjdq: 10,
  referralBountyMjdq: 5,
  maxParticipants: 100,
  reservedParticipants: 10,
  completedParticipants: 1,
  preQuestRequirements: [],
  status: 'active',
  createdAt: '2026-08-01T00:00:00Z',
);

const _setupSteps = <QuestStepModel>[
  QuestStepModel(
    order: 1,
    title: 'Arrive at the entrance',
    description: 'Check in near the main gate.',
    checkpointType: 'location',
    required: true,
    status: 'ready',
  ),
  QuestStepModel(
    order: 2,
    title: 'Scan the heritage plaque',
    description: 'Scan the QR code on the plaque.',
    checkpointType: 'qr',
    required: true,
    status: 'needs_changes',
    rejectionReason: 'Get closer to the plaque.',
  ),
  QuestStepModel(
    order: 3,
    title: 'Photograph the view',
    description: 'Take a clear photo of the cove.',
    checkpointType: 'photo',
    required: true,
    status: 'pending_review',
  ),
  QuestStepModel(
    order: 4,
    title: 'Find the AR token',
    description: 'Find the floating token.',
    checkpointType: 'ar',
    required: true,
    status: 'verified',
  ),
  QuestStepModel(
    order: 5,
    title: 'Answer the story',
    description: 'Open the in-app story.',
    checkpointType: 'action',
    required: true,
    status: 'not_started',
  ),
];

Future<ApiClient> _detailApi(
  QuestModel quest, {
  List<QuestStepModel>? steps,
  bool completeSucceeds = true,
  bool rewardAwarded = true,
  bool hasAttempt = true,
}) async {
  final api = ApiClient(enableRetries: false);
  final attemptSteps = steps ?? _setupSteps;
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/${quest.id}/progress') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'has_completed': false,
                  'active_attempt': !hasAttempt
                      ? null
                      : {
                          'id': 'attempt-1',
                          'quest_id': quest.id,
                          'user_id': _user.id,
                          'status': 'in_progress',
                          'step_order_mode': 'sequential',
                          'verified_steps': attemptSteps
                              .where((step) => step.isVerified)
                              .length,
                          'required_steps': attemptSteps.length,
                          'total_steps': attemptSteps.length,
                          'steps': attemptSteps
                              .map((step) => step.toJson())
                              .toList(),
                        },
                },
              },
            ),
          );
          return;
        }
        if (options.path == '/quests/${quest.id}/complete') {
          if (completeSucceeds) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'reward_awarded': rewardAwarded,
                    'awarded_points': rewardAwarded ? 75 : 0,
                  },
                },
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 503,
                  data: {
                    'error': {'message': 'Completion unavailable.'},
                  },
                ),
              ),
            );
          }
          return;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ),
        );
      },
    ),
  );
  return api;
}

GoRouter _router(
  String initial,
  Widget screen,
) =>
    GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: initial, builder: (_, __) => screen),
        GoRoute(
          path: '/quests/campaigns/:id',
          builder: (_, state) =>
              _RouteProbe('/quests/campaigns/${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/quests/:id',
          builder: (_, state) =>
              _RouteProbe('/quests/${state.pathParameters['id']}'),
        ),
        GoRoute(
            path: '/navigate',
            builder: (_, __) => const _RouteProbe('/navigate')),
        GoRoute(path: '/map', builder: (_, __) => const _RouteProbe('/map')),
        GoRoute(
            path: '/login', builder: (_, __) => const _RouteProbe('/login')),
        GoRoute(
          path: '/quests/:id/edit',
          builder: (_, state) =>
              _RouteProbe('/quests/${state.pathParameters['id']}/edit'),
        ),
        GoRoute(
          path: '/quests/:id/qr-sheet',
          builder: (_, state) =>
              _RouteProbe('/quests/${state.pathParameters['id']}/qr-sheet'),
        ),
        GoRoute(
          path: '/quests/:id/funding',
          builder: (_, state) =>
              _RouteProbe('/quests/${state.pathParameters['id']}/funding'),
        ),
        GoRoute(
          path: '/quests/:id/ar',
          builder: (_, state) =>
              _RouteProbe('/quests/${state.pathParameters['id']}/ar'),
        ),
      ],
    );

Future<void> _pumpList(
  WidgetTester tester, {
  List<QuestModel>? quests,
  List<CampaignModel>? campaigns,
  SubmissionState? submissions,
  bool mission = false,
  bool signedOut = false,
  Future<bool> Function()? missionFetcher,
  SavedQuestsStorage? savedStorage,
  Size size = const Size(400, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final api = ApiClient(enableRetries: false);
  final router = _router('/quests', const QuestListScreen());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(
          (ref) => _Auth(
            api,
            ref.watch(authRefreshProvider.notifier),
            signedOut ? null : _user,
          ),
        ),
        questProvider.overrideWith(
          (ref) => _QuestFixture(
            api,
            QuestState(
              quests: quests ??
                  [
                    _quest('q1', 'Coastal cleanup'),
                    _quest('q2', 'Heritage walk', category: 'cultural'),
                  ],
              isLoading: false,
            ),
          ),
        ),
        campaignProvider.overrideWith(
          (ref) => _CampaignFixture(
            api,
            CampaignState(campaigns: campaigns ?? [_campaign], hasLoaded: true),
          ),
        ),
        submissionProvider.overrideWith(
          (ref) => _SubmissionFixture(
            api,
            submissions ??
                SubmissionState(submissions: const [], isLoading: false),
          ),
        ),
        savedQuestsStorageProvider.overrideWithValue(
          savedStorage ?? _MemorySavedStorage(),
        ),
        dailyMissionFetcherProvider.overrideWithValue(
          missionFetcher ?? () async => mission,
        ),
      ],
      child: MaterialApp.router(
        key: UniqueKey(),
        theme: AppTheme.pixel,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  QuestModel quest, {
  List<QuestStepModel>? steps,
  UserModel? user,
  bool completeSucceeds = true,
  bool rewardAwarded = true,
  bool hasAttempt = true,
  Size size = const Size(400, 2400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final api = await _detailApi(
    quest,
    steps: steps,
    completeSucceeds: completeSucceeds,
    rewardAwarded: rewardAwarded,
    hasAttempt: hasAttempt,
  );
  final router = _router('/detail', QuestDetailScreen(quest: quest));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(
          (ref) => _Auth(
              api, ref.watch(authRefreshProvider.notifier), user ?? _user),
        ),
        savedQuestsStorageProvider.overrideWithValue(_MemorySavedStorage()),
      ],
      child: MaterialApp.router(
        key: UniqueKey(),
        theme: AppTheme.pixel,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('QuestModel exposes base reward, difficulty, test flag and tags', () {
    final quest = _quest('q1', 'Quest');
    final roundTrip = QuestModel.fromJson(quest.toJson());
    expect(roundTrip.baseRewardPhp, 25);
    expect(roundTrip.difficultyFactor, 1.2);
    expect(roundTrip.tags, ['eco', 'heritage']);
    expect(quest.isTest, isFalse);
    final testQuest = QuestModel.fromJson({
      'id': 'q2',
      'title': 'Test quest',
      'base_reward_php': 40,
      'difficulty_factor': 2,
      'is_test': true,
    });
    expect(testQuest.baseRewardPhp, 40);
    expect(testQuest.difficultyFactor, 2);
    expect(testQuest.isTest, isTrue);
  });

  test('daily mission parsing only activates an incomplete quest_step', () {
    expect(dailyQuestStepActive(null), isFalse);
    expect(dailyQuestStepActive({'missions': []}), isFalse);
    expect(
      dailyQuestStepActive({
        'missions': [
          {'kind': 'cheer_post', 'completed': false},
          {'kind': 'quest_step', 'completed': true},
        ],
      }),
      isFalse,
    );
    expect(
      dailyQuestStepActive({
        'missions': [
          {'kind': 'quest_step', 'completed': false},
        ],
      }),
      isTrue,
    );
    final quests = [
      _quest('done', 'Done'),
      _quest('next', 'Next'),
    ];
    String statusOf(QuestModel quest) =>
        quest.id == 'done' ? 'COMPLETED' : 'AVAILABLE';
    expect(dailyMissionQuestId(quests, statusOf, true), 'next');
    expect(dailyMissionQuestId(quests, statusOf, false), isNull);
    expect(
      dailyMissionQuestId([_quest('done', 'Done')], statusOf, true),
      isNull,
    );
  });

  test('paging grows by ten and clamps to the total', () {
    expect(nextPageCount(10, 35), 20);
    expect(nextPageCount(30, 35), 35);
    expect(nextPageCount(35, 35), 35);
  });

  test('saved quests toggle persists through the storage', () async {
    final storage = _MemorySavedStorage(['old']);
    final notifier = SavedQuestsNotifier(storage);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, {'old'});
    expect(notifier.toggle('q1'), isTrue);
    expect(notifier.state, {'old', 'q1'});
    await Future<void>.delayed(Duration.zero);
    expect(storage.ids, containsAll(['old', 'q1']));
    expect(notifier.toggle('old'), isFalse);
    expect(notifier.state, {'q1'});
    notifier.dispose();
  });

  test('task icons are 16x16 palette sprites', () {
    for (final art in [
      QuestTaskIcons.location,
      QuestTaskIcons.qr,
      QuestTaskIcons.photo,
      QuestTaskIcons.ar,
      QuestTaskIcons.action,
      QuestTaskIcons.lock,
    ]) {
      expect(art.width, 16);
      expect(art.height, 16);
      for (final row in art.rows) {
        expect(row.length, 16);
        for (final key in row.split('')) {
          expect(key == '.' || PixelPalette.byKey.containsKey(key), isTrue);
        }
      }
    }
  });

  testWidgets('quest list tabs, category filter, search and status chips', (
    tester,
  ) async {
    final pending = SubmissionModel(
      id: 'q1',
      questTitle: 'Coastal cleanup',
      category: 'eco',
      status: 'pending',
      rewardPoints: 10,
      createdAt: '2026-11-02T00:00:00Z',
    );
    await _pumpList(
      tester,
      submissions: SubmissionState(submissions: [pending], isLoading: false),
    );
    expect(find.text('Coastal cleanup'), findsOneWidget);
    expect(find.text('Heritage walk'), findsOneWidget);
    expect(find.text('PENDING REVIEW'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quests_category_cultural')));
    await tester.pumpAndSettle();
    expect(find.text('Coastal cleanup'), findsNothing);
    expect(find.text('Heritage walk'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quests_category_')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'walk');
    await tester.pumpAndSettle();
    expect(find.text('Heritage walk'), findsOneWidget);
    expect(find.text('Coastal cleanup'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Bangus Festival 2026'), findsOneWidget);
  });

  testWidgets('quest list save toggle and directions/view targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpList(tester);
    final save = find.bySemanticsLabel('Save Coastal cleanup');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Remove Coastal cleanup from saved'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quest_directions_q1')));
    await tester.pumpAndSettle();
    expect(find.text('route:/navigate'), findsOneWidget);
    semantics.dispose();

    await _pumpList(tester);
    await tester.tap(find.byKey(const ValueKey('quest_open_q1')));
    await tester.pumpAndSettle();
    expect(find.text('route:/quests/q1'), findsOneWidget);
  });

  testWidgets('quest list marks the daily mission quest', (tester) async {
    await _pumpList(tester, mission: true);
    expect(find.text('Daily mission · Complete a quest step'), findsOneWidget);
    expect(find.text('Play >'), findsOneWidget);
  });

  testWidgets('daily mission pill stays hidden when signed out or unavailable',
      (
    tester,
  ) async {
    await _pumpList(tester, mission: true, signedOut: true);
    expect(find.text('Daily mission · Complete a quest step'), findsNothing);

    await _pumpList(
      tester,
      missionFetcher: () async => throw StateError('offline'),
    );
    expect(find.text('Daily mission · Complete a quest step'), findsNothing);

    await _pumpList(tester, mission: false);
    expect(find.text('Daily mission · Complete a quest step'), findsNothing);
  });

  testWidgets('quests that arrive after the first build are shown',
      (tester) async {
    await _pumpList(tester, quests: const []);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(QuestListScreen)));
    (container.read(questProvider.notifier) as _QuestFixture).emit(QuestState(
      quests: [for (var i = 0; i < 14; i++) _quest('q$i', 'Trail $i')],
      isLoading: false,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QuestCard), findsWidgets);
  });

  testWidgets('quest list TOP button jumps to the top', (tester) async {
    final quests = [
      for (var i = 1; i <= 15; i++) _quest('q$i', 'Quest $i'),
    ];
    await _pumpList(tester, quests: quests, size: const Size(400, 600));
    await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quests_top_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quests_top_btn')));
    await tester.pump();
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, 0);
  });

  testWidgets('quest list campaign card opens the campaign route',
      (tester) async {
    await _pumpList(tester);
    await tester.tap(find.text('Events · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View event >'));
    await tester.pumpAndSettle();
    expect(find.text('route:/quests/campaigns/c1'), findsOneWidget);
  });

  testWidgets('quest detail renders every task state and its action', (
    tester,
  ) async {
    final quest = _quest('q1', 'State quest', steps: _setupSteps);
    await _pumpDetail(tester, quest);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Needs changes'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Feedback: Get closer to the plaque.'), findsOneWidget);

    final qrAction = find.byKey(const ValueKey('quest_task_action_2'));
    expect(qrAction, findsOneWidget);
    await tester.ensureVisible(qrAction);
    await tester.tap(qrAction);
    await tester.pumpAndSettle();
    expect(find.text('Scan Checkpoint QR'), findsOneWidget);
  });

  testWidgets('quest detail funded panel only appears with funding', (
    tester,
  ) async {
    final funded = _quest(
      'q1',
      'Funded quest',
      funding: const QuestFundingSummary(
        status: 'active',
        mode: 'budget',
        rewardPoints: 50,
        completionsLeftEstimate: 10,
        sponsors: [
          {'name': 'Dagupan Tourism'},
        ],
      ),
    );
    await _pumpDetail(tester, funded, steps: const []);
    expect(find.text('Funded Eco-Quest'), findsOneWidget);
    expect(find.text('50 pts each'), findsOneWidget);

    await _pumpDetail(tester, _quest('q2', 'Unfunded quest'), steps: const []);
    expect(find.text('Funded Eco-Quest'), findsNothing);
  });

  testWidgets('quest detail author tools appear for the author',
      (tester) async {
    final authorQuest = _quest('q1', 'Authored quest', authorId: _user.id);
    await _pumpDetail(tester, authorQuest, steps: const []);
    expect(find.byKey(const ValueKey('quest_edit_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_qr_sheet_btn')), findsOneWidget);
  });

  testWidgets('quest detail author tools stay hidden for other travelers', (
    tester,
  ) async {
    final authorQuest = _quest('q1', 'Authored quest', authorId: _user.id);
    final other = UserModel(
      id: 'other',
      seedId: 'other',
      displayName: 'Other Traveler',
      email: '',
      avatarUrl: '',
      role: 'explorer',
      demoPoints: 0,
    );
    await _pumpDetail(tester, authorQuest, steps: const [], user: other);
    expect(find.byKey(const ValueKey('quest_edit_btn')), findsNothing);
  });

  testWidgets('quest detail full map opens the map route', (tester) async {
    await _pumpDetail(tester, _quest('q1', 'Map quest'), steps: const []);
    await tester.tap(find.text('Full map >'));
    await tester.pumpAndSettle();
    expect(find.text('route:/map'), findsOneWidget);
  });

  testWidgets('detail bottom bar and task action are tappable in landscape, 2x',
      (
    tester,
  ) async {
    final quest = _quest('q1', 'Landscape quest', steps: _setupSteps);
    await _pumpDetail(
      tester,
      quest,
      steps: _setupSteps,
      hasAttempt: false,
      size: const Size(568, 320),
      textScale: 2,
    );
    final accept = find.byKey(const ValueKey('quest_accept_btn'));
    expect(accept, findsOneWidget);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _pumpDetail(
      tester,
      quest,
      steps: _setupSteps,
      size: const Size(568, 320),
      textScale: 2,
    );
    final action = find.byKey(const ValueKey('quest_task_action_2'));
    for (var i = 0; i < 12 && action.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump();
    }
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Scan Checkpoint QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FINISH QUEST success pushes the celebration page',
      (tester) async {
    final quest = _quest('q1', 'Finish quest', steps: _setupSteps);
    final verified =
        _setupSteps.map((step) => step.copyWith(status: 'verified')).toList();
    await _pumpDetail(tester, quest, steps: verified);
    final finish = find.byKey(const ValueKey('quest_finish_btn'));
    expect(finish, findsOneWidget);
    await tester.tap(finish);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CelebrationPage), findsOneWidget);
  });

  testWidgets('FINISH QUEST failure does not push the celebration page', (
    tester,
  ) async {
    final quest = _quest('q1', 'Finish failure', steps: _setupSteps);
    final verified =
        _setupSteps.map((step) => step.copyWith(status: 'verified')).toList();
    await _pumpDetail(
      tester,
      quest,
      steps: verified,
      completeSucceeds: false,
    );
    await tester.tap(find.byKey(const ValueKey('quest_finish_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CelebrationPage), findsNothing);
  });

  testWidgets('FINISH QUEST sent to review does not celebrate', (
    tester,
  ) async {
    final quest = _quest('q1', 'Finish review', steps: _setupSteps);
    final verified =
        _setupSteps.map((step) => step.copyWith(status: 'verified')).toList();
    await _pumpDetail(tester, quest, steps: verified, rewardAwarded: false);
    await tester.tap(find.byKey(const ValueKey('quest_finish_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CelebrationPage), findsNothing);
  });

  testWidgets('builder validation panel shows the exact messages',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient(enableRetries: false);
    final repo = _FakeBuilderRepo(api);
    final router =
        _router('/builder', const QuestBuilderScreen(initialSpot: _spot));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _Auth(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questBuilderRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(
          key: UniqueKey(),
          theme: AppTheme.pixel,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quest_title_input')), '');
    await tester.tap(find.byKey(const Key('builder_publish_btn')));
    await tester.pumpAndSettle();
    expect(find.text('FIX BEFORE PUBLISHING'), findsOneWidget);
    expect(find.text('Title must be at least 3 characters.'), findsOneWidget);
    expect(repo.lastCreatedPayload, isNull);
  });

  testWidgets('builder segmented controls change the published payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient(enableRetries: false);
    final repo = _FakeBuilderRepo(api);
    final router =
        _router('/builder', const QuestBuilderScreen(initialSpot: _spot));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _Auth(api, ref.watch(authRefreshProvider.notifier), _user),
          ),
          questBuilderRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(
          key: UniqueKey(),
          theme: AppTheme.pixel,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cultural Heritage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 pts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any order'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('builder_publish_btn')));
    await tester.pumpAndSettle();
    expect(repo.lastCreatedPayload, isNotNull);
    expect(repo.lastCreatedPayload!['category'], 'cultural');
    expect(repo.lastCreatedPayload!['reward_points'], 100);
    expect(repo.lastCreatedPayload!['step_order_mode'], 'any');
  });

  testWidgets('builder bottom bar is tappable at 320x568 and 568x320, 2x', (
    tester,
  ) async {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final api = ApiClient(enableRetries: false);
      final repo = _FakeBuilderRepo(api);
      final router =
          _router('/builder', const QuestBuilderScreen(initialSpot: _spot));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(
              (ref) =>
                  _Auth(api, ref.watch(authRefreshProvider.notifier), _user),
            ),
            questBuilderRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            key: UniqueKey(),
            theme: AppTheme.pixel,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('builder_save_draft_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.lastCreatedPayload, isNotNull, reason: 'save tap $size');
      expect(tester.takeException(), isNull, reason: 'layout $size');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
