import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_add_photo_sheet.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_cover_picker_sheet.dart';

// Plan 124b (owner 2026-11-26): "authors can select cover photos from the
// uploaded approved photos in the post and should allow multi photo".

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null
        ? AuthState()
        : AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

UserModel _user(String id, {String role = 'explorer'}) => UserModel(
      id: id,
      seedId: id,
      email: '$id@juanderquest.app',
      displayName: id,
      avatarUrl: '',
      role: role,
      demoPoints: 0,
    );

final _bytes = Uint8List.fromList(List<int>.filled(16, 7));

const _a1 = SpotCoverCandidate(
  assetId: 'a1',
  url: 'https://cdn.example/a1.jpg',
);
const _a2 = SpotCoverCandidate(
  assetId: 'a2',
  url: 'https://cdn.example/a2.jpg',
);

SpotModel _spot({required String author, String? cover}) => SpotModel(
      id: 'spot-124b',
      slug: 'p124b-cove',
      name: 'P124b Cove',
      description: 'Cove.',
      category: 'nature_outdoors',
      subcategory: 'beach',
      municipality: 'Alaminos',
      address: 'Alaminos, Pangasinan',
      sourceName: 'Author',
      trustLevel: 'community',
      gpsLat: 16.15,
      gpsLng: 119.98,
      tags: const [],
      reasons: const [],
      createdBy: author,
      imageUrl: cover ?? _a1.url,
      media: [SpotPhoto(url: _a1.url), SpotPhoto(url: _a2.url)],
      coverCandidates: const [_a1, _a2],
    );

ApiClient _client(
  List<(String, String, dynamic)> calls, {
  int failPhotoPostAt = -1,
}) {
  final client = ApiClient(enableRetries: false);
  var photoPosts = 0;
  var uploads = 0;
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        calls.add((options.method, options.path, options.data));
        if (options.path == '/spot-media') {
          uploads++;
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {'asset_id': 'up-$uploads'},
            },
          ));
        }
        if (options.path.endsWith('/photos') && options.method == 'POST') {
          final n = photoPosts++;
          if (n == failPhotoPostAt) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 429,
                data: {
                  'success': false,
                  'error': {'message': 'Too many pending photos.'},
                },
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {'status': 'pending'},
            },
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': []},
        ));
      },
    ),
  );
  return client;
}

Widget _host(ApiClient client, Widget child, {UserModel? user}) =>
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith(
          (ref) => _InertAuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            user,
          ),
        ),
      ],
      child: MaterialApp(theme: AppTheme.pixel, home: child),
    );

