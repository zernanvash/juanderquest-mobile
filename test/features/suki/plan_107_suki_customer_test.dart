import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/suki/models/suki_models.dart';
import 'package:juanderquest_app/features/suki/providers/suki_provider.dart';
import 'package:juanderquest_app/features/suki/screens/suki_cards_screen.dart';
import 'package:juanderquest_app/features/suki/suki_codes.dart';
import 'package:juanderquest_app/features/suki/suki_scan_flow.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_card_grid.dart';

const _standee =
    'https://juanderquest.app/suki/suki_abc123?v=2&s=0123456789abcdef';

Map<String, dynamic> _programJson({String mode = 'standee'}) => {
      'id': 'suki_abc123',
      'title': 'Kape Suki',
      'reward_kind': 'amount_off',
      'reward_value': 20,
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

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier) {
    state = AuthState(
      user: UserModel(
        id: 'u-107',
        seedId: 'u-107',
        email: 'suki@juanderquest.app',
        displayName: 'Suki 107',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 0,
      ),
      token: 'inert_token',
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

Override _signedIn() => authProvider.overrideWith((ref) => _InertAuthNotifier(
      ref.watch(apiClientProvider),
      ref.watch(authRefreshProvider.notifier),
    ));

class _FakeSukiApi extends SukiApi {
  _FakeSukiApi({this.error, this.cards = const []})
      : super(ApiClient(enableRetries: false));

  final Object? error;
  final List<SukiCard> cards;
  int visits = 0;

  @override
  Future<SukiVisitResult> recordVisit({
    required String standee,
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    visits++;
    if (error != null) throw error!;
    return SukiVisitResult.fromJson({
      'program': _programJson(),
      'card': {'card_id': 'c1', 'cycle': 1, 'visits': 4, 'required': 10},
    });
  }

  @override
  Future<List<SukiCard>> myCards() async => cards;
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

void main() {
  group('scanner code extractors', () {
    test('a standee URL is accepted only from juanderquest.app with v and s',
        () {
      expect(extractSukiStandee(_standee), _standee);
      expect(extractSukiStandee('  $_standee '), _standee);
      expect(sukiProgramIdFromStandee(_standee), 'suki_abc123');
      expect(
          extractSukiStandee(
              'https://evil.example/suki/x?v=1&s=0123456789abcdef'),
          isNull);
      expect(
          extractSukiStandee(
              'http://juanderquest.app/suki/x?v=1&s=0123456789abcdef'),
          isNull);
      expect(extractSukiStandee('https://juanderquest.app/suki/x?v=1'), isNull);
      expect(
          extractSukiStandee(
              'https://juanderquest.app/quests/x?v=1&s=0123456789abcdef'),
          isNull);
      expect(extractSukiStandee(null), isNull);
    });

    test('the counter scanner takes passes, Suki rewards and voucher codes',
        () {
      expect(extractCounterCode('JDQSUKIPASS:abc.def.ghi'),
          'JDQSUKIPASS:abc.def.ghi');
      expect(extractCounterCode('suki-abc123-def456'), 'SUKI-ABC123-DEF456');
      expect(
          extractCounterCode(' JDQ - ABC123 - DEF456 '), 'JDQ-ABC123-DEF456');
      expect(extractCounterCode('JDQPASS:quest-pass'), isNull);
      expect(extractCounterCode('hello'), isNull);
    });
  });

  test('visit results parse the reward and the reset card', () {
    final result = SukiVisitResult.fromJson({
      'program': _programJson(),
      'card': {
        'card_id': 'c1',
        'cycle': 2,
        'visits': 0,
        'required': 10,
        'visited_today': true
      },
      'reward_issued': {
        'id': 'r1',
        'code': 'SUKI-ABC123-DEF456',
        'reward_text': '₱20 off any drink',
        'reward_tag': '₱20 OFF',
        'status': 'issued',
        'expires_at': '2027-01-17T00:00:00Z',
        'expired': false,
      },
      'xp_awarded': 5,
      'badges': ['suki_first_card'],
    });
    expect(result.rewardIssued!.claimable, isTrue);
    expect(result.card.cycle, 2);
    expect(result.card.visitedToday, isTrue);
    expect(result.badges, ['suki_first_card']);
    expect(result.program.rewardTag, '₱20 OFF');
  });

  group('card grid', () {
    testWidgets('shows filled slots and the visits left', (tester) async {
      await tester.pumpWidget(_host(const Scaffold(
        body: SukiCardGrid(
            visits: 3,
            required: 10,
            rewardTag: 'FREE',
            rewardText: 'Free iced coffee'),
      )));
      expect(find.byKey(const ValueKey('suki_slot_9')), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('7 more visits for: Free iced coffee'), findsOneWidget);
    });

    testWidgets('a full card says the reward is ready', (tester) async {
      await tester.pumpWidget(_host(const Scaffold(
        body: SukiCardGrid(
            visits: 5,
            required: 5,
            rewardTag: 'PROMO',
            rewardText: 'Buy 1 Take 1'),
      )));
      expect(find.text('Reward ready: Buy 1 Take 1'), findsOneWidget);
    });
  });

  group('scan flow', () {
    Future<void> run(WidgetTester tester, _FakeSukiApi api,
        {Position? pos}) async {
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
        overrides: [sukiApiProvider.overrideWithValue(api)],
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('a second visit today says come back tomorrow', (tester) async {
      final api = _FakeSukiApi(error: _serverError('ALREADY_VISITED_TODAY'));
      await run(tester, api, pos: _fix());
      expect(api.visits, 1);
      expect(find.text('You already visited today. Come back tomorrow!'),
          findsOneWidget);
    });

    testWidgets('outside the shop asks to be at the shop', (tester) async {
      await run(tester,
          _FakeSukiApi(error: _serverError('OUT_OF_RANGE', status: 422)),
          pos: _fix());
      expect(find.text('You need to be at the shop to collect a visit.'),
          findsOneWidget);
    });

    testWidgets('a staff-scan shop points to the pass', (tester) async {
      await run(
          tester, _FakeSukiApi(error: _serverError('SUKI_STAFF_SCAN_ONLY')),
          pos: _fix());
      expect(find.text('This shop scans your pass. Tap Show my Suki pass.'),
          findsOneWidget);
    });

    testWidgets('no GPS fix sends nothing and explains why', (tester) async {
      final api = _FakeSukiApi();
      await run(tester, api);
      expect(api.visits, 0);
      expect(find.text('Location needed'), findsOneWidget);
    });
  });

  group('no overflow at 2x text', () {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets(
          'Suki Cards list ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final card = SukiCard.fromJson({
          'card_id': 'c1',
          'cycle': 1,
          'visits': 4,
          'required': 10,
          'visited_today': true,
          'program': _programJson(),
          'rewards': [
            {
              'id': 'r1',
              'code': 'SUKI-ABC123-DEF456',
              'reward_text': '₱20 off',
              'status': 'issued',
              'expires_at': '2027-01-01T00:00:00Z'
            },
          ],
        });
        await tester.pumpWidget(_host(
          const SukiCardsScreen(),
          scale: 2,
          overrides: [
            _signedIn(),
            sukiApiProvider.overrideWithValue(_FakeSukiApi(cards: [card]))
          ],
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('card grid ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
          const Scaffold(
            body: SingleChildScrollView(
              child: SukiCardGrid(
                  visits: 19,
                  required: 20,
                  rewardTag: '₱5000 OFF',
                  rewardText: 'A long reward line for the full card'),
            ),
          ),
          scale: 2,
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
