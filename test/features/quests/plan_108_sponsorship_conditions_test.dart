import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/theater/theater_title_block.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state =
        user == null ? AuthState() : AuthState(user: user, token: 'test-token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _QuestFixture extends QuestNotifier {
  _QuestFixture(super.apiClient, QuestState initial) {
    state = initial;
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

final _creator = UserModel(
  id: 'creator-1',
  seedId: 'creator-1',
  displayName: 'Creator',
  email: 'creator@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 500,
);

const _baseSpotMap = <String, dynamic>{
  'id': 'spot-1',
  'slug': 'cape-bolinao',
  'name': 'Cape Bolinao Lighthouse',
  'description': 'Historic coastal lighthouse in Pangasinan.',
  'category': 'Heritage',
  'subcategory': 'Landmark',
  'municipality': 'Bolinao',
  'address': 'Patar, Bolinao',
  'source_name': 'LGU Bolinao',
  'trust_level': 'lgu_verified',
  'gps_lat': 16.3069,
  'gps_lng': 119.7867,
  'tags': <String>[],
  'recommendation_reasons': <String>[],
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 108 unit & widget tests', () {
    test('SpotModel.fromJson parses sponsors and defaults to empty list', () {
      final withoutSponsors = SpotModel.fromJson(_baseSpotMap);
      expect(withoutSponsors.sponsors, isEmpty);

      final withSponsors = SpotModel.fromJson({
        ..._baseSpotMap,
        'sponsors': [
          {
            'name': 'Bolinao Cafe',
            'logo': 'https://example.test/logo.png',
            'quest_id': 'q-99',
          },
          {'name': '   ', 'logo': null, 'quest_id': 'q-bad'},
        ],
      });
      expect(withSponsors.sponsors, hasLength(1));
      expect(withSponsors.sponsors.first.name, 'Bolinao Cafe');
      expect(withSponsors.sponsors.first.logo, 'https://example.test/logo.png');
      expect(withSponsors.sponsors.first.questId, 'q-99');
    });

    testWidgets(
        'Ask a merchant: search, pick, send request, and see it in round list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ApiClient(enableRetries: false);
      final requests = <Map<String, dynamic>>[];
      Map<String, dynamic>? sentBody;
      Map<String, dynamic>? sentHeaders;

      client.dio.interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) {
          if (options.path == '/quests/quest-1/funding-plan' &&
              options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'plan': {
                    'id': 'plan-1',
                    'status': 'pending_sponsors',
                    'mode': 'budget',
                    'reward_points': 50,
                    'target_points': 530,
                    'ends_at': DateTime.now()
                        .add(const Duration(days: 14))
                        .toIso8601String(),
                    'contributions': [],
                    'sponsorships': List<Map<String, dynamic>>.from(requests),
                  },
                },
              },
            ));
          }
          if (options.path == '/sponsor-directory' && options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    {
                      'id': 'm-dagupan',
                      'name': 'Dagupan Bangus Roasters',
                      'municipality': 'Dagupan',
                      'category': 'dining',
                      'description': 'Fresh coffee and local treats',
                      'same_municipality': true,
                      'vouchers': [
                        {
                          'id': 'v-1',
                          'title': 'Free iced coffee',
                          'description': ''
                        },
                      ],
                    },
                    {
                      'id': 'm-bolinao',
                      'name': 'Patar Cove Bakery',
                      'municipality': 'Bolinao',
                      'category': 'bakery',
                      'description': 'Morning pastries',
                      'same_municipality': false,
                      'vouchers': [],
                    },
                  ],
                  'page': 1,
                },
              },
            ));
          }
          if (options.path == '/funding-plans/plan-1/sponsorships' &&
              options.method == 'POST') {
            sentBody = Map<String, dynamic>.from(options.data as Map);
            sentHeaders = Map<String, dynamic>.from(options.headers);
            requests.add({
              'id': 'sp-1',
              'merchant_id': 'm-dagupan',
              'merchant_name': 'Dagupan Bangus Roasters',
              'status': 'requested',
              'points': sentBody!['points'],
              'voucher_qty': sentBody!['voucher_qty'],
              'promo': sentBody!['promo'],
              'terms_version': 1,
              'conditions': [],
            });
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': requests.first},
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': {}},
          ));
        }),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: QuestFundingScreen(questId: 'quest-1'),
        ),
      ));
      await _settle(tester);

      expect(find.textContaining('web merchant workspace'), findsNothing);
      final askBtn = find.byKey(const ValueKey('funding_ask_merchant'));
      expect(askBtn, findsOneWidget);
      await tester.ensureVisible(askBtn);
      await tester.tap(askBtn);
      await _settle(tester);

      // Search with FuzzySearch (typo tolerant: "Dagpan" -> "Dagupan Bangus Roasters")
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('sponsor_search_field')),
          matching: find.byType(TextField),
        ),
        'Dagpan',
      );
      await _settle(tester);
      expect(find.text('Dagupan Bangus Roasters'), findsOneWidget);
      expect(find.text('Patar Cove Bakery'), findsNothing);

      // Pick the merchant and submit request
      await tester
          .tap(find.byKey(const ValueKey('sponsor_merchant_m-dagupan')));
      await _settle(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('sponsor_request_message')),
          matching: find.byType(TextField),
        ),
        'Join our eco walk!',
      );
      await tester.tap(find.byKey(const ValueKey('sponsor_request_send')));
      await _settle(tester);

      expect(sentBody?['merchant_id'], 'm-dagupan');
      expect(sentBody?['message'], 'Join our eco walk!');
      expect(sentHeaders?['x-idempotency-key'], isNotEmpty);
      expect(
          find.text('Request sent to Dagupan Bangus Roasters'), findsOneWidget);
      expect(find.byKey(const ValueKey('funding_sponsorship_sp-1')),
          findsOneWidget);
      expect(find.text('Dagupan Bangus Roasters'), findsOneWidget);
    });

    testWidgets(
        'Creator sees countered terms with conditions and can ACCEPT COUNTER',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ApiClient(enableRetries: false);
      var accepted = false;
      client.dio.interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) {
          if (options.path == '/quests/quest-1/funding-plan' &&
              options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'plan': {
                    'id': 'plan-1',
                    'status': 'pending_sponsors',
                    'mode': 'budget',
                    'reward_points': 50,
                    'target_points': 530,
                    'ends_at': DateTime.now()
                        .add(const Duration(days: 14))
                        .toIso8601String(),
                    'contributions': [],
                    'sponsorships': [
                      {
                        'id': 'sp-c1',
                        'merchant_id': 'm-1',
                        'merchant_name': 'Dagupan Coffee',
                        'status': accepted ? 'accepted' : 'countered',
                        'points': 100,
                        'voucher_qty': 0,
                        'counter_points': 150,
                        'counter_voucher_qty': 1,
                        'counter_message': 'Adjusted to 150',
                        'terms_version': 2,
                        'conditions': [
                          {
                            'type': 'same_town',
                            'met': true,
                            'detail': 'Quest and shop are both in Dagupan',
                          },
                          {
                            'type': 'min_players',
                            'value': 5,
                            'met': true,
                            'detail': '6 of 5 players',
                          },
                        ],
                      },
                    ],
                  },
                },
              },
            ));
          }
          if (options.path == '/sponsorships/sp-c1/accept-counter' &&
              options.method == 'POST') {
            accepted = true;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'status': 'accepted'}
              },
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': {}},
          ));
        }),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: QuestFundingScreen(questId: 'quest-1'),
        ),
      ));
      await _settle(tester);

      expect(find.textContaining('Counter terms: 150 pts'), findsOneWidget);
      expect(find.text('Quest and shop are both in Dagupan'), findsOneWidget);
      final acceptCounterBtn =
          find.byKey(const ValueKey('creator_accept_counter_sp-c1'));
      await tester.ensureVisible(acceptCounterBtn);
      await tester.tap(acceptCounterBtn);
      await _settle(tester);

      expect(accepted, isTrue);
      expect(find.text('ACCEPTED'), findsOneWidget);
    });

    testWidgets(
        'Merchant SET CONDITIONS sends PUT body; unmet ACCEPT shows warning dialog (CANCEL vs ACCEPT ANYWAY)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ApiClient(enableRetries: false);
      final calls = <(String, String, Object?)>[];
      var currentConditions = <Map<String, dynamic>>[
        {
          'type': 'same_town',
          'met': false,
          'detail': 'Quest is in Dagupan; shop is in Calasiao',
        },
      ];

      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(onRequest: (options, handler) {
          calls.add((options.method, options.path, options.data));
          if (options.path == '/merchant/dashboard') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'merchant': {
                    'name': 'Calasiao Cafe',
                    'category': 'dining',
                    'municipality': 'Calasiao',
                    'is_published': true,
                  },
                  'counts': {'active_products': 0},
                  'checklist': {'items': []},
                  'truthful_notice': {'statement': 'Showcase.'},
                },
              },
            ));
          }
          if (options.path == '/merchant/points') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'balance_points': 1000, 'history': []}
              },
            ));
          }
          if (options.path == '/merchant/sponsorships') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    {
                      'id': 's-cond-1',
                      'status': 'requested',
                      'quest_title': 'Dagupan Heritage Walk',
                      'spot_name': 'Dagupan Plaza',
                      'points': 200,
                      'voucher_qty': 0,
                      'promo': false,
                      'terms_version': 1,
                      'plan_id': 'p-1',
                      'plan_status': 'pending_sponsors',
                      'conditions': currentConditions,
                    },
                  ],
                },
              },
            ));
          }
          if (options.path == '/sponsorships/s-cond-1/conditions' &&
              options.method == 'PUT') {
            currentConditions = [
              for (final c in (options.data as Map)['conditions'] as List)
                {
                  ...Map<String, dynamic>.from(c as Map),
                  'met': false,
                  'detail': 'Checked on server',
                },
            ];
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'conditions': currentConditions}
              },
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': {}},
          ));
        }),
      );

      final router = GoRouter(initialLocation: '/merchant', routes: [
        GoRoute(
          path: '/merchant',
          builder: (_, __) => const MerchantDashboardScreen(),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith(
            (ref) => _Auth(
                client, ref.watch(authRefreshProvider.notifier), _creator),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('merchant_tab_sponsorships')));
      await _settle(tester);

      expect(find.text('DEAL CONDITIONS'), findsOneWidget);
      expect(find.text('Quest is in Dagupan; shop is in Calasiao'),
          findsOneWidget);

      // SET CONDITIONS: select min_players as well and save
      await tester
          .tap(find.byKey(const ValueKey('merchant_set_conditions_s-cond-1')));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('cond_min_players')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('cond_sheet_save')));
      await _settle(tester);

      final putCall = calls.singleWhere(
        (c) => c.$1 == 'PUT' && c.$2 == '/sponsorships/s-cond-1/conditions',
      );
      expect((putCall.$3 as Map)['conditions'], [
        {'type': 'same_town'},
        {'type': 'min_players', 'value': 5},
      ]);

      // ACCEPT with unmet conditions -> warning dialog -> CANCEL sends nothing
      await tester.tap(find.byKey(const ValueKey('merchant_accept_s-cond-1')));
      await _settle(tester);
      expect(find.text('Deal requirements not met yet'), findsOneWidget);
      expect(
        find.text(
          'You can still accept. The quest will show your shop as a sponsor now.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('merchant_override_cancel')));
      await _settle(tester);
      expect(
        calls.where((c) => c.$2 == '/sponsorships/s-cond-1/accept'),
        isEmpty,
      );

      // ACCEPT -> ACCEPT ANYWAY sends acknowledge_unmet: true
      await tester.tap(find.byKey(const ValueKey('merchant_accept_s-cond-1')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('merchant_override_confirm')));
      await _settle(tester);

      final acceptCall = calls.singleWhere(
        (c) => c.$1 == 'POST' && c.$2 == '/sponsorships/s-cond-1/accept',
      );
      expect((acceptCall.$3 as Map)['acknowledge_unmet'], isTrue);
    });

    testWidgets('QuestDetailScreen shows Sponsored by for 1, 2, and 4 sponsors',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> pumpWithSponsors(List<Map<String, dynamic>> sponsors) async {
        final quest = QuestModel(
          id: 'q-s',
          title: 'Coastal Heritage',
          description: 'Visit the cove.',
          category: 'eco',
          locationName: 'Bolinao',
          gpsLat: 16.3,
          gpsLng: 119.78,
          radiusMeters: 100,
          rewardPoints: 50,
          markerImageUrl: '',
          funding: QuestFundingSummary(
            status: 'active',
            mode: 'budget',
            rewardPoints: 50,
            completionsLeftEstimate: 5,
            sponsors: sponsors,
          ),
        );
        final client = ApiClient(enableRetries: false);
        client.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'quest': quest.toJson()}
            },
          )),
        ));
        final router = GoRouter(initialLocation: '/quests/q-s', routes: [
          GoRoute(
            path: '/quests/:id',
            builder: (_, state) => QuestDetailScreen(
              questId: state.pathParameters['id'] ?? '',
              quest: quest,
            ),
          ),
        ]);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            authProvider.overrideWith(
              (ref) => _Auth(
                  client, ref.watch(authRefreshProvider.notifier), _creator),
            ),
            questProvider.overrideWith(
              (ref) => _QuestFixture(
                client,
                QuestState(quests: [quest]),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ));
        await _settle(tester);
      }

      await pumpWithSponsors([
        {'name': 'Cafe A'}
      ]);
      expect(find.byKey(const Key('quest_sponsored_by')), findsOneWidget);
      expect(find.text('Sponsored by Cafe A'), findsOneWidget);

      await pumpWithSponsors([
        {'name': 'Cafe A'},
        {'name': 'Cafe B'}
      ]);
      expect(find.text('Sponsored by Cafe A and Cafe B'), findsOneWidget);

      await pumpWithSponsors([
        {'name': 'Cafe A'},
        {'name': 'Cafe B'},
        {'name': 'Cafe C'},
        {'name': 'Cafe D'},
      ]);
      expect(find.text('Sponsored by Cafe A, Cafe B +2'), findsOneWidget);
    });

    testWidgets(
        'Destination TheaterFirstViewport shows spot_sponsored_by and tapping opens the quest',
        (tester) async {
      final spot = SpotModel.fromJson({
        ..._baseSpotMap,
        'sponsors': [
          {'name': 'Lighthouse Coffee', 'logo': null, 'quest_id': 'q-777'},
        ],
      });
      String? pushedRoute;
      final router = GoRouter(initialLocation: '/spot', routes: [
        GoRoute(
          path: '/spot',
          builder: (_, __) => Theme(
            data: AppTheme.pixel,
            child: Scaffold(
              body: TheaterFirstViewport(
                spot: spot,
                scrollOffset: 0,
                hasPhoto: false,
                onDirections: () {},
                onPlayQuest: () {},
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/quests/:id',
          builder: (_, state) {
            pushedRoute = '/quests/${state.pathParameters['id']}';
            return Scaffold(body: Text('Quest ${state.pathParameters['id']}'));
          },
        ),
      ]);

      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ));
      await _settle(tester);

      final sponsoredRow = find.byKey(const Key('spot_sponsored_by'));
      expect(sponsoredRow, findsOneWidget);
      expect(find.text('Sponsored by Lighthouse Coffee'), findsOneWidget);
      await tester.ensureVisible(sponsoredRow);
      await tester.tap(sponsoredRow);
      await _settle(tester);

      expect(pushedRoute, '/quests/q-777');
    });
  });
}
