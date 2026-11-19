import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/cosmetics/screens/appearance_screen.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/cosmetic_avatar.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/profile/widgets/avatar_picker.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_add_photo_sheet.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

/// v0.3.10 team review: profile picture, quest rows, plain "None",
/// no duplicate post button, and empty / full profile states.

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient);
  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _Auth extends AuthNotifier {
  _Auth(super.client, super.refresh, this.onRefresh) {
    state = AuthState(token: 't', user: _user(''));
  }
  final Future<String> Function() onRefresh;
  int refreshes = 0;

  static UserModel _user(String avatar) => UserModel(
        id: 'usr-owner',
        seedId: 'juanscout',
        displayName: 'Juan Scout',
        email: 'juan@example.com',
        avatarUrl: avatar,
        role: 'user',
        demoPoints: 120,
      );

  // The real refresh also writes secure storage (no plugin in tests).
  @override
  Future<void> refreshProfile() async {
    refreshes++;
    state = AuthState(token: 't', user: _user(await onRefresh()));
  }
}

class _Api {
  _Api({this.full = false});
  final bool full;
  final requests = <String>[];
  String avatar = '';

  ApiClient build() {
    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requests.add('${o.method} ${o.path}');
      Response<dynamic> ok(Object? data) =>
          Response(requestOptions: o, statusCode: 200, data: {
            'success': true,
            'data': data,
          });
      final p = o.path;
      if (p == '/users/me/avatar') {
        avatar = o.method == 'PUT'
            ? '/api/v1/uploads/spot-photos/spot_photo_me.jpg'
            : 'https://api.dicebear.com/7.x/identicon/svg?seed=juanscout';
        return h.resolve(ok({'avatar_url': avatar}));
      }
      if (p == '/me/showcase') return h.resolve(ok(full ? _showcase : {}));
      if (p == '/me/achievements') {
        return h.resolve(ok({'catalog': [], 'earned': []}));
      }
      if (p.endsWith('/spots')) {
        return h.resolve(ok({'spots': full ? _spots : []}));
      }
      if (p.endsWith('/quests')) {
        return h.resolve(ok({'quests': full ? _quests : []}));
      }
      if (p == '/shop/cosmetics' || p == '/shop/teasers') {
        return h.resolve(ok([]));
      }
      if (p == '/me/cosmetics') {
        return h.resolve(ok({
          'owned': [
            {
              'id': 'b1',
              'kind': 'banner',
              'name': 'Sunset Sea',
              'asset': {},
              'source': 'shop',
            }
          ],
          'loadout': {'banner_id': 'b1'},
        }));
      }
      return h.resolve(ok({}));
    }));
    return client;
  }
}

final _showcase = {
  'bio': 'Bangus lover from Dagupan. Chasing every sunset in Bolinao and '
      'every waterfall in the east of the province.',
  'home_municipality': 'San Carlos City',
  'featured_badges': [
    for (final i in [1, 2, 3])
      {'id': 'b$i', 'title': 'Very Long Badge Title Number $i'}
  ],
  'favorite_spot': {
    'id': 's1',
    'slug': 's1',
    'name': 'Hundred Islands',
    'municipality': 'Alaminos'
  },
  'stats': {
    'quests_completed': 123,
    'spots_posted': 45,
    'trails_completed': 6,
    'best_weekly_rank': 1
  },
  'pasaporte': {
    'visited': [for (var i = 0; i < 20; i++) 'Town $i'],
    'total': 48
  },
  'latest_journey': [
    for (var i = 0; i < 5; i++)
      {'title': 'Journey $i', 'municipality': 'Bolinao', 'at': '2026-11-10'}
  ],
};

final _spots = [
  for (var i = 0; i < 12; i++)
    {
      'id': 'sp$i',
      'slug': 'spot-$i',
      'name': 'A Very Long Hidden Destination Name Number $i',
      'municipality': 'San Fabian',
      'category': 'beach',
      'lat': 16.1,
      'lng': 120.4,
    }
];

