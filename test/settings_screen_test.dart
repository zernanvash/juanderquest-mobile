import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';

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

  testWidgets('SettingsScreen renders key sections without overflow', (tester) async {
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
    expect(find.text('App System & Updates', skipOffstage: false), findsOneWidget);
    expect(find.text('Augmented Reality Studio', skipOffstage: false), findsOneWidget);
    expect(find.text('Developer & UI Designer Mode', skipOffstage: false), findsOneWidget);
    expect(find.text('Log Out of Account', skipOffstage: false), findsOneWidget);
  });

  testWidgets('SettingsScreen renders in landscape without overflow', (tester) async {
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
}
