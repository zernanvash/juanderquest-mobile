import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_analytics_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_counter_history_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_directory_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_page_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_staff_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_vouchers_screen.dart';
import 'package:juanderquest_app/features/merchant/widgets/merchant_counter.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';

class _Call {
  _Call(this.method, this.path, this.query, this.data);
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? data;
}

class _FakeAuth extends AuthNotifier {
  _FakeAuth(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'test-token');
  }

  @override
  Future<void> refreshProfile() async {}
}

final _ownerUser = UserModel(
  id: 'owner-1',
  seedId: 'owner-1',
  email: 'owner@shop.test',
  displayName: 'Owner',
  avatarUrl: '',
  role: 'user',
  demoPoints: 500,
);

ApiClient _mockClient(
  Object? Function(RequestOptions) responder,
  List<_Call> calls,
) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(_Call(
        options.method,
        options.path,
        Map<String, dynamic>.from(options.queryParameters),
        options.data,
      ));
      final reply = responder(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': reply},
      ));
    }),
  );
  return client;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child, {
  required Object? Function(RequestOptions) responder,
  required List<_Call> calls,
  UserModel? user,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final authUser = user ?? _ownerUser;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_mockClient(responder, calls)),
        authProvider.overrideWith((ref) => _FakeAuth(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              authUser,
            )),
        ...extraOverrides,
      ],
      child: MaterialApp(theme: AppTheme.pixel, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Plan 110b Merchant Vouchers CRUD', () {
    testWidgets('owner lists, creates, edits, and archives vouchers',
        (tester) async {
      final calls = <_Call>[];
      var vouchers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'title': 'Free Halo-Halo',
          'description': 'Show code at counter',
          'cost_points': 80,
          'availability': 'live',
          'is_active': true,
          'stock_limit': 10,
          'valid_days': 14,
          'icon_key': 'meal',
          'redeemed_count': 4,
          'used_count': 2,
        },
      ];
      await _pumpScreen(
        tester,
        const MerchantVouchersScreen(),
        calls: calls,
        responder: (req) {
          if (req.method == 'GET' && req.path == '/merchant/vouchers/manage') {
            return {
              'merchant_id': 'm1',
              'role': 'owner',
              'items': vouchers,
            };
          }
          if (req.method == 'POST' && req.path == '/merchant/vouchers') {
            final body = Map<String, dynamic>.from(req.data as Map);
            final created = {
              'id': 'v2',
              ...body,
              'availability': 'preview',
              'is_active': true,
              'redeemed_count': 0,
              'used_count': 0,
            };
            vouchers = [...vouchers, created];
            return created;
          }
          if (req.method == 'PATCH' && req.path == '/merchant/vouchers/v1') {
            final body = Map<String, dynamic>.from(req.data as Map);
            vouchers[0] = {...vouchers[0], ...body};
            return vouchers[0];
          }
          if (req.method == 'DELETE' && req.path == '/merchant/vouchers/v1') {
            vouchers[0] = {...vouchers[0], 'is_active': false};
            return {'id': 'v1', 'is_active': false};
          }
          return const {};
        },
      );

      expect(find.byKey(const ValueKey('merchant_managed_voucher_v1')),
          findsOneWidget);
      expect(find.text('4/10 claimed'), findsOneWidget);
      expect(find.text('Valid 14d'), findsOneWidget);

      // Create
      await tester.tap(find.byKey(const ValueKey('merchant_voucher_add')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_title')), 'Free Iced Coffee');
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_description')),
          'Redeemable after lunch');
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_cost')), '60');
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_stock')), '25');
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_valid_days')), '7');
      await tester.tap(find.byKey(const ValueKey('voucher_form_icon_coffee')));
      await tester.tap(find.byKey(const ValueKey('voucher_form_save')));
      await tester.pumpAndSettle();

      final createCall =
          calls.firstWhere((c) => c.method == 'POST' && c.path == '/merchant/vouchers');
      expect((createCall.data as Map)['title'], 'Free Iced Coffee');
      expect((createCall.data as Map)['cost_points'], 60);
      expect((createCall.data as Map)['stock_limit'], 25);
      expect((createCall.data as Map)['valid_days'], 7);
      expect((createCall.data as Map)['icon_key'], 'coffee');
      expect(find.byKey(const ValueKey('merchant_managed_voucher_v2')),
          findsOneWidget);

      // Edit
      await tester.tap(find.byKey(const ValueKey('merchant_voucher_edit_v1')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('voucher_form_cost')), '95');
      await tester.tap(find.byKey(const ValueKey('voucher_form_save')));
      await tester.pumpAndSettle();

      final patchCall = calls.firstWhere(
          (c) => c.method == 'PATCH' && c.path == '/merchant/vouchers/v1');
      expect((patchCall.data as Map)['cost_points'], 95);

      // Archive
      await tester.tap(find.byKey(const ValueKey('merchant_voucher_archive_v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voucher_archive_confirm')));
      await tester.pumpAndSettle();

      expect(
        calls.any((c) => c.method == 'DELETE' && c.path == '/merchant/vouchers/v1'),
        isTrue,
      );
      expect(find.text('ARCHIVED'), findsOneWidget);
    });

    testWidgets('staff view is read-only without add/edit/archive buttons',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const MerchantVouchersScreen(),
        calls: calls,
        responder: (req) => {
          'merchant_id': 'm1',
          'role': 'staff',
          'items': [
            {
              'id': 'v1',
              'title': 'Free Halo-Halo',
              'description': 'Show code',
              'cost_points': 80,
              'availability': 'live',
              'is_active': true,
              'redeemed_count': 1,
              'used_count': 0,
            },
          ],
        },
      );

      expect(find.byKey(const ValueKey('merchant_vouchers_staff_notice')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_voucher_add')), findsNothing);
      expect(
          find.byKey(const ValueKey('merchant_voucher_edit_v1')), findsNothing);
      expect(find.byKey(const ValueKey('merchant_voucher_archive_v1')),
          findsNothing);
    });
  });

  group('Plan 110b Merchant Staff Management', () {
    testWidgets('owner can add and revoke staff, cannot revoke owner',
        (tester) async {
      final calls = <_Call>[];
      var items = <Map<String, dynamic>>[
        {
          'id': 'mm-own',
          'user_id': 'owner-1',
          'display_name': 'Ate Nena',
          'email': 'owner@shop.test',
          'role': 'owner',
          'status': 'active',
        },
      ];
      await _pumpScreen(
        tester,
        const MerchantStaffScreen(),
        calls: calls,
        responder: (req) {
          if (req.method == 'GET' && req.path == '/merchant/staff') {
            return {'merchant_id': 'm1', 'items': items};
          }
          if (req.method == 'POST' && req.path == '/merchant/staff') {
            final created = {
              'id': 'mm-2',
              'user_id': 'staff-2',
              'display_name': 'Kuya Ben',
              'email': 'ben@shop.test',
              'role': 'staff',
              'status': 'active',
            };
            items = [...items, created];
            return created;
          }
          if (req.method == 'DELETE' && req.path == '/merchant/staff/staff-2') {
            items = items
                .map((m) => m['user_id'] == 'staff-2'
                    ? {...m, 'status': 'revoked'}
                    : m)
                .toList();
            return {'id': 'mm-2', 'user_id': 'staff-2', 'status': 'revoked'};
          }
          return const {};
        },
      );

      expect(find.byKey(const ValueKey('merchant_staff_owner-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_staff_revoke_owner-1')),
          findsNothing);

      await tester.enterText(
          find.byKey(const ValueKey('merchant_staff_email')), 'ben@shop.test');
      await tester.tap(find.byKey(const ValueKey('merchant_staff_add')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('merchant_staff_staff-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('merchant_staff_revoke_staff-2')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('merchant_staff_revoke_confirm')));
      await tester.pumpAndSettle();

      expect(
        calls.any((c) => c.method == 'DELETE' && c.path == '/merchant/staff/staff-2'),
        isTrue,
      );
      expect(find.text('REVOKED'), findsOneWidget);
    });
  });

  group('Plan 110b Counter History & Analytics', () {
    testWidgets('counter history displays events and filters by kind',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const MerchantCounterHistoryScreen(),
        calls: calls,
        responder: (req) => {
          'merchant_id': 'm1',
          'items': [
            {
              'kind': 'voucher',
              'customer': 'Suki #A1',
              'code': 'JDQ-AAA111-BBB222',
              'method': 'purchase',
              'detail': 'Free Halo-Halo',
              'staff_name': 'Kuya Ben',
              'at': '2026-11-19T02:00:00Z',
            },
            {
              'kind': 'visit',
              'customer': 'Suki #B2',
              'code': null,
              'method': 'standee',
              'detail': 'Bangus Loyalty',
              'staff_name': null,
              'at': '2026-11-19T01:00:00Z',
            },
          ],
        },
      );

      expect(find.byKey(const ValueKey('counter_history_item_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('counter_history_item_1')), findsOneWidget);
      expect(find.text('JDQ-AAA111-BBB222'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('counter_history_filter_visit')));
      await tester.pumpAndSettle();
      expect(find.text('Bangus Loyalty'), findsOneWidget);
      expect(find.text('Free Halo-Halo'), findsNothing);
    });

    testWidgets('analytics renders 3 KPI panels and switches day window',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const MerchantAnalyticsScreen(),
        calls: calls,
        responder: (req) {
          final days = int.tryParse('${req.queryParameters['days'] ?? 30}') ?? 30;
          return {
            'merchant_id': 'm1',
            'days': days,
            'funding': {
              'active_sponsorships': 2,
              'total_points_committed': 500,
              'total_points_paid': 200,
              'funded_completions': 4,
            },
            'vouchers': {
              'active_catalog_count': 3,
              'shop_redeemed_in_window': days == 7 ? 5 : 19,
              'perks_granted_in_window': 6,
              'confirmed_at_counter_in_window': 11,
            },
            'suki': {
              'visits_in_window': 42,
              'unique_customers': 28,
              'repeat_customers': 9,
              'rewards_issued': 7,
              'rewards_claimed': 4,
            },
          };
        },
      );

      expect(find.byKey(const ValueKey('analytics_funding_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('analytics_vouchers_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('analytics_suki_panel')), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('analytics_days_7')));
      await tester.pumpAndSettle();

      expect(
        calls.any((c) => c.path == '/merchant/analytics' && c.query['days'] == 7),
        isTrue,
      );
      expect(find.text('5'), findsOneWidget);
    });
  });

  group('Plan 110b Public Directory, Shop Stock & Hub Tools', () {
    testWidgets('directory searches, filters, paginates, and opens merchant page',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const MerchantDirectoryScreen(),
        calls: calls,
        extraOverrides: [
          merchantDirectoryLocationProvider.overrideWithValue(
            () async => (lat: 16.0433, lng: 120.3333),
          ),
        ],
        responder: (req) {
          if (req.path == '/merchants') {
            final page = int.tryParse('${req.queryParameters['page'] ?? 1}') ?? 1;
            if (page == 2) {
              return {
                'items': [
                  {
                    'id': 'm2',
                    'name': 'San Fabian Crafts',
                    'category': 'crafts',
                    'municipality': 'San Fabian',
                    'description': 'Handwoven gifts',
                    'active_voucher_count': 1,
                    'has_active_suki': false,
                  },
                ],
                'page': 2,
                'limit': 20,
                'total': 25,
              };
            }
            return {
              'items': [
                {
                  'id': 'm1',
                  'name': 'Aling Nena Cafe',
                  'category': 'cafe',
                  'municipality': 'Dagupan City',
                  'description': 'Iced coffee and suman',
                  'distance_m': 450,
                  'active_voucher_count': 3,
                  'has_active_suki': true,
                },
              ],
              'page': 1,
              'limit': 20,
              'total': 25,
            };
          }
          if (req.path == '/merchants/m1') {
            return {
              'merchant': {
                'id': 'm1',
                'name': 'Aling Nena Cafe',
                'description': 'Iced coffee and suman',
                'is_published': true,
              },
              'specialties': [],
              'products': [],
              'vouchers': [],
              'suki': {'enabled': false},
              'viewer': {'is_member': false},
            };
          }
          return const {};
        },
      );

      expect(find.byKey(const ValueKey('directory_merchant_m1')), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('3 offers'), findsOneWidget);
      expect(find.text('Suki Card'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('directory_cat_cafe')));
      await tester.pumpAndSettle();
      expect(
        calls.any((c) => c.path == '/merchants' && c.query['category'] == 'cafe'),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('directory_near_me')));
      await tester.pumpAndSettle();
      expect(
        calls.any((c) => c.path == '/merchants' && c.query['lat'] == 16.0433),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('directory_load_more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('directory_merchant_m2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('directory_merchant_m1')));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantPageScreen), findsOneWidget);
    });

    test('VoucherModel parses stock_limit, valid_days, redeemed_count, remaining_stock',
        () {
      final limited = VoucherModel.fromJson({
        'id': 'v1',
        'title': 'Latte',
        'cost_points': 50,
        'stock_limit': 10,
        'valid_days': 14,
        'redeemed_count': 7,
        'remaining_stock': 3,
      });
      expect(limited.stockLimit, 10);
      expect(limited.validDays, 14);
      expect(limited.redeemedCount, 7);
      expect(limited.remainingStock, 3);
      expect(limited.isOutOfStock, isFalse);

      final empty = VoucherModel.fromJson({
        'id': 'v2',
        'title': 'Sold Out',
        'cost_points': 50,
        'stock_limit': 5,
        'remaining_stock': 0,
      });
      expect(empty.isOutOfStock, isTrue);
    });

    testWidgets('ShopScreen shows Partner Shops card and voucher stock/expiry chips',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const ShopScreen(),
        calls: calls,
        responder: (req) {
          if (req.path == '/vouchers') {
            return [
              {
                'id': 'v1',
                'merchant_id': 'm1',
                'merchant_name': 'Aling Nena Cafe',
                'title': 'Limited Coffee',
                'cost_points': 50,
                'availability': 'live',
                'redeemable': true,
                'stock_limit': 10,
                'valid_days': 14,
                'redeemed_count': 7,
                'remaining_stock': 3,
              },
              {
                'id': 'v2',
                'merchant_id': 'm1',
                'merchant_name': 'Aling Nena Cafe',
                'title': 'Sold Out Muffin',
                'cost_points': 40,
                'availability': 'live',
                'redeemable': true,
                'stock_limit': 5,
                'remaining_stock': 0,
              },
            ];
          }
          if (req.path == '/cosmetics/catalog') {
            return {'items': [], 'teasers': []};
          }
          return const {};
        },
      );

      expect(find.byKey(const ValueKey('shop_browse_partners_button')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
      await tester.pumpAndSettle();

      expect(find.text('3 left'), findsOneWidget);
      expect(find.text('Valid 14d'), findsOneWidget);
      expect(find.text('Out of stock'), findsNWidgets(2));
    });

    testWidgets('MerchantDashboardScreen and MerchantCounterPanel expose 110b tools',
        (tester) async {
      final calls = <_Call>[];
      await _pumpScreen(
        tester,
        const MerchantDashboardScreen(),
        calls: calls,
        responder: (req) {
          if (req.path == '/merchant/dashboard') {
            return {
              'merchant': {
                'id': 'm1',
                'name': 'Aling Nena Cafe',
                'category': 'cafe',
                'municipality': 'Dagupan City',
                'is_published': true,
              },
              'counts': {'active_products': 2},
              'checklist': {'items': []},
              'truthful_notice': {'statement': ''},
            };
          }
          return const {};
        },
      );

      expect(find.byKey(const ValueKey('merchant_counter_history_btn')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_open_vouchers')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_open_staff')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_open_analytics')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_open_counter_history')),
          findsOneWidget);
      expect(find.byType(MerchantCounterPanel), findsOneWidget);
    });
  });
}
