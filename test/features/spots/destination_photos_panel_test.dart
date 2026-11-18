import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/app/router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/theater/theater_gallery_dialog.dart';
import 'package:juanderquest_app/features/spots/theater/theater_photos_section.dart';

// Owner 2026-11-18: approved photos must show on the destination, in a
// PHOTOS panel whose tiles open the full-screen gallery.

const _card = SpotModel(
  id: 'spot-capitol',
  slug: 'pangasinan-provincial-capitol',
  name: 'Pangasinan Provincial Capitol',
  description: 'The capitol.',
  category: 'landmark',
  subcategory: 'historic',
  municipality: 'Lingayen',
  address: 'Lingayen',
  sourceName: 'PTCAO',
  trustLevel: 'community',
  gpsLat: 16.02,
  gpsLng: 120.23,
  tags: [],
  reasons: [],
  crowdStatus: 'estimated_quiet',
  crowdConfidence: 'high',
);

List<SpotPhoto> _photos(int n) => [
      for (var i = 0; i < n; i++) SpotPhoto(url: 'https://example.com/p$i.jpg'),
    ];

Widget _section(List<SpotPhoto> media, {VoidCallback? onAdd}) => MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TheaterPhotosSection(media: media, onAddPhoto: onAdd),
        ),
      ),
    );

void main() {
  testWidgets('tiles open the full-screen gallery at that photo',
      (tester) async {
    await tester.pumpWidget(_section(_photos(3)));
    expect(find.byKey(const ValueKey('spot_photo_tile_2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('spot_photo_tile_2')));
    await tester.pumpAndSettle();
    final gallery =
        tester.widget<TheaterGalleryDialog>(find.byType(TheaterGalleryDialog));
    expect(gallery.initialIndex, 2);
    expect(gallery.media.length, 3);
  });

  testWidgets('more than six photos: six tiles, the last shows +N',
      (tester) async {
    await tester.pumpWidget(_section(_photos(9)));
    expect(find.byKey(const ValueKey('spot_photo_tile_5')), findsOneWidget);
    expect(find.byKey(const ValueKey('spot_photo_tile_6')), findsNothing);
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('no photos: a message and Add photo', (tester) async {
    var added = 0;
    await tester.pumpWidget(_section(const [], onAdd: () => added++));
    expect(find.textContaining('No photos yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('spot_photos_add')));
    expect(added, 1);
  });

  testWidgets(
      'opened from a list card, the page loads the full record '
      'and shows the approved photos', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        final detail = options.path == '/spots/pangasinan-provincial-capitol';
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': detail
                ? {
                    'id': 'spot-capitol',
                    'slug': 'pangasinan-provincial-capitol',
                    'name': 'Pangasinan Provincial Capitol',
                    'municipality': 'Lingayen',
                    'gps_lat': 16.02,
                    'gps_lng': 120.23,
                    'attached_assets': [
                      {'url': 'https://example.com/approved-1.jpg'},
                      {'url': 'https://example.com/approved-2.jpg'},
                    ],
                  }
                : [],
          },
        ));
      }),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => AuthNotifier(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier))),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const SpotDetailRouteScreen(
          slug: 'pangasinan-provincial-capitol',
          initialSpot: _card,
        ),
      ),
    ));
    // The card shows first; the full record replaces it a moment later.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('spot_photos_section')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final panel =
        tester.widget<TheaterPhotosSection>(find.byType(TheaterPhotosSection));
    expect(panel.media.map((p) => p.url), [
      'https://example.com/approved-1.jpg',
      'https://example.com/approved-2.jpg',
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
