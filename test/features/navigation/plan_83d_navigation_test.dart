import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/navigation/services/location_stream_service.dart';
import 'package:juanderquest_app/features/navigation/services/voice_guide.dart';
import 'package:juanderquest_app/features/navigation/services/wakelock_service.dart';
import 'package:juanderquest_app/features/navigation/utils/route_geometry.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_arrive_overlay.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_bottom_bar.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_top_banner.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/trail_offer_sheet.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';

Position _pos({
  required double lat,
  required double lng,
  double speed = 0.0,
  double heading = 0.0,
}) =>
    Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 8.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: heading,
      headingAccuracy: 0.0,
      speed: speed,
      speedAccuracy: 0.0,
    );

class _FakeTrailsApi83d extends Fake implements TrailsApi {
  final List<NearbyTrail> trails = const [];
  int? completionReward = 100;

  @override
  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    String? spotId,
  }) async =>
      trails;

  @override
  Future<TrailDetail> fetchTrail(String id) async {
    return const TrailDetail(
      id: 't-1',
      slug: 'coastal-loop',
      title: 'Coastal Heritage Loop',
      tagline: 'Historic Lingayen Bay',
      tier: TrailTier.starter,
      theme: 'heritage',
      municipalities: ['Lingayen', 'Binmaley'],
      stopCount: 2,
      totalMinutes: 45,
      totalKm: 8.0,
      unlockRule: UnlockRule(type: 'free'),
      isUnlocked: true,
      rewardPoints: 100,
      intro: 'Scenic coastal route.',
      stops: [
        TrailStop(
          position: 1,
          spotId: 's-1',
          name: 'Capitol Park',
          municipality: 'Lingayen',
          category: 'heritage',
          lat: 16.0218,
          lng: 120.2319,
          narration: 'Stop 1',
          arriveOffsetMin: 0,
          dwellMin: 10,
          legMinutes: 10,
          legKm: 2.0,
          checkinRadiusM: 60.0,
          checkedIn: false,
        ),
        TrailStop(
          position: 2,
          spotId: 's-2',
          name: 'Binmaley Church',
          municipality: 'Binmaley',
          category: 'heritage',
          lat: 16.0310,
          lng: 120.2700,
          narration: 'Stop 2',
          arriveOffsetMin: 20,
          dwellMin: 15,
          legMinutes: 15,
          legKm: 6.0,
          checkinRadiusM: 60.0,
          checkedIn: false,
        ),
      ],
      preview: [],
    );
  }

  @override
  Future<Map<String, dynamic>> checkInTrailStop(
    String id,
    int position, {
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    if (position >= 2) {
      return {
        'success': true,
        'completion': completionReward != null
            ? {'reward_points': completionReward}
            : null,
      };
    }
    return {'success': true};
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
          distanceKm: 2.0,
          durationSeconds: 300,
          durationFormatted: '5 min',
          costing: TravelCosting.auto,
          hasCrowdDiversion: false,
          engine: 'valhalla',
        ),
        coordinates: [LatLng(16.02, 120.23), LatLng(16.03, 120.24)],
        maneuvers: [],
      ),
      detourAreas: [],
    );
  }
}

class _TestNavNotifier83d extends NavigationNotifier {
  int fetchCalls = 0;

