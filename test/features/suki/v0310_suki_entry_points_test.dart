import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/suki/models/suki_models.dart';
import 'package:juanderquest_app/features/suki/providers/suki_provider.dart';
import 'package:juanderquest_app/features/suki/screens/suki_card_screen.dart';
import 'package:juanderquest_app/features/suki/screens/suki_cards_screen.dart';

/// v0.3.10 team review: "clicking suki card crashes the app". Opens the Suki
/// pages the way the app does (a shell with Home and Shop branches; Suki
/// routes live in the Home branch) with every server answer the team can hit.

DioException _err(int status, String code) {
  final o = RequestOptions(path: '/suki/programs/x');
  return DioException(
    requestOptions: o,
    response: Response(requestOptions: o, statusCode: status, data: {
      'success': false,
      'error': {'code': code, 'message': 'server text'},
    }),
  );
}

Map<String, dynamic> _program({String mode = 'standee'}) => {
      'id': 'suki_1',
      'title': 'Kape Suki',
      'reward_kind': 'free_item',
      'reward_value': null,
      'reward_text': 'Free iced coffee',
      'visits_required': '10',
      'mode': mode,
      'status': 'active',
      'merchant': {'id': 'm1', 'name': 'Aling Nena Cafe', 'municipality': null},
    };

class _Api extends SukiApi {
  _Api(this.answer) : super(ApiClient(enableRetries: false));

  final Object answer;

  @override
  Future<List<SukiCard>> myCards() async => const [];

  @override
  Future<List<SukiProgram>> nearby({double? lat, double? lng}) async {
    if (answer is Exception) throw answer;
    return const [];
  }

  @override
  Future<SukiProgramDetail> program(String id) async {
    if (answer is Exception) throw answer;
    return SukiProgramDetail.fromJson(answer as Map<String, dynamic>);
  }
}

GoRouter _router(String start) => GoRouter(
      initialLocation: start,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/dashboard', builder: (_, __) => const Text('home')),
              GoRoute(
                path: '/suki',
                builder: (_, __) => const SukiCardsScreen(),
                routes: [
                  GoRoute(
                    path: ':programId',
                    builder: (_, s) => SukiCardScreen(
                        programId: s.pathParameters['programId']!),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/shop',
                builder: (context, _) => Column(children: [
                  TextButton(
                    key: const ValueKey('open_card'),
                    onPressed: () => context.push('/suki/suki_1'),
                    child: const Text('card'),
                  ),
                  TextButton(
                    key: const ValueKey('open_all'),
                    onPressed: () => context.push('/suki'),
                    child: const Text('all'),
                  ),
                ]),
              ),
            ]),
          ],
        ),
      ],
    );

late GoRouter _r;

Future<void> _pump(WidgetTester tester, Object answer, String start) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sukiApiProvider.overrideWithValue(_Api(answer)),
      sukiQuickFixProvider
          .overrideWithValue(() async => (lat: null, lng: null)),
    ],
    child: MaterialApp.router(
        theme: AppTheme.pixel, routerConfig: _r = _router(start)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final answers = <String, Object>{
    'Suki off (503 SUKI_DISABLED)': _err(503, 'SUKI_DISABLED'),
    'unknown program (404)': _err(404, 'SUKI_NOT_FOUND'),
    'network error': DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError),
    'own shop program, no card': {'program': _program()},
    'expired and claimed rewards': {
      'program': _program(mode: 'staff_scan'),
      'my_card': {
        'card_id': 'c',
        'cycle': '2',
        'visits': '12',
        'required': '10'
      },
      'rewards': [
        {'id': 'r1', 'code': '', 'status': 'issued', 'expired': true},
        {'id': 'r2', 'code': 'SUKI-A-B', 'status': 'claimed'},
      ],
    },
    'empty body': <String, dynamic>{},
  };

  for (final entry in answers.entries) {
    testWidgets('Shop -> Suki card: ${entry.key} does not throw',
        (tester) async {
      await _pump(tester, entry.value, '/shop');
      await tester.tap(find.byKey(const ValueKey('open_card')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SukiCardScreen), findsOneWidget);
      // Back to Shop.
      _r.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('open_card')), findsOneWidget);
    });

    testWidgets('push /suki/<id> deep link: ${entry.key} does not throw',
        (tester) async {
      await _pump(tester, entry.value, '/suki/suki_1');
      expect(tester.takeException(), isNull);
      expect(find.byType(SukiCardScreen), findsOneWidget);
    });
  }

  testWidgets('Shop -> All cards with Suki off says coming soon',
      (tester) async {
    await _pump(tester, _err(503, 'SUKI_DISABLED'), '/shop');
    await tester.tap(find.byKey(const ValueKey('open_all')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('suki_coming_soon')), findsOneWidget);
  });
}
