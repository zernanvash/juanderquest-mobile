import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/theater/theater_backdrop.dart';
import 'package:juanderquest_app/features/spots/theater/theater_gallery_dialog.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

Widget _wrapScreen({
  required SpotModel spot,
  UserModel? user,
  ApiClient? client,
}) {
  final testClient = client ?? ApiClient(enableRetries: false);
  testClient.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/comments')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
        }
        if (options.path.contains('/alternatives')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': {}},
        ));
      },
    ),
  );

  final activeUser = user ??
      UserModel(
        id: 'traveler-1',
        seedId: 'traveler-1',
        email: 'traveler@juanderquest.app',
        displayName: 'Traveler One',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 50,
      );

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testClient),
      authProvider.overrideWith((ref) => _InertAuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            activeUser,
          )),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: SpotDetailScreen(spot: spot),
    ),
  );
}

const _fullSpot = SpotModel(
  id: 'spot-theater-full',
  slug: 'hundred-islands-national-park',
  name: 'Hundred Islands National Park',
  description: 'A protected archipelago of 124 islands in Alaminos. Famous for snorkeling, cave exploration, and pristine beaches.',
  category: 'nature',
  subcategory: 'islands',
  municipality: 'Alaminos',
  address: 'Lucap Wharf, Alaminos City',
  sourceName: 'LGU Alaminos',
  sourceUrl: 'https://alaminoscity.gov.ph',
  trustLevel: 'lgu_verified',
  gpsLat: 16.20,
  gpsLng: 120.04,
  tags: ['islands', 'snorkeling', 'caves'],
  reasons: ['Iconic Pangasinan destination'],
  crowdStatus: 'estimated_quiet',
  crowdConfidence: 'high',
  distanceKm: 24.0,
  questId: 'quest-hundred-islands',
  imageUrl: 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86',
  createdBy: 'author-999',
  saved: false,
  goodFor: ['Island hopping', 'Snorkeling', 'Kayaking'],
  bestTime: ['Early Morning', 'Dry Season'],
  hours: {'monday': '6:00 AM - 6:00 PM', 'sunday': '6:00 AM - 6:00 PM'},
  amenities: ['Boat rentals', 'Restrooms', 'Life vests'],
  isTest: false,
  media: [
    SpotPhoto(
      url: 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86',
      isVideo: false,
      sourceName: 'LGU Alaminos',
      sourceUrl: 'https://alaminoscity.gov.ph',
    ),
    SpotPhoto(
      url: 'https://example.com/aerial.mp4',
      isVideo: true,
      sourceName: 'Drone Footage',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spot Theater Widget Tests', () {
    testWidgets('stationary photo layer keeps EXACT position and size after 2000px scroll', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      final photoFinder = find.byKey(const Key('theater_still_photo'));
      expect(photoFinder, findsOneWidget);

      final renderBoxBefore = tester.renderObject<RenderBox>(photoFinder);
      final offsetBefore = renderBoxBefore.localToGlobal(Offset.zero);
      final sizeBefore = renderBoxBefore.size;

      // Drag CustomScrollView by 2000 px upwards
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final renderBoxAfter = tester.renderObject<RenderBox>(photoFinder);
      final offsetAfter = renderBoxAfter.localToGlobal(Offset.zero);
      final sizeAfter = renderBoxAfter.size;

      // Must remain completely still (0 movement)
      expect(offsetAfter.dx, offsetBefore.dx);
      expect(offsetAfter.dy, offsetBefore.dy);
      expect(sizeAfter.width, sizeBefore.width);
      expect(sizeAfter.height, sizeBefore.height);
    });

    testWidgets('no-photo fallback renders DitherBackground', (tester) async {
      const spotNoPhoto = SpotModel(
        id: 'spot-no-photo',
        slug: 'no-photo',
        name: 'Spot Without Photo',
        description: 'A spot with no photo provided.',
        category: 'landmark',
        subcategory: 'historic',
        municipality: 'Lingayen',
        address: 'Capitol',
        sourceName: 'Tourism Office',
        trustLevel: 'community',
        gpsLat: 16.02,
        gpsLng: 120.23,
        tags: [],
        reasons: [],
        imageUrl: null,
        media: [],
      );

      await tester.pumpWidget(_wrapScreen(spot: spotNoPhoto));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theater_still_photo_dither')), findsOneWidget);
    });

    testWidgets('PLAY QUEST is shown only with questId; CREATE A QUEST HERE only for author', (tester) async {
      // 1. Full spot with questId, viewed by author
      final authorUser = UserModel(
        id: 'author-999',
        seedId: 'author-999',
        email: 'author@juanderquest.app',
        displayName: 'Author User',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 100,
      );

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot, user: authorUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theater_play_quest_btn')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spot_create_quest_btn')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spot_create_quest_btn')), findsOneWidget);

      // 2. Spot without questId, viewed by non-author
      final nonAuthorSpot = _fullSpot.copyWith(questId: null);
      final nonAuthorUser = UserModel(
        id: 'different-user',
        seedId: 'different-user',
        email: 'other@juanderquest.app',
        displayName: 'Other User',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 20,
      );

      await tester.pumpWidget(_wrapScreen(spot: nonAuthorSpot, user: nonAuthorUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theater_play_quest_btn')), findsNothing);
      expect(find.byKey(const ValueKey('spot_create_quest_btn')), findsNothing);
    });

    testWidgets('no sticky chapter bar; double-tap pops a heart',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.byType(SliverPersistentHeader), findsNothing);

      final hearts = find.descendant(
        of: find.byType(TheaterDoubleTapHearts),
        matching: find.byType(Opacity),
      );
      expect(hearts, findsNothing);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 80));
      expect(hearts, findsOneWidget);

      // The heart is gone after its short animation.
      await tester.pump(const Duration(seconds: 1));
      expect(hearts, findsNothing);
    });

    testWidgets('backdrop treatment follows the Pixel lab choice',
        (tester) async {
      for (final mode in TheaterBackdrop.values) {
        await tester.pumpWidget(ProviderScope(
          key: ValueKey(mode),
          overrides: [theaterBackdropProvider.overrideWith((ref) => mode)],
          child: MaterialApp(
            home: TheaterBackdropLayers(
              spot: _fullSpot,
              reveal: ValueNotifier(1.0),
            ),
          ),
        ));
        expect(
          find.byType(TheaterBackdropTreatment),
          mode == TheaterBackdrop.off ? findsNothing : findsOneWidget,
          reason: mode.name,
        );
      }
    });

    testWidgets('Pixel lab preview tiles switch the backdrop', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TheaterBackdropPicker(
                image: AssetImage('assets/images/pangasinan_banner.png'),
              ),
            ),
          ),
        ),
      ));
      expect(find.byType(TheaterBackdropTreatment), findsNWidgets(4));
      await tester.tap(find.byKey(const ValueKey('lab_backdrop_blur')));
      await tester.pump();
      expect(container.read(theaterBackdropProvider), TheaterBackdrop.blur);
    });

    testWidgets('empty about sub-blocks are hidden', (tester) async {
      const minimalSpot = SpotModel(
        id: 'minimal-spot',
        slug: 'minimal-spot',
        name: 'Minimal Spot',
        description: 'Just a simple description.',
        category: 'culture',
        subcategory: 'monument',
        municipality: 'Dagupan',
        address: 'Downtown',
        sourceName: 'LGU',
        trustLevel: 'community',
        gpsLat: 16.04,
        gpsLng: 120.33,
        tags: [],
        reasons: [],
        goodFor: [],
        bestTime: [],
        hours: {},
        amenities: [],
      );

      await tester.pumpWidget(_wrapScreen(spot: minimalSpot));
      await tester.pumpAndSettle();

      // Drag to about section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('GOOD FOR'), findsNothing);
      expect(find.text('BEST TIME TO VISIT'), findsNothing);
      expect(find.text('OPERATING HOURS'), findsNothing);
      expect(find.text('AMENITIES'), findsNothing);
    });

    testWidgets('gallery opens, navigates and closes without changing page photo', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      final galleryBtn = find.byKey(const Key('theater_gallery_btn'));
      expect(galleryBtn, findsOneWidget);

      await tester.tap(galleryBtn);
      await tester.pumpAndSettle();

      // Gallery is open
      expect(find.byType(TheaterGalleryDialog), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // Tap NEXT button
      final nextBtn = find.byKey(const Key('gallery_next_btn'));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      // Tap CLOSE button
      final closeBtn = find.byKey(const Key('gallery_close_btn'));
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Back to main screen, gallery dialog popped
      expect(find.byType(TheaterGalleryDialog), findsNothing);
      expect(find.byKey(const Key('theater_still_photo')), findsOneWidget);
    });

    testWidgets('action buttons trigger handlers (Save, Share, Like, Directions)', (tester) async {
      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.byKey(const Key('theater_save_btn'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('Added "Hundred Islands National Park" to saved places.'), findsOneWidget);

      // Tap Share
      final shareBtn = find.byKey(const Key('theater_share_btn'));
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Share link copied:'), findsOneWidget);

      // Scroll to notes and tap Like
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spot_like')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // The pinned bar covers the top strip once the hero is gone; nudge the
      // note back into the tappable area under it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
      await tester.pumpAndSettle();

      final likeBtn = find.byKey(const ValueKey('spot_like'));
      expect(likeBtn, findsOneWidget);
      await tester.tap(likeBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('LIKED'), findsOneWidget);
    });

    testWidgets('pinned bar replaces the scrolled-away hero controls',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theater_pinned_bar')), findsNothing);

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const Key('theater_pinned_bar'));
      expect(bar, findsOneWidget);
      expect(tester.getTopLeft(bar).dy, 0);
      expect(find.byKey(const Key('theater_pinned_save')), findsOneWidget);
      expect(find.byKey(const Key('theater_pinned_share')), findsOneWidget);

      await tester.tap(find.byKey(const Key('theater_pinned_save')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Added "Hundred Islands National Park"'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('theater_pinned_share')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Share link copied:'), findsOneWidget);
    });

    testWidgets('one photo is singular and credits strip the PHOTO: prefix',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spot = _fullSpot.copyWith(
        sourceName: 'PHOTO: BIANCABRAZAL',
        media: [_fullSpot.media.first],
        trustLevel: 'community',
      );

      await tester.pumpWidget(_wrapScreen(spot: spot));
      await tester.pumpAndSettle();

      expect(find.text('1 PHOTO'), findsOneWidget);
      expect(find.text('1 PHOTOS'), findsNothing);
      expect(find.textContaining('PHOTO: BIANCABRAZAL'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Shared by BIANCABRAZAL'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Shared by BIANCABRAZAL'), findsOneWidget);
      expect(find.textContaining('PHOTO:'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Photography & curation: BIANCABRAZAL'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Photography & curation: BIANCABRAZAL'),
        findsOneWidget,
      );
      expect(find.textContaining('PHOTO:'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('the notes header no longer duplicates Report a problem',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(spot: _fullSpot));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spot_like')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('spot_report')), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('theater_end_report_btn')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('theater_end_report_btn')), findsOneWidget);
    });
  });
}
