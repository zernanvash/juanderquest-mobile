import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/merchant/models/merchant_models.dart';
import 'package:juanderquest_app/features/merchant/screens/affiliate_pending_screen.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';
import 'package:latlong2/latlong.dart';

/// Plan 95: merchant affiliate flow and the in-app merchant workspace.

final _user = UserModel(
  id: 'user-1',
  seedId: 'user-1',
  displayName: 'Maria Santos',
  email: 'maria@example.test',
  avatarUrl: '',
  role: 'traveler',
  demoPoints: 0,
);

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier) {
    state = AuthState(user: _user, token: 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _Call {
  _Call(this.method, this.path, this.data);
  final String method;
  final String path;
  final Object? data;
}

/// Answers each request from [routes] (`'GET /path'` → body or status code).
ApiClient _api(Map<String, Object?> routes, List<_Call> calls) {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(_Call(options.method, options.path, options.data));
      final reply = routes['${options.method} ${options.path}'];
      if (reply is int) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: reply,
            data: {
              'success': false,
              'error': {'code': 'INCOMPLETE_PROFILE', 'message': 'Add contact'},
            },
          ),
          type: DioExceptionType.badResponse,
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: reply ?? {'success': true, 'data': null},
      ));
    }),
  );
  return api;
}

/// Dio answers on zero-delay timers, which `pumpAndSettle` alone does not
/// advance when no frame is pending.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Widget _probe(String path) => Scaffold(body: Text('probe $path'));

