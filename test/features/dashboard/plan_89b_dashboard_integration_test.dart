import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/main_shell.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_adventure_calendar.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_command_grid.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_dual_bento_row.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_hero.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _MemoryTipsStore implements HomeTipsStore {
  @override
  Future<bool> seen() async => true;

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> reset() async {}
}

class _AuthFixture extends AuthNotifier {
  _AuthFixture(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'tok');
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

class _CampaignFixture extends CampaignNotifier {
  _CampaignFixture(super.apiClient, CampaignState initial) {
    state = initial;
  }

  @override
  Future<void> fetchCampaigns({
    String? municipality,
    bool forceRefresh = false,
  }) async {}
}

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient) {
    state = SubmissionState(submissions: const [], isLoading: false);
  }

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _SpotDiscoveryFixture extends SpotDiscoveryNotifier {
  _SpotDiscoveryFixture(super.ref) {
    state = const SpotDiscoveryState(isInitialLoading: false);
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

class _QotdFixture extends HomeQotdNotifier {
  _QotdFixture(super.ref) : super(autoLoad: false) {
    state = const AsyncValue.data(
      HomeQotdState(
        date: '2026-11-14',
        quizTitle: 'Daily Lore',
        questionId: 'qq-1',
        questionText: 'Where is Hundred Islands?',
        options: [HomeQotdOption(id: 'o1', ordinal: 1, text: 'Alaminos')],
        answered: false,
        correct: false,
      ),
    );
  }
}

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
            data: {'success': true, 'data': <String, dynamic>{}},
          ),
        );
      },
    ),
  );
  return api;
}

UserModel _user() => UserModel.fromJson({
      'id': 'u1',
      'email': 'juan@example.com',
      'username': 'juan',
      'display_name': 'Juan',
      'role': 'traveler',
      'balance_mjdq': 250,
    });

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.route);
  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('route:$route')));
  }
}

List<Override> _baseOverrides({
  List<CampaignModel> campaigns = const [],
}) {
  final api = _stubApi();
  return [
    apiClientProvider.overrideWithValue(api),
    homeTipsStoreProvider.overrideWithValue(_MemoryTipsStore()),
    authProvider.overrideWith(
      (ref) => _AuthFixture(api, ref.watch(authRefreshProvider.notifier), _user()),
    ),
    questProvider.overrideWith(
      (ref) => _QuestFixture(
        api,
        QuestState(
          quests: [
            QuestModel(
              id: 'q1',
              title: 'Lingayen Capitol Trail',
              description: 'Walk the capitol grounds.',
              category: 'heritage',
              locationName: 'Lingayen',
              gpsLat: 16.02,
              gpsLng: 120.23,
              radiusMeters: 100,
              rewardPoints: 50,
              markerImageUrl: '',
            ),
          ],
          isLoading: false,
        ),
      ),
    ),
    campaignProvider.overrideWith(
      (ref) => _CampaignFixture(
        api,
        CampaignState(campaigns: campaigns, hasLoaded: true),
      ),
    ),
    submissionProvider.overrideWith((ref) => _SubmissionFixture(api)),
    spotDiscoveryProvider.overrideWith((ref) => _SpotDiscoveryFixture(ref)),
    homeDailyProvider.overrideWith(
      (ref) async => const HomeDailyState(
        stamps: 10,
        missions: [],
        claimedDays: 2,
        streak: 0,
      ),
    ),
    homeQotdProvider.overrideWith((ref) => _QotdFixture(ref)),
    hiddenGemProvider.overrideWith((ref) async => const []),
    choiceOverviewProvider.overrideWith(
      (ref) async => const ChoiceOverview(
        current: null,
        nextOpensAt: null,
        nextClosesAt: null,
        nextTheme: null,
        previous: null,
        notice: null,
        votingEnabled: true,
      ),
    ),
  ];
}

GoRouter _appRouter() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MainShell(navigationShell: shell, location: state.uri.path),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (_, __) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  builder: (_, __) => const _RouteProbe('/explore'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/map',
                  builder: (_, __) => const _RouteProbe('/map'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/shop',
                  builder: (_, __) => const _RouteProbe('/shop'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, __) => const _RouteProbe('/profile'),
                ),
              ],
            ),
          ],
        ),
        for (final path in [
          '/search',
          '/settings',
          '/notifications',
          '/quests',
          '/navigate',
          '/choice',
          '/plaza',
          '/map/add-spot',
          '/saved',
          '/history',
        ])
          GoRoute(path: path, builder: (_, __) => _RouteProbe(path)),
      ],
    );

