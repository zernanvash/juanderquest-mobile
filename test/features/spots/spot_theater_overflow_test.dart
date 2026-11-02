import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/theater/theater_gallery_dialog.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

const _testSpot = SpotModel(
  id: 'spot-overflow-test',
  slug: 'patar-white-beach',
  name: 'Patar White Beach',
  description: 'Golden white sands of Bolinao with breathtaking sunsets. Popular for beach camping and coastal photography.',
  category: 'nature',
  subcategory: 'beach',
  municipality: 'Bolinao',
  address: 'Brgy. Patar, Bolinao, Pangasinan',
  sourceName: 'LGU Bolinao',
  sourceUrl: 'https://bolinao.gov.ph',
  trustLevel: 'lgu_verified',
  gpsLat: 16.30,
  gpsLng: 119.78,
  tags: ['beach', 'sunset', 'white_sand'],
  reasons: ['Tranquil beach'],
  crowdStatus: 'estimated_quiet',
  crowdConfidence: 'high',
  distanceKm: 42.0,
  questId: 'quest-patar',
  imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  createdBy: 'user-author',
  goodFor: ['Sunset viewing', 'Swimming'],
  bestTime: ['4 PM - 6 PM'],
  hours: {'monday': 'Open 24 hours'},
  amenities: ['Cottages', 'Parking'],
  media: [
    SpotPhoto(
      url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
      isVideo: false,
      sourceName: 'LGU Bolinao',
    ),
    SpotPhoto(
      url: 'https://example.com/patar-tour.mp4',
      isVideo: true,
      sourceName: 'Travel Video',
    ),
  ],
);

Widget _buildOverflowApp({required SpotModel spot}) {
  final testClient = ApiClient(enableRetries: false);
  testClient.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': []},
        ));
      },
    ),
  );

  final user = UserModel(
    id: 'user-author',
    seedId: 'user-author',
    email: 'author@juanderquest.app',
    displayName: 'Patar Author',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 100,
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SpotDetailScreen(spot: spot),
      ),
      GoRoute(
        path: '/navigate',
        builder: (context, state) => const Scaffold(body: Text('NAVIGATE')),
      ),
      GoRoute(
        path: '/quests/:id',
        builder: (context, state) => const Scaffold(body: Text('QUEST')),
      ),
      GoRoute(
        path: '/explore/:slug',
        builder: (context, state) => const Scaffold(body: Text('EXPLORE')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testClient),
      authProvider.overrideWith((ref) => _InertAuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            user,
          )),
    ],
    child: MaterialApp.router(
      theme: AppTheme.pixel,
      routerConfig: router,
    ),
  );
}

void _checkNoException(WidgetTester tester) {
  final err = tester.takeException();
  expect(err, isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spot Theater Responsive & Zero-Overflow Tests (2.0x Text Scaling)', () {
    testWidgets('320x568 portrait at 2.0x text scaling passes with 0 overflows and taps buttons', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_buildOverflowApp(spot: _testSpot));
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 1. Open gallery at top, navigate, close
      final galleryBtn = find.byKey(const Key('theater_gallery_btn'));
      expect(galleryBtn, findsOneWidget);
      await tester.tap(galleryBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TheaterGalleryDialog), findsOneWidget);
      _checkNoException(tester);

      final nextBtn = find.byKey(const Key('gallery_next_btn'));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      final closeBtn = find.byKey(const Key('gallery_close_btn'));
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 2. Mid-story: Scroll down and tap a chapter button
      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      _checkNoException(tester);

      final aboutTab = find.text('ABOUT');
      expect(aboutTab, findsWidgets);
      await tester.tap(aboutTab.first);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 3. Tap GET DIRECTIONS (at top of screen)
      await tester.scrollUntilVisible(
        find.byKey(const Key('theater_directions_btn')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final dirBtn = find.byKey(const Key('theater_directions_btn'));
      expect(dirBtn, findsOneWidget);
      await tester.tap(dirBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);
    });

    testWidgets('568x320 landscape at 2.0x text scaling passes with 0 overflows and taps buttons', (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_buildOverflowApp(spot: _testSpot));
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 1. Top of screen: Tap gallery button, navigate, close
      final galleryBtn = find.byKey(const Key('theater_gallery_btn'));
      expect(galleryBtn, findsOneWidget);
      await tester.tap(galleryBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TheaterGalleryDialog), findsOneWidget);
      _checkNoException(tester);

      final nextBtn = find.byKey(const Key('gallery_next_btn'));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      final closeBtn = find.byKey(const Key('gallery_close_btn'));
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 2. Mid-story: Scroll down and tap a chapter button
      await tester.scrollUntilVisible(
        find.text('NOTES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      _checkNoException(tester);

      final notesTab = find.text('NOTES');
      expect(notesTab, findsWidgets);
      await tester.tap(notesTab.first);
      await tester.pumpAndSettle();
      _checkNoException(tester);

      // 3. Tap GET DIRECTIONS
      await tester.scrollUntilVisible(
        find.byKey(const Key('theater_directions_btn')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final dirBtn = find.byKey(const Key('theater_directions_btn'));
      expect(dirBtn, findsOneWidget);
      await tester.tap(dirBtn);
      await tester.pumpAndSettle();
      _checkNoException(tester);
    });
  });
}
