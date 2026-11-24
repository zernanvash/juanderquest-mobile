import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/celebrations/celebration.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/providers/voucher_provider.dart';
import 'package:juanderquest_app/features/suki/models/suki_models.dart';
import 'package:juanderquest_app/features/suki/providers/suki_provider.dart';
import 'package:juanderquest_app/features/suki/screens/suki_card_screen.dart';
import 'package:juanderquest_app/features/suki/screens/suki_cards_screen.dart';
import 'package:juanderquest_app/features/suki/suki_codes.dart';
import 'package:juanderquest_app/features/suki/suki_scan_flow.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_card_view.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_pass_sheet.dart';

const _standee =
    'https://juanderquest.app/suki/suki_abc123?v=2&s=0123456789abcdef';

Map<String, dynamic> _programJson({String mode = 'standee'}) => {
      'id': 'suki_abc123',
      'title': 'Kape Suki',
      'reward_kind': 'amount_off',
      'reward_value': '20.00',
      'reward_text': '₱20 off any drink',
      'reward_tag': '₱20 OFF',
      'visits_required': 10,
      'mode': mode,
      'status': 'active',
      'merchant': {
        'id': 'm1',
        'name': 'Aling Nena Cafe',
        'municipality': 'Dagupan City'
      },
    };

Map<String, dynamic> _rewardJson({bool expired = false}) => {
      'id': 'r1',
      'code': 'SUKI-ABC123-DEF456',
      'reward_text': '₱20 off any drink',
      'reward_tag': '₱20 OFF',
      'status': 'issued',
      'expires_at': '2027-01-17T00:00:00Z',
      'expired': expired,
    };

final _user = UserModel(
  id: 'u-107',
  seedId: 'u-107',
  email: 'suki@juanderquest.app',
  displayName: 'Suki 107',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 0,
);

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier) {
    state = AuthState(user: _user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

Override _noFix() =>
    sukiQuickFixProvider.overrideWithValue(() async => (lat: null, lng: null));

Override _signedIn() => authProvider.overrideWith((ref) => _InertAuthNotifier(
      ref.watch(apiClientProvider),
      ref.watch(authRefreshProvider.notifier),
    ));

class _FakeSukiApi extends SukiApi {
  _FakeSukiApi({
    this.error,
    this.visit,
    this.detail,
    this.visitedAfter = 1,
  }) : super(ApiClient(enableRetries: false));

  final Object? error;
  final Map<String, dynamic>? visit;
  final SukiProgramDetail? detail;
  final int visitedAfter;
  int visits = 0;
  int polls = 0;

  @override
  Future<SukiVisitResult> recordVisit({
    required String standee,
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    visits++;
    if (error != null) throw error!;
    return SukiVisitResult.fromJson(visit ??
        {
          'program': _programJson(),
          'card': {'card_id': 'c1', 'cycle': 1, 'visits': 4, 'required': 10},
        });
  }

  @override
  Future<List<SukiCard>> myCards() async => const [];

  @override
  Future<List<SukiProgram>> nearby({double? lat, double? lng}) async {
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<SukiProgramDetail> program(String id) async {
    if (error != null) throw error!;
    return detail!;
  }

  @override
  Future<({String pass, DateTime? expiresAt})> pass(String programId) async => (
        pass: 'JDQSUKIPASS:abc.def.ghi',
        expiresAt: DateTime.now().add(const Duration(seconds: 120)),
      );

  @override
  Future<({bool visitedToday, SukiCardProgress? card})> passStatus(
      String programId) async {
    polls++;
    final done = polls >= visitedAfter;
    return (
      visitedToday: done,
      card: done
          ? SukiCardProgress.fromJson(const {
              'card_id': 'c1',
              'cycle': 1,
              'visits': 5,
              'required': 10,
              'visited_today': true,
            })
          : null,
    );
  }
}

DioException _serverError(String code, {int status = 409}) {
  final options = RequestOptions(path: '/suki/visits');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'success': false,
        'error': {'code': code, 'message': 'server text'},
      },
    ),
  );
}

Position _fix() => Position(
      latitude: 16.043,
      longitude: 120.333,
      timestamp: DateTime(2026, 11, 18),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Widget _host(Widget child,
        {List<Override> overrides = const [], double scale = 1}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        ),
      ),
    );