  _TestNavNotifier83d({
    required super.apiClient,
    required super.trailsApi,
    super.voiceGuide,
    required super.initialDestination,
    required NavigationState initialState,
  }) {
    state = initialState;
  }

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {
    fetchCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const target = NavTarget(
    name: 'Patar Beach',
    lat: 16.0310,
    lng: 120.2700,
    address: 'Bolinao',
  );

  const sampleRoute = RouteModel(
    summary: RouteSummary(
      distanceKm: 10.0,
      durationSeconds: 600,
      durationFormatted: '10 min',
      costing: TravelCosting.auto,
      hasCrowdDiversion: false,
      engine: 'valhalla',
    ),
    coordinates: [
      LatLng(16.0218, 120.2319),
      LatLng(16.0260, 120.2500),
      LatLng(16.0310, 120.2700),
    ],
    maneuvers: [
      RouteManeuver(
        instruction: 'Head east on Capitol Blvd',
        distanceMeters: 1500,
        timeSeconds: 180,
        streetName: 'Capitol Blvd',
      ),
      RouteManeuver(
        instruction: 'Turn left onto Coastal Hwy',
        distanceMeters: 2500,
        timeSeconds: 240,
        streetName: 'Coastal Hwy',
      ),
      RouteManeuver(
        instruction: 'Arrive at destination',
        distanceMeters: 100,
        timeSeconds: 15,
      ),
    ],
  );

  group('Plan 83d: Geometry, Bug Fixes & Voice Unit Tests', () {
    test('Bug C1: TrailsApi.extractErrorMessage never exposes raw TypeError',
        () {
      expect(
        TrailsApi.extractErrorMessage(TypeError()),
        equals("Couldn't load this. Try again."),
      );
      expect(
        TrailsApi.extractErrorMessage(const FormatException('bad json')),
        equals("Couldn't load this. Try again."),
      );
      expect(
        TrailsApi.extractErrorMessage(Exception('Trail already unlocked')),
        equals('Trail already unlocked'),
      );
    });

    test('Bug B6: effectiveEndPoint uses last trail stop when trail is picked',
        () {
      const trail = TrailDetail(
        id: 't-1',
        slug: 'loop',
        title: 'Loop',
        tagline: '',
        tier: TrailTier.starter,
        theme: 'heritage',
        municipalities: [],
        stopCount: 2,
        totalMinutes: 30,
        totalKm: 5.0,
        unlockRule: UnlockRule(type: 'free'),
        isUnlocked: true,
        rewardPoints: 50,
        intro: '',
        stops: [
          TrailStop(
            position: 1,
            spotId: 's1',
            name: 'Stop 1',
            municipality: 'Lingayen',
            category: 'heritage',
            lat: 16.01,
            lng: 120.20,
            narration: '',
            arriveOffsetMin: 0,
            dwellMin: 5,
            legMinutes: 5,
            legKm: 1.0,
            checkinRadiusM: 60.0,
            checkedIn: false,
          ),
          TrailStop(
            position: 2,
            spotId: 's2',
            name: 'Final Stop',
            municipality: 'Binmaley',
            category: 'heritage',
            lat: 16.05,
            lng: 120.29,
            narration: '',
            arriveOffsetMin: 15,
            dwellMin: 10,
            legMinutes: 10,
            legKm: 4.0,
            checkinRadiusM: 60.0,
            checkedIn: false,
          ),
        ],
        preview: [],
      );

      const state = NavigationState(
        destination: target,
        selectedTrail: trail,
        isDirectRoute: false,
      );
      expect(state.effectiveEndPoint, equals(const LatLng(16.05, 120.29)));
    });

    test(
        '§4 rules 3-4 & Bug A3: snapToPolyline snaps within 30m and computes remaining ETA',
        () {
      const poly = [
        LatLng(16.0000, 120.0000),
        LatLng(16.0100, 120.0000),
        LatLng(16.0200, 120.0000),
      ];
      // Midpoint along second segment, ~10m off east
      final snap = RouteGeometry.snapToPolyline(
        const LatLng(16.0150, 120.0001),
        poly,
        maxSnapMeters: 30.0,
      );
      expect(snap.snapped, isTrue);
      expect(snap.segmentIndex, equals(1));
      expect(snap.remainingPolyline.length, equals(2));
      expect(snap.remainingMeters, lessThan(700));
      expect(snap.remainingMeters, greaterThan(450));

      final remSec = RouteGeometry.remainingDurationSeconds(500.0, 2000.0, 400);
      expect(remSec, equals(100));
    });

    test(
        '§4 rule 1: acquireStartFixAndFetchRoute updates origin from GPS and handles null',
        () async {
      final api = _FakeTrailsApi83d();
      final notifier = _TestNavNotifier83d(
        apiClient: ApiClient(),
        trailsApi: api,
        initialDestination: target,
        initialState: const NavigationState(
          destination: target,
          route: sampleRoute,
        ),
      );

      final missingLoc = FakeLocationStreamService(
        stream: const Stream.empty(),
        currentFix: null,
      );
      final failOk = await notifier.acquireStartFixAndFetchRoute(missingLoc);
      expect(failOk, isFalse);
      expect(notifier.state.error, contains("Couldn't find your location"));

      final goodLoc = FakeLocationStreamService(
        stream: const Stream.empty(),
        currentFix: _pos(lat: 16.0218, lng: 120.2319),
      );
      final ok = await notifier.acquireStartFixAndFetchRoute(goodLoc);
      expect(ok, isTrue);
      expect(notifier.state.origin.isGps, isTrue);
      expect(notifier.fetchCalls, equals(1));
    });

    test(
        '§6 VoiceGuide speaks once per step at start/300m/40m/arrive and respects mute',
        () async {
      final api = _FakeTrailsApi83d();
      final voice = FakeVoiceGuide();
      final notifier = _TestNavNotifier83d(
        apiClient: ApiClient(),
        trailsApi: api,
        voiceGuide: voice,
        initialDestination: target,
        initialState: const NavigationState(
          destination: target,
          route: sampleRoute,
          isDirectRoute: true,
        ),
      );

      notifier.startAdventure();
      expect(voice.spoken.length, equals(1));
      expect(voice.spoken.first, contains('Head east'));

      // Mute suppresses further speech
      notifier.toggleVoiceMuted();
      expect(notifier.state.isVoiceMuted, isTrue);
      expect(voice.isMuted, isTrue);

      notifier.updatePosition(_pos(lat: 16.0310, lng: 120.2700));
      expect(voice.spoken.length, equals(1));

      // Unmute allows arrival phrase once
      notifier.toggleVoiceMuted();
      final notifier2 = _TestNavNotifier83d(
        apiClient: ApiClient(),
        trailsApi: api,
        voiceGuide: voice,
        initialDestination: target,
        initialState: const NavigationState(
          destination: target,
          route: sampleRoute,
          isDirectRoute: true,
        ),
      );
      notifier2.startAdventure();
      notifier2.updatePosition(_pos(lat: 16.0310, lng: 120.2700));
      expect(voice.spoken.any((s) => s.contains('arrived')), isTrue);
    });

    // Orchestrator review: after a reroute the steps restart at 0, so the
    // first instruction must be spoken again (it was silently skipped).
    test('voice announces the first turn again after a reroute', () async {
      final voice = FakeVoiceGuide();
      final notifier = _TestNavNotifier83d(
        apiClient: ApiClient(),
        trailsApi: _FakeTrailsApi83d(),
        voiceGuide: voice,
        initialDestination: target,
        initialState: const NavigationState(
          destination: target,
          route: sampleRoute,
          isDirectRoute: true,
        ),
      );
      notifier.startAdventure();
      notifier.updatePosition(_pos(lat: 16.0200, lng: 120.2300));
      final before = voice.spoken.length;
      await notifier.rerouteFromCurrentLocation();
      expect(voice.spoken.length, before + 1);
      expect(voice.spoken.last, contains('Head east'));
    });
  });

  group('Plan 83d: Preview, Driving & Arrive Widget Tests', () {
    testWidgets('RoutePreviewSheet caps visible trails at 3 with MORE TRAILS',
        (tester) async {
      const trails = [
        NearbyTrail(
          id: 't1',
          slug: 't1',
          title: 'Trail One',
          tagline: '',
          tier: TrailTier.starter,
          theme: 'heritage',
          municipalities: ['Lingayen'],
          stopCount: 3,
          totalMinutes: 30,
          totalKm: 5.0,
          nearestKm: 1.2,
          unlockRule: UnlockRule(type: 'free'),
          isUnlocked: true,
          rewardPoints: 50,
          passesHere: false,
        ),
        NearbyTrail(
          id: 't2',
          slug: 't2',
          title: 'Trail Two',
          tagline: '',
          tier: TrailTier.starter,
          theme: 'heritage',
          municipalities: ['Lingayen'],
          stopCount: 3,
          totalMinutes: 35,
          totalKm: 6.0,
          nearestKm: 1.8,
          unlockRule: UnlockRule(type: 'free'),
          isUnlocked: false,
          rewardPoints: 60,
          passesHere: false,
        ),
        NearbyTrail(
          id: 't3',
          slug: 't3',
          title: 'Trail Three',
          tagline: '',
          tier: TrailTier.signature,
          theme: 'nature',
          municipalities: ['Alaminos'],
          stopCount: 4,
          totalMinutes: 45,
          totalKm: 8.0,
          nearestKm: 2.5,
          unlockRule: UnlockRule(type: 'points', pricePoints: 100),
          isUnlocked: false,
          rewardPoints: 100,
          passesHere: true,
        ),
        NearbyTrail(
          id: 't4',
          slug: 't4',
          title: 'Trail Four Hidden',
          tagline: '',
          tier: TrailTier.signature,
          theme: 'food',
          municipalities: ['Dagupan'],
          stopCount: 2,
          totalMinutes: 20,
          totalKm: 3.0,
          nearestKm: 3.0,
          unlockRule: UnlockRule(type: 'points', pricePoints: 80),
          isUnlocked: false,
          rewardPoints: 80,
          passesHere: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: const NavigationState(
                  destination: target,
                  route: sampleRoute,
                  nearbyTrails: trails,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('DIRECT ROUTE'), findsOneWidget);
      expect(find.text('TRAIL ONE'), findsOneWidget);
      expect(find.text('TRAIL TWO'), findsOneWidget);
      // Scrollable 3-row viewport hides the 4th trail until scrolled
      expect(find.text('TRAIL FOUR HIDDEN'), findsNothing);
    });

    testWidgets('TrailOfferSheet shows USE THIS TRAIL and gold stop chips',
        (tester) async {
      final api = _FakeTrailsApi83d();
      const trail = NearbyTrail(
        id: 't-1',
        slug: 'coastal-loop',
        title: 'Coastal Heritage Loop',
        tagline: 'Historic Lingayen Bay',
        tier: TrailTier.starter,
        theme: 'heritage',
        municipalities: ['Lingayen'],
        stopCount: 2,
        totalMinutes: 45,
        totalKm: 8.0,
        nearestKm: 1.0,
        unlockRule: UnlockRule(type: 'free'),
        isUnlocked: true,
        rewardPoints: 100,
        passesHere: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailsApiProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => AuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider),
                )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TrailOfferSheet(
                trail: trail,
                onChoose: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('USE THIS TRAIL'), findsOneWidget);
      final chip = tester.widget<PixelChip>(
        find.ancestor(
          of: find.text('1'),
          matching: find.byType(PixelChip),
        ),
      );
      expect(chip.style, equals(PixelBoxStyle.gold));
    });

    testWidgets(
        'AdventureTopBanner shows green banner, distance, THEN pill and opens steps',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdventureTopBanner(
              currentManeuver: sampleRoute.maneuvers[0],
              distanceToManeuverM: 300,
              upcomingManeuvers: [sampleRoute.maneuvers[1]],
              onOpenSteps: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('300 M'), findsOneWidget);
      expect(find.text('HEAD EAST ON CAPITOL BLVD'), findsOneWidget);
      expect(find.text('Capitol Blvd'), findsOneWidget);
      expect(find.text('THEN TURN LEFT'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_adventure_top_banner')));
      expect(tapped, isTrue);
    });

    testWidgets(
        'Driving view renders speed box, mute & gold re-centre when panning',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fakeMap = FakeJdqMap();
      final fakeApi = _FakeTrailsApi83d();
      final fakeLoc = FakeLocationStreamService(
        stream: const Stream.empty(),
        currentFix: _pos(lat: 16.0218, lng: 120.2319, speed: 12.0),
      );
      final fakeWakelock = FakeWakelockService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeApi),
            locationStreamServiceProvider.overrideWithValue(fakeLoc),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            navigationProvider(target).overrideWith(
              (ref) => _TestNavNotifier83d(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeApi,
                initialDestination: target,
                initialState: NavigationState(
                  destination: target,
                  route: sampleRoute,
                  isAdventureActive: true,
                  isCameraFollowing: false,
                  currentPosition: _pos(
                    lat: 16.0218,
                    lng: 120.2319,
                    speed: 12.0,
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav_speed_box')), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(find.text('KM/H'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_mute_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_recenter')), findsOneWidget);
      expect(find.byType(AdventureBottomBar), findsOneWidget);

      // Re-centre container should be gold when !isCameraFollowing
      final recenterContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('nav_recenter')),
          matching: find.byType(Container),
        ),
      );
      final deco = recenterContainer.decoration as BoxDecoration;
      expect(deco.color, equals(PixelPalette.gold));
    });

    testWidgets(
        'AdventureArriveOverlay renders CHECKED IN!, TRAIL COMPLETE! with/without reward, and YOU\'VE ARRIVED',
        (tester) async {
      var continued = false;
      var doneCount = 0;

      // 1. CHECKED IN! card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdventureArriveOverlay(
              checkedInStop: const TrailStop(
                position: 1,
                spotId: 's-1',
                name: 'Capitol Park',
                municipality: 'Lingayen',
                category: 'heritage',
                lat: 16.02,
                lng: 120.23,
                narration: '',
                arriveOffsetMin: 0,
                dwellMin: 10,
                legMinutes: 10,
                legKm: 2.0,
                checkinRadiusM: 60.0,
                checkedIn: true,
              ),
              nextStop: const TrailStop(
                position: 2,
                spotId: 's-2',
                name: 'Binmaley Church',
                municipality: 'Binmaley',
                category: 'heritage',
                lat: 16.03,
                lng: 120.27,
                narration: '',
                arriveOffsetMin: 20,
                dwellMin: 15,
                legMinutes: 15,
                legKm: 6.0,
                checkinRadiusM: 60.0,
                checkedIn: false,
              ),
              totalStops: 2,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () => continued = true,
              onDone: () => doneCount++,
            ),
          ),
        ),
      );
      expect(find.text('CHECKED IN!'), findsOneWidget);
      expect(find.text('STOP 1 OF 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_checkin_continue')));
      expect(continued, isTrue);

      // 2. TRAIL COMPLETE! with server reward
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Coastal Heritage Loop',
              trailRewardPoints: 150,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () => doneCount++,
            ),
          ),
        ),
      );
      expect(find.text('TRAIL COMPLETE!'), findsOneWidget);
      expect(find.text('+150 PTS'), findsOneWidget);

      // 3. TRAIL COMPLETE! without reward (already completed) -> no PTS chip
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Coastal Heritage Loop',
              trailRewardPoints: null,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () => doneCount++,
            ),
          ),
        ),
      );
      expect(find.text('TRAIL COMPLETE!'), findsOneWidget);
      expect(find.textContaining('PTS'), findsNothing);

      // 4. YOU'VE ARRIVED direct card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdventureArriveOverlay(
              hasArrivedDirect: true,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () => doneCount++,
            ),
          ),
        ),
      );
      expect(find.text("YOU'VE ARRIVED"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_arrive_done')));
      expect(doneCount, equals(1));
    });
  });
}
