import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/collapsible_spot_photo.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_featured_card.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_spot_card.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/theater/theater_still_photo.dart';
import 'package:juanderquest_app/features/spots/theater/theater_title_block.dart';

// Network images always fail in flutter_test (HTTP 400), which stands in for a
// photo that was taken down.

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

SpotModel _spot({String? imageUrl, List<SpotPhoto> media = const []}) =>
    SpotModel(
      id: 'spot-98',
      slug: 'spot-98',
      name: 'Tondol White Sand Beach',
      description: 'Shallow water and soft sand at low tide.',
      category: 'beach',
      subcategory: 'beach',
      municipality: 'Anda',
      address: 'Tondol, Anda',
      sourceName: 'Community',
      trustLevel: 'community',
      gpsLat: 16.3,
      gpsLng: 120.0,
      tags: const [],
      reasons: const [],
      imageUrl: imageUrl,
      media: media,
    );

Widget _app(Widget home) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'data': options.path.contains('/alternatives') ||
                  options.path.contains('/comments')
              ? []
              : {},
        },
      )),
    ),
  );
  final user = UserModel(
    id: 'traveler-1',
    seedId: 'traveler-1',
    email: 'traveler@juanderquest.app',
    displayName: 'Traveler One',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 0,
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith((ref) => _InertAuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            user,
          )),
    ],
    child: MaterialApp(theme: AppTheme.pixel, home: home),
  );
}

ExploreSpotCard _card(SpotModel spot) => ExploreSpotCard(
      spot: spot,
      likeCount: 0,
      isLiked: false,
      isSaved: false,
      onTapCard: () {},
      onToggleLike: () {},
      onToggleSave: () {},
      onPlayQuest: null,
    );

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(CollapsibleSpotPhoto.resetFailedUrls);

  group('Explore cards (Plan 98 2.1)', () {
    testWidgets('no photo: no photo area, no placeholder strip',
        (tester) async {
      await _size(tester, const Size(400, 900));
      await tester.pumpWidget(_app(Scaffold(body: _card(_spot()))));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const Key('explore_photo_collapsed')), findsOneWidget);
      expect(find.textContaining('EXPLORE'), findsNothing);
    });

    testWidgets('a photo that fails collapses instead of Photo unavailable',
        (tester) async {
      await _size(tester, const Size(400, 900));
      final spot = _spot(imageUrl: 'https://photos.example/taken-down.jpg');
      await tester.pumpWidget(_app(Scaffold(
        body: ListView(children: [
          ExploreFeaturedCard(spot: spot, onTap: () {}),
          _card(spot),
        ]),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Photo unavailable'), findsNothing);
      expect(find.byType(AspectRatio), findsNothing);
      expect(
          find.byKey(const Key('explore_photo_collapsed')), findsNWidgets(2));
    });
  });

  group('Spot page (Plan 98 2.2)', () {
    testWidgets('a broken cover photo moves on to the gallery photos in order',
        (tester) async {
      await _size(tester, const Size(400, 900));
      final seen = <String?>[];
      final spot = _spot(
        imageUrl: 'https://photos.example/cover.jpg',
        media: const [
          SpotPhoto(url: 'https://photos.example/cover.jpg'),
          SpotPhoto(url: 'https://photos.example/clip.mp4', isVideo: true),
          SpotPhoto(url: 'https://photos.example/second.jpg'),
        ],
      );
      expect(SpotStillPhoto.candidateUrlsFor(spot), [
        'https://photos.example/cover.jpg',
        'https://photos.example/second.jpg',
      ]);
      await tester.pumpWidget(MaterialApp(
        home: SpotStillPhoto(spot: spot, onPhotoChanged: seen.add),
      ));
      await tester.pumpAndSettle();
      // It tried the second photo next (here it fails too, so it ends at none).
      expect(seen, ['https://photos.example/second.jpg', null]);
    });

    testWidgets('broken cover with gallery photos keeps the Gallery button',
        (tester) async {
      await _size(tester, const Size(400, 900));
      await tester.pumpWidget(_app(SpotDetailScreen(
        spot: _spot(
          imageUrl: 'https://photos.example/cover.jpg',
          media: const [
            SpotPhoto(url: 'https://photos.example/cover.jpg'),
            SpotPhoto(url: 'https://photos.example/second.jpg'),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('theater_gallery_btn')), findsNothing);
      expect(find.byKey(const ValueKey('spot_photos_section')), findsOneWidget);
    });

    testWidgets('no photos at all: one placeholder and a shorter header',
        (tester) async {
      await _size(tester, const Size(400, 900));
      await tester.pumpWidget(_app(SpotDetailScreen(spot: _spot())));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('theater_no_photo_placeholder')),
          findsOneWidget);
      expect(find.byKey(const Key('theater_gallery_btn')), findsNothing);
      final header = tester
          .getSize(find.byKey(const Key('theater_first_viewport_compact')));
      expect(header.height, lessThan(520));
      expect(find.text('Tondol White Sand Beach'), findsWidgets);
    });

    // Owner 2026-11-20: without a photo there is nothing to scroll past, so ADD PHOTO shows at
    // once and the SCROLL hint is hidden.
    testWidgets('no photos at all: ADD PHOTO at once, no scroll hint',
        (tester) async {
      await _size(tester, const Size(400, 900));
      await tester.pumpWidget(_app(SpotDetailScreen(spot: _spot())));
      await tester.pumpAndSettle();
      final compact = find.byKey(const Key('theater_first_viewport_compact'));
      expect(
          find.descendant(
              of: compact,
              matching: find.byKey(const ValueKey('spot_add_photo'))),
          findsOneWidget);
      expect(find.text('SCROLL ▼'), findsNothing);
    });

    testWidgets('with a cover photo: SCROLL hint, ADD PHOTO waits for a scroll',
        (tester) async {
      await _size(tester, const Size(400, 900));
      Widget viewport(double offset) => _app(Scaffold(
            body: SingleChildScrollView(
              child: TheaterFirstViewport(
                spot: _spot(),
                scrollOffset: offset,
                onDirections: () {},
                onPlayQuest: () {},
                onAddPhoto: () {},
                hasPhoto: true,
              ),
            ),
          ));
      await tester.pumpWidget(viewport(0));
      await tester.pump();
      expect(find.text('SCROLL ▼'), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_add_photo')), findsNothing);
      await tester.pumpWidget(viewport(10));
      await tester.pump();
      expect(find.text('SCROLL ▼'), findsNothing);
      expect(find.byKey(const ValueKey('spot_add_photo')), findsOneWidget);
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('no-photo header fits $size at 2.0x text', (tester) async {
        await _size(tester, size);
        await tester.pumpWidget(_app(MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2.0),
          ),
          child: SpotDetailScreen(spot: _spot()),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('theater_no_photo_placeholder')),
            findsOneWidget);
      });
    }
  });
}
