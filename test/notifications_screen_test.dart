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
    expect(find.text('UPDATE'), findsOneWidget);
    // Owner 2026-11-18 (v0.3.3): no OPEN button (the note opens itself);
    // unread notes say NEW; MARK READ sits bottom right.
    expect(find.text('OPEN >'), findsNothing);
    expect(find.byKey(const ValueKey('notification_new_badge')), findsOneWidget);
    expect(find.text('MARK READ'), findsOneWidget);
    final note = tester.getRect(find.byKey(const ValueKey('notification_00000000-0000-4000-8000-000000000001')));
    final mark = tester.getRect(find.text('MARK READ'));
    expect(mark.right, greaterThan(note.center.dx));
    expect(mark.bottom, greaterThan(note.center.dy));
    expect(find.byKey(const ValueKey('notifications_read_all')), findsOneWidget);
    await tester.tap(find.text('MARK READ'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    expect(find.text('MARK READ'), findsNothing);
    expect(find.byKey(const ValueKey('notification_new_badge')), findsNothing);
    expect(find.text('READ'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications_read_all')), findsNothing);
  });

  testWidgets('maps kind labels, formats relative time, and READ ALL calls POST /notifications/read-all', (tester) async {
    final client = ApiClient(enableRetries: false);
    var readAllCalled = false;
    final twoHoursAgo =
        DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/notifications' && options.method == 'GET') {
        return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
          'success': true,
          'data': {
            'items': [
              {
                'id': 'n1',
                'kind': 'quest_reward',
                'title': 'Reward dropped',
                'message': '+20 mJDQ',
                'href': '/quests/q1',
                'read': false,
                'created_at': twoHoursAgo,
              },
              {
                'id': 'n2',
                'kind': 'weekly_recap',
                'title': 'Weekly Plaza recap',
                'message': 'You climbed 2 ranks.',
                'href': '/plaza',
                'read': false,
                'created_at': twoHoursAgo,
              },
            ],
          },
        }));
      }
      if (options.path == '/notifications/read-all' && options.method == 'POST') {
        readAllCalled = true;
        return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'success': true}));
      }
      return handler.reject(DioException(requestOptions: options));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('REWARD'), findsOneWidget);
    expect(find.text('PLAZA'), findsOneWidget);
    expect(find.text('2h ago'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('notifications_read_all')));
    await tester.pumpAndSettle();
    expect(readAllCalled, isTrue);
    expect(find.byKey(const ValueKey('notifications_read_all')), findsNothing);
    expect(find.text('READ'), findsNWidgets(2));
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
