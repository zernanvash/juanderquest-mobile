// Regression test for login screen and dialog rendering on small screens & insets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/login_screen.dart';

class _SignedOut extends AuthNotifier {
  _SignedOut() : super(ApiClient(), AuthRefreshNotifier()) {
    state = AuthState();
  }
}

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('login rendering ${size.width}x${size.height}, 2x text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith((ref) => _SignedOut())],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Simulated'), findsNothing);
      expect(find.text('LGU Admin'), findsNothing);
      expect(find.textContaining('SELECT DEMO'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Sign in with email'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.tap(find.byType(TextField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }

  testWidgets(
      'traveler can switch to email signup and sees verification requirements',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _SignedOut())],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    ));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth_display_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth_age_eligibility')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth_terms')), findsOneWidget);
    expect(find.text('Create traveler account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
