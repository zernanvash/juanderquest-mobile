import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/models/merchant_page.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_page_screen.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_loyalty_tab.dart';
import 'package:juanderquest_app/features/merchant/widgets/merchant_counter.dart';

/// v0.3.10 team review, Shop track: voucher counter with Suki off,
/// specialty pins, cover photo upload, the public merchant page.

class _Call {
  _Call(this.method, this.path, this.data);
  final String method;
  final String path;
  final Object? data;
}

class _Fail {
  const _Fail(this.status, this.code);
  final int status;
  final String code;
}

ApiClient _api(Map<String, Object?> routes, List<_Call> calls) {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(_Call(options.method, options.path, options.data));
      var reply = routes['${options.method} ${options.path}'];
      if (reply is Function) reply = reply(options.data);
      if (reply is _Fail) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: reply.status,
            data: {
              'success': false,
              'error': {'code': reply.code, 'message': 'server ${reply.code}'},
            },
          ),
          type: DioExceptionType.badResponse,
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': reply},
      ));
    }),
  );
  return api;
}

final _dashboard = {
  'merchant': {
    'id': 'm1',
    'name': 'Aling Nena Cafe',
    'category': 'cafe',
    'municipality': 'Dagupan City',
    'is_published': true,
  },
  'counts': {'active_products': '2'},
  'checklist': {'items': []},
  'truthful_notice': {'statement': ''},
};

