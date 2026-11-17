import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/open_route.dart';

// Owner 2026-11-17: "go to map from main menu, then click home (shows home)
// then click explore, it shows the wrong page (map)". The menu pushed /map, a
// tab root, onto the Home tab's stack.
void main() {
  late StatefulNavigationShell shell;

  GoRouter router() => GoRouter(
        initialLocation: '/dashboard',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, nav) {
              shell = nav;
              return Scaffold(body: nav);
            },
            branches: [
              for (final p in ['/dashboard', '/explore', '/map'])
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: p,
                    builder: (context, _) => Builder(
                      builder: (context) => Column(children: [
                        Text('page $p'),
                        TextButton(
                          onPressed: () => openRoute(context, '/map'),
                          child: Text('open map from $p'),
                        ),
                      ]),
                    ),
                  ),
                ]),
            ],
          ),
        ],
      );

  testWidgets('Map from the menu, then Home, then Explore shows Explore',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
    await tester.tap(find.text('open map from /dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('page /map'), findsOneWidget);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    expect(find.text('page /dashboard'), findsOneWidget);

    shell.goBranch(1);
    await tester.pumpAndSettle();
    expect(find.text('page /explore'), findsOneWidget);
    expect(find.text('page /map'), findsNothing);
  });
}
