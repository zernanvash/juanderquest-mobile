import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/router.dart';

// go_router 14 asserts (`!keyReservation.contains(key)`) when a page on the
// root navigator pushes a route inside the tab shell. Search, Notifications and
// Saved open spots and quests, so they must live inside the shell.
void main() {
  testWidgets('pages that open spots or quests are inside the tab shell',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    for (final path in const ['/search', '/notifications', '/saved']) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.isError, isFalse, reason: '$path has no route');
      expect(match.matches.first, isA<ShellRouteMatch>(),
          reason: '$path must be inside the shell');
    }
  });

  testWidgets('settings sub-pages resolve', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    for (final path in const [
      '/settings/appearance',
      '/settings/updates',
      '/settings/developer',
      '/history',
      '/about',
    ]) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.isError, isFalse, reason: '$path has no route');
      expect(match.uri.path, path);
    }
  });
}
