import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/navigation/widgets/detour_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/origin_picker_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_top_bar.dart';
import 'package:juanderquest_app/features/navigation/widgets/steps_sheet.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';

class _FakeTrailsApi extends Fake implements TrailsApi {
  @override
  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    String? spotId,
  }) async {
    return [
      const NearbyTrail(
        id: 'trail-lingayen-gulf',
        slug: 'lingayen-gulf',
        title: 'Lingayen Gulf Heritage',
        tagline: 'Coastal history & war relics',
        tier: TrailTier.starter,
        theme: 'history',
        municipalities: ['Lingayen', 'Binmaley'],
        stopCount: 3,
        totalMinutes: 90,
        totalKm: 12.5,
        unlockRule: UnlockRule(type: 'free'),
        isUnlocked: true,
        rewardPoints: 50,
        passesHere: true,
        nearestKm: 0.2,
      ),
      const NearbyTrail(
        id: 'trail-hiyas-alaminos',
        slug: 'hiyas-alaminos',
        title: 'Hundred Islands Royal Trail',
        tagline: 'Curated island treasures',
        tier: TrailTier.signature,
        theme: 'nature',
        municipalities: ['Alaminos'],
        stopCount: 5,
        totalMinutes: 180,
        totalKm: 28.0,
        unlockRule: UnlockRule(type: 'points', pricePoints: 150),
        isUnlocked: false,
        rewardPoints: 200,
        passesHere: false,
        nearestKm: 3.5,
      ),
    ];
  }

  @override
  Future<TripPlan> planTrip({
    required LatLng start,
    required LatLng end,
    List<LatLng> via = const [],
    String costing = 'auto',
    bool avoidCongested = true,
  }) async {
    return const TripPlan(
      baselineRoute: RouteModel(
        summary: RouteSummary(
          distanceKm: 45.2,
          durationSeconds: 3200,
          durationFormatted: '53 min',
          costing: TravelCosting.auto,
          hasCrowdDiversion: false,
          engine: 'valhalla',
        ),
        coordinates: [
          LatLng(16.02, 120.23),
          LatLng(16.15, 120.10),
          LatLng(16.20, 119.98),
        ],
        maneuvers: [
          RouteManeuver(
            instruction: 'Drive northwest on Pangasinan Highway',
            distanceMeters: 15000,
            timeSeconds: 1200,
            streetName: 'MacArthur Highway',
          ),
          RouteManeuver(
            instruction: 'Turn right toward destination',
            distanceMeters: 5000,
            timeSeconds: 400,
            streetName: 'Coastal Access Rd',
          ),
        ],
      ),
      detourAreas: [
        DetourArea(
          municipality: 'Binmaley',
          center: LatLng(16.03, 120.26),
          detourKm: 1.2,
          extraMinutes: 8,
          score: 1.0,
          spotCount: 1,
          highlights: [
            DetourHighlight(
              spotId: 'spot-binmaley-church',
              name: 'Binmaley Church',
              category: 'history',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<TrailDetail> fetchTrail(String id) async {
    return const TrailDetail(
      id: 'trail-lingayen-gulf',
      slug: 'lingayen-gulf',
      title: 'Lingayen Gulf Heritage',
      tagline: 'Coastal history & war relics',
      tier: TrailTier.starter,
      theme: 'history',
      intro: 'A journey along the gulf coastline.',
      rewardPoints: 50,
      totalMinutes: 90,
      totalKm: 12.5,
      stopCount: 2,
      municipalities: ['Lingayen', 'Binmaley'],
      unlockRule: UnlockRule(type: 'free'),
      isUnlocked: true,
      stops: [
        TrailStop(
          position: 1,
          spotId: 'ts-1',
          name: 'Veterans Memorial Park',
          municipality: 'Lingayen',
          category: 'history',
          lat: 16.021,
          lng: 120.235,
          narration: '',
          arriveOffsetMin: 0,
          dwellMin: 20,
          legMinutes: 10,
          legKm: 5.0,
          checkinRadiusM: 50.0,
          checkedIn: false,
        ),
        TrailStop(
          position: 2,
          spotId: 'ts-2',
          name: 'Capitol Beach',
          municipality: 'Lingayen',
          category: 'nature',
          lat: 16.030,
          lng: 120.240,
          narration: '',
          arriveOffsetMin: 20,
          dwellMin: 30,
          legMinutes: 10,
          legKm: 5.0,
          checkinRadiusM: 50.0,
          checkedIn: false,
        ),
      ],
      preview: [],
    );
  }

  @override
  Future<Map<String, dynamic>> unlockTrail(String id) async {
    return {'unlocked': true};
  }
}

class _TestNavNotifier extends NavigationNotifier {
  _TestNavNotifier({
    required super.apiClient,
    required super.trailsApi,
    required NavTarget destination,
    required NavigationState initialState,
  }) : super(
          initialDestination: destination,
        ) {
    state = initialState;
  }

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {}

  @override
  Future<void> fetchNearbyTrails() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  const target = NavTarget(
    name: 'Patar Beach',
    lat: 16.2,
    lng: 119.9,
    address: 'Bolinao, Pangasinan',
  );

  const testRoute = RouteModel(
    summary: RouteSummary(
      distanceKm: 52.4,
      durationSeconds: 3600,
      durationFormatted: '1 hr',
      costing: TravelCosting.auto,
      hasCrowdDiversion: false,
      engine: 'valhalla',
    ),
    coordinates: [
      LatLng(16.02, 120.23),
      LatLng(16.10, 120.10),
      LatLng(16.20, 119.90),
    ],
    maneuvers: [
      RouteManeuver(
        instruction: 'Drive northwest toward Bolinao',
        distanceMeters: 25000,
        timeSeconds: 1800,
        streetName: 'Lingayen-Alaminos Rd',
      ),
      RouteManeuver(
        instruction: 'Turn left onto Patar Rd',
        distanceMeters: 12000,
        timeSeconds: 900,
        streetName: 'Patar Beach Rd',
      ),
    ],
  );

  group('Plan 83a: Navigation & Route Overlay Unit Tests', () {
    test('RouteOverlay generates start A, end B and route points', () {
      const state = NavigationState(
        origin: NavOrigin(
          name: 'Lingayen Capitol',
          point: LatLng(16.02, 120.23),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
      );

      final overlay = state.routeOverlay;
      expect(overlay, isNotNull);
      expect(overlay!.points.length, equals(2));
      expect(overlay.points.first.label, equals('A'));
      expect(overlay.points.first.kind, equals(JdqRoutePointKind.start));
      expect(overlay.points.last.label, equals('B'));
      expect(overlay.points.last.kind, equals(JdqRoutePointKind.end));
      expect(overlay.degraded, isFalse);
    });

    test('RouteOverlay generates numbered trail stops when trail is active',
        () {
      const state = NavigationState(
        origin: NavOrigin(
          name: 'Lingayen Capitol',
          point: LatLng(16.02, 120.23),
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: false,
        selectedTrail: TrailDetail(
          id: 'trail-1',
          slug: 'trail-1',
          title: 'Heritage Trail',
          tagline: 'Stops test',
          tier: TrailTier.starter,
          theme: 'history',
          intro: '',
          rewardPoints: 100,
          totalMinutes: 60,
          totalKm: 10,
          stopCount: 2,
          municipalities: ['Lingayen'],
          unlockRule: UnlockRule(type: 'free'),
          isUnlocked: true,
          stops: [
            TrailStop(
              position: 1,
              spotId: 's1',
              name: 'Stop 1',
              municipality: 'Lingayen',
              category: 'history',
              lat: 16.025,
              lng: 120.235,
              narration: '',
              arriveOffsetMin: 0,
              dwellMin: 15,
              legMinutes: 10,
              legKm: 5.0,
              checkinRadiusM: 50.0,
              checkedIn: true,
            ),
            TrailStop(
              position: 2,
              spotId: 's2',
              name: 'Stop 2',
              municipality: 'Lingayen',
              category: 'nature',
              lat: 16.030,
              lng: 120.240,
              narration: '',
              arriveOffsetMin: 15,
              dwellMin: 15,
              legMinutes: 10,
              legKm: 5.0,
              checkinRadiusM: 50.0,
              checkedIn: false,
            ),
          ],
          preview: [],
        ),
      );

      final overlay = state.routeOverlay;
      expect(overlay, isNotNull);
      // Point A + 2 stops
      expect(overlay!.points.length, equals(3));
      expect(overlay.points[1].label, equals('1'));
      expect(overlay.points[1].kind, equals(JdqRoutePointKind.done));
      expect(overlay.points[2].label, equals('2'));
      expect(overlay.points[2].kind, equals(JdqRoutePointKind.stop));
    });
  });

  group('Plan 83a: NavigationScreen & WP-4 UI Widget Tests', () {
    testWidgets(
        'Renders JdqMapCanvas with FakeJdqMap, route deck and action bar',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();

      const initialState = NavigationState(
        origin: NavOrigin(
          name: 'Lingayen Capitol',
          point: LatLng(16.02, 120.23),
          isGps: false,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
        nearbyTrails: [
          NearbyTrail(
            id: 'trail-lingayen-gulf',
            slug: 'lingayen-gulf',
            title: 'Lingayen Gulf Heritage',
            tagline: 'Coastal history & war relics',
            tier: TrailTier.starter,
            theme: 'history',
            municipalities: ['Lingayen'],
            stopCount: 3,
            totalMinutes: 90,
            totalKm: 12.5,
            unlockRule: UnlockRule(type: 'free'),
            isUnlocked: true,
            rewardPoints: 50,
            passesHere: true,
            nearestKm: 0.2,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            navigationProvider(target).overrideWith(
              (ref) => _TestNavNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                destination: target,
                initialState: initialState,
              ),
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Fake map surface rendered
      expect(find.byKey(const ValueKey('fake-jdq-map')), findsOneWidget);
      // Route overlay was passed to fake map
      expect(fakeMap.routeOverlay, isNotNull);
      expect(fakeMap.routeOverlay!.points.length, equals(2));

      // Header controls rendered (83d RoutePreviewTopBar + RoutePreviewSheet)
      expect(find.byType(RoutePreviewTopBar), findsOneWidget);
      expect(find.text('TO'), findsOneWidget);
      expect(find.text('Patar Beach'), findsOneWidget);
      expect(find.byType(RoutePreviewSheet), findsOneWidget);
      expect(find.text('CHANGE'), findsOneWidget);

      // Route modes and route rows rendered
      expect(find.text('DRIVE'), findsOneWidget);
      expect(find.text('MOTO'), findsOneWidget);
      expect(find.text('BIKE'), findsOneWidget);
      expect(find.text('WALK'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('nav_route_direct')), findsOneWidget);
      expect(find.text('DIRECT ROUTE'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_route_trail_trail-lingayen-gulf')),
          findsOneWidget);

      // Pinned Action Bar
      expect(
          find.byKey(const ValueKey('nav_steps_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_start_adventure')), findsOneWidget);

      // Tapping STEPS bar button opens StepsSheet
      await tester.tap(find.byKey(const ValueKey('nav_steps_button')));
      await tester.pumpAndSettle();
      expect(find.byType(StepsSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StepsSheet),
          matching: find.textContaining('TURN GUIDANCE (2 STEPS)'),
        ),
        findsOneWidget,
      );
      expect(find.text('DRIVE NORTHWEST TOWARD BOLINAO'), findsOneWidget);

      // Close StepsSheet
      await tester.tap(find.byKey(const ValueKey('steps_sheet_close')));
      await tester.pumpAndSettle();
      expect(find.byType(StepsSheet), findsNothing);
    });

    testWidgets('OriginPickerSheet shows GPS and gateway hubs', (tester) async {
      NavOrigin? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginPickerSheet(
              currentOrigin: NavOrigin.defaultLingayen,
              onSelect: (o) => selected = o,
            ),
          ),
        ),
      );

      expect(find.text('ROUTE OPTIONS'), findsOneWidget);
      expect(find.text('MY GPS LOCATION'), findsOneWidget);
      expect(find.text('POPULAR STARTING HUBS'), findsOneWidget);

      await tester.tap(find.text('MY GPS LOCATION'));
      expect(selected, isNotNull);
      expect(selected!.isGps, isTrue);
    });

    testWidgets('DetourSheet allows toggling detours', (tester) async {
      DetourArea? toggled;
      const detour = DetourArea(
        municipality: 'Binmaley',
        center: LatLng(16.03, 120.26),
        detourKm: 1.5,
        extraMinutes: 10,
        score: 1.0,
        spotCount: 1,
        highlights: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetourSheet(
              availableDetours: const [detour],
              selectedDetours: const [],
              onToggleDetour: (a) => toggled = a,
              onClear: () {},
            ),
          ),
        ),
      );

      expect(find.text('SCENIC DETOURS'), findsOneWidget);
      expect(find.text('BINMALEY'), findsOneWidget);
      await tester.tap(find.text('BINMALEY'));
      expect(toggled, isNotNull);
      expect(toggled!.municipality, equals('Binmaley'));
    });
  });
}
