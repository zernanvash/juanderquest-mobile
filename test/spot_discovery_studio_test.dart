// Plan 70: Spot Discovery Studio — location cascade, photo EXIF GPS, saved drafts, publish.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/screens/spot_discovery_studio_screen.dart';
import 'package:juanderquest_app/features/spots/utils/exif_gps.dart';
import 'package:juanderquest_app/features/spots/utils/spot_location_handoff.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';

/// A minimal JPEG whose EXIF carries GPS (same layout as the web fixture).
Uint8List jpegWithGps(double lat, double lng, {bool littleEndian = true}) {
  List<int> u16(int v) => littleEndian ? [v & 255, v >> 8] : [v >> 8, v & 255];
  List<int> u32(int v) => littleEndian
      ? [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]
      : [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<List<int>> dms(double value) {
    final abs = value.abs(), d = abs.floor(), m = ((abs - d) * 60).floor();
    final s = ((((abs - d) * 60) - m) * 60 * 1000).round();
    return [
      [d, 1],
      [m, 1],
      [s, 1000]
    ];
  }

  const gpsIfd = 26, data = gpsIfd + 2 + 4 * 12 + 4;
  final tiff = <int>[
    ...(littleEndian ? [0x49, 0x49] : [0x4d, 0x4d]),
    ...u16(42),
    ...u32(8),
    ...u16(1),
    ...u16(0x8825),
    ...u16(4),
    ...u32(1),
    ...u32(gpsIfd),
    ...u32(0),
    ...u16(4),
    ...u16(1),
    ...u16(2),
    ...u32(2),
    (lat >= 0 ? 'N' : 'S').codeUnitAt(0),
    0,
    0,
    0,
    ...u16(2),
    ...u16(5),
    ...u32(3),
    ...u32(data),
    ...u16(3),
    ...u16(2),
    ...u32(2),
    (lng >= 0 ? 'E' : 'W').codeUnitAt(0),
    0,
    0,
    0,
    ...u16(4),
    ...u16(5),
    ...u32(3),
    ...u32(data + 24),
    ...u32(0),
    for (final r in [...dms(lat), ...dms(lng)]) ...[...u32(r[0]), ...u32(r[1])],
  ];
  final app1 = [0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff];
  final length = app1.length + 2;
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xe1,
    length >> 8,
    length & 255,
    ...app1,
    0xff,
    0xda,
    0,
    2
  ]);
}

class _MemoryDraftStore extends SpotDraftStore {
  SavedSpotDraft? saved;
  bool cleared = false;
  @override
  Future<void> save(StudioPin pin, SpotLocationSource source,
          SpotPostingDraft draft) async =>
      saved = SavedSpotDraft(pin: pin, source: source, draft: draft);
  @override
  Future<SavedSpotDraft?> load() async => saved;
  @override
  Future<void> clear() async {
    saved = null;
    cleared = true;
  }
}

