import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_loyalty_tab.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_suki_codes.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_suki_models.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_suki_widgets.dart';
import 'package:juanderquest_app/features/merchant/suki/suki_badge_art.dart';
import 'package:juanderquest_app/features/merchant/suki/suki_standee_screen.dart';

/// Plan 107 P3: merchant Loyalty tab, counter scanner, standee, badge art.

class _Call {
  _Call(this.method, this.path, this.data);
  final String method;
  final String path;
  final Object? data;
}

/// A failed reply: HTTP [status] with API error [code].
class _Fail {
  const _Fail(this.status, this.code);
  final int status;
  final String code;
}

/// Answers each request from [routes] (`'GET /path'` -> data, a [_Fail], or
/// a function of the request body).
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

Map<String, dynamic> _program(String status, {String? pausedBy}) => {
      'id': 'suki_1',
      'title': 'Kape Suki',
      'reward_kind': 'amount_off',
      'reward_value': '20.00', // NUMERIC arrives as a string
      'reward_text': '₱20 off your order',
      'reward_tag': '₱20 OFF',
      'visits_required': 10,
      'mode': 'standee',
      'status': status,
      'radius_m': 75,
      'standee_version': 2,
      'paused_by': pausedBy,
      'pause_reason': pausedBy == 'admin' ? 'Reported fake visits' : null,
      'merchant': {'id': 'm1', 'name': 'Aling Nena Cafe'},
    };

Map<String, dynamic> _view({
  String? status,
  String? pausedBy,
  bool location = true,
  bool published = true,
  String role = 'owner',
}) =>
    {
      'role': role,
      'program': status == null ? null : _program(status, pausedBy: pausedBy),
      'shop_location': location ? {'lat': 16.04, 'lng': 120.33} : null,
      'checklist': {'has_location': location, 'is_published': published},
    };

final _stats = {
  'days': 30,
  'visits_by_day': [
    {'date': '2026-11-17', 'visits': 3},
    {'date': '2026-11-18', 'visits': '5'},
  ],
  'unique_customers': 6,
  'repeat_customers': 2,
  'new_to_app': 4,
  'rewards_issued': 2,
  'rewards_claimed': 1,
  'vouchers_confirmed': 3,
  'top_regulars': [
    {'label': 'Suki #A3F', 'visits': 4},
  ],
};

const _scanResults = {
  'visit': {
    'kind': 'visit',
    'customer': 'Suki #A3F',
    'title': 'Visit recorded',
    'detail': 'Visit 4 of 10',
  },
  'reward': {
    'kind': 'reward',
    'customer': 'Suki #B12',
    'title': 'Reward claimed',
    'detail': '₱20 off your order',
  },
  'voucher': {
    'kind': 'voucher',
    'customer': 'Suki #C9D',
    'title': 'Voucher confirmed',
    'detail': 'Free halo-halo',
  },
};

