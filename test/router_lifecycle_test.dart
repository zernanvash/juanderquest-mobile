import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/app/router.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('auth refresh keeps the router and its redirect callback alive', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    container.read(authRefreshProvider).notify();
    await tester.pump();

    expect(identical(container.read(routerProvider), router), isTrue);
  });
}