void main() {
  group('SpotCoverCandidate.fromSpotJson', () {
    test('keeps approved images with ids, drops videos/pending/duplicates', () {
      final list = SpotCoverCandidate.fromSpotJson({
        'attached_assets': [
          {
            'id': 'u1',
            'url': 'https://cdn.example/u1.jpg',
            'status': 'attached'
          },
          {
            'id': 'v1',
            'url': 'https://cdn.example/v1.mp4',
            'status': 'attached',
            'media_type': 'video',
          },
          {
            'id': 'p1',
            'url': 'https://cdn.example/p1.jpg',
            'status': 'pending'
          },
          {'url': 'https://cdn.example/no-id.jpg'},
        ],
        'photos': [
          {'id': 'c1', 'url': 'https://cdn.example/c1.jpg'},
          {'id': 'u1', 'url': 'https://cdn.example/u1.jpg'},
        ],
      });
      expect(list.map((c) => c.assetId), ['u1', 'c1']);
    });
  });

  group('SpotCoverPickerSheet', () {
    Future<void> open(
      WidgetTester tester,
      SpotCoverPickFn onPick,
      void Function(String?) done,
    ) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.pixel,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => done(await SpotCoverPickerSheet.show(
                context,
                candidates: const [_a1, _a2],
                currentUrl: _a1.url,
                onPick: onPick,
              )),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('marks the current cover and returns the picked url',
        (tester) async {
      final picked = <String>[];
      String? result;
      await open(tester, (id) async {
        picked.add(id);
        return _a2.url;
      }, (r) => result = r);
      expect(find.byKey(const ValueKey('spot_cover_badge_a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_cover_badge_a2')), findsNothing);

      // Tapping the current cover changes nothing.
      await tester.tap(find.byKey(const ValueKey('spot_cover_option_a1')));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);

      await tester.tap(find.byKey(const ValueKey('spot_cover_option_a2')));
      await tester.pumpAndSettle();
      expect(picked, ['a2']);
      expect(result, _a2.url);
    });

    testWidgets('shows an error and stays open when the change fails',
        (tester) async {
      await open(tester, (_) async => throw Exception('nope'), (_) {});
      await tester.tap(find.byKey(const ValueKey('spot_cover_option_a2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spot_cover_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_cover_picker_sheet')),
          findsOneWidget);
    });
  });

  group('SpotAddPhotoSheet multi-photo', () {
    Future<void> openSheet(
      WidgetTester tester,
      ApiClient client,
      void Function(bool?) done,
    ) async {
      var n = 0;
      await tester.pumpWidget(_host(
        client,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => done(await SpotAddPhotoSheet.show(
                context,
                spot: _spot(author: 'someone'),
                pickPhotoOverride: (_) async =>
                    PickedSpotPhoto(bytes: _bytes, filename: 'p${++n}.png'),
              )),
              child: const Text('Open'),
            ),
          ),
        ),
        user: _user('u-124b'),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('spot_add_photo_gallery')));
      await tester.pumpAndSettle();
    }

    testWidgets('sends every picked photo for review', (tester) async {
      final calls = <(String, String, dynamic)>[];
      bool? popped;
      await openSheet(tester, _client(calls), (r) => popped = r);
      await pick(tester);
      await pick(tester);
      expect(find.text('p1.png'), findsOneWidget);
      expect(find.text('p2.png'), findsOneWidget);
      expect(find.text('2/3 photos'), findsOneWidget);
      expect(find.text('SEND 2 FOR REVIEW'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('spot_add_photo_submit')));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      final posts = calls
          .where((c) => c.$1 == 'POST' && c.$2 == '/spots/spot-124b/photos')
          .map((c) => (c.$3 as Map)['asset_id'])
          .toList();
      expect(posts, ['up-1', 'up-2']);
    });

    testWidgets('stops at the limit of 3', (tester) async {
      await openSheet(tester, _client([]), (_) {});
      for (var i = 0; i < 4; i++) {
        await pick(tester);
      }
      expect(find.text('3/3 photos'), findsOneWidget);
      expect(find.text('p4.png'), findsNothing);
      final gallery = tester.widget<PixelButton>(
          find.byKey(const ValueKey('spot_add_photo_gallery')));
      expect(gallery.onPressed, isNull);
    });

    testWidgets('a failed send keeps only the unsent photos', (tester) async {
      bool? popped;
      await openSheet(
        tester,
        _client([], failPhotoPostAt: 1),
        (r) => popped = r,
      );
      await pick(tester);
      await pick(tester);
      await tester.tap(find.byKey(const ValueKey('spot_add_photo_submit')));
      await tester.pumpAndSettle();
      expect(popped, isNull);
      expect(find.text('p1.png'), findsNothing);
      expect(find.text('p2.png'), findsOneWidget);
      expect(find.text('Too many pending photos.'), findsOneWidget);
    });
  });

  group('small screens at 2.0x text (zero overflow)', () {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('cover picker and a full add-photo sheet fit $size',
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        Widget scaled(Widget child) => Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child,
              ),
            );
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: scaled(SpotCoverPickerSheet(
              candidates: const [_a1, _a2],
              currentUrl: _a1.url,
              onPick: (_) async => _a2.url,
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        var n = 0;
        await tester.pumpWidget(_host(
          _client([]),
          Scaffold(
            body: scaled(SpotAddPhotoSheet(
              spot: _spot(author: 'someone'),
              pickPhotoOverride: (_) async => PickedSpotPhoto(
                  bytes: _bytes, filename: 'a-long-photo-name-${++n}.png'),
            )),
          ),
          user: _user('u-124b'),
        ));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(
              find.byKey(const ValueKey('spot_add_photo_gallery')));
          await tester
              .tap(find.byKey(const ValueKey('spot_add_photo_gallery')));
          await tester.pumpAndSettle();
        }
        expect(find.text('3/3 photos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Spot detail CHOOSE COVER', () {
    Future<void> pumpDetail(WidgetTester tester, UserModel user) async {
      await tester.pumpWidget(_host(
        _client([]),
        SpotDetailScreen(spot: _spot(author: 'author-124b')),
        user: user,
      ));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('spot_photos_section')),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('author sees Choose cover', (tester) async {
      await pumpDetail(tester, _user('author-124b'));
      expect(find.byKey(const ValueKey('spot_photos_choose_cover')),
          findsOneWidget);
    });

    testWidgets('other travelers do not', (tester) async {
      await pumpDetail(tester, _user('someone-else'));
      expect(
          find.byKey(const ValueKey('spot_photos_choose_cover')), findsNothing);
    });
  });
}
