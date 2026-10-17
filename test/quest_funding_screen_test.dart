import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('author can create a draft funding round from mobile', (tester) async {
    final client = ApiClient(enableRetries: false);
    var createdPlan = false;
    var submittedBody = <String, dynamic>{};
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/quest-1/funding-plan' && options.method == 'GET') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'plan': createdPlan
                    ? {
                        'id': 'plan-1',
                        'status': 'draft',
                        'mode': 'budget',
                        'reward_points': 50,
                        'target_points': 530,
                        'ends_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
                        'contributions': [],
                      }
                    : null,
              },
            },
          ));
        }
        if (options.path == '/quests/quest-1/funding-plans' && options.method == 'POST') {
          submittedBody = Map<String, dynamic>.from(options.data as Map);
          createdPlan = true;
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': {'id': 'plan-1'}},
          ));
        }
        return handler.reject(DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 404,
            data: {'success': false},
          ),
        ));
      },
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: QuestFundingScreen(questId: 'quest-1')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Set up this round'), findsOneWidget);

    await tester.ensureVisible(find.text('Create draft funding plan'));
    await tester.tap(find.text('Create draft funding plan'));
    await tester.pumpAndSettle();

    expect(submittedBody['mode'], 'budget');
    expect(submittedBody['planned_completions'], 10);
    expect(submittedBody['idempotency_key'], isA<String>());
    expect(find.textContaining('Funding round · draft'), findsOneWidget);
  });

  testWidgets('funding setup remains usable at 320px with 2x text', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': {'plan': null}},
      )),
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: QuestFundingScreen(questId: 'quest-1')),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });
}