Future<void> _pumpRouter(
  WidgetTester tester, {
  List<CampaignModel> campaigns = const [],
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _baseOverrides(campaigns: campaigns),
      child: MaterialApp.router(
        theme: AppTheme.pixel,
        routerConfig: _appRouter(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Designer icons render on MainShell Profile, AppBar, and PLAZA tile',
      (tester) async {
    await _pumpRouter(tester);

    final sprites = tester.widgetList<PixelSprite>(find.byType(PixelSprite));
    final arts = sprites.map((s) => s.art).toSet();

    expect(arts.contains(DesignerArt.navProfile), isTrue);
    expect(arts.contains(DesignerArt.plazaTrophy), isTrue);
    expect(arts.contains(DesignerArt.search), isTrue);
    expect(arts.contains(DesignerArt.navSettings), isTrue);
  });

  testWidgets('Home renders 4 Concept B bands in exact top-to-bottom order',
      (tester) async {
    await _pumpRouter(tester);

    final heroY = tester.getTopLeft(find.byType(HomeHero)).dy;
    final gridY = tester.getTopLeft(find.byType(HomeCommandGrid)).dy;
    final bentoY = tester.getTopLeft(find.byType(HomeDualBentoRow)).dy;

    expect(heroY, lessThan(gridY));
    expect(gridY, lessThan(bentoY));

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final calY = tester.getTopLeft(find.byType(HomeAdventureCalendar)).dy;
    final bentoAfterScrollY = tester.getTopLeft(find.byType(HomeDualBentoRow)).dy;
    expect(bentoAfterScrollY, lessThan(calY));
  });

  testWidgets('App bar Search/Settings and all 8 Command Grid tiles open routes',
      (tester) async {
    Future<void> tapAndCheck(Key key, String expectedRoute) async {
      await _pumpRouter(tester);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.text('route:$expectedRoute'), findsOneWidget);
    }

    await tapAndCheck(const ValueKey('home_appbar_search'), '/search');
    await tapAndCheck(const ValueKey('home_appbar_settings'), '/settings');
    await tapAndCheck(const ValueKey('home_menu_quests'), '/quests');
    await tapAndCheck(const ValueKey('home_tile_route'), '/navigate');
    await tapAndCheck(const ValueKey('home_tile_vote'), '/choice');
    await tapAndCheck(const ValueKey('home_tile_plaza'), '/plaza');
    await tapAndCheck(const ValueKey('home_tile_add_spot'), '/map/add-spot');
    await tapAndCheck(const ValueKey('home_tile_saved'), '/saved');
    await tapAndCheck(const ValueKey('home_tile_history'), '/history');

    // QUIZZES tile opens the Quizzes & Fiestas bottom sheet
    await _pumpRouter(tester);
    await tester.tap(find.byKey(const ValueKey('home_tile_quizzes')));
    await tester.pumpAndSettle();
    expect(find.text('QUIZZES & FIESTAS'), findsOneWidget);
  });

  testWidgets(
      'Home calendar shows dated campaign, toggles week/month, and jumps with NEXT EVENT',
      (tester) async {
    final now = DateTime.now();
    final futureDay = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 3),
    );
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final campaign = CampaignModel(
      id: 'c1',
      hostId: 'h1',
      hostName: 'Dagupan',
      title: 'Bangus Festival Cleanup',
      category: 'eco',
      locationName: 'Dagupan',
      municipality: 'Dagupan City',
      bannerImageUrl: '',
      description: 'Join the cleanup.',
      eventDate: fmt(futureDay),
      startDate: fmt(futureDay),
      endDate: fmt(futureDay),
      totalBudgetMjdq: 1000,
      rewardPerParticipantMjdq: 50,
      referralBountyMjdq: 10,
      maxParticipants: 50,
      reservedParticipants: 10,
      completedParticipants: 0,
      preQuestRequirements: const [],
      status: 'active',
      createdAt: '2026-10-01',
    );

    await _pumpRouter(tester, campaigns: [campaign]);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    // Toggle week <-> month
    expect(find.byKey(const ValueKey('home_calendar_panel')), findsOneWidget);
    expect(find.text('MO'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_calendar_mode_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('WK'), findsOneWidget);

    // Filter to EVENT and tap NEXT EVENT to jump to the dated campaign
    await tester.ensureVisible(find.text('EVENT'));
    await tester.tap(find.text('EVENT'));
    await tester.pumpAndSettle();

    final nextEventBtn = find.byKey(const ValueKey('home_calendar_next_event'));
    expect(nextEventBtn, findsOneWidget);
    await tester.ensureVisible(nextEventBtn);
    await tester.tap(nextEventBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bangus Festival Cleanup'), findsWidgets);
  });
}
