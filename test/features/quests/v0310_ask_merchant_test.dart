import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/quests/screens/sponsor_request_screen.dart';

/// v0.3.10 team review: "app crash when interacting with ask merchant
/// funding". Quest > Funding > ASK A MERCHANT with real payload shapes.

class _Fake {
  _Fake({required this.plan, required this.merchants});

  final Map<String, dynamic>? plan;
  final Object? merchants;
  Map<String, dynamic>? sent;

  ApiClient client() {
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        Response ok(Object data) =>
            Response(requestOptions: options, statusCode: 200, data: data);
        if (options.path.endsWith('/funding-plan')) {
          return handler.resolve(ok({
            'success': true,
            'data': {'plan': plan},
          }));
        }
        if (options.path == '/sponsor-directory') {
          return handler.resolve(ok({
            'success': true,
            'data': {'items': merchants, 'page': 1, 'simulated': true},
          }));
        }
        if (options.path.endsWith('/sponsorships')) {
          sent = Map<String, dynamic>.from(options.data as Map);
          return handler.resolve(ok({'success': true, 'data': {}}));
        }
        return handler.resolve(ok({'success': true, 'data': {}}));
      }),
    );
    return client;
  }
}

Map<String, dynamic> _plan({Object? id = 'plan-1'}) => {
      if (id != null) 'id': id,
      'status': 'pending_sponsors',
      'mode': 'budget',
      'reward_points': '10',
      'target_points': '1000',
      'committed_points': '100',
      'held_points': null,
      'ends_at': '2026-12-31T00:00:00Z',
      'contributions': [],
      'sponsorships': [],
    };

final _merchants = [
  {
    'id': 'm1',
    'name': 'Aling Nena Cafe',
    'municipality': 'Bolinao',
    'category': 'cafe',
    'logo_url': null,
    'description': null,
    'same_municipality': true,
    'distance_m': '350',
    'vouchers': [
      {'id': 'v1', 'title': 'Free halo-halo', 'description': null},
      {'id': 'v1', 'title': 'Free halo-halo (dup)', 'description': ''},
      {'id': 'v2', 'title': null, 'description': 'x'},
    ],
  },
  {
    'id': 'm2',
    'name': 'Bare Shop',
    'municipality': null,
    'category': null,
    'logo_url': null,
    'description': '',
    'same_municipality': false,
    'distance_m': null,
    'vouchers': null,
  },
];

Future<void> _pump(WidgetTester tester, _Fake fake) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(fake.client())],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: const QuestFundingScreen(questId: 'quest-1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ask a merchant: pick a shop, a voucher, send', (tester) async {
    final fake = _Fake(plan: _plan(), merchants: _merchants);
    await _pump(tester, fake);
    await tester
        .ensureVisible(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.tap(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.pumpAndSettle();
    expect(find.byType(SponsorRequestScreen), findsOneWidget);
    expect(find.text('Aling Nena Cafe'), findsOneWidget);
    expect(find.text('Bare Shop'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sponsor_merchant_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sponsor_request_voucher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free halo-halo').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('sponsor_request_send')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The repeated v1 and the untitled v2 are one item each.
    expect(fake.sent?['voucher_id'], 'v1');
    expect(find.byType(SponsorRequestScreen), findsNothing);
  });

  testWidgets('a shop without vouchers or details can be asked',
      (tester) async {
    final fake = _Fake(plan: _plan(), merchants: _merchants);
    await _pump(tester, fake);
    await tester
        .ensureVisible(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.tap(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sponsor_merchant_m2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sponsor_request_send')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(fake.sent?['merchant_id'], 'm2');
  });

  testWidgets('an empty directory says so', (tester) async {
    final fake = _Fake(plan: _plan(), merchants: const []);
    await _pump(tester, fake);
    await tester
        .ensureVisible(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.tap(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No matching active merchants found.'), findsOneWidget);
  });

  testWidgets('a plan without an id explains instead of doing nothing',
      (tester) async {
    final fake = _Fake(plan: _plan(id: null), merchants: _merchants);
    await _pump(tester, fake);
    final button = find.byKey(const ValueKey('funding_ask_merchant'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(SponsorRequestScreen), findsNothing);
    expect(find.textContaining('still saving'), findsOneWidget);
  });

  testWidgets('a numeric plan id still opens the directory', (tester) async {
    final fake = _Fake(plan: _plan(id: 42), merchants: _merchants);
    await _pump(tester, fake);
    await tester
        .ensureVisible(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.tap(find.byKey(const ValueKey('funding_ask_merchant')));
    await tester.pumpAndSettle();
    expect(find.byType(SponsorRequestScreen), findsOneWidget);
  });
}
