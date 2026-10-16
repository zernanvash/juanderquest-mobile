import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_posting_sheet.dart';

Widget wrapSheet(ApiClient client, {SpotPostingDraft? draft, int step = 0}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(
        body: SpotPostingSheet(
          initialLat: 14.5995,
          initialLng: 120.9842,
          initialDraft: draft,
          initialStep: step,
        ),
      ),
    ),
  );
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blocks advancing with an invalid first step and preserves answers on Back',
      (tester) async {
    await tester.pumpWidget(wrapSheet(ApiClient()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 1 of 6'), findsOneWidget);

    await tapNext(tester);
    expect(find.textContaining('at least 3 characters'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Destination name *'),
      'Tambobong White Beach',
    );
    await tapNext(tester);
    expect(find.textContaining('Step 2 of 6'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Tambobong White Beach'), findsOneWidget);
  });

  testWidgets('publishes through the API and reports the created destination', (tester) async {
    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/spots' && options.method == 'POST') {
          expect(options.data['gps_lat'], 14.5995);
          expect(options.data['gps_lng'], 120.9842);
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'id': 'spot-sheet-1',
                'slug': 'qa-sheet-destination',
                'name': 'Tambobong White Beach',
                'gps_lat': 14.5995,
                'gps_lng': 120.9842,
              },
            },
          ));
        }
        return handler.next(options);
      },
    ));

    await tester.pumpWidget(wrapSheet(client));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Destination name *'),
      'Tambobong White Beach',
    );
    await tapNext(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'What makes it worth visiting? *'),
      'A quiet stretch of white sand with calm water for swimming and picnics.',
    );
    await tapNext(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Municipality / city *'), 'Dasol');
    await tester.enterText(find.widgetWithText(TextField, 'Address / landmark *'), 'Brgy. Tambobong, Dasol');
    await tapNext(tester);

    await tapNext(tester);
    await tapNext(tester);

    expect(find.textContaining('Step 6 of 6'), findsOneWidget);
    await tester.tap(find.text('Publish destination'));
    await tester.pumpAndSettle();

    expect(find.text('Destination published'), findsOneWidget);
    expect(find.textContaining('Tambobong White Beach is now visible'), findsOneWidget);
  });

  testWidgets('keeps the draft when publishing fails and can retry successfully', (tester) async {
    var attempts = 0;
    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/spots' && options.method == 'POST') {
          attempts += 1;
          if (attempts == 1) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {
                  'success': false,
                  'error': {'message': 'Destination temporarily unavailable. Please try again.'},
                },
              ),
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'id': 'spot-sheet-2',
                'slug': 'qa-sheet-retry',
                'name': 'Tambobong White Beach',
                'gps_lat': 14.5995,
                'gps_lng': 120.9842,
              },
            },
          ));
        }
        return handler.next(options);
      },
    ));

    await tester.pumpWidget(wrapSheet(client));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Destination name *'),
      'Tambobong White Beach',
    );
    await tapNext(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'What makes it worth visiting? *'),
      'A quiet stretch of white sand with calm water for swimming and picnics.',
    );
    await tapNext(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Municipality / city *'), 'Dasol');
    await tester.enterText(find.widgetWithText(TextField, 'Address / landmark *'), 'Brgy. Tambobong, Dasol');
    await tapNext(tester);
    await tapNext(tester);
    await tapNext(tester);

    await tester.tap(find.text('Publish destination'));
    await tester.pumpAndSettle();
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.text('Tambobong White Beach'), findsWidgets);

    await tester.tap(find.text('Publish destination'));
    await tester.pumpAndSettle();
    expect(find.text('Destination published'), findsOneWidget);
    expect(attempts, 2);
  });
}
