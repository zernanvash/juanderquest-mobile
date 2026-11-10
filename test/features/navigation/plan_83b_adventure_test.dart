import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/navigation/services/location_stream_service.dart';
import 'package:juanderquest_app/features/navigation/services/wakelock_service.dart';
import 'package:juanderquest_app/features/navigation/utils/route_geometry.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_bottom_bar.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_top_banner.dart';
import 'package:juanderquest_app/features/navigation/widgets/safety_disclaimer_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/trail_offer_sheet.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';

ApiClient _createMockApiClient() {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'summary': {
                  'distance_km': 10.0,
                  'duration_s': 600,
                  'costing': 'auto',
                },
                'coordinates': [
                  {'lat': 16.0410, 'lng': 120.2610},
                  {'lat': 16.0300, 'lng': 120.2400},
                ],
                'maneuvers': [
                  {
                    'instruction': 'Drive toward destination',
                    'distance_m': 10000,
                    'time_s': 600,
                    'street_name': 'Rerouted Rd',
                  }
                ],
              },
            },
          ),
        );
      },
    ),
  );
  return api;
}

class _FakeTrailsApi extends Fake implements TrailsApi {
  bool starterUnlocked = false;
  bool hiyasUnlocked = false;
  int unlockCallCount = 0;
  Map<String, dynamic>? lastCheckinPayload;
  int? lastCheckinPosition;
  String? lastCheckinTrailId;

  NearbyTrail get starterNearby => _makeStarter(starterUnlocked);
  NearbyTrail get hiyasNearby => _makeHiyas(hiyasUnlocked);

  NearbyTrail _makeStarter(bool unlocked) => NearbyTrail(
        id: 'trail-free-starter',
        slug: 'free-starter',
        title: 'Free Lingayen Starter',
        tagline: 'Historic capital walk',
        tier: TrailTier.starter,
        theme: 'history',
        municipalities: const ['Lingayen'],
        stopCount: 2,
        totalMinutes: 45,
        totalKm: 3.5,
        unlockRule: const UnlockRule(type: 'free'),
        isUnlocked: unlocked,
        rewardPoints: 50,
        passesHere: true,
        nearestKm: 0.1,
      );

  NearbyTrail _makeHiyas(bool unlocked) => NearbyTrail(
        id: 'trail-hiyas-alaminos',
        slug: 'hiyas-alaminos',
        title: 'Hundred Islands Royal Trail',
        tagline: 'Curated island treasures',
        tier: TrailTier.signature,
        theme: 'nature',
        municipalities: const ['Alaminos'],
        stopCount: 3,
        totalMinutes: 120,
        totalKm: 15.0,
        unlockRule: const UnlockRule(type: 'points', pricePoints: 100),
        isUnlocked: unlocked,
        rewardPoints: 200,
        passesHere: false,
        nearestKm: 2.0,
      );

