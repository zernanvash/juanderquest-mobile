import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/suki/merchant_loyalty_tab.dart';
import 'package:juanderquest_app/features/suki/models/suki_models.dart';
import 'package:juanderquest_app/features/suki/providers/suki_provider.dart';
import 'package:juanderquest_app/features/suki/screens/suki_card_screen.dart';
import 'package:juanderquest_app/features/suki/screens/suki_points_history_screen.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_card_skin.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_card_view.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_points_menu.dart';
import 'package:juanderquest_app/features/suki/widgets/suki_reward_ladder.dart';

final _user = UserModel(
  id: 'u-111',
  seedId: 'u-111',
  email: 'suki111@juanderquest.app',
  displayName: 'Maria Suki',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 0,
);

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier) {
    state = AuthState(user: _user, token: 'tok');
  }

  @override
  Future<void> refreshProfile() async {}
}

Override _signedIn() => authProvider.overrideWith((ref) => _Auth(
      ref.watch(apiClientProvider),
      ref.watch(authRefreshProvider.notifier),
    ));

Map<String, dynamic> _v2ProgramJson({bool pointsEnabled = true}) => {
      'id': 'suki_v2',
      'title': 'Kapehan Loyalty',
      'reward_kind': 'free_item',
      'reward_value': null,
      'reward_text': 'Free cold brew',
      'reward_tag': 'FREE',
      'visits_required': 6,
      'skin_key': 'jdq_classic',
      'mode': 'standee',
      'status': 'active',
      'tiers': [
        {
          'visit_number': 2,
          'reward_kind': 'amount_off',
          'reward_value': 15,
          'reward_text': '₱15 off drink',
          'reward_tag': '₱15 OFF',
          'icon_key': 'discount',
          'state': 'claimed',
        },
        {
          'visit_number': 4,
          'reward_kind': 'promo',
          'reward_value': null,
          'reward_text': 'Free upsize',
          'reward_tag': 'PROMO',
          'icon_key': 'drink',
          'state': 'issued',
        },
        {
          'visit_number': 6,
          'reward_kind': 'free_item',
          'reward_value': null,
          'reward_text': 'Free cold brew',
          'reward_tag': 'FREE',
          'icon_key': 'coffee',
          'state': 'locked',
        },
      ],
      'points': {
        'enabled': pointsEnabled,
        'per_visit': 15,
        'pesos_per_point': 20,
        'max_per_visit': 50,
      },
      'merchant': {
        'id': 'm111',
        'name': 'Kapehan Suki',
        'municipality': 'Dagupan City',
      },
    };

SukiProgramDetail _v2Detail({bool pointsEnabled = true, int balance = 40}) =>
    SukiProgramDetail.fromJson({
      'program': _v2ProgramJson(pointsEnabled: pointsEnabled),
      'my_card': {
        'card_id': 'card_111',
        'card_no': 'SUKI 0042-A3F7',
        'cycle': 1,
        'visits': 4,
        'required': 6,
        'total_visits': 4,
        'visited_today': false,
        'tiers': _v2ProgramJson()['tiers'],
        'points': {
          'enabled': pointsEnabled,
          'balance': balance,
          'lifetime': 100,
          'per_visit': 15,
        },
      },
      'points_menu': pointsEnabled
          ? [
              {
                'id': 'item_1',
                'program_id': 'suki_v2',
                'title': 'Iced Americano',
                'points_cost': 30,
                'icon_key': 'coffee',
                'is_active': true,
                'sort_order': 0,
              },
              {
                'id': 'item_2',
                'program_id': 'suki_v2',
                'title': 'Whole Cake',
                'points_cost': 120,
                'icon_key': 'dessert',
                'is_active': true,
                'sort_order': 1,
              },
            ]
          : const [],
      'rewards': const [],
    });

class _FakeV2Api extends SukiApi {
  _FakeV2Api({
    required this.detail,
    this.pages = const [],
  }) : super(ApiClient(enableRetries: false));

  final SukiProgramDetail detail;
  final List<SukiPointsLedgerPage> pages;
  int redeemCalls = 0;
  int ledgerCalls = 0;

  @override
  Future<SukiProgramDetail> program(String id) async => detail;

