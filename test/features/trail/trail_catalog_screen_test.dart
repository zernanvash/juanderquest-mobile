import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';
import 'package:juanderquest_app/features/trail/trail_catalog_screen.dart';

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null ? AuthState() : AuthState(user: user, token: 't');
  }

  @override
  Future<void> refreshProfile() async {}
}

final _user = UserModel(
  id: 'u-trail',
  seedId: 'trail_scout',
  displayName: 'Trail Scout',
  email: 'scout@juanderquest.ph',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 500,
);

Map<String, dynamic> _trail(
  String id,
  String tier, {
  bool unlocked = false,
  int price = 0,
}) => {
  'id': id,
  'title': 'Trail $id',
  'tier': tier,
  'stop_count': 2,
  'total_minutes': 90,
  'total_km': 5,
  'unlock_rule': price > 0
      ? {'type': 'points', 'price_points': price}
      : {'type': 'free'},
  'is_unlocked': unlocked,
};

class _FakeTrailsApi extends TrailsApi {
  _FakeTrailsApi({this.generation}) : super(ApiClient());

  final PersonalGeneration? generation;
  final unlocked = <String>{};
  final createKeys = <String>[];
  Map<String, Object?>? lastCreate;
  int loads = 0;
  bool failCreate = false;

  @override
  Future<TrailCatalog> fetchTrails() async {
    loads++;
    return TrailCatalog(
      items: [
        _trail('starter', 'starter', unlocked: true),
        _trail(
          'hiyas',
          'signature',
          unlocked: unlocked.contains('hiyas'),
          price: 150,
        ),
        if (createKeys.isNotEmpty && !failCreate)
          _trail('mine', 'personal', unlocked: true),
      ].map(NearbyTrail.fromJson).toList(),
      personalGeneration: generation,
    );
  }

  @override
  Future<Map<String, dynamic>> unlockTrail(String id) async {
    unlocked.add(id);
    return {};
  }

  @override
  Future<TrailDetail> fetchTrail(String id) async => TrailDetail.fromJson({
    'id': id,
    'title': 'Trail $id',
    'tier': 'starter',
    'is_unlocked': true,
    'stops': [
      {'position': 1, 'name': 'First', 'lat': 16.0, 'lng': 120.3},
      {'position': 2, 'name': 'Last Stop', 'lat': 16.2, 'lng': 120.04},
    ],
  });

  @override
  Future<String> createPersonalTrail({
    required String idempotencyKey,
    String? text,
    List<String> themes = const [],
    int? budgetMin,
    String? pace,
  }) async {
    createKeys.add(idempotencyKey);
    lastCreate = {
      'text': text,
      'themes': themes,
      'budget_min': budgetMin,
      'pace': pace,
    };
    if (failCreate) throw Exception('Generator is busy');
    return 'mine';
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeTrailsApi api, {
  UserModel? user,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/trail',
    routes: [
      GoRoute(path: '/trail', builder: (_, __) => const TrailCatalogScreen()),
      GoRoute(
        path: '/navigate',
        builder: (_, state) => Scaffold(body: Text('nav:${state.uri}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trailsApiProvider.overrideWithValue(api),
        authProvider.overrideWith(
          (ref) => _InertAuth(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            user,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Plan 83c: the `/trail` catalog replaces the coming-soon page.
void main() {
  testWidgets('Discover lists public trails; My Trails lists unlocked ones', (
    tester,
  ) async {
    await _pump(tester, _FakeTrailsApi(), user: _user);
    expect(find.byKey(const ValueKey('trail_card_starter')), findsOneWidget);
    expect(find.byKey(const ValueKey('trail_card_hiyas')), findsOneWidget);
    expect(find.text('150 PTS'), findsOneWidget);

    await tester.tap(find.text('My Trails'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trail_card_starter')), findsOneWidget);
    expect(find.byKey(const ValueKey('trail_card_hiyas')), findsNothing);
  });

  testWidgets('an unlocked trail opens navigation to its last stop', (
    tester,
  ) async {
    await _pump(tester, _FakeTrailsApi(), user: _user);
    await tester.tap(find.byKey(const ValueKey('trail_card_starter')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'nav:/navigate?trail_id=starter&name=Last+Stop'
        '&lat=16.2&lng=120.04',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a priced trail asks first, unlocks, then navigates', (
    tester,
  ) async {
    final api = _FakeTrailsApi();
    await _pump(tester, api, user: _user);
    await tester.tap(find.byKey(const ValueKey('trail_card_hiyas')));
    await tester.pumpAndSettle();
    expect(find.textContaining('costs 150 points'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trail_unlock_confirm')));
    await tester.pumpAndSettle();
    expect(api.unlocked, {'hiyas'});
    expect(find.textContaining('nav:/navigate?trail_id=hiyas'), findsOneWidget);
  });

  testWidgets('signed out: locked trails ask to log in, Create is gated', (
    tester,
  ) async {
    final api = _FakeTrailsApi();
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('trail_card_hiyas')));
    await tester.pump();
    expect(find.text('Log in to start a trail'), findsOneWidget);
    expect(api.unlocked, isEmpty);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trail_create_login')), findsOneWidget);
  });

  testWidgets('Create sends the form, keeps the key for a retry, then '
      'shows the new trail in My Trails', (tester) async {
    final api = _FakeTrailsApi(
      generation: const PersonalGeneration(freeRemaining: 1, pricePoints: 80),
    )..failCreate = true;
    await _pump(tester, api, user: _user);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Free this week: 1 left'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail_create_submit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trail_create_error')), findsOneWidget);
    expect(api.createKeys, isEmpty);

    await tester.tap(find.byKey(const ValueKey('trail_theme_nature_outdoors')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trail_create_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Generator is busy'), findsOneWidget);

    api.failCreate = false;
    await tester.tap(find.byKey(const ValueKey('trail_create_submit')));
    await tester.pumpAndSettle();
    expect(api.createKeys, hasLength(2));
    expect(api.createKeys[0], api.createKeys[1]);
    expect(api.lastCreate, {
      'text': '',
      'themes': ['nature_outdoors'],
      'budget_min': 240,
      'pace': 'balanced',
    });
    expect(find.byKey(const ValueKey('trail_card_mine')), findsOneWidget);
  });
}
