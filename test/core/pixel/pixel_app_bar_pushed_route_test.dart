import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/core/pixel/pixel_nav.dart';

// v0.3.10: a PixelAppBar on a screen pushed with Navigator.push inside a
// StatefulShellRoute branch froze the app (GoRouterState.of looped forever).
void main() {
  testWidgets(
      'PixelAppBar on a Navigator.push screen inside a shell branch builds',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/shop',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => shell,
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/shop',
                builder: (context, state) => Scaffold(
                  body: Builder(
                    builder: (ctx) => TextButton(
                      onPressed: () => Navigator.of(ctx).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: PixelAppBar(title: 'Scan Suki'),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PixelAppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
