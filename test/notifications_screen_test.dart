import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/notifications/screens/notifications_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows durable funding notifications and marks only the selected one read', (tester) async {
    final client = ApiClient(enableRetries: false);
    var read = false;
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/notifications' && options.method == 'GET') {
        return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
          'success': true,
          'data': {'items': [{'id': '00000000-0000-4000-8000-000000000001', 'kind': 'quest_funding',
            'title': 'Quest funding ready', 'message': 'Your quest can now accept attempts.', 'href': '/funding', 'read': read}]},
        }));
      }
      if (options.path.endsWith('/read') && options.method == 'PATCH') {
        read = true;
        return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'success': true}));
      }
      return handler.reject(DioException(requestOptions: options));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Quest funding ready'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    expect(find.byTooltip('Mark as read'), findsNothing);
  });

  testWidgets('shows an empty state when the inbox has no events', (tester) async {
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {'success': true, 'data': {'items': []}},
    ))));
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('all caught up'), findsOneWidget);
  });
}
