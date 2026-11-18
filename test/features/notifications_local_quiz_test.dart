import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/notifications/providers/local_notifications_provider.dart';
import 'package:juanderquest_app/features/notifications/screens/notifications_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Plan 100 WP-5: a nearby quiz shows in Notifications and is read on the phone',
      (tester) async {
    final client = ApiClient(enableRetries: false);
    var serverPatched = false;
    client.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/notifications' && options.method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': {'items': []},
          },
        ));
      }
      if (options.method == 'PATCH') serverPatched = true;
      return handler.reject(DioException(requestOptions: options));
    }));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      localNotificationsProvider.overrideWith((ref) {
        final reads = ref.watch(localNotificationReadsProvider);
        const id = 'local:quiz:q1:2026-11-16';
        return [
          {
            'id': id,
            'kind': 'nearby_quiz',
            'title': 'Quiz unlocked: Hundred Islands',
            'message': 'You are at Hundred Islands. Play it now.',
            'href': '/cultural-quizzes/q1',
            'read': reads.contains(id),
          },
        ];
      }),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Quiz unlocked: Hundred Islands'), findsOneWidget);
    expect(find.text('NEARBY'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications_empty')), findsNothing);

    await tester.tap(find.text('MARK READ'));
    await tester.pumpAndSettle();
    expect(serverPatched, isFalse, reason: 'phone-made items never hit the API');
    expect(find.text('MARK READ'), findsNothing);
    expect(container.read(localNotificationReadsProvider),
        contains('local:quiz:q1:2026-11-16'));
  });
}