  @override
  Future<SukiPointsRedeemResult> redeemPoints({required String itemId}) async {
    redeemCalls++;
    return SukiPointsRedeemResult.fromJson({
      'replayed': false,
      'reward': {
        'id': 'rw_pts_1',
        'code': 'SUKI-111111-222222',
        'reward_text': 'Iced Americano',
        'reward_tag': 'FREE',
        'status': 'issued',
        'source': 'points',
        'points_cost': 30,
        'expires_at': '2027-02-01T00:00:00Z',
        'expired': false,
      },
      'card': {
        'card_id': 'card_111',
        'card_no': 'SUKI 0042-A3F7',
        'cycle': 1,
        'visits': 4,
        'required': 6,
        'total_visits': 4,
        'visited_today': false,
        'points': {'enabled': true, 'balance': 10, 'lifetime': 100, 'per_visit': 15},
      },
    });
  }

  @override
  Future<SukiPointsLedgerPage> cardPoints(
    String cardId, {
    String? cursor,
    int limit = 25,
  }) async {
    final idx = ledgerCalls++;
    return idx < pages.length
        ? pages[idx]
        : const SukiPointsLedgerPage(cardId: 'card_111', balance: 40, lifetime: 100);
  }
}

Widget _host(
  Widget child, {
  List<Override> overrides = const [],
  double scale = 1,
}) =>
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
  test('SukiTierArt custom sprites are rectangular and use only palette keys', () {
    for (final key in sukiIconKeys) {
      final art = SukiTierArt.byKey(key);
      for (final row in art.rows) {
        expect(row.length, art.width, reason: key);
        for (final ch in row.split('')) {
          expect(ch == '.' || PixelPalette.byKey.containsKey(ch), isTrue,
              reason: '$key: $ch');
        }
      }
    }
  });

  testWidgets('SukiCardView flips 3D between front and back faces',
      (tester) async {
    final d = _v2Detail();
    await tester.pumpWidget(_host(Scaffold(
      body: SingleChildScrollView(
        child: SukiCardView(
          program: d.program,
          card: d.card,
          tiers: d.effectiveTiers,
          points: d.card!.points,
          holder: const SukiHolder(displayName: 'Maria Suki', handle: 'mariasuki'),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suki_card_front')), findsOneWidget);
    expect(find.text('SUKI 0042-A3F7'), findsOneWidget);
    expect(find.byKey(const ValueKey('suki_card_points_chip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suki_card_flip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suki_card_back')), findsOneWidget);
    expect(find.text('Maria Suki'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suki_card_flip_front')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suki_card_front')), findsOneWidget);
  });

  testWidgets('SukiRewardLadder displays claimed, issued and locked milestones',
      (tester) async {
    final d = _v2Detail();
    await tester.pumpWidget(_host(Scaffold(
      body: SukiRewardLadder(tiers: d.effectiveTiers, visits: 4),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suki_reward_ladder')), findsOneWidget);
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('Unlocked!'), findsOneWidget);
    expect(find.text('Visit 6 (2 left)'), findsOneWidget);
  });

  testWidgets('SukiPointsMenu hides when disabled, redeems when affordable',
      (tester) async {
    final disabled = _v2Detail(pointsEnabled: false);
    final enabled = _v2Detail(pointsEnabled: true, balance: 40);
    final api = _FakeV2Api(detail: enabled);
    await tester.pumpWidget(_host(
      Scaffold(
        body: SukiPointsMenu(
          program: disabled.program,
          points: disabled.card!.points,
          menu: disabled.pointsMenu,
          cardId: disabled.card!.cardId,
        ),
      ),
      overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
    ));
    expect(find.byKey(const ValueKey('suki_points_menu')), findsNothing);

    await tester.pumpWidget(_host(
      Scaffold(
        body: SingleChildScrollView(
          child: SukiPointsMenu(
            program: enabled.program,
            points: enabled.card!.points,
            menu: enabled.pointsMenu,
            cardId: enabled.card!.cardId,
          ),
        ),
      ),
      overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
    ));
    await tester.pumpAndSettle();

    // item_1 (30 pts) is affordable; item_2 (120 pts) is disabled.
    final btn1 = tester
        .widget<PixelButton>(find.byKey(const ValueKey('suki_redeem_item_1')));
    final btn2 = tester
        .widget<PixelButton>(find.byKey(const ValueKey('suki_redeem_item_2')));
    expect(btn1.onPressed, isNotNull);
    expect(btn2.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('suki_redeem_item_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suki_redeem_confirm')));
    await tester.pumpAndSettle();
    expect(api.redeemCalls, 1);
  });

  testWidgets('SukiPointsHistoryScreen loads cursor pages', (tester) async {
    final api = _FakeV2Api(
      detail: _v2Detail(),
      pages: [
        SukiPointsLedgerPage(
          cardId: 'card_111',
          balance: 40,
          lifetime: 100,
          items: [
            SukiPointsLedgerEntry(
              id: 'e1',
              delta: 25,
              reason: 'spend',
              amountSpent: 500,
              createdAt: DateTime.utc(2026, 11, 20),
            ),
          ],
          nextCursor: 'cursor_2',
        ),
        SukiPointsLedgerPage(
          cardId: 'card_111',
          balance: 40,
          lifetime: 100,
          items: [
            SukiPointsLedgerEntry(
              id: 'e2',
              delta: -30,
              reason: 'redeem',
              createdAt: DateTime.utc(2026, 11, 19),
            ),
          ],
          nextCursor: null,
        ),
      ],
    );
    await tester.pumpWidget(_host(
      const SukiPointsHistoryScreen(
        programId: 'suki_v2',
        cardId: 'card_111',
        shopName: 'Kapehan Suki',
      ),
      overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Balance: 40 pts'), findsOneWidget);
    expect(find.byKey(const ValueKey('suki_ledger_entry_e1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suki_points_load_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suki_ledger_entry_e2')), findsOneWidget);
    expect(find.byKey(const ValueKey('suki_points_load_more')), findsNothing);
  });

  group('no overflow at 2x text on 320x568 and 568x320', () {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('SukiCardScreen v2 $label', (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final api = _FakeV2Api(detail: _v2Detail(pointsEnabled: true));
        await tester.pumpWidget(_host(
          const SukiCardScreen(programId: 'suki_v2'),
          overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
          scale: 2,
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('suki_card_front')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SukiPointsHistoryScreen $label', (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final api = _FakeV2Api(
          detail: _v2Detail(),
          pages: [
            SukiPointsLedgerPage(
              cardId: 'card_111',
              balance: 40,
              lifetime: 100,
              items: [
                SukiPointsLedgerEntry(
                  id: 'e1',
                  delta: 15,
                  reason: 'visit',
                  createdAt: DateTime.utc(2026, 11, 20),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_host(
          const SukiPointsHistoryScreen(
              programId: 'suki_v2', cardId: 'card_111', shopName: 'Kapehan'),
          overrides: [_signedIn(), sukiApiProvider.overrideWithValue(api)],
          scale: 2,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('MerchantLoyaltyTab v2 multi-tier + points $label',
          (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final client = ApiClient(enableRetries: false);
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(onRequest: (options, handler) {
            Object? data;
            if (options.path == '/merchant/suki') {
              data = {
                'role': 'owner',
                'global_points_enabled': true,
                'program': _v2ProgramJson(pointsEnabled: true),
                'points_menu': [
                  {
                    'id': 'item_1',
                    'program_id': 'suki_v2',
                    'title': 'Iced Americano',
                    'points_cost': 30,
                    'icon_key': 'coffee',
                    'is_active': true,
                  }
                ],
                'checklist': {'has_location': true, 'is_published': true},
              };
            } else if (options.path == '/merchant/suki/stats') {
              data = {
                'days': 30,
                'visits_by_day': const [],
                'unique_customers': 5,
                'repeat_customers': 2,
                'new_to_app': 1,
                'rewards_issued': 3,
                'rewards_claimed': 2,
                'vouchers_confirmed': 1,
                'points_issued': 150,
                'points_redeemed': 60,
                'top_regulars': const [],
              };
            }
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': data},
            ));
          }),
        );

        await tester.pumpWidget(_host(
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: MerchantLoyaltyTab(),
            ),
          ),
          overrides: [apiClientProvider.overrideWithValue(client)],
          scale: 2,
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('loyalty_points_menu_editor')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
