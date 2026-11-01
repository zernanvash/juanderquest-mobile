import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/app/router.dart';

// Plan 73: the builder buttons push these paths; each must match a real route
// (a /spots/... path once fell through to "Page Not Found" on the phone).
void main() {
  testWidgets('quest builder paths resolve in the app router', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    for (final path in const [
      '/explore/some-spot-1a2b3c/quests/new',
      '/quests/q-1/edit',
      '/quests/q-1/qr-sheet',
    ]) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.isError, isFalse, reason: '$path has no route');
      expect(match.uri.path, path);
    }
  });
}