/// A tall phone so the whole card page is built.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  group('standee extractor', () {
    test('accepts only juanderquest.app/suki URLs with v and s', () {
      expect(extractSukiStandee(_standee), _standee);
      expect(extractSukiStandee('  $_standee '), _standee);
      expect(sukiProgramIdFromStandee(_standee), 'suki_abc123');
      // wrong host
      expect(
          extractSukiStandee(
              'https://evil.example/suki/x?v=1&s=0123456789abcdef'),
          isNull);
      expect(
          extractSukiStandee(
              'http://juanderquest.app/suki/x?v=1&s=0123456789abcdef'),
          isNull);
      // missing signature / version
      expect(extractSukiStandee('https://juanderquest.app/suki/x?v=1'), isNull);
      expect(
          extractSukiStandee(
              'https://juanderquest.app/suki/x?s=0123456789abcdef'),
          isNull);
      expect(
          extractSukiStandee(
              'https://juanderquest.app/quests/x?v=1&s=0123456789abcdef'),
          isNull);
      expect(extractSukiStandee('SUKI-ABC123-DEF456'), isNull);
      expect(extractSukiStandee(null), isNull);
    });
  });

  group('models', () {
    test('visit results parse the reward and the reset card', () {
      final result = SukiVisitResult.fromJson({
        'program': _programJson(),
        'card': {
          'card_id': 'c1',
          'cycle': '2',
          'visits': '0',
          'required': '10',
          'visited_today': true
        },
        'reward_issued': _rewardJson(),
        'xp_awarded': '5',
        'badges': ['suki_first_card'],
        'mission_completed': true,
      });
      expect(result.rewardIssued!.claimable, isTrue);
      expect(result.card.cycle, 2);
      expect(result.visitNumber, 10);
      expect(result.xpAwarded, 5);
      expect(result.missionCompleted, isTrue);
      expect(result.badges, ['suki_first_card']);
      expect(result.program.rewardValue, 20);
    });

    test('reward tags are derived when the server leaves them out', () {
      expect(sukiRewardTag('percent_off', 10), '10% OFF');
      expect(sukiRewardTag('amount_off', 20), '₱20 OFF');
      expect(sukiRewardTag('promo', null), 'PROMO');
      expect(sukiRewardTag('free_item', null), 'FREE');
    });

    test('a card accepts a single reward or a list', () {
      final one = SukiCard.fromJson({
        'card_id': 'c1',
        'program': _programJson(),
        'reward': _rewardJson(),
      });
      expect(one.rewards.single.code, 'SUKI-ABC123-DEF456');
      final none = SukiCard.fromJson({'card_id': 'c1', 'rewards': []});
      expect(none.rewards, isEmpty);
    });
  });

  group('card view', () {
    Future<void> pumpCard(WidgetTester tester, int visits, int required) {
      final p = SukiProgram.fromJson({
        ..._programJson(),
        'reward_kind': 'free_item',
        'reward_value': null,
        'reward_tag': 'FREE',
        'reward_text': 'Free iced coffee',
        'visits_required': required,
      });
      final c = SukiCardProgress(
        cardId: 'c1',
        cycle: 1,
        visits: visits,
        required: required,
        totalVisits: visits,
        visitedToday: false,
      );
      return tester.pumpWidget(_host(Scaffold(
        body: SingleChildScrollView(
          child: SukiCardView(program: p, card: c, tiers: p.effectiveTiers),
        ),
      )));
    }

    testWidgets('an empty card shows every slot and the reward slot',
        (tester) async {
      await pumpCard(tester, 0, 10);
      expect(find.byKey(const ValueKey('suki_slot_9')), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_reward_slot')), findsOneWidget);
      expect(find.text('10 more visits for: Free iced coffee'), findsOneWidget);
    });

    testWidgets('a partial card counts the visits left', (tester) async {
      await pumpCard(tester, 3, 10);
      expect(find.text('7 more visits for: Free iced coffee'), findsOneWidget);
      await pumpCard(tester, 9, 10);
      expect(find.text('1 more visit for: Free iced coffee'), findsOneWidget);
    });

    testWidgets('a full card says the reward is ready', (tester) async {
      await pumpCard(tester, 5, 5);
      expect(find.text('Reward ready: Free iced coffee'), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_reward_slot')), findsNothing);
    });
  });

  group('card screen', () {
    SukiProgramDetail detail({bool expired = false, String mode = 'standee'}) =>
        SukiProgramDetail.fromJson({
          'program': _programJson(mode: mode),
          'my_card': {
            'card_id': 'c1',
            'cycle': 2,
            'visits': 3,
            'required': 10,
            'visited_today': true,
          },
          'rewards': [_rewardJson(expired: expired)],
        });

    testWidgets('an issued reward shows its QR and code', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
          _host(const SukiCardScreen(programId: 'suki_abc123'), overrides: [
        _signedIn(),
        sukiApiProvider.overrideWithValue(_FakeSukiApi(detail: detail())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('SUKI-ABC123-DEF456'), findsOneWidget);
      expect(find.text('Show this at the counter. Staff scan it once.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('suki_visited_today')), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_card_scan')), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_show_pass')), findsOneWidget);
    });

    testWidgets('an expired reward hides the code', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
          _host(const SukiCardScreen(programId: 'suki_abc123'), overrides: [
        _signedIn(),
        sukiApiProvider
            .overrideWithValue(_FakeSukiApi(detail: detail(expired: true))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('This reward has expired.'), findsOneWidget);
      expect(find.text('SUKI-ABC123-DEF456'), findsNothing);
    });

    testWidgets('a staff-scan shop offers only the pass', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
          _host(const SukiCardScreen(programId: 'suki_abc123'), overrides: [
        _signedIn(),
        sukiApiProvider.overrideWithValue(
            _FakeSukiApi(detail: detail(mode: 'staff_scan'))),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('suki_card_scan')), findsNothing);
      expect(find.byKey(const ValueKey('suki_show_pass')), findsOneWidget);
    });

    testWidgets('Suki switched off says coming soon', (tester) async {
      await tester.pumpWidget(
          _host(const SukiCardScreen(programId: 'suki_abc123'), overrides: [
        _signedIn(),
        sukiApiProvider.overrideWithValue(
            _FakeSukiApi(error: _serverError('SUKI_DISABLED', status: 503))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Suki Cards are coming soon.'), findsOneWidget);
    });
  });

  group('cards screen', () {
    testWidgets('Suki switched off says coming soon', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_host(const SukiCardsScreen(), overrides: [
        _signedIn(),
        _noFix(),
        sukiApiProvider.overrideWithValue(
            _FakeSukiApi(error: _serverError('SUKI_DISABLED', status: 503))),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('suki_coming_soon')), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_empty')), findsOneWidget);
    });
  });

  group('scan flow', () {
    Future<void> run(WidgetTester tester, _FakeSukiApi api,
        {Position? pos, bool settle = true}) async {
      await tester.pumpWidget(_host(
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => scanSukiStandee(
                  context,
                  ref,
                  scan: (_) async => _standee,
                  getPosition: () async => pos,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
      ));
      await tester.tap(find.text('go'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a visit plays the stamp-drop celebration', (tester) async {
      final api = _FakeSukiApi();
      await run(tester, api, pos: _fix(), settle: false);
      expect(api.visits, 1);
      final page = tester.widget<CelebrationPage>(find.byType(CelebrationPage));
      final scene = page.celebration as StampEarned;
      expect(scene.title, 'SUKI VISIT!');
      expect(scene.stampName, 'Visit 4 of 10 at Aling Nena Cafe');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CelebrationPage), findsNothing);
    });

    testWidgets('the Nth visit celebrates the reward with Show reward',
        (tester) async {
      final api = _FakeSukiApi(visit: {
        'program': _programJson(),
        'card': {'card_id': 'c1', 'cycle': 2, 'visits': 0, 'required': 10},
        'reward_issued': _rewardJson(),
      });
      await run(tester, api, pos: _fix(), settle: false);
      final scene = tester
          .widget<CelebrationPage>(find.byType(CelebrationPage))
          .celebration as StampEarned;
      expect(scene.title, 'SUKI REWARD!');
      expect(scene.stampName, 'Visit 10 of 10 at Aling Nena Cafe');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Suki reward unlocked!'), findsOneWidget);
      expect(find.byKey(const ValueKey('suki_show_reward')), findsOneWidget);
    });

    const copy = {
      'ALREADY_VISITED_TODAY': 'You already visited today. Come back tomorrow!',
      'OUT_OF_RANGE': 'You need to be at the shop to collect a visit.',
      'LOCATION_ACCURACY_TOO_LOW':
          'Your GPS is weak. Step outside or wait a moment and try again.',
      'STANDEE_REPLACED': 'This QR was replaced. Ask the shop for the new one.',
      'SUKI_STAFF_SCAN_ONLY':
          'This shop scans your pass. Tap Show my Suki pass.',
      'EMAIL_NOT_VERIFIED': 'Verify your email to collect Suki visits.',
      'SUKI_DISABLED': 'Suki Cards are coming soon.',
    };
    for (final entry in copy.entries) {
      testWidgets('${entry.key} shows its plain message', (tester) async {
        final api = _FakeSukiApi(error: _serverError(entry.key));
        await run(tester, api, pos: _fix());
        expect(api.visits, 1);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('server text'), findsNothing);
      });
    }

    testWidgets('no GPS fix sends nothing and explains why', (tester) async {
      final api = _FakeSukiApi();
      await run(tester, api);
      expect(api.visits, 0);
      expect(find.text('Location needed'), findsOneWidget);
    });
  });

  group('pass sheet', () {
    testWidgets('counts down and closes once staff record the visit',
        (tester) async {
      final api = _FakeSukiApi(visitedAfter: 2);
      Object? closedWith;
      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  closedWith = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const SukiPassSheet(
                        programId: 'suki_abc123', shopName: 'Aling Nena Cafe'),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final countdown = tester
          .widget<Text>(find.byKey(const ValueKey('suki_pass_countdown')))
          .data!;
      expect(countdown, matches(RegExp(r'Valid for (2:00|1:5\d), one scan')));
      // First poll: not yet. Second poll: visited today, the sheet closes.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SukiPassSheet), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(api.polls, 2);
      expect(find.byType(SukiPassSheet), findsNothing);
      expect(closedWith, isA<SukiCardProgress>());
      expect((closedWith as SukiCardProgress).visits, 5);
    });
  });

  group('My vouchers from the server', () {
    ApiClient client(List<String> calls,
        {Object? redeemData = const {'id': 'red_1'}}) {
      final c = ApiClient(enableRetries: false);
      c.dio.interceptors.insert(
        0,
        InterceptorsWrapper(onRequest: (options, handler) {
          calls.add('${options.method} ${options.path}');
          Object? data;
          var status = 200;
          if (options.path == '/vouchers') {
            data = [
              {'id': 'v1', 'title': 'Free halo-halo', 'cost_points': 50}
            ];
          } else if (options.path == '/me/redemptions') {
            data = {
              'items': [
                {
                  'id': 'red_1',
                  'code': 'JDQ-AAAAAA-BBBBBB',
                  'cost_points': '50',
                  'created_at': '2026-11-18T01:00:00Z',
                  'used_at': '2026-11-18T02:00:00Z',
                  'voucher': {'id': 'v1', 'title': 'Free halo-halo'},
                  'merchant': {'id': 'm1', 'name': 'Aling Nena Cafe'},
                },
              ],
            };
          } else if (options.path == '/vouchers/v1/redeem') {
            status = 201;
            data = redeemData;
          }
          handler.resolve(Response(
            requestOptions: options,
            statusCode: status,
            data: {'success': true, 'data': data},
          ));
        }),
      );
      return c;
    }

    ProviderContainer container(ApiClient api) {
      final c = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(api),
        _signedIn(),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('loading the shop loads redemptions with used state', () async {
      final calls = <String>[];
      final c = container(client(calls));
      await c.read(voucherProvider.notifier).fetchVouchers();
      final redeemed = c.read(voucherProvider).redeemedVouchers;
      expect(calls, contains('GET /me/redemptions'));
      expect(redeemed.single.code, 'JDQ-AAAAAA-BBBBBB');
      expect(redeemed.single.offerTitle, 'Free halo-halo');
      expect(redeemed.single.merchantName, 'Aling Nena Cafe');
      expect(redeemed.single.usedAt, isNotNull);
      expect(redeemed.single.expiresAt, isNull);
    });

    test('a redemption without a code never invents one', () async {
      final calls = <String>[];
      final c = container(client(calls));
      final result = await c.read(voucherProvider.notifier).redeemVoucher(
            VoucherModel(
              id: 'v1',
              merchantName: 'Aling Nena Cafe',
              offerTitle: 'Free halo-halo',
              costPoints: 50,
              category: 'REWARDS',
              location: 'Dagupan',
              description: '',
              isActive: true,
            ),
          );
      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(calls, contains('GET /me/redemptions'));
      // Only the server's code is listed.
      expect(c.read(voucherProvider).redeemedVouchers.map((r) => r.code),
          ['JDQ-AAAAAA-BBBBBB']);
    });

    test('a new redemption (201) returns the server code', () async {
      final calls = <String>[];
      final c = container(client(calls,
          redeemData: const {'id': 'red_1', 'code': 'JDQ-AAAAAA-BBBBBB'}));
      final result = await c.read(voucherProvider.notifier).redeemVoucher(
            VoucherModel(
              id: 'v1',
              merchantName: 'Aling Nena Cafe',
              offerTitle: 'Free halo-halo',
              costPoints: 50,
              category: 'REWARDS',
              location: 'Dagupan',
              description: '',
              isActive: true,
            ),
          );
      expect(result.success, isTrue);
      expect(result.code, 'JDQ-AAAAAA-BBBBBB');
      expect(c.read(voucherProvider).redeemedVouchers, hasLength(1));
    });
  });
}