void main() {
  group('photo EXIF GPS', () {
    test('reads little- and big-endian GPS inside the Philippines', () {
      for (final little in [true, false]) {
        final gps =
            parseJpegGps(jpegWithGps(16.3268, 119.7842, littleEndian: little))!;
        expect(gps.lat, closeTo(16.3268, 1e-4));
        expect(gps.lng, closeTo(119.7842, 1e-4));
      }
    });

    test('ignores other countries, PNGs and broken files', () {
      expect(parseJpegGps(jpegWithGps(35.68, 139.69)), isNull);
      expect(
          parseJpegGps(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])), isNull);
      expect(
          parseJpegGps(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe1, 0, 4, 1])),
          isNull);
      expect(metersBetween(16, 120, 16.001, 120), inInclusiveRange(100, 120));
    });
  });

  group('location cascade', () {
    const draft = SpotPostingDraft(name: 'Saved cove');
    const saved = SavedSpotDraft(
        pin: StudioPin(16.1, 120.3, 16),
        source: SpotLocationSource.mapCrosshair,
        draft: draft);

    test('tier 1: the route pin wins, keeping a draft for the same place', () {
      final result = resolveInitialSpotLocation(
          fromRoute: const StudioPin(16.10001, 120.30001, 17), saved: saved);
      expect(result.source, SpotLocationSource.mapCrosshair);
      expect(result.draft?.name, 'Saved cove');
      expect(
          resolveInitialSpotLocation(
                  fromRoute: const StudioPin(16.5, 120.5, 17), saved: saved)
              .draft,
          isNull);
    });

    test('tier 2 then 4: saved draft, last map view, Lingayen', () {
      expect(resolveInitialSpotLocation(saved: saved).source,
          SpotLocationSource.draft);
      expect(
          resolveInitialSpotLocation(
                  lastMapCenter: const StudioPin(16.2, 119.9, 14))
              .source,
          SpotLocationSource.mapViewport);
      final anchor = resolveInitialSpotLocation();
      expect(anchor.source, SpotLocationSource.fallbackAnchor);
      expect(anchor.pin.lat, lingayenAnchor.lat);
      expect(StudioPin.tryParse('999', 'x'), isNull);
      expect(StudioPin.tryParse('16.3', '119.8', '40')!.zoom, 19);
    });

    test('drafts round-trip through JSON', () {
      const full = SpotPostingDraft(
          name: 'Cove',
          description: 'Clear water and soft sand all day.',
          lat: 16.3,
          lng: 119.8,
          goodFor: ['families'],
          bestTime: ['sunset'],
          amenities: ['parking'],
          dailyHours: '6 AM - 6 PM');
      final back = SpotPostingDraft.fromJson(full.toJson());
      expect([
        back.name,
        back.lat,
        back.goodFor,
        back.amenities,
        back.dailyHours
      ], [
        'Cove',
        16.3,
        ['families'],
        ['parking'],
        '6 AM - 6 PM'
      ]);
    });
  });

  testWidgets(
      'studio opens on the handed-off place and publishes into the celebration',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _MemoryDraftStore();
    final posted = <dynamic>[];
    final api = ApiClient();
    api.dio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/spots' && options.method == 'POST') {
        posted.add(options.data);
        handler
            .resolve(Response(requestOptions: options, statusCode: 201, data: {
          'success': true,
          'data': {
            'id': 'spot-9',
            'slug': 'patar-cove',
            'name': 'Patar Cove',
            'description': 'x',
            'category': 'nature_outdoors',
            'subcategory': 'beach',
            'municipality': 'Bolinao',
            'gps_lat': 16.3268,
            'gps_lng': 119.7842
          },
        }));
        return;
      }
      handler.resolve(Response(
          requestOptions: options, statusCode: 404, data: {'success': false}));
    }));
    final recognition = SpotRecognitionResult.fromJson({
      'recognized': true,
      'place_name': 'Patar Cove',
      'name_suggestions': ['Patar Cove'],
      'formatted_address': 'Patar Road, Brgy. Patar, Bolinao, Pangasinan',
      'municipality': 'Bolinao',
      'barangay': 'Brgy. Patar',
      'outside_pangasinan': false,
      'suggested_category': 'nature_outdoors',
      'suggested_subcategory': 'beach',
      'suggested_details': {
        'good_for': ['families'],
        'best_time': ['sunset'],
        'amenities': [],
        'daily_hours': ''
      },
      'story_starters': [
        'Patar Cove in Brgy. Patar, Bolinao with relaxing views and fresh air.'
      ],
      'nearby_duplicates': [],
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        spotDraftStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api)
      ],
      child: MaterialApp(
        home: SpotDiscoveryStudioScreen(
            routePin: const StudioPin(16.3268, 119.7842, 17),
            routeRecognition: recognition),
      ),
    ));
    await tester.pump();
    expect(find.text('Spot Discovery Studio'), findsOneWidget);
    expect(find.byKey(const ValueKey('spot_postcard')), findsOneWidget);
    expect(find.textContaining('Patar Cove'), findsWidgets);

    await tester.scrollUntilVisible(
        find.textContaining('+ Patar Cove in Brgy'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('+ Patar Cove in Brgy'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.saved?.draft.description,
        startsWith('Patar Cove in Brgy. Patar'));
    expect(find.text('✓ Draft saved'), findsOneWidget);

    await tester.tap(find.text('Publish spot'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('studio_celebration')), findsOneWidget);
    expect(find.text('Patar Cove is on the map!'), findsOneWidget);
    expect(posted.single, containsPair('gps_lat', 16.3268));
    expect(store.cleared, isTrue);
  });
}