Future<void> _pump(
  WidgetTester tester,
  ApiClient api, {
  required String initial,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(
        path: '/affiliate',
        builder: (_, state) => AffiliateApplicationScreen(
            edit: state.uri.queryParameters['edit'] == '1')),
    GoRoute(
        path: '/affiliate/pending',
        builder: (_, __) => const AffiliatePendingScreen()),
    GoRoute(
        path: '/merchant', builder: (_, __) => const MerchantDashboardScreen()),
    GoRoute(path: '/shop', builder: (_, __) => _probe('/shop')),
    GoRoute(path: '/probe', builder: (_, __) => _probe('/probe')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith(
          (ref) => _Auth(api, ref.watch(authRefreshProvider.notifier))),
      ...extra,
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Map<String, Object?> _me(Map<String, Object?>? app, {Object? merchant}) => {
      'success': true,
      'data': app,
      'merchant': merchant,
    };

const _application = {
  'id': 'app-1',
  'status': 'received',
  'business_name': 'Bonuan Grill',
  'category': 'dining',
  'municipality': 'Dagupan City',
  'business_province': 'Pangasinan',
  'gps_lat': 16.0754,
  'gps_lng': 120.3421,
  'contact_name': 'Maria Santos',
  'contact_email': 'maria@example.test',
  'contact_phone': '09170000000',
  'sponsorship_goals': ['quest_stop'],
};

void main() {
  group('MerchantHubStatus', () {
    test('maps each application state to the screen it opens', () {
      expect(MerchantHubStatus.fromResponse(_me(null)).route, '/affiliate');
      expect(MerchantHubStatus.fromResponse(_me(_application)).route,
          '/affiliate/pending');
      expect(
          MerchantHubStatus.fromResponse(
              _me({..._application, 'status': 'needs_changes'})).state,
          MerchantHubState.needsChanges);
      expect(
          MerchantHubStatus.fromResponse(
              _me({..._application, 'status': 'rejected'})).route,
          '/affiliate');
      final approved = MerchantHubStatus.fromResponse(
          _me(_application, merchant: {'id': 'm1', 'name': 'Bonuan Grill'}));
      expect(approved.route, '/merchant');
      expect(approved.label, 'Merchant dashboard');
    });
  });

  group('AffiliateApplicationScreen', () {
    testWidgets('a submitted application opens the status screen',
        (tester) async {
      final calls = <_Call>[];
      await _pump(tester,
          _api({'GET /affiliate/applications/me': _me(_application)}, calls),
          initial: '/affiliate');
      await _settle(tester);
      expect(find.text('IN REVIEW BY TOURISM TEAM'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
    });

    testWidgets('an approved merchant goes straight to the dashboard',
        (tester) async {
      final calls = <_Call>[];
      await _pump(
          tester,
          _api({
            'GET /affiliate/applications/me': _me(
                {..._application, 'status': 'approved'},
                merchant: {'id': 'm1', 'name': 'Bonuan Grill'}),
          }, calls),
          initial: '/affiliate');
      await _settle(tester);
      expect(find.text('MERCHANT HUB'), findsOneWidget);
    });

    testWidgets('edit mode keeps the form and prefills the reviewer request',
        (tester) async {
      final calls = <_Call>[];
      await _pump(
          tester,
          _api({
            'GET /affiliate/applications/me': _me({
              ..._application,
              'status': 'needs_changes',
              'applicant_feedback': 'Move the pin',
            }),
          }, calls),
          initial: '/affiliate?edit=1');
      await _settle(tester);
      expect(find.text('Resubmit Revised Application'), findsOneWidget);
      expect(find.text('1. BUSINESS IDENTITY'), findsOneWidget);
    });

    testWidgets(
        'accordion submit needs the declaration, then posts and opens status',
        (tester) async {
      final calls = <_Call>[];
      final map = FakeJdqMap();
      final routes = <String, Object?>{
        'GET /affiliate/applications/me': _me(null),
        'POST /affiliate/applications': {
          'success': true,
          'data': _application,
        },
      };
      await _pump(tester, _api(routes, calls), initial: '/affiliate', extra: [
        jdqMapFactoryProvider.overrideWithValue(() => map),
        mapStyleProvider.overrideWith((ref) async => '{}'),
      ]);
      await _settle(tester);

      // Contact details come from the signed-in account.
      await tester.tap(find.byKey(const ValueKey('affiliate_section_3')));
      await _settle(tester);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('maria@example.test'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Bonuan Grill');
      await tester.enterText(fields.at(1), 'Dagupan City');
      await tester.enterText(fields.at(2), 'Pangasinan');
      map.onTapEmpty?.call(const LatLng(16.0754, 120.3421));
      await tester.pump();
      // Fields: business, town, province, place search, contact, email, phone.
      await tester.enterText(fields.at(6), '09170000000');
      await tester.tap(find.byKey(const ValueKey('affiliate_contact_sms')));
      await tester.tap(find.byKey(const ValueKey('affiliate_goal_quest_stop')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('affiliate_submit')));
      await _settle(tester);
      expect(find.text('Confirm the declaration before submitting.'),
          findsOneWidget);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);

      await tester
          .tap(find.byKey(const ValueKey('affiliate_declaration_checkbox')));
      await tester.pump();
      routes['GET /affiliate/applications/me'] = _me(_application);
      await tester.tap(find.byKey(const ValueKey('affiliate_submit')));
      await _settle(tester);

      final post = calls.singleWhere((c) => c.method == 'POST');
      expect(post.path, '/affiliate/applications');
      final body = post.data as Map;
      expect(body['preferred_contact_method'], 'sms');
      expect(body['contact_name'], 'Maria Santos');
      expect(body['gps_lat'], closeTo(16.0754, 1e-6));
      expect(find.text('IN REVIEW BY TOURISM TEAM'), findsOneWidget);
    });
  });

  group('AffiliatePendingScreen', () {
    testWidgets('needs_changes shows reviewer feedback and an edit action',
        (tester) async {
      final calls = <_Call>[];
      await _pump(
          tester,
          _api({
            'GET /affiliate/applications/me': _me({
              ..._application,
              'status': 'needs_changes',
              'applicant_feedback': 'Move the pin to the storefront.',
            }),
          }, calls),
          initial: '/affiliate/pending');
      await _settle(tester);
      expect(find.byKey(const ValueKey('affiliate_pending_feedback')),
          findsOneWidget);
      expect(find.text('Move the pin to the storefront.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('affiliate_pending_edit')));
      await _settle(tester);
      expect(find.text('Resubmit Revised Application'), findsOneWidget);
    });

    testWidgets('approved shows the workspace button', (tester) async {
      final calls = <_Call>[];
      await _pump(
          tester,
          _api({
            'GET /affiliate/applications/me':
                _me(_application, merchant: {'id': 'm1', 'name': 'Grill'}),
          }, calls),
          initial: '/affiliate/pending');
      await _settle(tester);
      expect(find.byKey(const ValueKey('affiliate_pending_open_merchant')),
          findsOneWidget);
    });
  });

  group('MerchantDashboardScreen', () {
    Map<String, Object?> dashboardRoutes({bool published = false}) => {
          'GET /merchant/dashboard': {
            'success': true,
            'data': {
              'merchant': {
                'id': 'm1',
                'name': 'Bonuan Grill',
                'category': 'dining',
                'municipality': 'Dagupan City',
                'is_published': published,
              },
              'counts': {'active_products': 1},
              'checklist': {
                'items': [
                  {
                    'id': 'profile_info',
                    'title': 'Review business info & address',
                    'completed': true
                  },
                  {
                    'id': 'catalog_item',
                    'title': 'Add your first product or specialty',
                    'completed': false
                  },
                ],
              },
              'truthful_notice': {'statement': 'Showcase only.'},
            },
          },
          'GET /merchant/profile': {
            'success': true,
            'data': {'name': 'Bonuan Grill', 'contact_email': 'a@b.test'},
          },
          'GET /merchant/products': {
            'success': true,
            'data': [
              {
                'id': 'p1',
                'name': 'Grilled bangus',
                'description': 'Boneless',
                'price': 250,
                'currency': 'PHP'
              },
            ],
          },
          'GET /merchant/points': {
            'success': true,
            'data': {'balance_points': 1500, 'history': []},
          },
          'GET /merchant/sponsorships': {
            'success': true,
            'data': {
              'items': [
                {
                  'id': 's1',
                  'status': 'requested',
                  'quest_title': 'Bangus trail',
                  'spot_name': 'Bonuan',
                  'points': 300,
                  'voucher_qty': 0,
                  'promo': false,
                  'terms_version': 2,
                  'plan_id': 'plan-1',
                  'plan_status': 'draft',
                },
              ],
            },
          },
        };

    testWidgets('overview, publish, and the connected tabs', (tester) async {
      final calls = <_Call>[];
      await _pump(tester, _api(dashboardRoutes(), calls), initial: '/merchant');
      await _settle(tester);
      expect(find.text('BONUAN GRILL'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Showcase only.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('merchant_publish_toggle')));
      await _settle(tester);
      expect(calls.any((c) => c.path == '/merchant/profile/publish'), isTrue);

      await tester.tap(find.byKey(const ValueKey('merchant_tab_catalog')));
      await _settle(tester);
      expect(find.text('Grilled bangus'), findsOneWidget);
      expect(find.text('PHP 250.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('merchant_add_product')));
      await _settle(tester);
      await tester.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('merchant_product_name')),
              matching: find.byType(TextField)),
          'Pasalubong box');
      await tester.tap(find.byKey(const ValueKey('merchant_product_save')));
      await _settle(tester);
      final created = calls.singleWhere(
          (c) => c.method == 'POST' && c.path == '/merchant/products');
      expect((created.data as Map)['name'], 'Pasalubong box');

      await tester.tap(find.byKey(const ValueKey('merchant_tab_profile')));
      await _settle(tester);
      expect(find.text('a@b.test'), findsOneWidget);
    });

    testWidgets('publishing an incomplete profile switches to Profile',
        (tester) async {
      final calls = <_Call>[];
      final routes = dashboardRoutes()
        ..['POST /merchant/profile/publish'] = 400;
      await _pump(tester, _api(routes, calls), initial: '/merchant');
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('merchant_publish_toggle')));
      await _settle(tester);
      expect(find.text('PROFILE · SHOWCASE DETAILS'), findsOneWidget);
    });

    testWidgets('sponsorships: buy points and accept a request',
        (tester) async {
      final calls = <_Call>[];
      await _pump(tester, _api(dashboardRoutes(), calls), initial: '/merchant');
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('merchant_tab_sponsorships')));
      await _settle(tester);
      expect(find.text('1500 PTS'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('merchant_buy_500')));
      await _settle(tester);
      final buy =
          calls.singleWhere((c) => c.path == '/merchant/points/purchase');
      expect((buy.data as Map)['package'], 500);
      expect((buy.data as Map)['idempotency_key'], isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('merchant_accept_s1')));
      await _settle(tester);
      final accept =
          calls.singleWhere((c) => c.path == '/sponsorships/s1/accept');
      expect((accept.data as Map)['terms_version'], 2);
    });
  });
}
