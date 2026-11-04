import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/providers/cultural_quiz_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_detail_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_play_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/screens/juanchoice_screen.dart';
import 'package:juanderquest_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';
import 'package:juanderquest_app/features/plaza/plaza_provider.dart';
import 'package:juanderquest_app/features/plaza/plaza_screen.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/screens/campaign_detail_screen.dart';
import 'package:juanderquest_app/features/vote/models/governance_proposal_model.dart';
import 'package:juanderquest_app/features/vote/providers/governance_provider.dart';
import 'package:juanderquest_app/features/vote/screens/proposal_list_screen.dart';
import 'package:juanderquest_app/features/vote/screens/vote_screen.dart';
import 'package:juanderquest_app/features/wallet/models/wallet_model.dart';
import 'package:juanderquest_app/features/wallet/providers/wallet_provider.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _GovFixture extends GovernanceNotifier {
  _GovFixture(super.ref, GovernanceState initial) {
    state = initial;
  }

  int loads = 0;
  int casts = 0;
  int creates = 0;

  @override
  Future<void> loadGovernanceData() async {
    loads++;
  }

  @override
  Future<bool> castVote({required String proposalId, required String choice}) async {
    casts++;
    return true;
  }

  @override
  Future<bool> createAndSubmitProposal({
    required String title,
    required String locationName,
    required String category,
    required String description,
  }) async {
    creates++;
    return true;
  }
}

class _QuizFixture extends CulturalQuizController {
  _QuizFixture(super.client);

  int submits = 0;

  @override
  Future<CulturalQuizGradedResultModel> submitAttempt({
    required String attemptId,
    required List<({String questionId, String selectedOptionId})> answers,
  }) async {
    submits++;
    return _result;
  }
}

class _PlazaFeedFixture extends PlazaFeedNotifier {
  _PlazaFeedFixture(super.api, AsyncValue<List<ActivityItemModel>> initial) {
    state = initial;
  }

  int loads = 0;
  int cheers = 0;
  String? setScopeValue;

  @override
  Future<void> loadFeed({bool reset = false}) async {
    loads++;
  }

  @override
  void setScope(String newScope) {
    setScopeValue = newScope;
  }

  @override
  Future<void> toggleCheer(String activityId) async {
    cheers++;
  }
}

class _PushFixture extends PushService {
  _PushFixture({this.asked = false}) : super(ApiClient());

  final bool asked;
  int requests = 0;

  @override
  Future<bool> hasAskedPermission() async => asked;

  @override
  Future<bool> requestPermissionAndRegister() async {
    requests++;
    return true;
  }
}

class _CampaignFixture extends CampaignNotifier {
  _CampaignFixture(super.apiClient, CampaignState initial) {
    state = initial;
  }

  int loads = 0;

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {
    loads++;
  }
}

class _WalletFixture extends WalletNotifier {
  _WalletFixture(super.ref, WalletModel wallet) {
    state = AsyncValue.data(wallet);
  }

  @override
  Future<void> fetchWallet() async {}
}

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$label')));
}

final _user = UserModel(
  id: 'u1',
  seedId: 'scale-01',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 1250,
);

const _quiz = CulturalQuizModel(
  id: 'quiz-1',
  destinationId: 'spot-1',
  destinationName: 'Patar Beach',
  municipality: 'Bolinao',
  gpsLat: 16.2,
  gpsLng: 119.9,
  title: 'Bolinao Coastal Heritage',
  description: 'Explore Cape Bolinao historical landmarks and culture.',
  language: 'en',
  radiusMeters: 200,
  xpReward: 25,
  timeLimitMinutes: 30,
  cooldownHours: 24,
  status: 'published',
  version: 1,
  isCompleted: false,
);

const _questions = [
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
      CulturalQuizOptionModel(
          id: 'c', questionId: 'q-1', ordinal: 3, optionText: '1920'),
      CulturalQuizOptionModel(
          id: 'd', questionId: 'q-1', ordinal: 4, optionText: '1945'),
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
          id: 'e', questionId: 'q-2', ordinal: 1, optionText: 'South China Sea'),
      CulturalQuizOptionModel(
          id: 'f', questionId: 'q-2', ordinal: 2, optionText: 'Sulu Sea'),
    ],
  ),
];

