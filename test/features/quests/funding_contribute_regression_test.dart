import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';

// Owner 2026-11-18 (screen recording): contributing 100 points to a draft
// round turned the funding screen blank grey.

Map<String, dynamic> _plan({required bool contributed}) => {
      'id': 'plan-1',
      'quest_id': 'quest-1',
      'status': 'draft',
      'mode': 'budget',
      'round_number': 1,
      'reward_points': 50,
      'fee_points': 3,
      'planned_completions': 10,
      'target_points': '530',
      'version': contributed ? 2 : 1,
      'starts_at': '2026-11-18T11:12:00.000Z',
      'ends_at': '2026-12-02T11:12:00.000Z',
      'is_test': false,
      'contributions': contributed
          ? [
              {
                'id': 'c-1',
                'plan_id': 'plan-1',
                'funder_kind': 'author',
                'funder_user_id': 'u-1',
                'merchant_id': null,
                'sponsorship_id': null,
                'is_test': false,
                'committed_points': '100',
                'remaining_points': '100',
                'held_points': '0',
                'paid_reward_points': '0',
                'paid_fee_points': '0',
                'refunded_points': '0',
                'created_at': '2026-11-18T11:12:14.000Z',
                'updated_at': '2026-11-18T11:12:14.000Z',
              }
            ]
          : [],
      'holds': [],
      'sponsorships': [],
      'simulated': true,
    };

void main() {
  testWidgets('contributing to a draft round keeps the screen working',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var contributed = false;
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.path == '/quests/quest-1/funding-plan') {
        return h.resolve(Response(requestOptions: o, statusCode: 200, data: {
          'success': true,
          'data': {'plan': _plan(contributed: contributed)},
        }));
      }
      if (o.path == '/funding-plans/plan-1/self-contribution') {
        contributed = true;
        return h.resolve(Response(requestOptions: o, statusCode: 200, data: {
          'success': true,
          'data': {'contribution_id': 'c-1', 'balance': '400'},
        }));
      }
      return h.resolve(Response(
          requestOptions: o, statusCode: 200, data: {'success': true}));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const QuestFundingScreen(questId: 'quest-1'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('funding_points')),
        matching: find.byType(TextField),
      ),
      '100',
    );
    final button = find.byKey(const ValueKey('funding_contribute'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('100 committed'), findsOneWidget);
  });
}
