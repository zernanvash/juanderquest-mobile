// Regression test for login screen and dialog rendering on small screens & insets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/demo_login_screen.dart';

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
          home: const DemoLoginScreen(),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Sign In with Email & Password'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sign In with Email & Password'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.tap(find.byType(TextField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}
