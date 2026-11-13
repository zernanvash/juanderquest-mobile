import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/engine/jdq_map.dart';
import '../../trail/models/trail_models.dart';
import '../../trail/services/trails_api.dart';
import '../models/route_model.dart';
import '../services/location_stream_service.dart';
import '../services/voice_guide.dart';
import '../utils/route_geometry.dart';

/// Default fallback coordinate: Lingayen Provincial Capitol, Pangasinan
const LatLng kDefaultOrigin = LatLng(16.0218, 120.2319);

class NavOrigin {
  final String name;
  final LatLng point;
  final bool isGps;

  const NavOrigin({
    required this.name,
    required this.point,
    this.isGps = false,
  });

  static const defaultLingayen = NavOrigin(
    name: 'Lingayen Capitol',
    point: kDefaultOrigin,
    isGps: false,
  );
}

/// State for the sovereign Valhalla turn-by-turn navigation engine
class NavigationState {
  final NavOrigin origin;
  final LatLng? userLocation;
  final NavTarget destination;
  final TravelCosting costing;
  final bool avoidCongested;
  final RouteModel? route;
  final List<NearbyTrail> nearbyTrails;
  final TrailDetail? selectedTrail;
  final List<DetourArea> selectedDetours;
  final List<DetourArea> availableDetours;
  final bool isLoadingRoute;
  final bool isLoadingTrails;
  final bool isLocating;
  final bool isFindingGps;
  final String? error;
  final int? activeStepIndex;
  final bool isDirectRoute;
  final bool isAdventureActive;
  final bool isCameraFollowing;
  final bool isRerouting;
  final Position? currentPosition;
  final bool isCheckingIn;
  final bool hasArrivedDirect;
  final bool isTrailCompleted;
  final int? trailCompletionReward;
  final TrailStop? lastCheckedInStop;
  final double? distanceToManeuverM;
  final LatLng? snappedPuckPosition;
  final List<LatLng>? trimmedPolyline;
  final double? remainingDistanceMeters;
  final int? remainingDurationSeconds;
  final bool isVoiceMuted;

  const NavigationState({
    this.origin = NavOrigin.defaultLingayen,
    this.userLocation,
    required this.destination,
    this.costing = TravelCosting.auto,
    this.avoidCongested = true,
    this.route,
    this.nearbyTrails = const [],
    this.selectedTrail,
    this.selectedDetours = const [],
    this.availableDetours = const [],
    this.isLoadingRoute = false,
    this.isLoadingTrails = false,
    this.isLocating = false,
    this.isFindingGps = false,
    this.error,
    this.activeStepIndex,
    this.isDirectRoute = true,
    this.isAdventureActive = false,
    this.isCameraFollowing = true,
    this.isRerouting = false,
    this.currentPosition,
    this.isCheckingIn = false,
    this.hasArrivedDirect = false,
    this.isTrailCompleted = false,
    this.trailCompletionReward,
    this.lastCheckedInStop,
    this.distanceToManeuverM,
    this.snappedPuckPosition,
    this.trimmedPolyline,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.isVoiceMuted = false,
  });

  LatLng get effectiveOriginPoint => userLocation ?? origin.point;

  LatLng get effectiveEndPoint {
    final stops = selectedTrail?.stops;
    if (stops != null && stops.isNotEmpty) {
      return stops.last.point;
    }
    return destination.point;
  }

  TrailStop? get nextUncheckedStop {
    if (selectedTrail == null || selectedTrail!.stops.isEmpty) return null;
    for (final s in selectedTrail!.stops) {
      if (!s.checkedIn) return s;
    }
    return null;
  }

  int get currentStopNumber {
    final next = nextUncheckedStop;
    if (next != null) return next.position;
    return selectedTrail?.stops.length ?? 0;
  }

  int get totalTrailStops => selectedTrail?.stops.length ?? 0;