final _quests = [
  {
    'id': 'qd',
    'title': 'Draft Quest',
    'status': 'draft',
    'reward_points': 50,
    'step_count': 1,
    'spot_name': 'Patar'
  },
  {
    'id': 'qp',
    'title': 'Published Quest',
    'status': 'published',
    'reward_points': 80,
    'step_count': 3,
    'spot_name': 'Bolinao'
  },
  for (var i = 0; i < 10; i++)
    {
      'id': 'q$i',
      'title': 'Hundred Islands Coastal Cleanup Adventure $i',
      'status': i.isEven ? 'published' : 'pending_review',
      'reward_points': 100,
      'step_count': 4,
      'spot_name': 'Hundred Islands National Park'
    },
];

Widget _app(_Api api,
    {String initial = '/profile', AvatarPhotoPicker? picker}) {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(
      path: '/profile',
      builder: (_, s) =>
          ProfileScreen(initialTab: s.uri.queryParameters['tab']),
    ),
    GoRoute(path: '/appearance', builder: (_, __) => const AppearanceScreen()),
    GoRoute(
      path: '/quests/:id',
      builder: (_, s) => Text('detail ${s.pathParameters['id']}'),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (_, s) => Text('builder ${s.pathParameters['id']}'),
        ),
      ],
    ),
  ]);
  final client = api.build();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith((r) => _Auth(r.read(apiClientProvider),
          r.read(authRefreshProvider.notifier), () async => api.avatar)),
      submissionProvider
          .overrideWith((r) => _SubmissionFixture(r.read(apiClientProvider))),
      if (picker != null) avatarPhotoPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp.router(theme: AppTheme.pixel, routerConfig: router),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('resolveAvatarUrl: uploads resolve, SVG defaults fall back', () {
    expect(resolveAvatarUrl(''), isNull);
    expect(resolveAvatarUrl(null), isNull);
    expect(
        resolveAvatarUrl(
            'https://api.dicebear.com/7.x/identicon/svg?seed=juanscout'),
        isNull);
    expect(resolveAvatarUrl('https://x.test/a.svg'), isNull);
    expect(resolveAvatarUrl('https://lh3.googleusercontent.com/a/pic'),
        'https://lh3.googleusercontent.com/a/pic');
    final up = resolveAvatarUrl('/api/v1/uploads/spot-photos/spot_photo_1.jpg');
    expect(up, startsWith('http'));
    expect(up, endsWith('/api/v1/uploads/spot-photos/spot_photo_1.jpg'));
  });

  testWidgets('item 1: choose from gallery uploads, then Remove resets',
      (tester) async {
    _tall(tester);
    final api = _Api();
    ImageSource? asked;
    await tester.pumpWidget(_app(api, picker: (source) async {
      asked = source;
      return PickedSpotPhoto(
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
          filename: 'me.jpg');
    }));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_avatar_edit')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('avatar_take_photo')), findsOneWidget);
    // Nothing to remove while the account shows its initial.
    expect(find.byKey(const ValueKey('avatar_remove_photo')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('avatar_choose_photo')));
    await _settle(tester);
    expect(asked, ImageSource.gallery);
    expect(api.requests, contains('PUT /users/me/avatar'));
    expect(find.text('Profile picture updated.'), findsOneWidget);
    // The uploaded (root-relative) picture is drawn instead of the initial.
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is NetworkImage &&
            (w.image as NetworkImage).url.endsWith('spot_photo_me.jpg')),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('profile_avatar_edit')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('avatar_remove_photo')));
    await _settle(tester);
    expect(api.requests, contains('DELETE /users/me/avatar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Photo removed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('item 1: Appearance has a Profile picture row', (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, initial: '/appearance'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('appearance_photo_change')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('avatar_choose_photo')), findsOneWidget);
  });

  testWidgets('item 4: "None" is plain text, not a button, and still clears',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, initial: '/appearance'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('appearance_banner_choose')));
    await _settle(tester);
    final none = find.byKey(const ValueKey('appearance_pick_none'));
    expect(none, findsOneWidget);
    expect(tester.widget(none), isNot(isA<PixelButton>()));
    expect(find.ancestor(of: none, matching: find.byType(PixelButton)),
        findsNothing);
    expect(find.descendant(of: none, matching: find.byType(PixelButton)),
        findsNothing);
    expect(
        find.descendant(of: none, matching: find.text('None')), findsOneWidget);
    // Owned items stay buttons.
    expect(find.byKey(const ValueKey('appearance_pick_b1')), findsOneWidget);
    await tester.tap(none);
    await _settle(tester);
    expect(none, findsNothing);
    expect(
        api.requests.any((r) => r.contains('equip') || r.contains('loadout')),
        isTrue);
  });

  testWidgets('items 2-3: quest rows have no Edit/Open button; tap opens it',
      (tester) async {
    _tall(tester);
    final api = _Api(full: true);
    await tester.pumpWidget(_app(api, initial: '/profile?tab=quests'));
    await _settle(tester);
    expect(find.text('EDIT ›'), findsNothing);
    expect(find.text('Edit ›'), findsNothing);
    expect(find.text('Open ›'), findsNothing);

    await tester.tap(find.text('Published Quest'));
    await _settle(tester);
    expect(find.text('detail qp'), findsOneWidget);
  });

  testWidgets('item 2: a draft row opens the quest builder', (tester) async {
    _tall(tester);
    final api = _Api(full: true);
    await tester.pumpWidget(_app(api, initial: '/profile?tab=quests'));
    await _settle(tester);
    await tester.tap(find.text('Draft Quest'));
    await _settle(tester);
    expect(find.text('builder qd'), findsOneWidget);
  });

  testWidgets('item 3: quest rows are spaced further apart', (tester) async {
    _tall(tester);
    final api = _Api(full: true);
    await tester.pumpWidget(_app(api, initial: '/profile?tab=quests'));
    await _settle(tester);
    final a = tester
        .getRect(find.byKey(const ValueKey('profile_quest_open_qd')).first);
    final b = tester
        .getRect(find.byKey(const ValueKey('profile_quest_open_qp')).first);
    final titleTop = tester.getTopLeft(find.text('Draft Quest')).dy;
    // Row padding is 4 grid units (was 2) above the first chip line.
    expect(b.top - a.bottom, greaterThanOrEqualTo(0));
    expect(titleTop - a.top, greaterThan(16));
  });

  testWidgets('items 5-6: empty profile has no duplicate post button',
      (tester) async {
    _tall(tester);
    final api = _Api();
    await tester.pumpWidget(_app(api));
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_no_spots')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_post_spot_empty')), findsNothing);
    expect(find.byKey(const ValueKey('profile_post_spot')), findsOneWidget);
    expect(find.textContaining('Tell other explorers'), findsOneWidget);

    // An empty "+ Equip" slot opens the badge picker (it did nothing before).
    await tester
        .ensureVisible(find.byKey(const ValueKey('profile_badge_slot_0')));
    await tester.tap(find.byKey(const ValueKey('profile_badge_slot_0')));
    await _settle(tester);
    expect(find.text('Equip badges'), findsOneWidget);
  });

  testWidgets('item 6: empty and full profiles have no overflow at 2.0x text',
      (tester) async {
    for (final full in [false, true]) {
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        for (final tab in ['overview', 'quests', 'progress', 'timeline']) {
          await tester
              .pumpWidget(_app(_Api(full: full), initial: '/profile?tab=$tab'));
          await _settle(tester);
          expect(tester.takeException(), isNull,
              reason: 'full=$full $tab at $size');
        }
        await tester.pumpWidget(_app(_Api(full: full), initial: '/appearance'));
        await _settle(tester);
        expect(tester.takeException(), isNull,
            reason: 'appearance full=$full at $size');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
