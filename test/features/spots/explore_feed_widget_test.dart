import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/pixel/pixel_feedback.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/screens/spot_explore_screen.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _TestDiscoveryNotifier extends SpotDiscoveryNotifier {
  bool reloadCalled = false;
  SpotModel? toggledSpot;

  _TestDiscoveryNotifier(super.ref, SpotDiscoveryState initialState) {
    state = initialState;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {
    reloadCalled = true;
  }

  @override
  Future<ApiFailure?> toggleSaved(SpotModel spot) async {
    toggledSpot = spot;
    final next = !spot.saved;
    state = state.copyWith(
      spots: state.spots
          .map((s) => s.id == spot.id ? s.copyWith(saved: next) : s)
          .toList(),
    );
    return null;
  }
}

SpotModel _makeSpot({
  required String id,
  required String name,
  String? slug,
  String? category,
  String? subcategory,
  String? municipality,
  String? imageUrl,
  String? questId,
  String? sourceName,
  bool saved = false,
  bool isTest = false,
  String? crowdStatus,
  String? trustLevel,
}) {
  return SpotModel(
    id: id,
    slug: slug ?? id,
    name: name,
    description: 'A wonderful destination in Pangasinan with historic value.',
    category: category ?? 'nature',
    subcategory: subcategory ?? 'general',
    municipality: municipality ?? 'Lingayen',
    address: 'Capitol Complex, Lingayen',
    sourceName: sourceName ?? 'LGU Lingayen',
    trustLevel: trustLevel ?? 'lgu_verified',
    gpsLat: 16.02,
    gpsLng: 120.23,
    tags: const ['beach'],
    reasons: const ['Scenic spot'],
    crowdStatus: crowdStatus ?? 'estimated_quiet',
    questId: questId,
    imageUrl: imageUrl,
    saved: saved,
    isTest: isTest,
  );
}

Widget _buildHarness({
  required _TestDiscoveryNotifier discoveryNotifier,
  ChoiceSpotlight? spotlight,
  List<String>? pushedRoutes,
  bool showTest = false,
}) {
  final testClient = ApiClient(enableRetries: false);
  final user = UserModel(
    id: 'user-traveler-1',
    seedId: 'seed-1',
    email: 'traveler@juanderquest.app',
    displayName: 'Traveler One',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 100,
  );

  final router = GoRouter(
    initialLocation: '/explore',
    routes: [
      GoRoute(
        path: '/explore',
        builder: (_, __) => const SpotExploreScreen(),
        routes: [
          GoRoute(
            path: ':slug',
            builder: (_, state) {
              pushedRoutes?.add('/explore/${state.pathParameters['slug']}');
              return Scaffold(
                body: Text('ROUTE:/explore/${state.pathParameters['slug']}'),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/quests/:id',
        builder: (_, state) {
          pushedRoutes?.add('/quests/${state.pathParameters['id']}');
          return Scaffold(
            body: Text('ROUTE:/quests/${state.pathParameters['id']}'),
          );
        },
      ),
      GoRoute(
        path: '/juanchoice',
        builder: (_, __) {
          pushedRoutes?.add('/juanchoice');
          return const Scaffold(body: Text('ROUTE:/juanchoice'));
        },
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) {
          pushedRoutes?.add('/search');
          return const Scaffold(body: Text('ROUTE:/search'));
        },
      ),
      GoRoute(
        path: '/trail',
        builder: (_, __) {
          pushedRoutes?.add('/trail');
          return const Scaffold(body: Text('ROUTE:/trail'));
        },
      ),
      GoRoute(
        path: '/map/add-spot',
        builder: (_, __) {
          pushedRoutes?.add('/map/add-spot');
          return const Scaffold(body: Text('ROUTE:/map/add-spot'));
        },
      ),
    ],
  );

  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      apiClientProvider.overrideWithValue(testClient),
      authProvider.overrideWith((ref) => _InertAuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            user,
          )),
      spotDiscoveryProvider.overrideWith((ref) => discoveryNotifier),
      choiceSpotlightProvider.overrideWith((ref) => spotlight),
      hiddenGemProvider.overrideWith((ref) async => const []),
      showTestContentProvider.overrideWith((ref) => showTest),
    ],
    child: MaterialApp.router(
      theme: AppTheme.pixel,
      routerConfig: router,
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder, {int maxDrags = 30, double dy = -250}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (finder.evaluate().isNotEmpty) {
      final center = tester.getCenter(finder.first);
      if (center.dy > 50 && center.dy < 550) return;
    }
    await tester.drag(find.byType(ListView), Offset(0, dy));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explore Feed Screen Widget Tests', () {
    testWidgets('featured card shows when a spot with photo exists', (tester) async {
      final spotWithPhoto = _makeSpot(
        id: 's1',
        name: 'Lingayen Beach',
        imageUrl: 'https://images.unsplash.com/photo-beach',
      );
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: [spotWithPhoto], isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(discoveryNotifier: notifier));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('FEATURED DESTINATION'));
      expect(find.text('FEATURED DESTINATION'), findsOneWidget);
      expect(find.text('Lingayen Beach'), findsWidgets);
    });

    testWidgets('featured card does not show when no spot has a photo', (tester) async {
      final spotNoPhoto = _makeSpot(
        id: 's2',
        name: 'Hidden Cave',
        imageUrl: null,
      );
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: [spotNoPhoto], isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(discoveryNotifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('FEATURED DESTINATION'), findsNothing);
      await _scrollTo(tester, find.text('Hidden Cave'));
      expect(find.text('Hidden Cave'), findsWidgets);
    });

    testWidgets('JuanChoice card sits at the computed index and buttons work', (tester) async {
      final pushedRoutes = <String>[];
      final spots = List.generate(
        5,
        (i) => _makeSpot(
          id: 'spot-$i',
          name: 'Spot Number $i',
          slug: 'spot-$i',
        ),
      );

      final spotlight = ChoiceSpotlight(
        campaignId: 'bangus-fest-2026',
        theme: 'Best Pangasinan Seafood',
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        winnerSpotIds: {'spot-4'},
      );

      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: spots, isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(
        discoveryNotifier: notifier,
        spotlight: spotlight,
        pushedRoutes: pushedRoutes,
      ));
      await tester.pumpAndSettle();

      final spotlightTitle = find.text('JUANCHOICE SPOTLIGHT');
      await _scrollTo(tester, spotlightTitle);
      expect(spotlightTitle, findsOneWidget);
      expect(find.text('Best Pangasinan Seafood'), findsOneWidget);

      // Tap "SEE FINAL RESULTS" link first
      final seeResultsBtn = find.text('SEE FINAL RESULTS ›');
      await _scrollTo(tester, seeResultsBtn);
      expect(seeResultsBtn, findsOneWidget);
      await tester.tap(seeResultsBtn);
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/juanchoice'));

      // Pop back from /juanchoice to return to feed
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pumpAndSettle();

      // Tap winner destination button inside JuanChoice ('SPOT NUMBER 4 · LINGAYEN')
      final winnerBtn = find.text('SPOT NUMBER 4 · LINGAYEN');
      await _scrollTo(tester, winnerBtn);
      expect(winnerBtn, findsOneWidget);
      await tester.tap(winnerBtn);
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/explore/spot-4'));
    });

    testWidgets('action buttons work: like, save, PLAY QUEST, and card tap', (tester) async {
      final pushedRoutes = <String>[];
      final spot = _makeSpot(
        id: 'spot-interactive',
        name: 'Interactive Spot',
        slug: 'interactive-spot',
        questId: 'quest-999',
        sourceName: 'Tourism Board',
      );

      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: [spot], isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(
        discoveryNotifier: notifier,
        pushedRoutes: pushedRoutes,
      ));
      await tester.pumpAndSettle();

      // Plan 75m: the credit moved to the spot page's end panel.
      expect(find.text('SHARED BY TOURISM BOARD'), findsNothing);

      // 1. Like button tap (initial likes: 45 + 16*3 = 93)
      final likeBtn = find.widgetWithText(PixelButton, '93');
      await _scrollTo(tester, likeBtn);
      expect(likeBtn, findsOneWidget);
      await tester.tap(likeBtn);
      await tester.pump();
      // Incremented to 94
      expect(find.widgetWithText(PixelButton, '94'), findsOneWidget);

      // 2. Save button tap
      final saveBtn = find.bySemanticsLabel('Save bookmark');
      await _scrollTo(tester, saveBtn);
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();
      expect(notifier.toggledSpot?.id, equals('spot-interactive'));

      // 3. Plan 75m: no report flag on the card; "Report a problem" is on
      //    the spot page (theater_end_report_btn).
      expect(find.bySemanticsLabel('Report problem'), findsNothing);

      // 4. PLAY QUEST button tap
      final playQuestBtn = find.text('PLAY QUEST');
      await _scrollTo(tester, playQuestBtn);
      expect(playQuestBtn, findsOneWidget);
      await tester.tap(playQuestBtn);
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/quests/quest-999'));

      // Pop back from /quests/:id
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pumpAndSettle();

      // 5. Card tap navigates to /explore/:slug
      final cardTapTarget = find.text('Interactive Spot');
      await _scrollTo(tester, cardTapTarget);
      expect(cardTapTarget, findsWidgets);
      await tester.tap(cardTapTarget.first);
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/explore/interactive-spot'));
    });

    testWidgets('non-quest cards offer VIEW SPOT on the right',
        (tester) async {
      final pushedRoutes = <String>[];
      final spot = _makeSpot(
        id: 'plain-spot',
        name: 'Plain Cove',
        slug: 'plain-cove',
      );
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: [spot], isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(
        discoveryNotifier: notifier,
        pushedRoutes: pushedRoutes,
      ));
      await tester.pumpAndSettle();

      final viewSpot =
          find.byKey(const ValueKey('explore_view_spot_plain-spot'));
      await _scrollTo(tester, viewSpot);
      expect(viewSpot, findsOneWidget);
      await tester.tap(viewSpot);
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/explore/plain-cove'));
    });

    testWidgets('test spots appear only with the developer switch on',
        (tester) async {
      final normal = _makeSpot(id: 'normal', name: 'Normal Cove');
      final testSpot = _makeSpot(
        id: 'artest',
        name: 'ARTEST Spot',
        isTest: true,
      );
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(
          spots: [normal, testSpot],
          isInitialLoading: false,
        ),
      );

      await tester.pumpWidget(_buildHarness(discoveryNotifier: notifier));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Normal Cove'));
      expect(find.text('Normal Cove'), findsWidgets);
      expect(find.text('ARTEST Spot'), findsNothing);

      final showNotifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(
          spots: [normal, testSpot],
          isInitialLoading: false,
        ),
      );
      await tester.pumpWidget(_buildHarness(
        discoveryNotifier: showNotifier,
        showTest: true,
      ));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('ARTEST Spot'));
      expect(find.text('ARTEST Spot'), findsWidgets);
    });

    testWidgets('loading state displays PixelLoader', (tester) async {
      final loadingNotifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        const SpotDiscoveryState(spots: [], isInitialLoading: true),
      );
      await tester.pumpWidget(_buildHarness(discoveryNotifier: loadingNotifier));
      await tester.pump();
      expect(find.byType(PixelLoader), findsWidgets);
    });

    testWidgets('error state displays web wording and allows retry', (tester) async {
      final errorNotifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        const SpotDiscoveryState(
          spots: [],
          isInitialLoading: false,
          failure: ApiFailure(
            code: 'network_error',
            message: 'Network timeout connecting to server',
          ),
        ),
      );
      await tester.pumpWidget(_buildHarness(discoveryNotifier: errorNotifier));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Failed to load feed'));
      expect(find.text('Failed to load feed'), findsOneWidget);
      expect(find.text('Network timeout connecting to server'), findsOneWidget);
      final retryBtn = find.text('TRY AGAIN');
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pump();
      expect(errorNotifier.reloadCalled, isTrue);
    });

    testWidgets('empty state displays web wording', (tester) async {
      final emptyNotifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        const SpotDiscoveryState(spots: [], isInitialLoading: false),
      );
      await tester.pumpWidget(_buildHarness(discoveryNotifier: emptyNotifier));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('No destinations found in feed'));
      expect(find.text('No destinations found in feed'), findsOneWidget);
      expect(
        find.text('The community feed could not find active destinations matching your filter.'),
        findsOneWidget,
      );
    });

    testWidgets('LOAD MORE button pages items and caught-up message displays', (tester) async {
      // Create 15 spots
      final spots = List.generate(
        15,
        (i) => _makeSpot(
          id: 'paged-$i',
          name: 'Paged Spot $i',
          slug: 'paged-$i',
        ),
      );

      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: spots, isInitialLoading: false),
      );

      await tester.pumpWidget(_buildHarness(discoveryNotifier: notifier));
      await tester.pumpAndSettle();

      // Initially, Paged Spot 0 is visible
      await _scrollTo(tester, find.text('Paged Spot 0'));
      expect(find.text('Paged Spot 0'), findsWidgets);
      expect(find.text('Paged Spot 14'), findsNothing);

      // Scroll to and find LOAD MORE button
      final loadMoreBtn = find.text('LOAD MORE');
      await _scrollTo(tester, loadMoreBtn);
      expect(loadMoreBtn, findsOneWidget);

      // Tap LOAD MORE
      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();

      // Scroll to Paged Spot 14
      await _scrollTo(tester, find.text('Paged Spot 14'));
      expect(find.text('Paged Spot 14'), findsWidgets);

      // Caught up message
      final caughtUpText = find.text("You're caught up. Checking for new posts…");
      await _scrollTo(tester, caughtUpText);
      expect(caughtUpText, findsOneWidget);
    });
  });
}