  @override
  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    String? spotId,
  }) async {
    return [
      _makeStarter(starterUnlocked),
      _makeHiyas(hiyasUnlocked),
    ];
  }

  @override
  Future<TrailDetail> fetchTrail(String id) async {
    if (id == 'trail-free-starter') {
      return TrailDetail(
        id: 'trail-free-starter',
        slug: 'free-starter',
        title: 'Free Lingayen Starter',
        tagline: 'Historic capital walk',
        tier: TrailTier.starter,
        theme: 'history',
        intro: 'Discover the heritage of Lingayen gulf.',
        rewardPoints: 50,
        totalMinutes: 45,
        totalKm: 3.5,
        stopCount: 2,
        municipalities: const ['Lingayen'],
        unlockRule: const UnlockRule(type: 'free'),
        isUnlocked: starterUnlocked,
        stops: starterUnlocked
            ? const [
                TrailStop(
                  position: 1,
                  spotId: 'ts-1',
                  name: 'Lingayen Capitol Park',
                  municipality: 'Lingayen',
                  category: 'history',
                  lat: 16.0210,
                  lng: 120.2350,
                  narration: 'Historic provincial capitol.',
                  arriveOffsetMin: 0,
                  dwellMin: 15,
                  legMinutes: 10,
                  legKm: 1.5,
                  checkinRadiusM: 50.0,
                  checkedIn: false,
                ),
                TrailStop(
                  position: 2,
                  spotId: 'ts-2',
                  name: 'Veterans Memorial Beach',
                  municipality: 'Lingayen',
                  category: 'history',
                  lat: 16.0300,
                  lng: 120.2400,
                  narration: 'WWII landing site.',
                  arriveOffsetMin: 20,
                  dwellMin: 20,
                  legMinutes: 15,
                  legKm: 2.0,
                  checkinRadiusM: 50.0,
                  checkedIn: false,
                ),
              ]
            : const [],
        preview: const [
          TrailPreviewStop(
            name: 'Lingayen Capitol Park',
            municipality: 'Lingayen',
            category: 'history',
            blurb: 'Provincial grounds',
          ),
          TrailPreviewStop(
            name: 'Veterans Memorial Beach',
            municipality: 'Lingayen',
            category: 'history',
            blurb: 'WWII landing site',
          ),
        ],
      );
    } else {
      return TrailDetail(
        id: 'trail-hiyas-alaminos',
        slug: 'hiyas-alaminos',
        title: 'Hundred Islands Royal Trail',
        tagline: 'Curated island treasures',
        tier: TrailTier.signature,
        theme: 'nature',
        intro: 'Explore protected islands.',
        rewardPoints: 200,
        totalMinutes: 120,
        totalKm: 15.0,
        stopCount: 3,
        municipalities: const ['Alaminos'],
        unlockRule: const UnlockRule(type: 'points', pricePoints: 100),
        isUnlocked: hiyasUnlocked,
        stops: hiyasUnlocked
            ? const [
                TrailStop(
                  position: 1,
                  spotId: 'ts-h1',
                  name: 'Governor Island',
                  municipality: 'Alaminos',
                  category: 'nature',
                  lat: 16.2050,
                  lng: 120.0450,
                  narration: 'Viewdeck over islands.',
                  arriveOffsetMin: 0,
                  dwellMin: 30,
                  legMinutes: 20,
                  legKm: 5.0,
                  checkinRadiusM: 60.0,
                  checkedIn: false,
                ),
              ]
            : const [],
        preview: const [
          TrailPreviewStop(
            name: 'Governor Island',
            municipality: 'Alaminos',
            category: 'nature',
            blurb: 'Viewdeck summit',
          ),
        ],
      );
    }
  }

  @override
  Future<Map<String, dynamic>> unlockTrail(String id) async {
    unlockCallCount++;
    if (id == 'trail-free-starter') {
      starterUnlocked = true;
    } else if (id == 'trail-hiyas-alaminos') {
      hiyasUnlocked = true;
    }
    return {'unlocked': true};
  }

  @override
  Future<Map<String, dynamic>> checkInTrailStop(
    String id,
    int position, {
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    lastCheckinTrailId = id;
    lastCheckinPosition = position;
    lastCheckinPayload = {
      'lat': lat,
      'lng': lng,
      'accuracy_m': accuracyM,
    };
    return {
      'success': true,
      'reward': {'points': 50},
    };
  }

  @override
  Future<TripPlan> planTrip({
    required LatLng start,
    required LatLng end,
    List<LatLng> via = const [],
    String costing = 'auto',
    bool avoidCongested = true,
  }) async {
    final coords = [start, ...via, end];
    return TripPlan(
      baselineRoute: RouteModel(
        summary: const RouteSummary(
          distanceKm: 25.0,
          durationSeconds: 1800,
          durationFormatted: '30 min',
          costing: TravelCosting.auto,
          hasCrowdDiversion: false,
          engine: 'valhalla',
        ),
        coordinates: coords,
        maneuvers: const [
          RouteManeuver(
            instruction: 'Drive north toward destination',
            distanceMeters: 500,
            timeSeconds: 60,
            streetName: 'Capitol Blvd',
          ),
          RouteManeuver(
            instruction: 'Turn right onto Baywalk Ave',
            distanceMeters: 1000,
            timeSeconds: 120,
            streetName: 'Baywalk Ave',
          ),
          RouteManeuver(
            instruction: 'Arrive at destination',
            distanceMeters: 100,
            timeSeconds: 15,
            streetName: 'Destination Entrance',
          ),
        ],
      ),
      detourAreas: const [],
    );
  }
}

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user != null ? 'test-token' : null);
  }

  @override
  Future<void> refreshProfile() async {}
}

