import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/demo_login_screen.dart';
import '../features/quests/screens/quest_detail_screen.dart';
import '../features/ar_experience/screens/ar_experience_screen.dart';
import '../features/submissions/screens/submission_history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/map/screens/map_view_screen.dart';
import '../features/vote/screens/vote_screen.dart';
import '../features/vote/screens/proposal_list_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/spots/screens/spot_explore_screen.dart';
import '../features/spots/screens/add_spot_screen.dart';
import '../features/spots/models/spot_model.dart';
import 'main_shell.dart';

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
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));

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

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(authRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggedIn = authState.isAuthenticated;
      final onLogin = state.matchedLocation == '/';
      final publicDiscovery = state.matchedLocation == '/explore' || state.matchedLocation.startsWith('/explore/');

      if (!loggedIn && !onLogin && !publicDiscovery) return '/';
      if (loggedIn && onLogin) return '/explore';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DemoLoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const SpotExploreScreen(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) => SpotDetailScreen(spot: state.extra as SpotModel),
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
                path: '/vote',
                builder: (context, state) => const VoteScreen(),
                routes: [
                  GoRoute(
                    path: 'proposals',
                    pageBuilder: (context, state) => buildDirectionalSlidePage(
                      context: context,
                      state: state,
                      child: const ProposalListScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (context, state) => const ShopScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/quests/:id',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: QuestDetailScreen(questId: state.pathParameters['id'] ?? ''),
        ),
        routes: [
          GoRoute(
            path: 'ar',
            pageBuilder: (context, state) => buildDirectionalSlidePage(
              context: context,
              state: state,
              child: ARExperienceScreen(questId: state.pathParameters['id']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => buildDirectionalSlidePage(
          context: context,
          state: state,
          child: const SubmissionHistoryScreen(),
        ),
      ),
    ],
  );
});