Position _pos(double accuracy) => Position(
      latitude: 16.0431,
      longitude: 120.3333,
      timestamp: DateTime(2026, 11, 18),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  ApiClient api, {
  Widget child = const MerchantLoyaltyTab(),
  List<String?> scans = const [],
  Size? size,
  double scale = 1,
  bool scroll = true,
}) async {
  final s = size ?? const Size(480, 2400);
  tester.view.physicalSize = Size(s.width * 2, s.height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final queue = [...scans];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      merchantSukiScannerProvider.overrideWithValue(
          (_) async => queue.isEmpty ? null : queue.removeAt(0)),
      merchantSukiPositionProvider.overrideWithValue(() async => _pos(8)),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: scroll
              ? Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

void main() {
  group('extractCounterCode', () {
    test('accepts a Suki pass and keeps the JWT case', () {
      expect(extractCounterCode('JDQSUKIPASS:eyJhbGci.AbC.dEf'),
          'JDQSUKIPASS:eyJhbGci.AbC.dEf');
      expect(extractCounterCode('  jdqsukipass: eyJhbGci.AbC.dEf \n'),
          'JDQSUKIPASS:eyJhbGci.AbC.dEf');
      expect(extractCounterCode('JDQSUKIPASS:'), isNull);
    });

    test('accepts Suki reward codes, case-insensitive with spaces', () {
      expect(extractCounterCode('SUKI-ABC123-DEF456'), 'SUKI-ABC123-DEF456');
      expect(
          extractCounterCode(' suki-abc123 - def456 '), 'SUKI-ABC123-DEF456');
    });

    test('accepts voucher / perk codes', () {
      expect(extractCounterCode('JDQ-7KX2-9QPA'), 'JDQ-7KX2-9QPA');
      expect(extractCounterCode('jdq-7kx2 9qpa'), 'JDQ-7KX29QPA');
    });

    test('rejects anything else', () {
      for (final raw in [
        null,
        '',
        '   ',
        'https://juanderquest.app/suki/suki_1?v=1&s=abc',
        'MARKER-123',
        'SUKI-',
        'JDQ',
        'hello world',
      ]) {
        expect(extractCounterCode(raw), isNull, reason: '$raw');
      }
    });
  });

  group('models', () {
    test('parse string numbers and build reward tags', () {
      final view = MerchantSukiView.fromJson(_view(status: 'active'));
      expect(view.program!.rewardValue, 20);
      expect(view.program!.rewardTag, '₱20 OFF');
      expect(view.program!.standeeVersion, 2);
      final stats = MerchantSukiStats.fromJson(_stats);
      expect(stats.totalVisits, 8);
      expect(stats.claimRate, 0.5);
      expect(sukiRewardTag('percent_off', 10), '10% OFF');
      expect(sukiRewardTag('free_item', null), 'FREE');
      expect(sukiRewardTag('promo', null), 'PROMO');
    });
  });

  test('Suki badge art is rectangular and uses only palette keys', () {
    for (final key in ['suki_card', 'suki_regular', 'suki_towns']) {
      final art = SukiBadgeArt.byKey[key]!;
      for (final row in art.rows) {
        expect(row.length, art.width, reason: key);
        for (final ch in row.split('')) {
          expect(ch == '.' || PixelPalette.byKey.containsKey(ch), isTrue,
              reason: '$key: $ch');
        }
      }
    }
    expect(SukiBadgeArt.byKey['suki_first_card'], SukiBadgeArt.sukiCard);
  });

  testWidgets('no program: setup form, stepper at 10, validation and save',
      (tester) async {
    final calls = <_Call>[];
    final api = _api({
      'GET /merchant/suki': _view(),
      'PUT /merchant/suki': (_) => _view(status: 'draft', location: false),
    }, calls);
    await _pump(tester, api);

    expect(find.byKey(const ValueKey('loyalty_form')), findsOneWidget);
    expect(find.text('Turn your regulars into JuanderQuest explorers'),
        findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.byKey(const ValueKey('loyalty_value')), findsNothing);

    await _tap(tester, const ValueKey('loyalty_visits_plus'));
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('loyalty_visits'))).data,
        '11');
    await _tap(tester, const ValueKey('loyalty_visits_minus'));

    await tester.tap(find.text('% OFF'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('loyalty_value')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('loyalty_value')), '150');
    await tester.tap(find.text('10% off your order'));
    await _settle(tester);
    expect(find.text('150% OFF'), findsOneWidget); // live preview tag
    await _tap(tester, const ValueKey('loyalty_save'));
    expect(find.text('Percent off must be 5 to 50.'), findsOneWidget);
    expect(calls.where((c) => c.method == 'PUT'), isEmpty);

    await tester.enterText(find.byKey(const ValueKey('loyalty_value')), '10');
    await _tap(tester, const ValueKey('loyalty_save'));
    final put = calls.singleWhere((c) => c.method == 'PUT');
    expect(put.path, '/merchant/suki');
    expect(put.data, containsPair('reward_kind', 'percent_off'));
    expect(put.data, containsPair('reward_value', 10));
    expect(put.data, containsPair('reward_text', '10% off your order'));
    expect(put.data, containsPair('visits_required', 10));
    expect(put.data, containsPair('mode', 'standee'));
    // Saved -> draft view.
    expect(find.byKey(const ValueKey('loyalty_checklist')), findsOneWidget);
  });

  testWidgets('draft: checklist, pin location, then Activate', (tester) async {
    final calls = <_Call>[];
    var view = _view(status: 'draft', location: false);
    final api = _api({
      'GET /merchant/suki': (_) => view,
      'PUT /merchant/suki/location': (_) =>
          view = _view(status: 'draft', location: true),
      'POST /merchant/suki/activate': (_) => view = _view(status: 'active'),
      'GET /merchant/suki/stats': _stats,
    }, calls);
    await _pump(tester, api);

    expect(find.byKey(const ValueKey('loyalty_state_draft')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_checklist')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_scan')), findsNothing);
    final activate = find.byKey(const ValueKey('loyalty_activate'));
    expect(tester.widget<PixelButton>(activate).onPressed, isNull);

    await _tap(tester, const ValueKey('loyalty_pin'));
    final pin = calls.singleWhere((c) => c.path == '/merchant/suki/location');
    expect(pin.data, {'lat': 16.0431, 'lng': 120.3333, 'accuracy_m': 8.0});
    expect(tester.widget<PixelButton>(activate).onPressed, isNotNull);

    await _tap(tester, const ValueKey('loyalty_activate'));
    expect(find.byKey(const ValueKey('loyalty_state_active')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_scan')), findsOneWidget);
  });

  testWidgets('active: SCAN, stats panel, Print standee and Pause',
      (tester) async {
    final calls = <_Call>[];
    final api = _api({
      'GET /merchant/suki': _view(status: 'active'),
      'GET /merchant/suki/stats': _stats,
      'POST /merchant/suki/pause': (_) =>
          _view(status: 'paused', pausedBy: 'merchant'),
      'GET /merchant/suki/standee': {
        'url': 'https://juanderquest.app/suki/suki_1?v=2&s=abcd',
        'title': 'Kape Suki',
        'reward_text': '₱20 off your order',
        'shop_name': 'Aling Nena Cafe',
        'version': 2,
        'visits_required': 10,
      },
    }, calls);
    await _pump(tester, api);

    expect(find.byKey(const ValueKey('loyalty_scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_stats')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_stats_bars')), findsOneWidget);
    expect(find.text('Suki #A3F · 4'), findsOneWidget);
    expect(find.text('Rewards claimed: 1 of 2'), findsOneWidget);
    expect(calls.any((c) => c.path == '/merchant/suki/stats'), isTrue);

    await _tap(tester, const ValueKey('loyalty_standee'));
    expect(find.byType(SukiStandeeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('suki_standee_qr')), findsOneWidget);
    expect(find.text('Aling Nena Cafe'), findsOneWidget);
    expect(find.text('Visit 10 times: ₱20 off your order'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(tester);

    await _tap(tester, const ValueKey('loyalty_pause'));
    expect(calls.any((c) => c.path == '/merchant/suki/pause'), isTrue);
    expect(find.byKey(const ValueKey('loyalty_state_paused')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_activate')), findsOneWidget);
  });

  testWidgets('paused by admin: red panel, reason, Activate disabled',
      (tester) async {
    await _pump(
        tester,
        _api({
          'GET /merchant/suki': _view(status: 'paused', pausedBy: 'admin'),
        }, []));
    expect(find.byKey(const ValueKey('loyalty_admin_paused')), findsOneWidget);
    expect(find.text('Reason: Reported fake visits'), findsOneWidget);
    expect(find.text('Contact your LGU tourism office to resume it.'),
        findsOneWidget);
    final activate = find.byKey(const ValueKey('loyalty_activate'));
    expect(tester.widget<PixelButton>(activate).onPressed, isNull);
    expect(find.byKey(const ValueKey('loyalty_edit')), findsNothing);
  });

  testWidgets('503 SUKI_DISABLED shows coming soon', (tester) async {
    await _pump(
        tester,
        _api({
          'GET /merchant/suki': const _Fail(503, 'SUKI_DISABLED'),
        }, []));
    expect(find.byKey(const ValueKey('loyalty_disabled')), findsOneWidget);
    expect(find.text('Suki Cards are coming soon.'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_retry')), findsNothing);
  });

  testWidgets('staff see the card but no owner controls', (tester) async {
    await _pump(
        tester,
        _api({
          'GET /merchant/suki': _view(status: 'active', role: 'staff'),
          'GET /merchant/suki/stats': _stats,
        }, []));
    expect(find.byKey(const ValueKey('loyalty_scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_pause')), findsNothing);
    expect(find.byKey(const ValueKey('loyalty_edit')), findsNothing);
  });

  group('counter scanner', () {
    for (final kind in ['visit', 'reward', 'voucher']) {
      testWidgets('result dialog: $kind', (tester) async {
        final calls = <_Call>[];
        final api = _api({
          'GET /merchant/suki': _view(status: 'active'),
          'GET /merchant/suki/stats': _stats,
          'POST /merchant/suki/scan': _scanResults[kind],
        }, calls);
        await _pump(tester, api, scans: [' suki-abc123-def456 ']);
        await _tap(tester, const ValueKey('loyalty_scan'));

        final scan = calls.singleWhere((c) => c.path == '/merchant/suki/scan');
        expect(scan.data, {'code': ' suki-abc123-def456 '});
        final r = _scanResults[kind]!;
        expect(
            find.byKey(ValueKey('loyalty_scan_result_$kind')), findsOneWidget);
        expect(find.text(r['title']!), findsOneWidget);
        expect(find.text(r['customer']!), findsOneWidget);
        expect(find.text(r['detail']!), findsWidgets);
        expect(find.text(kind.toUpperCase()), findsOneWidget);
        await _tap(tester, const ValueKey('loyalty_scan_done'));
        expect(find.byKey(ValueKey('loyalty_scan_result_$kind')), findsNothing);
      });
    }

    testWidgets('Scan next opens the scanner again', (tester) async {
      final calls = <_Call>[];
      final api = _api({
        'GET /merchant/suki': _view(status: 'active'),
        'GET /merchant/suki/stats': _stats,
        'POST /merchant/suki/scan': (Object? body) =>
            (body as Map)['code'] == 'JDQ-AAAA-BBBB'
                ? _scanResults['voucher']
                : _scanResults['visit'],
      }, calls);
      await _pump(tester, api,
          scans: ['JDQSUKIPASS:eyJ.a.b', 'JDQ-AAAA-BBBB', null]);
      await _tap(tester, const ValueKey('loyalty_scan'));
      expect(find.byKey(const ValueKey('loyalty_scan_result_visit')),
          findsOneWidget);
      await _tap(tester, const ValueKey('loyalty_scan_next'));
      expect(find.byKey(const ValueKey('loyalty_scan_result_voucher')),
          findsOneWidget);
      await _tap(tester, const ValueKey('loyalty_scan_next'));
      expect(calls.where((c) => c.path == '/merchant/suki/scan').length, 2);
      expect(find.byKey(const ValueKey('loyalty_scan_result_voucher')),
          findsNothing);
    });

    testWidgets('refused code shows plain language', (tester) async {
      final api = _api({
        'GET /merchant/suki': _view(status: 'active'),
        'GET /merchant/suki/stats': _stats,
        'POST /merchant/suki/scan': const _Fail(409, 'REWARD_ALREADY_CLAIMED'),
      }, []);
      await _pump(tester, api, scans: ['SUKI-ABC123-DEF456']);
      await _tap(tester, const ValueKey('loyalty_scan'));
      expect(find.text('Not accepted'), findsOneWidget);
      expect(find.text('This reward was already claimed.'), findsOneWidget);
    });
  });

  testWidgets('merchant hub opens the Loyalty tab from ?tab=loyalty',
      (tester) async {
    final api = _api({
      'GET /merchant/dashboard': {
        'merchant': {'name': 'Aling Nena Cafe', 'is_published': true},
      },
      'GET /merchant/suki': _view(),
    }, []);
    tester.view.physicalSize = const Size(960, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const MerchantDashboardScreen(initialTab: 'loyalty'),
      ),
    ));
    await _settle(tester);
    expect(find.byKey(const ValueKey('merchant_tab_loyalty')), findsOneWidget);
    expect(find.byType(MerchantLoyaltyTab), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty_form')), findsOneWidget);
  });

  group('no overflow at 2x text', () {
    final states = <String, Map<String, dynamic>>{
      'setup': _view(),
      'draft': _view(status: 'draft', location: false, published: false),
      'active': _view(status: 'active'),
      'admin paused': _view(status: 'paused', pausedBy: 'admin'),
    };
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      for (final entry in states.entries) {
        testWidgets('Loyalty tab ${entry.key} $label', (tester) async {
          await _pump(
              tester,
              _api({
                'GET /merchant/suki': entry.value,
                'GET /merchant/suki/stats': _stats,
              }, []),
              size: size,
              scale: 2);
          expect(tester.takeException(), isNull);
        });
      }

      for (final kind in ['visit', 'reward', 'voucher']) {
        testWidgets('scan result $kind $label', (tester) async {
          await _pump(
              tester,
              _api({
                'GET /merchant/suki': _view(status: 'active'),
                'GET /merchant/suki/stats': _stats,
                'POST /merchant/suki/scan': _scanResults[kind],
              }, []),
              scans: ['JDQ-AAAA-BBBB'],
              size: size,
              scale: 2);
          await _tap(tester, const ValueKey('loyalty_scan'));
          expect(find.byKey(ValueKey('loyalty_scan_result_$kind')),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('standee screen $label', (tester) async {
        await _pump(
          tester,
          _api({
            'GET /merchant/suki/standee': {
              'url': 'https://juanderquest.app/suki/suki_1?v=1&s=abcd',
              'title': 'Kape Suki',
              'reward_text': 'Buy 1 Take 1 halo-halo every Saturday',
              'shop_name': 'Aling Nena Cafe and Sari-Sari Store',
              'version': 1,
              'visits_required': 10,
            },
          }, []),
          child: const SukiStandeeScreen(),
          size: size,
          scale: 2,
          scroll: false,
        );
        expect(find.byKey(const ValueKey('suki_standee_qr')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('stats panel fills missing days with empty bars', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: SukiStatsPanel(
          stats: MerchantSukiStats.fromJson(_stats),
          today: DateTime(2026, 11, 18),
        ),
      ),
    ));
    await tester.pump();
    final bars = find.descendant(
        of: find.byKey(const ValueKey('loyalty_stats_bars')),
        matching: find.byType(ColoredBox));
    expect(bars, findsNWidgets(30));
    final green = tester
        .widgetList<ColoredBox>(bars)
        .where((b) => b.color == PixelPalette.greenBright);
    expect(green.length, 2);
  });
}