final _attempt = CulturalQuizAttemptModel(
  id: 'att-1',
  quizId: 'quiz-1',
  versionId: 'v-1',
  rewardScopeId: 'scope-1',
  userId: 'u1',
  status: 'in_progress',
  startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  completedAt: null,
  score: null,
  totalQuestions: 2,
  xpAwarded: 0,
);

final _result = CulturalQuizGradedResultModel(
  attempt: _attempt,
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

final _proposal = GovernanceProposalModel(
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

const _campaign = CampaignModel(
  id: 'camp-1',
  hostId: 'dagupan-lgu',
  hostName: 'Dagupan City Tourism Office',
  title: 'Bangus Festival 2026',
  category: 'cultural',
  locationName: 'Dagupan City Plaza',
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

final _activity = ActivityItemModel(
  id: 'a1',
  verb: 'quest_completed',
  actorName: 'Ana Victoria',
  isFollowing: false,
  subjectType: 'quest',
  subjectTitle: 'Hundred Islands Eco Trek',
  municipality: 'Alaminos City',
  payload: const {},
  reason: 'mixed',
  cheerCount: 3,
  cheeredByMe: false,
  commentCount: 1,
  canHide: false,
  createdAt: DateTime(2026, 11, 3, 10),
);

final _standings = {
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
    {
      'rank': 2,
      'user_id': 'u2',
      'display_name': 'Ana Victoria',
      'score': 1200,
      'quests': 4,
      'home_town': 'Bolinao',
      'is_self': false,
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
};

GoRouter _router(Widget home, {String initial = '/'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/explore', builder: (_, __) => const _Probe('/explore')),
        GoRoute(path: '/choice', builder: (_, __) => const _Probe('/choice')),
        GoRoute(
            path: '/choice/:id',
            builder: (_, __) => const _Probe('/choice/detail')),
        GoRoute(
            path: '/cultural-quizzes/:id/play',
            builder: (_, __) => const _Probe('/quiz/play')),
        GoRoute(
            path: '/cultural-quizzes/:id/result',
            builder: (_, __) => const _Probe('/quiz/result')),
        GoRoute(
            path: '/vote/proposals',
            builder: (_, __) => const _Probe('/vote/proposals')),
        GoRoute(path: '/quests/:id', builder: (_, __) => const _Probe('/quests')),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String initial = '/',
  bool signedOut = false,
  GovernanceNotifier Function(Ref ref)? governance,
  CulturalQuizController Function(ApiClient client)? quizController,
  PlazaFeedNotifier Function(ApiClient client)? plazaFeed,
  PushService? push,
  CampaignNotifier Function(ApiClient client)? campaign,
  WalletNotifier Function(Ref ref)? wallet,
  Future<Map<String, dynamic>> Function(Ref ref, String key)? standings,
  Future<CulturalQuizModel?> Function(Ref ref, String key)? quizDetail,
  Future<ChoiceOverview> Function(Ref ref)? choiceOverview,
  Future<ChoiceDetail> Function(Ref ref, String key)? choiceDetail,
  Future<ChoiceSupporterQuest?> Function(Ref ref)? choiceQuest,
  Future<ChoiceEngagementSummary> Function(Ref ref)? choiceEngagement,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authProvider.overrideWith((ref) => _Auth(
              ref.read(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              signedOut ? null : _user,
            )),
        governanceProvider.overrideWith((ref) =>
            governance?.call(ref) ?? _GovFixture(ref, GovernanceState())),
        culturalQuizControllerProvider.overrideWith((ref) =>
            quizController?.call(ref.read(apiClientProvider)) ??
            _QuizFixture(ref.read(apiClientProvider))),
        plazaFeedProvider.overrideWith((ref) =>
            plazaFeed?.call(ref.read(apiClientProvider)) ??
            _PlazaFeedFixture(
                ref.read(apiClientProvider), const AsyncValue.data([]))),
        pushServiceProvider.overrideWithValue(push ?? _PushFixture()),
        campaignProvider.overrideWith((ref) =>
            campaign?.call(ref.read(apiClientProvider)) ??
            _CampaignFixture(ref.read(apiClientProvider), const CampaignState())),
        walletProvider.overrideWith((ref) =>
            wallet?.call(ref) ??
            _WalletFixture(
              ref,
              WalletModel(
                settlement: 'off-chain',
                unit: 'mJDQ',
                balanceMjdq: 1000,
                balanceJdq: 1,
              ),
            )),
        if (standings != null)
          plazaStandingsProvider.overrideWith(standings),
        if (quizDetail != null)
          culturalQuizDetailProvider.overrideWith(quizDetail),
        if (choiceOverview != null)
          choiceOverviewProvider.overrideWith(choiceOverview),
        if (choiceDetail != null)
          choiceDetailProvider.overrideWith(choiceDetail),
        if (choiceQuest != null)
          choiceSupporterQuestProvider.overrideWith(choiceQuest),
        if (choiceEngagement != null)
          choiceEngagementProvider.overrideWith(choiceEngagement),
      ],
      child: MaterialApp.router(routerConfig: _router(home, initial: initial)),
    ),
  );
  await tester.pump();
}

void main() {
  group('CulturalQuizDetailScreen', () {
    testWidgets('renders quiz data and starts a location check',
        (tester) async {
      await _pump(
        tester,
        const CulturalQuizDetailScreen(quizId: 'quiz-1'),
        quizDetail: (ref, key) async => _quiz,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Bolinao Coastal Heritage'), findsOneWidget);
      expect(find.text('Patar Beach · Bolinao'), findsOneWidget);
      expect(find.text('+25 Explorer XP'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_start')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Location'), findsWidgets);
    });

    testWidgets('missing quiz shows retry and reloads', (tester) async {
      var attempts = 0;
      await _pump(
        tester,
        const CulturalQuizDetailScreen(quizId: 'quiz-1'),
        quizDetail: (ref, key) async {
          attempts++;
          return null;
        },
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cultural Quiz not found.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_detail_retry')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(attempts, greaterThanOrEqualTo(2));
    });
  });

  group('CulturalQuizPlayScreen', () {
    testWidgets('answers every question and submits', (tester) async {
      late _QuizFixture fixture;
      final session = (attempt: _attempt, questions: _questions);
      await _pump(
        tester,
        CulturalQuizPlayScreen(quizId: 'quiz-1', session: session),
        quizController: (client) => fixture = _QuizFixture(client),
      );
      expect(find.text('When was Cape Bolinao Lighthouse built?'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_option_a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz_next')));
      await tester.pump();
      expect(find.text('Which sea borders Bolinao?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_previous')));
      await tester.pump();
      expect(find.text('When was Cape Bolinao Lighthouse built?'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_next')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz_option_e')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz_submit')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(fixture.submits, 1);
    });

    testWidgets('submitting early shows the answer-all message',
        (tester) async {
      final session = (attempt: _attempt, questions: _questions);
      await _pump(
        tester,
        CulturalQuizPlayScreen(quizId: 'quiz-1', session: session),
      );
      await tester.tap(find.byKey(const ValueKey('quiz_next')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz_submit')));
      await tester.pump();
      expect(find.text('Please answer all 5 questions before submitting.'),
          findsOneWidget);
    });
  });

  group('CulturalQuizResultScreen', () {
    testWidgets('renders the score, review and Explore action', (tester) async {
      await _pump(tester, CulturalQuizResultScreen(result: _result));
      expect(find.text('Quiz Passed!'), findsOneWidget);
      expect(find.text('+25 Explorer XP Awarded'), findsOneWidget);
      expect(find.text('1. When was Cape Bolinao Lighthouse built?'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz_result_explore')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore'), findsOneWidget);
    });

    testWidgets('failed quiz shows the incomplete state', (tester) async {
      final failed = CulturalQuizGradedResultModel(
        attempt: _attempt,
        passed: false,
        score: 1,
        totalQuestions: 2,
        xpAwarded: 0,
        alreadyCompletedPrior: false,
        breakdown: const [],
      );
      await _pump(tester, CulturalQuizResultScreen(result: failed));
      expect(find.text('Quiz Incomplete'), findsOneWidget);
    });
  });

  group('LeaderboardScreen', () {
    testWidgets('renders both boards and switches tabs', (tester) async {
      await _pump(tester, const LeaderboardScreen());
      expect(find.text('Explorer Leaderboard'), findsOneWidget);
      expect(find.text('Zernan Vash'), findsOneWidget);
      await tester.tap(find.text('ALL-TIME'));
      await tester.pump();
      expect(find.text('28500 mJDQ'), findsOneWidget);
      await tester.tap(find.text('30-DAY SPRINT'));
      await tester.pump();
      expect(find.text('4850 mJDQ'), findsOneWidget);
    });
  });

  group('JuanChoiceScreen', () {
    ChoiceOverview overview() => ChoiceOverview(
          current: ChoiceCampaign(
            id: 'campaign-id',
            theme: 'Coastal gems',
            region: 'Pangasinan',
            status: 'voting',
            opensAt: DateTime.now().subtract(const Duration(hours: 1)),
            closesAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: true,
          serverTime: DateTime.now(),
          receivedAt: DateTime.now(),
        );

    testWidgets('renders the overview and opens the current vote',
        (tester) async {
      await _pump(
        tester,
        const JuanChoiceScreen(),
        choiceOverview: (ref) async => overview(),
        choiceQuest: (ref) async => null,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Coastal gems'), findsOneWidget);
      expect(find.textContaining('free and separate'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choice_current')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/choice/detail'), findsOneWidget);
    });

    testWidgets('supporter quest buttons route and claim', (tester) async {
      await _pump(
        tester,
        const JuanChoiceScreen(),
        choiceOverview: (ref) async => overview(),
        choiceQuest: (ref) async => ChoiceSupporterQuest(
          campaignId: 'campaign-id',
          questId: 'quest-id',
          spotName: 'Hidden Cove',
          questTitle: 'Supporter visit',
          questDescription: 'Complete the verified destination quest.',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          explorerXp: 300,
          claimed: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Visit the community winner'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choice_open_quest')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/quests'), findsOneWidget);
    });

    testWidgets('overview error retries', (tester) async {
      var attempts = 0;
      await _pump(
        tester,
        const JuanChoiceScreen(),
        choiceOverview: (ref) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return overview();
        },
        choiceQuest: (ref) async => null,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Community voting is temporarily unavailable.'),
          findsOneWidget);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(attempts, greaterThanOrEqualTo(2));
      expect(find.text('Coastal gems'), findsOneWidget);
    });
  });

  group('JuanChoiceDetailScreen', () {
    final campaign = ChoiceCampaign(
      id: 'campaign-id',
      theme: 'Coastal gems',
      region: 'Pangasinan',
      status: 'voting',
      opensAt: DateTime.now().subtract(const Duration(hours: 1)),
      closesAt: DateTime.now().add(const Duration(hours: 1)),
    );

    testWidgets('guest sees the sign-in action', (tester) async {
      await _pump(
        tester,
        const JuanChoiceDetailScreen(campaignId: 'campaign-id'),
        signedOut: true,
        choiceOverview: (ref) async => ChoiceOverview(
          current: campaign,
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: true,
          serverTime: DateTime.now(),
          receivedAt: DateTime.now(),
        ),
        choiceDetail: (ref, key) async => ChoiceDetail(
          campaign: campaign,
          standings: const [
            ChoiceStanding(
                candidateId: 'candidate-id', spotName: 'Hidden Cove', votes: 2),
          ],
          ballot: null,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Hidden Cove'), findsOneWidget);
      expect(find.text('SIGN IN TO VOTE'), findsOneWidget);
      expect(find.text('VOTE FOR THIS PLACE'), findsNothing);
    });

    testWidgets('eligible signed-in traveler opens the confirm dialog',
        (tester) async {
      await _pump(
        tester,
        const JuanChoiceDetailScreen(campaignId: 'campaign-id'),
        choiceOverview: (ref) async => ChoiceOverview(
          current: campaign,
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: true,
          serverTime: DateTime.now(),
          receivedAt: DateTime.now(),
        ),
        choiceDetail: (ref, key) async => ChoiceDetail(
          campaign: campaign,
          standings: const [
            ChoiceStanding(
                candidateId: 'candidate-id', spotName: 'Hidden Cove', votes: 2),
          ],
          ballot: null,
          eligibility: const ChoiceEligibility(
            eligible: true,
            reason: null,
            eligibleAt: null,
            canVoteNow: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Pangasinan · Voting open'), findsOneWidget);
      await tester.tap(find.text('VOTE FOR THIS PLACE'));
      await tester.pump();
      expect(find.text('CONFIRM JUANCHOICE VOTE'), findsOneWidget);
      expect(find.byKey(const ValueKey('choice_confirm_vote')), findsOneWidget);
    });

    testWidgets('detail error retries', (tester) async {
      var attempts = 0;
      await _pump(
        tester,
        const JuanChoiceDetailScreen(campaignId: 'campaign-id'),
        choiceOverview: (ref) async => ChoiceOverview(
          current: campaign,
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: true,
          serverTime: DateTime.now(),
          receivedAt: DateTime.now(),
        ),
        choiceDetail: (ref, key) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return ChoiceDetail(
            campaign: campaign,
            standings: const [],
            ballot: null,
          );
        },
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Campaign unavailable. Please try again.'),
          findsOneWidget);
      await tester.tap(find.text('RETRY'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(attempts, greaterThanOrEqualTo(2));
    });
  });

  group('VoteScreen', () {
    testWidgets('renders the retired notice and archive', (tester) async {
      await _pump(
        tester,
        const VoteScreen(),
        governance: (ref) => _GovFixture(
          ref,
          GovernanceState(proposals: [_proposal]),
        ),
      );
      expect(find.text('Voting System Retired'), findsOneWidget);
      expect(find.text('Historical Proposals (Archive)'), findsOneWidget);
      expect(find.text('Patar White Beach Eco Trail'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vote_choice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/choice'), findsOneWidget);
    });

    testWidgets('empty and error states retry', (tester) async {
      late _GovFixture fixture;
      await _pump(
        tester,
        const VoteScreen(),
        governance: (ref) => fixture = _GovFixture(ref, GovernanceState()),
      );
      expect(find.byKey(const ValueKey('vote_empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vote_choice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await _pump(
        tester,
        const VoteScreen(),
        governance: (ref) => fixture = _GovFixture(
          ref,
          GovernanceState(error: 'Could not load proposals.'),
        ),
      );
      expect(find.text('Could not load proposals.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vote_retry')));
      await tester.pump();
      expect(fixture.loads, greaterThanOrEqualTo(1));
    });

    testWidgets('suggest modal validates and submits', (tester) async {
      late _GovFixture fixture;
      await _pump(
        tester,
        const VoteScreen(),
        governance: (ref) => fixture = _GovFixture(ref, GovernanceState()),
      );
      await tester.tap(find.bySemanticsLabel('Suggest Location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Suggest New Location'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suggest_submit')));
      await tester.pump();
      expect(find.text('Please fill out the destination title and location.'),
          findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('suggest_title')), 'New Spot');
      await tester.enterText(
          find.byKey(const ValueKey('suggest_location')), 'Bolinao');
      await tester.tap(find.byKey(const ValueKey('suggest_submit')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.creates, 1);
    });
  });

  group('ProposalListScreen', () {
    testWidgets('renders and casts a yes vote', (tester) async {
      late _GovFixture fixture;
      await _pump(
        tester,
        const ProposalListScreen(),
        governance: (ref) => fixture = _GovFixture(
          ref,
          GovernanceState(proposals: [_proposal]),
        ),
      );
      expect(find.text('All Proposals'), findsOneWidget);
      expect(find.text('Patar White Beach Eco Trail'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('proposal_yes_p1')));
      await tester.pump();
      expect(find.text('CONFIRM VOTE (YES)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('proposal_cast_yes')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.casts, 1);
    });

    testWidgets('empty and error states retry', (tester) async {
      late _GovFixture fixture;
      await _pump(
        tester,
        const ProposalListScreen(),
        governance: (ref) => fixture = _GovFixture(ref, GovernanceState()),
      );
      expect(find.byKey(const ValueKey('proposals_empty')), findsOneWidget);

      await _pump(
        tester,
        const ProposalListScreen(),
        governance: (ref) => fixture = _GovFixture(
          ref,
          GovernanceState(error: 'Could not load proposals.'),
        ),
      );
      expect(find.text('Could not load proposals.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('proposals_retry')));
      await tester.pump();
      expect(fixture.loads, greaterThanOrEqualTo(1));
    });
  });

  group('PlazaScreen', () {
    Future<void> pumpPlaza(
      WidgetTester tester, {
      required _PlazaFeedFixture feed,
      PushService? push,
      Map<String, dynamic>? standings,
      Object? standingsError,
    }) async {
      await _pump(
        tester,
        const PlazaScreen(),
        push: push,
        plazaFeed: (client) => feed,
        standings: (ref, key) async {
          if (standingsError != null) throw standingsError;
          return standings ?? {};
        },
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('renders standings and cheers an activity', (tester) async {
      late _PlazaFeedFixture feed;
      await pumpPlaza(
        tester,
        feed: feed = _PlazaFeedFixture(
          ApiClient(),
          AsyncValue.data([_activity]),
        ),
        standings: _standings,
      );
      expect(find.text('Pangasinan Plaza'), findsOneWidget);
      expect(find.text('Ana Victoria'), findsWidgets);
      expect(find.text('1500 pts'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plaza_cheer_a1')));
      await tester.pump();
      expect(feed.cheers, 1);
      await tester.tap(find.text('FOLLOWING').last);
      await tester.pump();
      expect(feed.setScopeValue, 'following');
      await tester.tap(find.text('ALL TIME'));
      await tester.pump();
    });

    testWidgets('empty feed and retry paths', (tester) async {
      await pumpPlaza(
        tester,
        feed: _PlazaFeedFixture(
          ApiClient(),
          const AsyncValue.data([]),
        ),
        standings: _standings,
      );
      expect(find.byKey(const ValueKey('plaza_feed_empty')), findsOneWidget);

      final errorFeed = _PlazaFeedFixture(
        ApiClient(),
        const AsyncValue.error('feed down', StackTrace.empty),
      );
      await pumpPlaza(
        tester,
        feed: errorFeed,
        standingsError: 'standings down',
      );
      expect(find.textContaining('Standings unavailable'), findsOneWidget);
      expect(find.text('No recent activity to display.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plaza_retry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plaza_feed_retry')));
      await tester.pump();
      expect(errorFeed.loads, greaterThanOrEqualTo(2));
    });

    testWidgets('push prompt buttons toggle', (tester) async {
      final push = _PushFixture(asked: false);
      await pumpPlaza(
        tester,
        feed: _PlazaFeedFixture(
          ApiClient(),
          const AsyncValue.data([]),
        ),
        push: push,
        standings: _standings,
      );
      expect(find.text('Turn on Plaza alerts'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plaza_alerts_on')));
      await tester.pump();
      expect(push.requests, 1);
      expect(find.text('Turn on Plaza alerts'), findsNothing);
    });
  });

  group('CampaignDetailScreen', () {
    testWidgets('renders campaign data and countdown', (tester) async {
      await _pump(
        tester,
        const CampaignDetailScreen(campaignId: 'camp-1', initialCampaign: _campaign),
      );
      expect(find.text('Bangus Festival 2026'), findsOneWidget);
      expect(find.text('EVENT COUNTDOWN'), findsOneWidget);
      expect(find.text('Complete Dagupan Bangus Market Check-in'),
          findsOneWidget);
    });

    testWidgets('missing campaign retries when the API fails', (tester) async {
      late _CampaignFixture fixture;
      await _pump(
        tester,
        const CampaignDetailScreen(campaignId: 'camp-1'),
        campaign: (client) => fixture = _CampaignFixture(
          client,
          const CampaignState(
            hasLoaded: true,
            failure: ApiFailure(code: 'OFFLINE', message: 'offline'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Campaigns are unavailable.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('campaign_retry')));
      await tester.pump();
      expect(fixture.loads, greaterThanOrEqualTo(1));
    });
  });
}
