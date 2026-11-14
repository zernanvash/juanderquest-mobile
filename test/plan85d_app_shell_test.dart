import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_developer_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final dummyStats = ProfileStatsModel(
    completedQuestsCount: 3,
    pendingSubmissionsCount: 1,
    totalPointsEarned: 150,
    ecoPioneerState: BadgeState.inProgress,
    heritageKeeperState: BadgeState.locked,
    foodExplorerState: BadgeState.earned,
  );

  final dummyUser = UserModel(
    id: 'u-85d',
    seedId: 'seed-85d',
    displayName: 'Juan Scout',
    email: 'juan@pangasinan.ph',
    avatarUrl: '',
    role: 'user',
    demoPoints: 250,
  );

  Future<void> pumpAtSize(
    WidgetTester tester,
    Widget child,
    Size size,
    double textScale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/target',
      routes: [
        GoRoute(path: '/target', builder: (_, __) => child),
        GoRoute(
          path: '/vote',
          builder: (_, __) => const Scaffold(body: Text('route:/vote')),
        ),
        GoRoute(
          path: '/shop',
          builder: (_, __) => const Scaffold(body: Text('route:/shop')),
        ),
        GoRoute(
          path: '/wallet/connect',
          builder: (_, __) => const Scaffold(body: Text('route:/wallet/connect')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (_) => _FakeAuthNotifier(AuthState(user: dummyUser, token: 'tok')),
          ),
          profileStatsProvider.overrideWithValue(dummyStats),
        ],
        child: MaterialApp.router(
          theme: AppTheme.pixel,
          routerConfig: router,
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: widget!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }

  testWidgets('SettingsDeveloperScreen holds Governance prototype and opens /vote',
      (tester) async {
    await pumpAtSize(
      tester,
      const SettingsDeveloperScreen(),
      const Size(390, 844),
      1.0,
    );
    final gov = find.byKey(const ValueKey('settings_governance'));
    await tester.scrollUntilVisible(
      gov,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(gov, findsOneWidget);
    await tester.tap(gov);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('route:/vote'), findsOneWidget);
  });

  testWidgets('SettingsScreen hides Governance prototype and labels testnet',
      (tester) async {
    await pumpAtSize(
      tester,
      const SettingsScreen(),
      const Size(390, 844),
      1.0,
    );
    expect(find.byKey(const ValueKey('settings_governance')), findsNothing);
    expect(find.text('Polygon Amoy testnet · not real money'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders Concept B command grid and almanac', (tester) async {
    await pumpAtSize(
      tester,
      const DashboardScreen(),
      const Size(390, 844),
      1.0,
    );
    expect(find.byKey(const ValueKey('home_command_grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_menu_quests')), findsOneWidget);
  });

  testWidgets('ProfileScreen exposes Shop card', (tester) async {
    await pumpAtSize(
      tester,
      const ProfileScreen(),
      const Size(390, 844),
      1.0,
    );
    expect(find.byKey(const ValueKey('profile_shop')), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('No overflow at ${size.width}x${size.height} 2x text on Settings, Dev, Profile, Home',
        (tester) async {
      await pumpAtSize(tester, const SettingsScreen(), size, 2.0);
      await pumpAtSize(tester, const SettingsDeveloperScreen(), size, 2.0);
      await pumpAtSize(tester, const ProfileScreen(), size, 2.0);
      await pumpAtSize(tester, const DashboardScreen(), size, 2.0);
    });
  }
}