Position _buildPosition({
  required double lat,
  required double lng,
  double heading = 0.0,
  double speed = 0.0,
  double accuracy = 10.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 10.0,
    altitudeAccuracy: 5.0,
    heading: heading,
    headingAccuracy: 5.0,
    speed: speed,
    speedAccuracy: 1.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const target = NavTarget(
    name: 'Veterans Memorial Beach',
    lat: 16.0300,
    lng: 120.2400,
    address: 'Lingayen, Pangasinan',
  );

  final testUser = UserModel(
    id: 'usr-100',
    seedId: 'seed-100',
    displayName: 'scout_juan',
    email: 'scout@example.com',
    avatarUrl: '',
    role: 'traveler',
    demoPoints: 250,
  );

  const testRoute = RouteModel(
    summary: RouteSummary(
      distanceKm: 12.0,
      durationSeconds: 900,
      durationFormatted: '15 min',
      costing: TravelCosting.auto,
      hasCrowdDiversion: false,
      engine: 'valhalla',
    ),
    coordinates: [
      LatLng(16.0210, 120.2350),
      LatLng(16.0250, 120.2380),
      LatLng(16.0300, 120.2400),
    ],
    maneuvers: [
      RouteManeuver(
        instruction: 'Drive north on Capitol Blvd',
        distanceMeters: 400,
        timeSeconds: 60,
        streetName: 'Capitol Blvd',
      ),
      RouteManeuver(
        instruction: 'Turn right onto Beach Rd',
        distanceMeters: 600,
        timeSeconds: 90,
        streetName: 'Beach Rd',
      ),
      RouteManeuver(
        instruction: 'Arrive at Veterans Memorial Beach',
        distanceMeters: 100,
        timeSeconds: 20,
        streetName: 'Beach Access',
      ),
    ],
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SafetyDisclaimerSheet.testAcknowledgedOverride = true;
  });

  tearDown(() {
    SafetyDisclaimerSheet.testAcknowledgedOverride = null;
  });

  group('Plan 83b - WP-0: Trails in Planner', () {
    testWidgets(
        'Free starter trail unlocks without confirm step and reloads with stops',
        (tester) async {
      final fakeTrailsApi = _FakeTrailsApi();
      TrailDetail? chosenTrail;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            authProvider.overrideWith((ref) => _InertAuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  testUser,
                )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      TrailOfferSheet.show(
                        context,
                        trail: fakeTrailsApi.starterNearby,
                        onChoose: (detail) => chosenTrail = detail,
                      );
                    },
                    child: const Text('OPEN SHEET'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open the offer sheet
      await tester.tap(find.text('OPEN SHEET'));
      await tester.pumpAndSettle();

      // Free trail shows CHOOSE TRAIL without unlock price or locked warning
      expect(find.text('FREE LINGAYEN STARTER'), findsOneWidget);
      expect(find.text('CHOOSE TRAIL'), findsOneWidget);
      expect(find.textContaining('WHAT YOU\'LL DISCOVER'), findsNothing);

      // Tap CHOOSE TRAIL -> calls unlock directly with NO confirm step
      await tester.tap(find.byKey(const ValueKey('trail_offer_primary_cta')));
      await tester.pumpAndSettle();

      // Verify unlock called once and stops were loaded into chosenTrail
      expect(fakeTrailsApi.unlockCallCount, equals(1));
      expect(fakeTrailsApi.starterUnlocked, isTrue);
      expect(chosenTrail, isNotNull);
      expect(chosenTrail!.stops.length, equals(2));
      expect(chosenTrail!.stops[0].name, equals('Lingayen Capitol Park'));
    });

    testWidgets(
        'Choosing trail when logged out shows "Log in to start a trail"',
        (tester) async {
      final fakeTrailsApi = _FakeTrailsApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            authProvider.overrideWith((ref) => _InertAuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  null, // Logged out
                )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      TrailOfferSheet.show(
                        context,
                        trail: fakeTrailsApi.starterNearby,
                        onChoose: (_) {},
                      );
                    },
                    child: const Text('OPEN SHEET'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN SHEET'));
      await tester.pumpAndSettle();

      // Tap CHOOSE TRAIL
      await tester.tap(find.byKey(const ValueKey('trail_offer_primary_cta')));
      await tester.pump();

      // Logged out warning appears
      expect(find.text('Log in to start a trail'), findsOneWidget);
      expect(fakeTrailsApi.unlockCallCount, equals(0));
    });

    testWidgets(
        'Hiyas signature trail retains two-step unlock with point confirmation',
        (tester) async {
      final fakeTrailsApi = _FakeTrailsApi();
      TrailDetail? chosenTrail;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            authProvider.overrideWith((ref) => _InertAuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  testUser, // 250 points balance
                )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      TrailOfferSheet.show(
                        context,
                        trail: fakeTrailsApi.hiyasNearby,
                        onChoose: (detail) => chosenTrail = detail,
                      );
                    },
                    child: const Text('OPEN SHEET'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN SHEET'));
      await tester.pumpAndSettle();

      // Step 1: Shows locked note and unlock price
      expect(find.text('WHAT YOU\'LL DISCOVER'), findsOneWidget);
      expect(find.text('UNLOCK & CHOOSE · 100 PTS'), findsOneWidget);

      // Tap Step 1: Reveals confirmation panel
      await tester.tap(find.byKey(const ValueKey('trail_offer_primary_cta')));
      await tester.pumpAndSettle();

      expect(find.text('UNLOCK HIYAS TRAIL'), findsOneWidget);
      expect(find.textContaining('Your balance: 250 pts'), findsOneWidget);
      expect(find.text('CONFIRM · 100 PTS'), findsOneWidget);
      expect(find.byKey(const ValueKey('trail_offer_cancel')), findsOneWidget);

      // Tap Step 2: Confirms unlock
      await tester.tap(find.byKey(const ValueKey('trail_offer_primary_cta')));
      await tester.pumpAndSettle();

      expect(fakeTrailsApi.unlockCallCount, equals(1));
      expect(fakeTrailsApi.hiyasUnlocked, isTrue);
      expect(chosenTrail, isNotNull);
      expect(chosenTrail!.stops.length, equals(1));
    });
  });

  group('Plan 83b - WP-5: START ADVENTURE Live Navigation', () {
    testWidgets('Start adventure -> shows top banner step 1 and bottom bar',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      const initialState = NavigationState(
        origin: NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith(
              (ref) => NavigationNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                initialDestination: target,
              )..state = initialState,
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap START ADVENTURE
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      // Wakelock enabled
      expect(fakeWakelock.isEnabled, isTrue);

      // Top banner shows step 1
      expect(find.byType(AdventureTopBanner), findsOneWidget);
      expect(find.text('DRIVE NORTH ON CAPITOL BLVD'), findsOneWidget);

      // Bottom bar shows ETA & END button
      expect(find.byType(AdventureBottomBar), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_end_adventure')), findsOneWidget);

      await locationController.close();
    });

    testWidgets('Position fix within 35 m advances banner to step 2',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      const initialState = NavigationState(
        origin: NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith(
              (ref) => NavigationNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                initialDestination: target,
              )..state = initialState,
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      expect(find.text('DRIVE NORTH ON CAPITOL BLVD'), findsOneWidget);

      final waypoints = RouteGeometry.computeManeuverWaypoints(
        testRoute.coordinates,
        testRoute.maneuvers,
      );

      // Emit a fix within 35 meters of the turn point (waypoints[0])
      locationController.add(_buildPosition(
        lat: waypoints[0].latitude,
        lng: waypoints[0].longitude,
        speed: 2.0,
        heading: 90.0,
      ));
      await tester.pumpAndSettle();

      // Maneuver advanced to step 2
      expect(find.text('TURN RIGHT ONTO BEACH RD'), findsOneWidget);

      await locationController.close();
    });

    testWidgets('2 consecutive fixes >250m off route triggers reroute',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      const initialState = NavigationState(
        origin: NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
      );

      final mockApi = _createMockApiClient();
      final notifier = NavigationNotifier(
        apiClient: mockApi,
        trailsApi: fakeTrailsApi,
        initialDestination: target,
      )..state = initialState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      // First fix off route (1 km away)
      locationController.add(_buildPosition(
        lat: 16.0400,
        lng: 120.2600,
        speed: 8.0,
      ));
      await tester.pump();
      expect(find.text('RECHARTING PATH…'), findsNothing);

      // Second fix off route -> triggers reroute
      locationController.add(_buildPosition(
        lat: 16.0410,
        lng: 120.2610,
        speed: 8.0,
      ));
      await tester.pump();

      // Shows recharting badge
      expect(find.text('RECHARTING PATH…'), findsOneWidget);
      await tester.pumpAndSettle();

      await locationController.close();
    });

    testWidgets(
        'Near stop shows CHECK IN with exact body {lat, lng, accuracy_m}',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      fakeTrailsApi.starterUnlocked = true;
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      final starterDetail =
          await fakeTrailsApi.fetchTrail('trail-free-starter');

      final initialState = NavigationState(
        origin: const NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        selectedTrail: starterDetail,
        isDirectRoute: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith(
              (ref) => NavigationNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                initialDestination: target,
              )..state = initialState,
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      // Emit a fix within stop 1 checkin radius (lat: 16.0210, lng: 120.2350, speed 1.0 m/s <= 3 m/s)
      locationController.add(_buildPosition(
        lat: 16.0211,
        lng: 120.2351,
        speed: 1.0,
        accuracy: 15.0,
      ));
      await tester.pumpAndSettle();

      // Check-in button appears
      expect(find.byKey(const ValueKey('nav_check_in_button')), findsOneWidget);
      expect(find.text('YOU\'RE HERE! CHECK IN'), findsOneWidget);

      // Tap check-in
      await tester.tap(find.byKey(const ValueKey('nav_check_in_button')));
      await tester.pumpAndSettle();

      // Verify strict check-in payload sent to API: exactly {lat, lng, accuracy_m}
      expect(fakeTrailsApi.lastCheckinTrailId, equals('trail-free-starter'));
      expect(fakeTrailsApi.lastCheckinPosition, equals(1));
      expect(fakeTrailsApi.lastCheckinPayload, isNotNull);
      expect(fakeTrailsApi.lastCheckinPayload!.keys.toSet(),
          equals({'lat', 'lng', 'accuracy_m'}));
      expect(fakeTrailsApi.lastCheckinPayload!['lat'], equals(16.0211));
      expect(fakeTrailsApi.lastCheckinPayload!['lng'], equals(120.2351));
      expect(fakeTrailsApi.lastCheckinPayload!['accuracy_m'], equals(15.0));

      await locationController.close();
    });

    testWidgets('Speed > 3 m/s disables CHECK IN with "Park first to check in"',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      fakeTrailsApi.starterUnlocked = true;
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      final starterDetail =
          await fakeTrailsApi.fetchTrail('trail-free-starter');

      final initialState = NavigationState(
        origin: const NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        selectedTrail: starterDetail,
        isDirectRoute: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith(
              (ref) => NavigationNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                initialDestination: target,
              )..state = initialState,
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      // Emit fix within stop radius but moving at 6.0 m/s (> 3.0 m/s)
      locationController.add(_buildPosition(
        lat: 16.0211,
        lng: 120.2351,
        speed: 6.0,
      ));
      await tester.pumpAndSettle();

      // Button is disabled and shows safety warning
      expect(find.text('Park first to check in'), findsOneWidget);

      await locationController.close();
    });

    testWidgets('END adventure stops stream and releases wakelock',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final fakeTrailsApi = _FakeTrailsApi();
      final fakeWakelock = FakeWakelockService();
      final locationController = StreamController<Position>.broadcast();
      final fakeLocation =
          FakeLocationStreamService(stream: locationController.stream);

      const initialState = NavigationState(
        origin: NavOrigin(
          name: 'Capitol',
          point: LatLng(16.0210, 120.2350),
          isGps: true,
        ),
        destination: target,
        route: testRoute,
        isDirectRoute: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            trailsApiProvider.overrideWithValue(fakeTrailsApi),
            wakelockServiceProvider.overrideWithValue(fakeWakelock),
            locationStreamServiceProvider.overrideWithValue(fakeLocation),
            navigationProvider(target).overrideWith(
              (ref) => NavigationNotifier(
                apiClient: ref.watch(apiClientProvider),
                trailsApi: fakeTrailsApi,
                initialDestination: target,
              )..state = initialState,
            ),
          ],
          child: const MaterialApp(
            home: NavigationScreen(destination: target),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_start_adventure')));
      await tester.pumpAndSettle();

      expect(fakeWakelock.isEnabled, isTrue);

      // Tap END in bottom bar
      await tester.tap(find.byKey(const ValueKey('nav_end_adventure')));
      await tester.pumpAndSettle();

      // Bottom sheet confirmation appears
      expect(find.text('END ADVENTURE?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_end_adventure_confirm')));
      await tester.pumpAndSettle();

      // Wakelock disabled and returned to planner
      expect(fakeWakelock.isEnabled, isFalse);
      expect(find.byType(AdventureTopBanner), findsNothing);
      expect(find.byKey(const ValueKey('nav_start_adventure')), findsOneWidget);

      await locationController.close();
    });
  });
}
