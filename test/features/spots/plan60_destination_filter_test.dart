import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/providers/user_spots_provider.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/profile/showcase.dart';
import 'package:juanderquest_app/features/shop/providers/cosmetics_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_posting_sheet.dart';

class _TestAuth extends AuthNotifier {
  _TestAuth(super.client, super.refresh, UserModel user) {
    state = AuthState(user: user, token: 'tok-plan60');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _TestCosmetics extends CosmeticsNotifier {
  _TestCosmetics(super.ref) {
    state = const CosmeticsState();
  }

  @override
  Future<void> load() async {}
}

class _TestDiscovery extends SpotDiscoveryNotifier {
  _TestDiscovery(super.ref) {
    state = const SpotDiscoveryState(isInitialLoading: false);
  }

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {}
}

const _recognition = {
  'recognized': true,
  'place_name': 'Patar White Beach',
  'name_suggestions': ['Patar White Beach'],
  'formatted_address': 'Patar Road, Bolinao, Pangasinan',
  'municipality': 'Bolinao',
  'barangay': 'Brgy. Patar',
  'outside_pangasinan': false,
  'suggested_category': 'nature_outdoors',
  'suggested_subcategory': 'beach',
  'suggested_details': <String, dynamic>{},
  'story_starters': <String>[],
  'nearby_duplicates': <dynamic>[],
};

final _ownerUser = UserModel(
  id: 'u-p60',
  seedId: 'seed-p60',
  displayName: 'Juan Scout',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'user',
  demoPoints: 500,
);

final _emptyStats = ProfileStatsModel(
  completedQuestsCount: 1,
  pendingSubmissionsCount: 0,
  totalPointsEarned: 50,
  ecoPioneerState: BadgeState.locked,
  heritageKeeperState: BadgeState.locked,
  foodExplorerState: BadgeState.locked,
);

void _setViewport(WidgetTester tester, Size size, double textScale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets(
      'SpotPostingSheet shows inline hold reasons, Use X instead duplicate action, and Update & resubmit flow',
      (tester) async {
    int patchCalls = 0;
    SpotDuplicateHint? usedDuplicate;
    SpotModel? finalPublished;

    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (opt, handler) {
      if (opt.path == '/spots/recognize') {
        return handler.resolve(Response(
          requestOptions: opt,
          statusCode: 200,
          data: {'success': true, 'data': _recognition},
        ));
      }
      if (opt.path == '/spots' && opt.method == 'POST') {
        return handler.resolve(Response(
          requestOptions: opt,
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'id': 'spot-held-60',
              'slug': 'patar-white-beach-held',
              'name': 'Patar White Beach',
              'description': 'A long scenic white-sand coastline in Bolinao.',
              'category': 'nature_outdoors',
              'subcategory': 'beach',
              'municipality': 'Bolinao',
              'address': 'Patar Road, Bolinao',
              'source_name': 'Community',
              'trust_level': 'community',
              'gps_lat': 16.3268,
              'gps_lng': 119.7842,
              'status': 'held',
              'moderation_reasons': ['POSSIBLE_DUPLICATE'],
              'moderation_messages': ['Is this the same as Patar Beach?'],
              'duplicate_spot': {
                'id': 'spot-orig-1',
                'slug': 'patar-beach',
                'name': 'Patar Beach',
                'municipality': 'Bolinao',
              },
            },
          },
        ));
      }
      if (opt.path == '/spots/spot-held-60' && opt.method == 'PATCH') {
        patchCalls++;
        return handler.resolve(Response(
          requestOptions: opt,
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': 'spot-held-60',
              'slug': 'patar-white-beach-held',
              'name': 'Patar North Cove',
              'description': 'Clean beach cove along Patar North Shore.',
              'category': 'nature_outdoors',
              'subcategory': 'beach',
              'municipality': 'Bolinao',
              'address': 'Patar Road, Bolinao',
              'source_name': 'Community',
              'trust_level': 'community',
              'gps_lat': 16.3268,
              'gps_lng': 119.7842,
              'status': 'published',
              'moderation_reasons': <String>[],
              'moderation_messages': <String>[],
            },
          },
        ));
      }
      return handler.next(opt);
    }));

    Future<void> pumpSheet(Size size) async {
      _setViewport(tester, size, 2.0);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              home: Scaffold(
                body: SpotPostingSheet(
                  key: ValueKey('sheet_${size.width}x${size.height}'),
                  initialLat: 16.3268,
                  initialLng: 119.7842,
                  embedded: true,
                  onUseDuplicate: (hint) => usedDuplicate = hint,
                  onPublished: (spot) => finalPublished = spot,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpSheet(const Size(320, 568));
    await tester
        .ensureVisible(find.byKey(const ValueKey('studio_description')));
    await tester.enterText(find.byKey(const ValueKey('studio_description')),
        'A long scenic white-sand coastline in Bolinao.');
    await tester.tap(find.byKey(const ValueKey('studio_publish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spot_hold_banner')), findsOneWidget);
    expect(find.text('Is this the same as Patar Beach?'), findsOneWidget);
    expect(find.text('Use Patar Beach instead'), findsOneWidget);
    expect(find.text('Update & resubmit'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Trigger duplicate button
    await tester
        .ensureVisible(find.byKey(const ValueKey('spot_use_duplicate')));
    await tester.tap(find.byKey(const ValueKey('spot_use_duplicate')));
    await tester.pump();
    expect(usedDuplicate?.slug, 'patar-beach');

    // Resubmit via PATCH -> transitions to published
    await tester.ensureVisible(find.byKey(const ValueKey('studio_publish')));
    await tester.tap(find.byKey(const ValueKey('studio_publish')));
    await tester.pumpAndSettle();
    expect(patchCalls, 1);
    expect(finalPublished?.status, 'published');
    expect(tester.takeException(), isNull);

    // Verify zero overflow on small landscape at 2.0x text scale
    await pumpSheet(const Size(568, 320));
    await tester
        .ensureVisible(find.byKey(const ValueKey('studio_description')));
    await tester.enterText(find.byKey(const ValueKey('studio_description')),
        'A long scenic white-sand coastline in Bolinao.');
    await tester.ensureVisible(find.byKey(const ValueKey('studio_publish')));
    await tester.tap(find.byKey(const ValueKey('studio_publish')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('spot_hold_banner')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('spot_hold_banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ProfileScreen renders HELD and AUTO-HIDDEN badges with reason for owner without overflow at 2.0x',
      (tester) async {
    const spots = [
      SpotModel(
        id: 'sp-1',
        slug: 'held-cove',
        name: 'Held Cove',
        description: 'Description here',
        category: 'nature_outdoors',
        subcategory: 'beach',
        municipality: 'Bolinao',
        address: 'Patar',
        sourceName: 'Community',
        trustLevel: 'community',
        gpsLat: 16.3,
        gpsLng: 119.8,
        tags: [],
        reasons: [],
        status: 'held',
        moderationReasons: ['TEXT_BLOCKED'],
        moderationMessages: ['Remove web links or blocked words.'],
      ),
      SpotModel(
        id: 'sp-2',
        slug: 'hidden-falls',
        name: 'Hidden Falls',
        description: 'Description here',
        category: 'nature_outdoors',
        subcategory: 'waterfall',
        municipality: 'Bolinao',
        address: 'Bolinao',
        sourceName: 'Community',
        trustLevel: 'community',
        gpsLat: 16.3,
        gpsLng: 119.8,
        tags: [],
        reasons: [],
        status: 'hidden_pending_review',
        moderationReasons: ['REPORT_THRESHOLD'],
        moderationMessages: ['Hidden pending moderator review.'],
      ),
    ];

    Future<void> pumpProfile(Size size) async {
      _setViewport(tester, size, 2.0);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: '/explore/:slug',
              builder: (_, __) => const Scaffold(body: Text('Spot'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuth(
                  ref.read(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  _ownerUser,
                )),
            profileStatsProvider.overrideWithValue(_emptyStats),
            showcaseProvider.overrideWith((ref, key) async => null),
            cosmeticsProvider.overrideWith((ref) => _TestCosmetics(ref)),
            spotDiscoveryProvider.overrideWith((ref) => _TestDiscovery(ref)),
            userSpotsProvider.overrideWith((ref, handle) async => spots),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpProfile(const Size(320, 568));
    await tester.scrollUntilVisible(
      find.text('HELD'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HELD'), findsOneWidget);
    expect(find.text('Remove web links or blocked words.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('AUTO-HIDDEN'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AUTO-HIDDEN'), findsOneWidget);
    expect(find.text('Hidden pending moderator review.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpProfile(const Size(568, 320));
    await tester.scrollUntilVisible(
      find.text('HELD'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HELD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
