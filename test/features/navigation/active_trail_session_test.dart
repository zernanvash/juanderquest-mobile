// Plan 124d: the trail keeps running away from the navigation screen, and the
// stop-arrival notification fires once per stop.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/active_trail_session_provider.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/services/location_stream_service.dart';
import 'package:juanderquest_app/features/navigation/services/trail_notification_bridge.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';

class _FakeTrailsApi extends TrailsApi {
  _FakeTrailsApi() : super(ApiClient());

  @override
  Future<TrailCatalog> fetchTrails() async => const TrailCatalog(items: []);

  @override
  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    double radiusKm = 30,
    String? spotId,
  }) async =>
      const [];
}

class _QuietNavNotifier extends NavigationNotifier {
  _QuietNavNotifier(NavigationState initial, {super.keepAlive})
      : super(
          apiClient: ApiClient(),
          trailsApi: _FakeTrailsApi(),
          initialDestination: initial.destination,
        ) {
    state = initial;
  }

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {}
}

class _RecordingBridge extends TrailNotificationBridge {
  final shown = <String>[];
  int cancels = 0;

  @override
  Future<void> showStopArrival({
    required String title,
    required String body,
    required String trailId,
    required int stopPosition,
  }) async {
    shown.add('$trailId:$stopPosition:$title');
  }

  @override
  Future<void> cancelAll() async => cancels++;
}

const _dest = NavTarget(name: 'Patar White Beach', lat: 16.32, lng: 119.78);

TrailStop _stop(int position, String name, double lat, double lng,
        {bool checkedIn = false}) =>
    TrailStop(
      position: position,
      spotId: 's$position',
      name: name,
      municipality: 'Bolinao',
      category: 'Beach',
      lat: lat,
      lng: lng,
      arriveOffsetMin: 0,
      dwellMin: 10,
      legMinutes: 10,
      legKm: 2,
      checkinRadiusM: 60,
      checkedIn: checkedIn,
      narration: '',
    );

final _trail = TrailDetail(
  id: 'trail-124d',
  slug: 'trail-124d',
  title: 'Bolinao Coast',
  tagline: '',
  tier: TrailTier.starter,
  theme: 'nature',
  municipalities: const ['Bolinao'],
  stopCount: 2,
  totalMinutes: 60,
  totalKm: 6,
  unlockRule: const UnlockRule(type: 'free'),
  isUnlocked: true,
  rewardPoints: 50,
  intro: '',
  stops: [
    _stop(1, 'Bolinao Falls', 16.30, 119.90),
    _stop(2, 'Patar White Beach', 16.32, 119.78),
  ],
);

Position _fix(double lat, double lng, {double speed = 0}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 11, 26, 9),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

void main() {
  late StreamController<Position> gps;
  late _RecordingBridge bridge;
  late bool foreground;

  ProviderContainer makeContainer({bool adventureActive = true}) {
    return ProviderContainer(overrides: [
      locationStreamServiceProvider
          .overrideWithValue(FakeLocationStreamService(stream: gps.stream)),
      trailNotificationBridgeProvider.overrideWithValue(bridge),
      activeTrailSessionProvider.overrideWith(
        (ref) =>
            ActiveTrailSessionNotifier(ref, isAppForeground: () => foreground),
      ),
      navigationProvider(_dest).overrideWith(
        (ref) => _QuietNavNotifier(
          NavigationState(
            destination: _dest,
            selectedTrail: _trail,
            isAdventureActive: adventureActive,
          ),
          keepAlive: ref.keepAlive,
        ),
      ),
    ]);
  }

  setUp(() {
    gps = StreamController<Position>.broadcast();
    bridge = _RecordingBridge();
    foreground = false;
  });

  tearDown(() => gps.close());

  test('arrival notification fires once per stop while away', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final session = c.read(activeTrailSessionProvider.notifier);
    session.start(_dest);
    expect(c.read(activeTrailSessionProvider).isRunning, isTrue);

    // Far from stop 1: no alert.
    gps.add(_fix(16.25, 119.95));
    await Future<void>.delayed(Duration.zero);
    expect(bridge.shown, isEmpty);
    expect(c.read(activeTrailSessionProvider).isWithinStopTolerance, isFalse);

    // Inside stop 1 radius, twice: one alert.
    gps.add(_fix(16.3001, 119.9001));
    await Future<void>.delayed(Duration.zero);
    gps.add(_fix(16.3002, 119.9001));
    await Future<void>.delayed(Duration.zero);
    expect(bridge.shown, ['trail-124d:1:Arrived near Bolinao Falls!']);
    final s = c.read(activeTrailSessionProvider);
    expect(s.isWithinStopTolerance, isTrue);
    expect(s.nextStopName, 'Bolinao Falls');
    expect(s.trailTitle, 'Bolinao Coast');
  });

  test('no notification while the navigation screen is open in the foreground',
      () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    foreground = true;
    final session = c.read(activeTrailSessionProvider.notifier)..attachScreen();
    session.start(_dest);
    gps.add(_fix(16.3001, 119.9001));
    await Future<void>.delayed(Duration.zero);
    expect(bridge.shown, isEmpty);
  });

  test('leaving the screen keeps the adventure; END TRAIL stops everything',
      () async {
    final c = makeContainer(adventureActive: false);
    addTearDown(c.dispose);
    // The screen watches the navigation state, starts the adventure, then closes.
    final screen = c.listen(navigationProvider(_dest), (_, __) {});
    final nav = c.read(navigationProvider(_dest).notifier);
    nav.startAdventure();
    final session = c.read(activeTrailSessionProvider.notifier);
    session.start(_dest);
    screen.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(identical(c.read(navigationProvider(_dest).notifier), nav), isTrue,
        reason: 'kept alive while the adventure runs');
    expect(c.read(navigationProvider(_dest)).isAdventureActive, isTrue);
    expect(gps.hasListener, isTrue);

    await session.stop();
    expect(gps.hasListener, isFalse);
    expect(bridge.cancels, 1);
    expect(c.read(activeTrailSessionProvider).isRunning, isFalse);
    expect(c.read(navigationProvider(_dest)).isAdventureActive, isFalse);
  });

  test('trail background settings use the Android foreground service', () {
    final android = trailBackgroundLocationSettings(isAndroid: true);
    expect(android, isA<AndroidSettings>());
    expect(
        (android as AndroidSettings).foregroundNotificationConfig, isNotNull);
    expect(trailBackgroundLocationSettings(isAndroid: false),
        isNot(isA<AndroidSettings>()));
  });
}
