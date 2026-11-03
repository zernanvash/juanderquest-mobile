import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
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
  }) async {}

  @override
  Future<ApiFailure?> toggleSaved(SpotModel spot) async => null;
}

SpotModel _makeSpot({
  required String id,
  required String name,
  String category = 'nature',
  String municipality = 'Lingayen',
  String? imageUrl,
  String? questId,
}) {
  return SpotModel(
    id: id,
    slug: id,
    name: name,
    description: 'A picturesque destination nestled in the heart of Pangasinan.',
    category: category,
    subcategory: 'general',
    municipality: municipality,
    address: 'Capitol Bay, Pangasinan',
    sourceName: 'LGU Tourism Office',
    trustLevel: 'lgu_verified',
    gpsLat: 16.02,
    gpsLng: 120.23,
    tags: const ['scenic', 'heritage'],
    reasons: const ['Scenic destination'],
    crowdStatus: 'estimated_quiet',
    questId: questId,
    imageUrl: imageUrl,
  );
}

Widget _wrapScreen({
  required _TestDiscoveryNotifier notifier,
  required Size size,
  required double textScale,
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
          GoRoute(path: ':slug', builder: (_, __) => const Scaffold()),
        ],
      ),
      GoRoute(path: '/quests/:id', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/search', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/trail', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/map/add-spot', builder: (_, __) => const Scaffold()),
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
      spotDiscoveryProvider.overrideWith((ref) => notifier),
      hiddenGemProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(
      theme: AppTheme.pixel,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder, {int maxDrags = 20, double dy = -250}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(ListView), Offset(0, dy));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final spots = [
    _makeSpot(
      id: 'spot-1',
      name: 'Lingayen Beach Capitol',
      category: 'nature',
      municipality: 'Lingayen',
      imageUrl: 'https://images.unsplash.com/photo-beach',
      questId: 'quest-lingayen',
    ),
    _makeSpot(
      id: 'spot-2',
      name: 'Dagupan Seafood Hub',
      category: 'food',
      municipality: 'Dagupan',
    ),
  ];

  group('Explore Screen Overflow Tests (2.0x text scaling)', () {
    testWidgets('Populated feed in portrait (320x568) with chip tap and like tap', (tester) async {
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: spots, isInitialLoading: false),
      );

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(
        notifier: notifier,
        size: const Size(320, 568),
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      // Tap a filter category chip
      final natureChip = find.text('Nature');
      if (natureChip.evaluate().isNotEmpty) {
        await tester.tap(natureChip);
        await tester.pumpAndSettle();
      }

      // Tap LIKE button if present in viewport or scroll down
      final likeBtn = find.text('108'); // Lingayen Beach Capitol (length 21): 45 + 63 = 108
      await _scrollTo(tester, likeBtn);
      if (likeBtn.evaluate().isNotEmpty) {
        await tester.tap(likeBtn.first);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Populated feed in landscape (568x320) with chip tap and like tap', (tester) async {
      final notifier = _TestDiscoveryNotifier(
        ProviderContainer().read(Provider((ref) => ref)),
        SpotDiscoveryState(spots: spots, isInitialLoading: false),
      );

      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(
        notifier: notifier,
        size: const Size(568, 320),
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      // Tap LIKE button
      final likeBtn = find.text('108');
      await _scrollTo(tester, likeBtn);
      if (likeBtn.evaluate().isNotEmpty) {
        await tester.tap(likeBtn.first);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Empty filter state in portrait (320x568) and landscape (568x320)', (tester) async {
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        final notifier = _TestDiscoveryNotifier(
          ProviderContainer().read(Provider((ref) => ref)),
          const SpotDiscoveryState(spots: [], isInitialLoading: false),
        );

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(_wrapScreen(
          notifier: notifier,
          size: size,
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        final emptyFinder = find.text('No destinations found in feed');
        await _scrollTo(tester, emptyFinder);
        expect(emptyFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Error state in portrait (320x568) and landscape (568x320)', (tester) async {
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        final notifier = _TestDiscoveryNotifier(
          ProviderContainer().read(Provider((ref) => ref)),
          const SpotDiscoveryState(
            spots: [],
            isInitialLoading: false,
            failure: ApiFailure(code: 'network_error', message: 'Connection timeout'),
          ),
        );

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(_wrapScreen(
          notifier: notifier,
          size: size,
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        final errorFinder = find.text('Failed to load feed');
        await _scrollTo(tester, errorFinder);
        expect(errorFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
