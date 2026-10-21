import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/demo_login_screen.dart';
import '../features/quests/models/quest_model.dart';
import '../features/quests/screens/quest_detail_screen.dart';
import '../features/quests/screens/quest_funding_screen.dart';
import '../features/ar_experience/screens/ar_diagnostics_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/spots/screens/interests_screen.dart';
import '../features/ar_experience/screens/ar_quest_screen.dart';
import '../features/submissions/screens/submission_history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/affiliate_application_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/map/screens/map_view_screen.dart';
import '../features/vote/screens/vote_screen.dart';
import '../features/vote/screens/proposal_list_screen.dart';
import '../features/juanchoice/screens/juanchoice_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/spots/screens/spot_explore_screen.dart';
import '../features/spots/screens/spot_search_screen.dart';
import '../features/spots/screens/spot_detail_screen.dart';
import '../features/spots/screens/add_spot_screen.dart';
import '../features/spots/screens/saved_spots_screen.dart';
import '../features/quests/screens/quest_list_screen.dart';
import '../features/quests/screens/campaign_detail_screen.dart';
import '../features/quests/models/campaign_model.dart';
import '../features/spots/models/spot_model.dart';
import '../features/plaza/plaza_screen.dart';
import '../features/about/screens/about_screen.dart';
import '../features/trail/trail_coming_soon_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/navigation/models/route_model.dart';
import '../features/navigation/screens/navigation_screen.dart';
import '../features/cultural_quizzes/models/cultural_quiz_model.dart';
import '../features/cultural_quizzes/screens/cultural_quiz_detail_screen.dart';
import '../features/cultural_quizzes/screens/cultural_quiz_play_screen.dart';
import '../features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';
import 'main_shell.dart';
import 'auth_redirect.dart';