Map<String, Object?> _hubRoutes({List<Map<String, dynamic>>? products}) => {
      'GET /merchant/dashboard': _dashboard,
      'GET /merchant/suki': const _Fail(503, 'SUKI_DISABLED'),
      'GET /merchant/profile': {
        'name': 'Aling Nena Cafe',
        'banner_url': null,
        'logo_url': '',
      },
      'GET /merchant/products': products ??
          [
            {
              'id': 'p1',
              'name': 'Bangus sisig',
              'price': '150.00',
              'specialty_at': null,
            },
            {
              'id': 'p2',
              'name': 'Halo-halo',
              'price': 90,
              'specialty_at': '2026-11-19T00:00:00Z',
            },
          ],
    };

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Map<String, Object?> routes,
  List<_Call> calls, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_api(routes, calls)),
      ...overrides,
    ],
    child: MaterialApp(theme: AppTheme.pixel, home: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('voucher counter (Suki Cards off)', () {
    testWidgets('the hub shows the counter even when Loyalty says coming soon',
        (tester) async {
      final calls = <_Call>[];
      await _pump(tester, const MerchantDashboardScreen(initialTab: 'loyalty'),
          _hubRoutes(), calls);
      expect(find.byKey(const ValueKey('loyalty_disabled')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchant_counter_panel')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchant_counter_scan')), findsOneWidget);
    });

    testWidgets('scanning a voucher QR confirms it', (tester) async {
      final calls = <_Call>[];
      await _pump(
        tester,
        const MerchantDashboardScreen(),
        {
          ..._hubRoutes(),
          'POST /merchant/suki/scan': {
            'kind': 'voucher',
            'customer': 'Suki #C9D',
            'title': 'Voucher confirmed',
            'detail': 'Free halo-halo',
          },
        },
        calls,
        overrides: [
          merchantSukiScannerProvider
              .overrideWithValue((_) async => 'JDQ-AAA111-BBB222'),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('merchant_counter_scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('loyalty_scan_result_voucher')),
          findsOneWidget);
      expect(find.text('Free halo-halo'), findsOneWidget);
      expect(calls.where((c) => c.path == '/merchant/suki/scan').single.data,
          {'code': 'JDQ-AAA111-BBB222'});
      await tester.tap(find.byKey(const ValueKey('loyalty_scan_done')));
      await tester.pumpAndSettle();
    });

    testWidgets('typing a code works, bad text is caught before sending',
        (tester) async {
      final calls = <_Call>[];
      await _pump(
        tester,
        const MerchantDashboardScreen(),
        {
          ..._hubRoutes(),
          'POST /merchant/suki/scan': const _Fail(409, 'CODE_ALREADY_USED'),
        },
        calls,
      );
      await tester.tap(find.byKey(const ValueKey('merchant_counter_enter')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('merchant_counter_code')), 'hello');
      await tester
          .tap(find.byKey(const ValueKey('merchant_counter_code_confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('merchant_counter_code_error')),
          findsOneWidget);
      expect(calls.where((c) => c.path == '/merchant/suki/scan'), isEmpty);
      await tester.enterText(
          find.byKey(const ValueKey('merchant_counter_code')),
          ' jdq-aaa111-bbb222 ');
      await tester
          .tap(find.byKey(const ValueKey('merchant_counter_code_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('This voucher was already used.'), findsOneWidget);
      expect(calls.where((c) => c.path == '/merchant/suki/scan').single.data,
          {'code': 'JDQ-AAA111-BBB222'});
      await tester.tap(find.byKey(const ValueKey('loyalty_scan_stop')));
      await tester.pumpAndSettle();
    });

    test('promptCounterCode is exported for the Loyalty tab', () {
      expect(promptCounterCode, isNotNull);
    });
  });

  group('specialty pins', () {
    testWidgets('pinned items show first with a badge; pin sends pinned:true',
        (tester) async {
      final calls = <_Call>[];
      await _pump(
        tester,
        const MerchantDashboardScreen(initialTab: 'catalog'),
        {
          ..._hubRoutes(),
          'PUT /merchant/products/p1/specialty': {'id': 'p1'},
        },
        calls,
      );
      expect(
          find.byKey(const ValueKey('merchant_specialty_p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_specialty_p1')), findsNothing);
      final p2 =
          tester.getTopLeft(find.byKey(const ValueKey('merchant_product_p2')));
      final p1 =
          tester.getTopLeft(find.byKey(const ValueKey('merchant_product_p1')));
      expect(p2.dy, lessThan(p1.dy));
      await tester.tap(find.byKey(const ValueKey('merchant_pin_p1')));
      await tester.pumpAndSettle();
      expect(
          calls
              .where((c) => c.path == '/merchant/products/p1/specialty')
              .single
              .data,
          {'pinned': true});
    });

    testWidgets('the 4th pin shows the server limit message', (tester) async {
      final calls = <_Call>[];
      await _pump(
        tester,
        const MerchantDashboardScreen(initialTab: 'catalog'),
        {
          ..._hubRoutes(),
          'PUT /merchant/products/p1/specialty':
              const _Fail(409, 'SPECIALTY_LIMIT'),
        },
        calls,
      );
      await tester.tap(find.byKey(const ValueKey('merchant_pin_p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('SPECIALTY_LIMIT'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  testWidgets('Upload cover photo uploads then saves banner_url',
      (tester) async {
    final calls = <_Call>[];
    await _pump(
      tester,
      const MerchantDashboardScreen(initialTab: 'profile'),
      {
        ..._hubRoutes(),
        'POST /spot-media': {
          'asset_id': 'a1',
          'url': '/api/v1/uploads/spot-photos/spot_photo_1.jpg',
        },
        'PATCH /merchant/profile': {'id': 'm1'},
      },
      calls,
      overrides: [
        merchantPhotoPickerProvider.overrideWithValue(
            () async => (bytes: [1, 2, 3], name: 'cover.jpg')),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('merchant_upload_cover')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls.map((c) => '${c.method} ${c.path}'),
        containsAllInOrder(['POST /spot-media', 'PATCH /merchant/profile']));
    expect(calls.firstWhere((c) => c.method == 'PATCH').data,
        {'banner_url': '/api/v1/uploads/spot-photos/spot_photo_1.jpg'});
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  group('public merchant page', () {
    Map<String, dynamic> page({
      bool suki = false,
      Map<String, dynamic>? card,
      bool member = false,
    }) =>
        {
          'merchant': {
            'id': 'm1',
            'name': 'Aling Nena Cafe',
            'category': 'cafe',
            'municipality': 'Dagupan City',
            'description': 'Bangus and halo-halo by the river.',
            'logo_url': null,
            'banner_url': null,
            'contact_phone': '0917 000 0000',
            'contact_email': null,
            'gps_lat': '16.043',
            'gps_lng': 120.333,
            'is_published': true,
          },
          'specialties': [
            {
              'id': 'p2',
              'name': 'Halo-halo',
              'price': '90.00',
              'is_specialty': true
            },
          ],
          'products': [
            {
              'id': 'p1',
              'name': 'Bangus sisig',
              'price': null,
              'is_specialty': false
            },
          ],
          'vouchers': [
            {'id': 'v1', 'title': 'Free halo-halo', 'cost_points': '10'},
          ],
          'suki': {
            'enabled': suki,
            'program': suki
                ? {
                    'id': 'suki_1',
                    'title': 'Kape Suki',
                    'reward_text': 'Free iced coffee',
                    'reward_tag': 'FREE',
                    'visits_required': 10,
                  }
                : null,
            'my_card': card,
          },
          'viewer': {'is_member': member},
        };

    testWidgets('shows details, specialties, vouchers and Suki coming soon',
        (tester) async {
      await _pump(tester, const MerchantPageScreen(merchantId: 'm1'),
          {'GET /merchants/m1': page()}, []);
      expect(find.text('Bangus and halo-halo by the river.'), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_page_specialties')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchant_page_products')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchant_page_vouchers')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_page_directions')),
          findsOneWidget);
      expect(find.text('Suki Cards are coming soon.'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchant_page_suki_open')), findsNothing);
    });

    testWidgets('shows my Suki card progress', (tester) async {
      await _pump(tester, const MerchantPageScreen(merchantId: 'm1'), {
        'GET /merchants/m1':
            page(suki: true, card: {'visits': '3', 'required': '10'}),
      }, []);
      expect(find.textContaining('Your card: 3 of 10'), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant_page_suki_open')),
          findsOneWidget);
    });

    testWidgets('offers a Suki card when I have none', (tester) async {
      await _pump(tester, const MerchantPageScreen(merchantId: 'm1'),
          {'GET /merchants/m1': page(suki: true)}, []);
      expect(find.textContaining('Get a Suki card'), findsWidgets);
    });

    testWidgets('a missing shop says not found', (tester) async {
      await _pump(tester, const MerchantPageScreen(merchantId: 'x'),
          {'GET /merchants/x': const _Fail(404, 'MERCHANT_NOT_FOUND')}, []);
      expect(find.text('Shop not found'), findsOneWidget);
    });

    test('the model accepts strings, nulls and an empty body', () {
      final empty = MerchantPageData.fromJson(const {});
      expect(empty.name, 'Shop');
      expect(empty.suki.enabled, isFalse);
      expect(empty.hasLocation, isFalse);
      final full = MerchantPageData.fromJson(page());
      expect(full.lat, 16.043);
      expect(full.vouchers.single.costPoints, 10);
      expect(full.specialties.single.priceLabel, 'PHP 90.00');
    });
  });
}