  bool get isWithinCheckinRadius {
    final next = nextUncheckedStop;
    final pos = currentPosition;
    if (next == null || pos == null) return false;
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      next.lat,
      next.lng,
    );
    return dist <= next.checkinRadiusM + 30.0;
  }

  double get currentSpeedMs => currentPosition?.speed ?? 0.0;

  RouteManeuver? get currentManeuver {
    final mList = route?.maneuvers;
    if (mList == null || mList.isEmpty) return null;
    final idx = activeStepIndex ?? 0;
    if (idx >= 0 && idx < mList.length) return mList[idx];
    return mList.first;
  }

  List<RouteManeuver> get upcomingManeuvers {
    final mList = route?.maneuvers;
    if (mList == null || mList.isEmpty) return const [];
    final idx = (activeStepIndex ?? 0) + 1;
    if (idx < mList.length) return mList.sublist(idx);
    return const [];
  }

  NavigationState copyWith({
    NavOrigin? origin,
    LatLng? Function()? userLocation,
    NavTarget? destination,
    TravelCosting? costing,
    bool? avoidCongested,
    RouteModel? Function()? route,
    List<NearbyTrail>? nearbyTrails,
    TrailDetail? Function()? selectedTrail,
    List<DetourArea>? selectedDetours,
    List<DetourArea>? availableDetours,
    bool? isLoadingRoute,
    bool? isLoadingTrails,
    bool? isLocating,
    bool? isFindingGps,
    String? Function()? error,
    int? Function()? activeStepIndex,
    bool? isDirectRoute,
    bool? isAdventureActive,
    bool? isCameraFollowing,
    bool? isRerouting,
    Position? Function()? currentPosition,
    bool? isCheckingIn,
    bool? hasArrivedDirect,
    bool? isTrailCompleted,
    int? Function()? trailCompletionReward,
    TrailStop? Function()? lastCheckedInStop,
    double? Function()? distanceToManeuverM,
    LatLng? Function()? snappedPuckPosition,
    List<LatLng>? Function()? trimmedPolyline,
    double? Function()? remainingDistanceMeters,
    int? Function()? remainingDurationSeconds,
    bool? isVoiceMuted,
  }) {
    return NavigationState(
      origin: origin ?? this.origin,
      userLocation: userLocation != null ? userLocation() : this.userLocation,
      destination: destination ?? this.destination,
      costing: costing ?? this.costing,
      avoidCongested: avoidCongested ?? this.avoidCongested,
      route: route != null ? route() : this.route,
      nearbyTrails: nearbyTrails ?? this.nearbyTrails,
      selectedTrail:
          selectedTrail != null ? selectedTrail() : this.selectedTrail,
      selectedDetours: selectedDetours ?? this.selectedDetours,
      availableDetours: availableDetours ?? this.availableDetours,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      isLoadingTrails: isLoadingTrails ?? this.isLoadingTrails,
      isLocating: isLocating ?? this.isLocating,
      isFindingGps: isFindingGps ?? this.isFindingGps,
      error: error != null ? error() : this.error,
      activeStepIndex:
          activeStepIndex != null ? activeStepIndex() : this.activeStepIndex,
      isDirectRoute: isDirectRoute ?? this.isDirectRoute,
      isAdventureActive: isAdventureActive ?? this.isAdventureActive,
      isCameraFollowing: isCameraFollowing ?? this.isCameraFollowing,
      isRerouting: isRerouting ?? this.isRerouting,
      currentPosition:
          currentPosition != null ? currentPosition() : this.currentPosition,
      isCheckingIn: isCheckingIn ?? this.isCheckingIn,
      hasArrivedDirect: hasArrivedDirect ?? this.hasArrivedDirect,
      isTrailCompleted: isTrailCompleted ?? this.isTrailCompleted,
      trailCompletionReward: trailCompletionReward != null
          ? trailCompletionReward()
          : this.trailCompletionReward,
      lastCheckedInStop: lastCheckedInStop != null
          ? lastCheckedInStop()
          : this.lastCheckedInStop,
      distanceToManeuverM: distanceToManeuverM != null
          ? distanceToManeuverM()
          : this.distanceToManeuverM,
      snappedPuckPosition: snappedPuckPosition != null
          ? snappedPuckPosition()
          : this.snappedPuckPosition,
      trimmedPolyline:
          trimmedPolyline != null ? trimmedPolyline() : this.trimmedPolyline,
      remainingDistanceMeters: remainingDistanceMeters != null
          ? remainingDistanceMeters()
          : this.remainingDistanceMeters,
      remainingDurationSeconds: remainingDurationSeconds != null
          ? remainingDurationSeconds()
          : this.remainingDurationSeconds,
      isVoiceMuted: isVoiceMuted ?? this.isVoiceMuted,
    );
  }

  /// Builds vector route overlay for JdqMap (Plan 83 WP-2 / 83d)
  JdqRouteOverlay? get routeOverlay {
    if (route == null || route!.coordinates.isEmpty) return null;

    final points = <JdqRoutePoint>[];
    if (!isAdventureActive) {
      // Start point dot (only in preview, not drawn while driving)
      points.add(JdqRoutePoint(
        point: effectiveOriginPoint,
        label: 'A',
        kind: JdqRoutePointKind.start,
      ));
    }

    // If trail is active: draw stops 1..N (no end marker on top of last shield)
    if (selectedTrail != null && selectedTrail!.stops.isNotEmpty) {
      for (final stop in selectedTrail!.stops) {
        points.add(JdqRoutePoint(
          point: stop.point,
          label: '${stop.position}',
          kind:
              stop.checkedIn ? JdqRoutePointKind.done : JdqRoutePointKind.stop,
        ));
      }
    } else {
      // If detours active
      for (int i = 0; i < selectedDetours.length; i++) {
        points.add(JdqRoutePoint(
          point: selectedDetours[i].center,
          label: '${i + 1}',
          kind: JdqRoutePointKind.detour,
        ));
      }
      // Destination point B
      points.add(JdqRoutePoint(
        point: destination.point,
        label: 'B',
        kind: JdqRoutePointKind.end,
      ));
    }

    if (isAdventureActive && currentPosition != null) {
      points.add(JdqRoutePoint(
        point: snappedPuckPosition ??
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
        label: 'puck',
        kind: JdqRoutePointKind.puck,
        bearing: currentPosition!.speed > 1.0 && currentPosition!.heading >= 0
            ? currentPosition!.heading
            : 0.0,
      ));
    }

    final isTrailOrQuiet = selectedTrail != null ||
        (avoidCongested && route!.summary.hasCrowdDiversion);

    final activeLine = (isAdventureActive &&
            trimmedPolyline != null &&
            trimmedPolyline!.length >= 2)
        ? trimmedPolyline!
        : route!.coordinates;

    return JdqRouteOverlay(
      line: activeLine,
      points: points,
      degraded: route!.isStraightLineFallback,
      color: isTrailOrQuiet
          ? const Color(0xFF2D6A4F) // Forest emerald
          : const Color(0xFF0284C7), // Sky route blue
      fitBounds: !isAdventureActive,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final ApiClient _apiClient;
  final TrailsApi _trailsApi;
  final VoiceGuide? _voiceGuide;
  int _consecutiveOffRouteFixes = 0;
  DateTime? _lastRerouteTime;
  DateTime? _lastPolylineTrimTime;
  List<LatLng> _cachedManeuverWaypoints = const [];
  final Set<String> _spokenCues = {};

  NavigationNotifier({
    required ApiClient apiClient,
    TrailsApi? trailsApi,
    VoiceGuide? voiceGuide,
    required NavTarget initialDestination,
  })  : _apiClient = apiClient,
        _trailsApi = trailsApi ?? TrailsApi(apiClient),
        _voiceGuide = voiceGuide,
        super(NavigationState(
          origin: NavOrigin.defaultLingayen,
          destination: initialDestination,
        )) {
    initNavigation();
  }

  /// Initialization: Acquire initial GPS (or default) and load route + trails
  Future<void> initNavigation() async {
    await _voiceGuide?.init();
    if (_voiceGuide != null) {
      state = state.copyWith(isVoiceMuted: _voiceGuide!.isMuted);
    }
    await _acquireLocation(silent: true);
    await fetchRoute();
    await fetchNearbyTrails();
  }

  void _speakOnce(String cueKey, String phrase) {
    if (!state.isAdventureActive || state.isVoiceMuted || _voiceGuide == null) {
      return;
    }
    if (_spokenCues.add(cueKey)) {
      unawaited(_voiceGuide!.speak(phrase));
    }
  }

  /// Acquire GPS position from device
  Future<void> acquireCurrentLocation() async =>
      _acquireLocation(silent: false);

  Future<void> _acquireLocation({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLocating: true, error: () => null);
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) {
          state = state.copyWith(
            isLocating: false,
            error: () => 'GPS location services are disabled on device.',
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent) {
            state = state.copyWith(
              isLocating: false,
              error: () => 'Location permission was denied.',
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent) {
          state = state.copyWith(
            isLocating: false,
            error: () => 'Location permission permanently denied.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final gpsPoint = LatLng(position.latitude, position.longitude);
      final newOrigin = NavOrigin(
        name: 'My Location',
        point: gpsPoint,
        isGps: true,
      );

      state = state.copyWith(
        origin: newOrigin,
        userLocation: () => gpsPoint,
        isLocating: false,
      );

      // Re-query route with new GPS coordinates
      fetchRoute();
      fetchNearbyTrails();
    } catch (e) {
      debugPrint('[Navigation] Geolocation error: $e');
      if (!silent) {
        state = state.copyWith(
          isLocating: false,
          error: () => 'Could not obtain GPS fix. Using Lingayen Capitol.',
        );
      }
    }
  }

  /// Acquire GPS fix (max 15s) and re-fetch route before entering driving view (Bug A1)
  Future<bool> acquireStartFixAndFetchRoute(
    LocationStreamService locationService,
  ) async {
    state = state.copyWith(isFindingGps: true, error: () => null);
    try {
      final pos = await locationService.getCurrentPosition(
        timeLimit: locationService.gpsAcquireTimeout,
      );
      if (pos == null) {
        state = state.copyWith(
          isFindingGps: false,
          error: () =>
              "Couldn't find your location. Go outside or turn on GPS.",
        );
        return false;
      }

      final gpsPoint = LatLng(pos.latitude, pos.longitude);
      state = state.copyWith(
        origin: NavOrigin(
          name: 'My Location',
          point: gpsPoint,
          isGps: true,
        ),
        userLocation: () => gpsPoint,
        currentPosition: () => pos,
      );

      await fetchRoute();
      state = state.copyWith(isFindingGps: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isFindingGps: false,
        error: () => "Couldn't find your location. Go outside or turn on GPS.",
      );
      return false;
    }
  }

  /// Fetch Sovereign route from POST /api/v1/routes or GET /api/v1/routes
  Future<void> fetchRoute() async {
    state = state.copyWith(isLoadingRoute: true, error: () => null);

    try {
      final originCoord = state.effectiveOriginPoint;
      final endCoord = state.effectiveEndPoint;

      // Check if we have intermediate 'via' stops (trail stops before last, or detours)
      final viaPoints = <Map<String, dynamic>>[];
      if (state.selectedTrail != null &&
          state.selectedTrail!.stops.isNotEmpty) {
        final stops = state.selectedTrail!.stops;
        for (int i = 0; i < stops.length - 1; i++) {
          final stop = stops[i];
          if (!state.isAdventureActive || !stop.checkedIn) {
            viaPoints.add({
              'lat': stop.lat,
              'lng': stop.lng,
            });
          }
        }
      } else if (state.selectedDetours.isNotEmpty) {
        for (final detour in state.selectedDetours) {
          viaPoints.add({
            'lat': detour.center.latitude,
            'lng': detour.center.longitude,
          });
        }
      }

      final Map<String, dynamic> responseData;

      if (viaPoints.isNotEmpty) {
        // Multi-stop route using POST /api/v1/routes (WP-1 fix)
        final response = await _apiClient.dio.post(
          '/routes',
          // The server's body: start/end objects (not "lat,lng" strings).
          data: {
            'start': {
              'lat': originCoord.latitude,
              'lng': originCoord.longitude
            },
            'end': {'lat': endCoord.latitude, 'lng': endCoord.longitude},
            'costing': state.costing.key,
            'avoid_congested': state.avoidCongested,
            'via': viaPoints,
          },
        );
        responseData = response.data['data'] as Map<String, dynamic>;
      } else {
        // Direct route via GET /api/v1/routes
        final response = await _apiClient.dio.get(
          '/routes',
          queryParameters: {
            'start_lat': originCoord.latitude,
            'start_lng': originCoord.longitude,
            'end_lat': endCoord.latitude,
            'end_lng': endCoord.longitude,
            'costing': state.costing.key,
            'avoid_congested': state.avoidCongested,
          },
        );
        responseData = response.data['data'] as Map<String, dynamic>;
      }

      final routeModel = RouteModel.fromJson(responseData);
      _cachedManeuverWaypoints = RouteGeometry.computeManeuverWaypoints(
        routeModel.coordinates,
        routeModel.maneuvers,
      );
      _lastPolylineTrimTime = null;

      state = state.copyWith(
        route: () => routeModel,
        isLoadingRoute: false,
        trimmedPolyline: () => null,
        remainingDistanceMeters: () => null,
        remainingDurationSeconds: () => null,
      );
    } catch (e) {
      debugPrint('[Navigation] Routing error: $e');
      // If backend fails, build a degraded straight-line fallback (never crash)
      final fallbackRoute = _buildStraightLineFallback(
        state.effectiveOriginPoint,
        state.effectiveEndPoint,
      );
      _cachedManeuverWaypoints = RouteGeometry.computeManeuverWaypoints(
        fallbackRoute.coordinates,
        fallbackRoute.maneuvers,
      );
      _lastPolylineTrimTime = null;
      state = state.copyWith(
        route: () => fallbackRoute,
        isLoadingRoute: false,
        trimmedPolyline: () => null,
        remainingDistanceMeters: () => null,
        remainingDurationSeconds: () => null,
        error: () => 'Routing estimate only — road guidance unavailable.',
      );
    }
  }

  RouteModel _buildStraightLineFallback(LatLng start, LatLng end) {
    final distanceMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final distanceKm = distanceMeters / 1000.0;
    // Estimate ~40 km/h driving time
    final durationSeconds = (distanceKm / 40.0 * 3600).round();

    return RouteModel(
      summary: RouteSummary(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        durationFormatted: '${(durationSeconds / 60).round()} min',
        costing: state.costing,
        hasCrowdDiversion: false,
        engine: 'haversine_fallback',
      ),
      coordinates: [start, end],
      maneuvers: [
        RouteManeuver(
          instruction: 'Proceed directly toward ${state.destination.name}',
          distanceMeters: distanceMeters.round(),
          timeSeconds: durationSeconds,
          streetName: state.destination.address,
        ),
      ],
      degraded: true,
    );
  }

  /// Fetch nearby published trails and corridor detours
  Future<void> fetchNearbyTrails() async {
    state = state.copyWith(isLoadingTrails: true);
    try {
      final dest = state.destination;
      final trailsFuture = _trailsApi.fetchTrailsNear(
        lat: dest.lat,
        lng: dest.lng,
      );

      final tripPlanFuture = _trailsApi.planTrip(
        start: state.effectiveOriginPoint,
        end: dest.point,
        costing: state.costing.key,
        avoidCongested: state.avoidCongested,
      );

      final results = await Future.wait([
        trailsFuture.catchError((_) => <NearbyTrail>[]),
        tripPlanFuture.catchError((_) => const TripPlan(
              baselineRoute: RouteModel.empty(),
              detourAreas: [],
            )),
      ]);

      final trails = results[0] as List<NearbyTrail>;
      final plan = results[1] as TripPlan;

      state = state.copyWith(
        nearbyTrails: trails,
        availableDetours: plan.detourAreas,
        isLoadingTrails: false,
      );
    } catch (e) {
      debugPrint('[Navigation] Note loading trails/detours: $e');
      state = state.copyWith(isLoadingTrails: false);
    }
  }

  /// Update starting point (origin)
  void setOrigin(NavOrigin origin) {
    state = state.copyWith(
      origin: origin,
      userLocation: () => origin.point,
    );
    fetchRoute();
    fetchNearbyTrails();
  }

  /// Update destination
  void updateDestination(NavTarget newDest) {
    state = state.copyWith(
      destination: newDest,
      selectedTrail: () => null,
      selectedDetours: [],
      isDirectRoute: true,
      activeStepIndex: () => null,
    );
    fetchRoute();
    fetchNearbyTrails();
  }

  /// Swap origin and destination
  void swapOriginAndDestination() {
    final oldOrigin = state.origin;
    final oldDest = state.destination;

    final newOrigin = NavOrigin(
      name: oldDest.name,
      point: oldDest.point,
      isGps: false,
    );

    final newDest = NavTarget(
      name: oldOrigin.name,
      lat: oldOrigin.point.latitude,
      lng: oldOrigin.point.longitude,
      address: oldOrigin.name,
    );

    state = state.copyWith(
      origin: newOrigin,
      userLocation: () => newOrigin.point,
      destination: newDest,
      selectedTrail: () => null,
      selectedDetours: [],
      isDirectRoute: true,
      activeStepIndex: () => null,
    );

    fetchRoute();
    fetchNearbyTrails();
  }

  /// Change travel costing mode
  void setCosting(TravelCosting costing) {
    if (state.costing == costing) return;
    state = state.copyWith(costing: costing);
    fetchRoute();
  }

  /// Toggle Quiet Roads (anti-crowd diversion)
  void toggleAvoidCongested() {
    state = state.copyWith(avoidCongested: !state.avoidCongested);
    fetchRoute();
  }

  /// Select direct route card
  void selectDirectRoute() {
    state = state.copyWith(
      selectedTrail: () => null,
      isDirectRoute: true,
    );
    fetchRoute();
  }

  /// Select a chosen trail (from TrailOfferSheet)
  void selectTrail(TrailDetail trail) {
    state = state.copyWith(
      selectedTrail: () => trail,
      isDirectRoute: false,
    );
    fetchRoute();
  }

  /// Fetch an already-unlocked trail's details and select it directly.
  Future<void> selectUnlockedTrail(String trailId) async {
    if (state.selectedTrail?.id == trailId && !state.isDirectRoute) {
      return;
    }
    try {
      final detail = await _trailsApi.fetchTrail(trailId);
      selectTrail(detail);
    } catch (e) {
      state = state.copyWith(
        error: () => TrailsApi.extractErrorMessage(e),
      );
    }
  }

  /// Toggle scenic detour on direct route
  void toggleDetour(DetourArea area) {
    final current = List<DetourArea>.from(state.selectedDetours);
    final exists = current.any((d) => d.municipality == area.municipality);
    if (exists) {
      current.removeWhere((d) => d.municipality == area.municipality);
    } else {
      if (current.length < 3) {
        current.add(area);
      }
    }
    state = state.copyWith(selectedDetours: current, isDirectRoute: true);
    fetchRoute();
  }

  /// Clear all detours
  void clearDetours() {
    state = state.copyWith(selectedDetours: []);
    fetchRoute();
  }

  /// Focus active maneuver step
  void setActiveStep(int? index) {
    state = state.copyWith(activeStepIndex: () => index);
  }

  /// Start active adventure live guidance
  void startAdventure() {
    _consecutiveOffRouteFixes = 0;
    _lastRerouteTime = null;
    _lastPolylineTrimTime = null;
    _spokenCues.clear();
    state = state.copyWith(
      isAdventureActive: true,
      isCameraFollowing: true,
      activeStepIndex: () => 0,
      hasArrivedDirect: false,
      isTrailCompleted: false,
      lastCheckedInStop: () => null,
      isRerouting: false,
      snappedPuckPosition: () => null,
      trimmedPolyline: () => null,
      remainingDistanceMeters: () => null,
      remainingDurationSeconds: () => null,
    );
    final route = state.route;
    if (route != null && route.maneuvers.isNotEmpty) {
      _speakOnce('step_0_start', route.maneuvers.first.instruction);
    }
  }

  /// End active adventure live guidance
  void endAdventure() {
    _consecutiveOffRouteFixes = 0;
    _lastRerouteTime = null;
    _lastPolylineTrimTime = null;
    _spokenCues.clear();
    unawaited(_voiceGuide?.stop());
    state = state.copyWith(
      isAdventureActive: false,
      isCameraFollowing: true,
      isRerouting: false,
      hasArrivedDirect: false,
      lastCheckedInStop: () => null,
      snappedPuckPosition: () => null,
      trimmedPolyline: () => null,
      remainingDistanceMeters: () => null,
      remainingDurationSeconds: () => null,
    );
  }

  /// Toggle or update camera follow state
  void setCameraFollowing(bool follow) {
    state = state.copyWith(isCameraFollowing: follow);
  }

  /// Toggle or set voice mute state
  void setVoiceMuted(bool muted) {
    if (state.isVoiceMuted == muted) return;
    state = state.copyWith(isVoiceMuted: muted);
    unawaited(_voiceGuide?.setMuted(muted));
  }

  void toggleVoiceMuted() {
    setVoiceMuted(!state.isVoiceMuted);
  }

  /// Live GPS position update from Geolocator stream
  void updatePosition(Position position) {
    final gpsPoint = LatLng(position.latitude, position.longitude);
    final route = state.route;

    LatLng? snappedPuck = gpsPoint;
    List<LatLng>? nextTrimmed = state.trimmedPolyline;
    double? nextRemDist = state.remainingDistanceMeters;
    int? nextRemSec = state.remainingDurationSeconds;

    if (route != null && route.coordinates.length >= 2) {
      final snap = RouteGeometry.snapToPolyline(
        gpsPoint,
        route.coordinates,
        maxSnapMeters: 30.0,
      );
      snappedPuck = snap.snapped ? snap.snappedPoint : gpsPoint;
      nextRemDist = snap.remainingMeters;
      final totalMeters = route.summary.distanceKm * 1000.0;
      nextRemSec = RouteGeometry.remainingDurationSeconds(
        snap.remainingMeters,
        totalMeters > 0 ? totalMeters : snap.remainingMeters,
        route.summary.durationSeconds,
      );

      final now = DateTime.now();
      if (_lastPolylineTrimTime == null ||
          now.difference(_lastPolylineTrimTime!) >=
              const Duration(seconds: 1)) {
        _lastPolylineTrimTime = now;
        nextTrimmed = snap.remainingPolyline;
      }
    }

    state = state.copyWith(
      currentPosition: () => position,
      userLocation: () => gpsPoint,
      snappedPuckPosition: () => snappedPuck,
      trimmedPolyline: () => nextTrimmed,
      remainingDistanceMeters: () => nextRemDist,
      remainingDurationSeconds: () => nextRemSec,
    );

    if (route == null) return;

    // 1. Maneuver waypoint distance and step advancement (Bug A8: cached once per route)
    final waypoints = _cachedManeuverWaypoints.isNotEmpty
        ? _cachedManeuverWaypoints
        : (_cachedManeuverWaypoints = RouteGeometry.computeManeuverWaypoints(
            route.coordinates,
            route.maneuvers,
          ));

    final curIdx = state.activeStepIndex ?? 0;
    if (waypoints.isNotEmpty && curIdx < waypoints.length) {
      final distToTurn = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        waypoints[curIdx].latitude,
        waypoints[curIdx].longitude,
      );

      // Within 35 m of maneuver point, advance step!
      if (distToTurn <= 35.0 && curIdx + 1 < route.maneuvers.length) {
        final nextIdx = curIdx + 1;
        final nextDist = nextIdx < waypoints.length
            ? Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                waypoints[nextIdx].latitude,
                waypoints[nextIdx].longitude,
              )
            : 0.0;
        state = state.copyWith(
          activeStepIndex: () => nextIdx,
          distanceToManeuverM: () => nextDist,
        );
        if (nextIdx < route.maneuvers.length) {
          _speakOnce(
            'step_${nextIdx}_start',
            route.maneuvers[nextIdx].instruction,
          );
        }
      } else {
        state = state.copyWith(
          distanceToManeuverM: () => distToTurn,
        );
        if (curIdx < route.maneuvers.length) {
          final instr = route.maneuvers[curIdx].instruction;
          if (distToTurn <= 40.0) {
            _speakOnce('step_${curIdx}_40', 'Now, $instr');
          } else if (distToTurn <= 300.0) {
            _speakOnce('step_${curIdx}_300', 'In 300 meters, $instr');
          }
        }
      }
    }

    // 2. Off-route detection (more than 250 m off route polyline for 2 fixes in a row)
    if (route.coordinates.length >= 2) {
      final offDist = RouteGeometry.distanceToPolylineMeters(
        gpsPoint,
        route.coordinates,
      );
      if (offDist > 250.0) {
        _consecutiveOffRouteFixes++;
        if (_consecutiveOffRouteFixes >= 2) {
          final now = DateTime.now();
          if (_lastRerouteTime == null ||
              now.difference(_lastRerouteTime!) >=
                  const Duration(seconds: 20)) {
            _lastRerouteTime = now;
            _consecutiveOffRouteFixes = 0;
            state = state.copyWith(isRerouting: true);
            _speakOnce(
              'reroute_${now.millisecondsSinceEpoch}',
              'Recalculating route',
            );
            rerouteFromCurrentLocation();
          }
        }
      } else {
        _consecutiveOffRouteFixes = 0;
        if (state.isRerouting) {
          state = state.copyWith(isRerouting: false);
        }
      }
    }

    // 3. Direct route arrival check (within 40 m of destination)
    if (state.isDirectRoute) {
      final distToDest = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        state.destination.lat,
        state.destination.lng,
      );
      if (distToDest <= 40.0 && !state.hasArrivedDirect) {
        state = state.copyWith(hasArrivedDirect: true);
        _speakOnce(
          'arrive_direct',
          'You have arrived at ${state.destination.name}',
        );
      }
    } else if (state.isWithinCheckinRadius && state.nextUncheckedStop != null) {
      final stop = state.nextUncheckedStop!;
      _speakOnce(
        'stop_checkin_${stop.position}',
        'Arrived at stop ${stop.position}, ${stop.name}',
      );
    }
  }

  /// Recalculate route from current GPS coordinates through remaining stops
  Future<void> rerouteFromCurrentLocation() async {
    final pos = state.currentPosition;
    if (pos == null) return;
    final gpsPoint = LatLng(pos.latitude, pos.longitude);
    state = state.copyWith(
      userLocation: () => gpsPoint,
      isRerouting: true,
    );
    await fetchRoute();
    state = state.copyWith(
      isRerouting: false,
      activeStepIndex: () => 0,
    );
  }

  /// Check in at current trail stop
  Future<void> checkInCurrentStop() async {
    final trail = state.selectedTrail;
    final stop = state.nextUncheckedStop;
    final pos = state.currentPosition;
    if (trail == null || stop == null || pos == null) return;
    if (pos.speed > 3.0) return;

    state = state.copyWith(isCheckingIn: true, error: () => null);

    try {
      final response = await _trailsApi.checkInTrailStop(
        trail.id,
        stop.position,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
      );

      final updatedStops = trail.stops.map((s) {
        if (s.position == stop.position) {
          return TrailStop(
            position: s.position,
            spotId: s.spotId,
            name: s.name,
            municipality: s.municipality,
            category: s.category,
            lat: s.lat,
            lng: s.lng,
            narration: s.narration,
            arriveOffsetMin: s.arriveOffsetMin,
            dwellMin: s.dwellMin,
            legMinutes: s.legMinutes,
            legKm: s.legKm,
            checkinRadiusM: s.checkinRadiusM,
            checkedIn: true,
            distanceM: (response['distance_m'] as num?)?.toDouble(),
            accuracyM: (response['accuracy_m'] as num?)?.toDouble(),
          );
        }
        return s;
      }).toList();

      final allDone = updatedStops.every((s) => s.checkedIn);
      // The server puts the reward in `completion` (null if this trail was
      // already completed before).
      final completion = response['completion'];
      final reward = completion is Map
          ? (completion['reward_points'] as num?)?.toInt()
          : null;

      final updatedTrail = TrailDetail(
        id: trail.id,
        slug: trail.slug,
        title: trail.title,
        tagline: trail.tagline,
        tier: trail.tier,
        theme: trail.theme,
        municipalities: trail.municipalities,
        stopCount: trail.stopCount,
        totalMinutes: trail.totalMinutes,
        totalKm: trail.totalKm,
        unlockRule: trail.unlockRule,
        availableUntil: trail.availableUntil,
        isUnlocked: true,
        rewardPoints: trail.rewardPoints,
        intro: trail.intro,
        stops: updatedStops,
        preview: trail.preview,
      );

      state = state.copyWith(
        selectedTrail: () => updatedTrail,
        isCheckingIn: false,
        isTrailCompleted: allDone,
        trailCompletionReward: () => allDone ? reward : null,
        lastCheckedInStop: () => allDone ? null : stop,
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingIn: false,
        error: () => TrailsApi.extractErrorMessage(e),
      );
    }
  }

  /// Dismisses the stop check-in card and re-fetches the route from the
  /// current position through the remaining stops.
  Future<void> continueAfterCheckIn() async {
    state = state.copyWith(lastCheckedInStop: () => null);
    await rerouteFromCurrentLocation();
  }
}

/// Family provider keyed by NavTarget
final navigationProvider = StateNotifierProvider.autoDispose
    .family<NavigationNotifier, NavigationState, NavTarget>(
  (ref, destination) {
    final apiClient = ref.watch(apiClientProvider);
    final trailsApi = ref.watch(trailsApiProvider);
    final voiceGuide = ref.watch(voiceGuideProvider);
    return NavigationNotifier(
      apiClient: apiClient,
      trailsApi: trailsApi,
      voiceGuide: voiceGuide,
      initialDestination: destination,
    );
  },
);