CustomTransitionPage buildDirectionalSlidePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: Curves.easeOutCubic));

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: curve,
          child: child,
        ),
      );
    },
  );
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter listens to auth changes itself. Watching the notifier here also
  // rebuilds the router during a redirect, leaving the old callback with a
  // stale Riverpod ref when sign-in triggers notifyListeners().
  final refreshNotifier = ref.read(authRefreshProvider);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isRestoringSession) {
        if (state.matchedLocation == '/') return null;
        return '/?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      final loggedIn = authState.isAuthenticated;
      return resolveAuthRedirect(
        loggedIn: loggedIn,
        matchedLocation: state.matchedLocation,
        uri: state.uri,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              ref.watch(authProvider).isRestoringSession
                  ? const _RestoringSessionScreen()
                  : const DemoLoginScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/explore',
                builder: (context, state) => const SpotExploreScreen(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) => SpotDetailRouteScreen(
                      slug: state.pathParameters['slug']!,
                      initialSpot: state.extra is SpotModel
                          ? state.extra as SpotModel
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/spots/new',
                builder: (context, state) => const AddSpotScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapViewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quests',
                builder: (context, state) => const QuestListScreen(),
                routes: [
                  GoRoute(
                    path: 'campaigns/:id',
                    pageBuilder: (context, state) => buildDirectionalSlidePage(
                      context: context,
                      state: state,
                      child: CampaignDetailScreen(
                        campaignId: state.pathParameters['id'] ?? '',
                        initialCampaign: state.extra as CampaignModel?,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => QuestDetailScreen(
                        questId: state.pathParameters['id'] ?? ''),
                    routes: [
                      GoRoute(
                        path: 'funding',
                        builder: (context, state) => QuestFundingScreen(
                          questId: state.pathParameters['id'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'ar',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ArQuestScreen(
                          questId: state.pathParameters['id'] ?? '',
                          stepOrder: int.tryParse(
                              state.uri.queryParameters['step'] ?? ''),
                          quest: state.extra is QuestModel
                              ? state.extra as QuestModel
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/choice',
                builder: (context, state) => const JuanChoiceScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => JuanChoiceDetailScreen(
                        campaignId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'candidates/:candidateId',
                        builder: (context, state) => JuanChoiceDetailScreen(
                          campaignId: state.pathParameters['id']!,
                          focusCandidateId:
                              state.pathParameters['candidateId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: ':username',
                    builder: (context, state) => ProfileScreen(
                      username: state.pathParameters['username'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/vote',
        builder: (context, state) => const VoteScreen(),
        routes: [
          GoRoute(
              path: 'proposals',
              builder: (context, state) => const ProposalListScreen()),
        ],
      ),
      GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
          path: '/saved',
          builder: (context, state) => const SavedSpotsScreen()),
      GoRoute(
          path: '/affiliate',
          builder: (context, state) => const AffiliateApplicationScreen()),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return buildDirectionalSlidePage(
            context: context,
            state: state,
            child: SpotSearchScreen(
              initialQuery:
                  state.uri.queryParameters['q'] ?? extra?['q']?.toString(),
              initialCategory: state.uri.queryParameters['category'] ??
                  extra?['category']?.toString(),
              initialCrowd: state.uri.queryParameters['crowd'] ??
                  extra?['crowd']?.toString(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const SubmissionHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/trail',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const TrailComingSoonScreen(),
        ),
      ),
      GoRoute(
        path: '/plaza',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: PlazaScreen(
            initialActivityId: state.uri.queryParameters['activity'],
            initialOpenComments: state.uri.queryParameters['comments'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/leaderboard',
        redirect: (context, state) => '/plaza',
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: '/navigate',
        pageBuilder: (context, state) {
          final extra = state.extra;
          NavTarget destination;
          if (extra is NavTarget) {
            destination = extra;
          } else {
            final lat =
                double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
                    16.2045;
            final lng =
                double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
                    120.0435;
            final name = state.uri.queryParameters['name'] ?? 'Hundred Islands';
            final address = state.uri.queryParameters['address'] ?? name;
            destination = NavTarget(
              name: name,
              lat: lat,
              lng: lng,
              address: address,
            );
          }

          return buildDirectionalSlidePage(
            context: context,
            state: state,
            child: NavigationScreen(destination: destination),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/onboarding/interests',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InterestsScreen(),
      ),
      GoRoute(
        path: '/ar-diagnostics',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const ArDiagnosticsScreen(),
        ),
      ),
      GoRoute(
        path: '/cultural-quizzes/:id',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: CulturalQuizDetailScreen(
            quizId: state.pathParameters['id'] ?? '',
          ),
        ),
        routes: [
          GoRoute(
            path: 'play',
            pageBuilder: (context, state) => buildDirectionalSlidePage(
              context: context,
              state: state,
              child: CulturalQuizPlayScreen(
                quizId: state.pathParameters['id'] ?? '',
                session: state.extra as ({
                  CulturalQuizAttemptModel attempt,
                  List<CulturalQuizQuestionModel> questions
                }),
              ),
            ),
          ),
          GoRoute(
            path: 'result',
            pageBuilder: (context, state) => buildDirectionalSlidePage(
              context: context,
              state: state,
              child: CulturalQuizResultScreen(
                result: state.extra as CulturalQuizGradedResultModel,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RestoringSessionScreen extends StatelessWidget {
  const _RestoringSessionScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring your account…'),
            ],
          ),
        ),
      );
}

/// Resolves a shared/deep-linked destination without requiring navigation extra.
class SpotDetailRouteScreen extends ConsumerStatefulWidget {
  final String slug;
  final SpotModel? initialSpot;

  const SpotDetailRouteScreen(
      {super.key, required this.slug, this.initialSpot});

  @override
  ConsumerState<SpotDetailRouteScreen> createState() =>
      _SpotDetailRouteScreenState();
}

class _SpotDetailRouteScreenState extends ConsumerState<SpotDetailRouteScreen> {
  late Future<SpotModel> _spotFuture;

  @override
  void initState() {
    super.initState();
    _spotFuture = _fetchSpot();
  }

  Future<SpotModel> _fetchSpot() async {
    if (widget.initialSpot != null) return widget.initialSpot!;
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/spots/${Uri.encodeComponent(widget.slug)}');
    return SpotModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SpotModel>(
        future: _spotFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) return SpotDetailScreen(spot: snapshot.data!);
          final error = snapshot.error;
          final missing =
              error is DioException && error.response?.statusCode == 404;
          return Scaffold(
            appBar: AppBar(title: const Text('Destination')),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: snapshot.hasError
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                missing
                                    ? 'Destination not found.'
                                    : 'Destination unavailable. Check your connection.',
                                textAlign: TextAlign.center),
                            if (!missing)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _spotFuture = _fetchSpot()),
                                child: const Text('Retry'),
                              ),
                          ])
                        : const CircularProgressIndicator())),
          );
        },
      );
}
