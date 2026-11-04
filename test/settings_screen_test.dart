import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:go_router/go_router.dart';

class InertAuthNotifier extends AuthNotifier {
  InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

void main() {
  final dummyUser = UserModel(
    id: 'u1111111-2222',
    seedId: 'test_scout',
    displayName: 'Juan Dela Cruz',
    email: 'juan@juanderquest.ph',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 500,
  );

  testWidgets('SettingsScreen renders key sections without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser,
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Explorer Settings'), findsOneWidget);
    // Settings home is a short list of categories; each opens its own page.
    for (final group in const ['ACCOUNT', 'ACTIVITY', 'APP', 'ABOUT']) {
      expect(find.text(group, skipOffstage: false), findsOneWidget,
          reason: group);
    }
    // Items moved here from the profile page.
    expect(find.text('My submissions', skipOffstage: false), findsOneWidget);
    expect(find.text('About JuanDerQuest & team', skipOffstage: false),
        findsOneWidget);
    expect(find.text('App updates', skipOffstage: false), findsOneWidget);
    expect(find.text('Developer tools', skipOffstage: false), findsOneWidget);
    // Detail now lives on the sub-pages, not on the home list.
    expect(
        find.text('App System & Updates', skipOffstage: false), findsNothing);
    expect(find.text('Developer & UI Designer Mode', skipOffstage: false),
        findsNothing);
    // Plan 47: the AR calibration/test studio is gone; travelers never calibrate.
    expect(find.text('Augmented Reality Studio', skipOffstage: false),
        findsNothing);
    expect(find.text('Text size', skipOffstage: false), findsOneWidget);
    expect(
        find.text('Log Out of Account', skipOffstage: false), findsOneWidget);
  });

  testWidgets('SettingsScreen renders in landscape without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser,
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Explorer Settings'), findsOneWidget);
  });

  testWidgets('Replay tutorial shows the first-run tutorial on Home again',
      (tester) async {
    final store = _MemoryTipsStore();
    late ProviderContainer container;
    final router = GoRouter(initialLocation: '/settings', routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (_, __) =>
              const Text('HOME', textDirection: TextDirection.ltr)),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeTipsStoreProvider.overrideWithValue(store),
          authProvider.overrideWith(
            (ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser,
            ),
          ),
        ],
        child: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(routerConfig: router);
        }),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings_replay_tutorial'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(store.resets, 1);
    expect(container.read(homeTipsControllerProvider).showing, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Text size dialog switches text scale setting', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => InertAuthNotifier(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              dummyUser,
            ),
          ),
        ],
        child: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const MaterialApp(
            home: SettingsScreen(),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('settings_text_size'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Text size'), findsWidgets);
    final smallerBtn = find.byKey(const ValueKey('settings_text_size_smaller'));
    expect(smallerBtn, findsOneWidget);
    await tester.tap(smallerBtn);
    await tester.pumpAndSettle();

    expect(container.read(pixelSettingsProvider).textSize,
        PixelTextSize.smaller);
  });
}

class _MemoryTipsStore implements HomeTipsStore {
  int resets = 0;

  @override
  Future<bool> seen() async => true;

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> reset() async => resets++;
}
