import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/nearby_merchants_section.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/quest_traveler_preview_card.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/quests/screens/sponsor_request_screen.dart';

Map<String, dynamic> _merchant(
  String id,
  String name, {
  Object? distance,
  bool sameTown = false,
  String town = 'Bolinao',
}) =>
    {
      'id': id,
      'name': name,
      'municipality': town,
      'category': 'cafe',
      'description': '',
      'same_municipality': sameTown,
      'distance_m': distance,
      'vouchers': [],
    };

class _Fake {
  _Fake({
    required this.merchants,
    this.plan,
    this.directoryStatus = 200,
  });

  final List<Map<String, dynamic>> merchants;
  final Map<String, dynamic>? plan;
  final int directoryStatus;
  Map<String, dynamic>? directoryQuery;

  ApiClient client() {
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == '/sponsor-directory') {
          directoryQuery = Map<String, dynamic>.from(options.queryParameters);
          if (directoryStatus != 200) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: directoryStatus,
                data: {
                  'success': false,
                  'error': {'code': 'NOT_AVAILABLE', 'message': 'Off'},
                },
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'items': merchants, 'page': 1},
            },
          ));
        }
        if (options.path.endsWith('/funding-plan')) {
          if (plan == null) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'plan': plan},
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
    return client;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Fake fake, {
  String? questId = 'quest-1',
  ValueChanged<List<NearbySponsorInvite>>? onInvites,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(fake.client())],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NearbyMerchantsSection(
              questId: questId,
              pinLat: 16.3,
              pinLng: 119.8,
              onInvitesChanged: onInvites,
            ),
          ],
        ),
      ),
    ),
  ));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  final merchants = [
    _merchant('far', 'Far Cafe', distance: 4200),
    _merchant('out', 'Out Of Range Diner', distance: 12000, town: 'Alaminos'),
    _merchant('town', 'Town Bakery', sameTown: true),
    _merchant('near', 'Near Kapihan', distance: '350'),
  ];

  testWidgets('lists nearby merchants sorted by distance from the pin',
      (tester) async {
    final fake = _Fake(merchants: merchants);
    await _pump(tester, fake);

    expect(fake.directoryQuery?['quest_id'], 'quest-1');
    expect(fake.directoryQuery?['lat'], 16.3);
    expect(fake.directoryQuery?['lng'], 119.8);
    expect(find.text('Out Of Range Diner'), findsNothing);
    final near = tester.getTopLeft(find.text('Near Kapihan')).dy;
    final far = tester.getTopLeft(find.text('Far Cafe')).dy;
    final town = tester.getTopLeft(find.text('Town Bakery')).dy;
    expect(near < far, isTrue);
    expect(far < town, isTrue);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget);
    expect(find.text('IN TOWN'), findsOneWidget);
  });

  testWidgets('invite opens the sponsorship request form for that shop',
      (tester) async {
    List<NearbySponsorInvite> invites = const [];
    final fake = _Fake(
      merchants: merchants,
      plan: {
        'id': 'plan-1',
        'status': 'pending_sponsors',
        'sponsorships': [
          {
            'merchant_id': 'far',
            'merchant_name': 'Far Cafe',
            'status': 'requested',
          },
        ],
      },
    );
    await _pump(tester, fake, onInvites: (v) => invites = v);

    expect(invites.map((i) => i.name), ['Far Cafe']);
    expect(find.byKey(const ValueKey('nearby_invited_far')), findsOneWidget);
    expect(find.byKey(const ValueKey('nearby_invite_far')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nearby_invite_near')));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<SponsorRequestScreen>(find.byType(SponsorRequestScreen));
    expect(screen.planId, 'plan-1');
    expect(screen.initialMerchant?.id, 'near');
    expect(find.byKey(const ValueKey('sponsor_request_send')), findsOneWidget);
  });

  testWidgets('invite without an open funding round opens the funding screen',
      (tester) async {
    final fake = _Fake(merchants: merchants);
    await _pump(tester, fake);
    await tester.tap(find.byKey(const ValueKey('nearby_invite_near')));
    await tester.pumpAndSettle();
    expect(find.byType(QuestFundingScreen), findsOneWidget);
    expect(find.byType(SponsorRequestScreen), findsNothing);
  });

  testWidgets('empty state when no shop is nearby', (tester) async {
    final fake = _Fake(merchants: [
      _merchant('out', 'Out Of Range Diner', distance: 12000),
    ]);
    await _pump(tester, fake);
    expect(
        find.byKey(const ValueKey('nearby_merchants_empty')), findsOneWidget);
  });

  testWidgets('unsaved quest asks to save first; funding off says so',
      (tester) async {
    final fake = _Fake(merchants: merchants);
    await _pump(tester, fake, questId: null);
    expect(find.byKey(const ValueKey('nearby_merchants_save_first')),
        findsOneWidget);
    expect(fake.directoryQuery, isNull);

    final off = _Fake(merchants: merchants, directoryStatus: 404);
    await _pump(tester, off, questId: 'quest-2');
    expect(find.byKey(const ValueKey('nearby_merchants_unavailable')),
        findsOneWidget);
  });

  testWidgets('review card lists invited sponsors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: const Scaffold(
        body: QuestTravelerPreviewCard(
          state: QuestBuilderState(
            title: 'Explore',
            description: 'A walk',
            category: 'eco',
            rewardPoints: 50,
            stepOrderMode: 'sequential',
            status: 'draft',
            tasks: [],
            version: 1,
          ),
          locationName: 'Bolinao',
          sponsorInvites: [
            NearbySponsorInvite(
                merchantId: 'far', name: 'Far Cafe', status: 'accepted'),
          ],
        ),
      ),
    ));
    expect(
        find.byKey(const ValueKey('preview_sponsor_invites')), findsOneWidget);
    expect(find.text('Far Cafe · ACCEPTED'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
        'nearby merchants do not overflow at ${size.width}x${size.height} 2x',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = _Fake(merchants: [
        _merchant('near',
            'A Very Long Merchant Name For The Bolinao Coastal Kapihan Shop',
            distance: 350),
        ...merchants,
      ], plan: {
        'id': 'plan-1',
        'status': 'active',
        'sponsorships': [
          {
            'merchant_id': 'far',
            'merchant_name': 'Far Cafe',
            'status': 'countered',
          },
        ],
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fake.client())],
        child: MaterialApp(
          theme: AppTheme.pixel,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                NearbyMerchantsSection(
                  questId: 'quest-1',
                  pinLat: 16.3,
                  pinLng: 119.8,
                ),
                QuestTravelerPreviewCard(
                  state: QuestBuilderState(
                    title: 'Explore',
                    description: 'A walk',
                    category: 'eco',
                    rewardPoints: 50,
                    stepOrderMode: 'sequential',
                    status: 'draft',
                    tasks: [],
                    version: 1,
                  ),
                  locationName: 'Bolinao',
                  sponsorInvites: [
                    NearbySponsorInvite(
                      merchantId: 'far',
                      name: 'A Very Long Merchant Name For The Coastal Shop',
                      status: 'countered',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
