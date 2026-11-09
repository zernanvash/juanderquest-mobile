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
  final String? error;
  final int? activeStepIndex;
  final bool isDirectRoute;

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
    this.error,
    this.activeStepIndex,
    this.isDirectRoute = true,
  });

  LatLng get effectiveOriginPoint => userLocation ?? origin.point;

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
    String? Function()? error,
    int? Function()? activeStepIndex,
    bool? isDirectRoute,
  }) {
    return NavigationState(
      origin: origin ?? this.origin,
      userLocation:
          userLocation != null ? userLocation() : this.userLocation,
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
      error: error != null ? error() : this.error,
      activeStepIndex:
          activeStepIndex != null ? activeStepIndex() : this.activeStepIndex,
      isDirectRoute: isDirectRoute ?? this.isDirectRoute,
    );
  }

  /// Builds vector route overlay for JdqMap (Plan 83 WP-2)
  JdqRouteOverlay? get routeOverlay {
    if (route == null || route!.coordinates.isEmpty) return null;

    final points = <JdqRoutePoint>[];
    // Start point A
    points.add(JdqRoutePoint(
      point: effectiveOriginPoint,
      label: 'A',
      kind: JdqRoutePointKind.start,
    ));

    // If trail is active
    if (selectedTrail != null && selectedTrail!.stops.isNotEmpty) {
      for (final stop in selectedTrail!.stops) {
        points.add(JdqRoutePoint(
          point: stop.point,
          label: '${stop.position}',
          kind: stop.checkedIn
              ? JdqRoutePointKind.done
              : JdqRoutePointKind.stop,
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

    final isTrailOrQuiet =
        selectedTrail != null || (avoidCongested && route!.summary.hasCrowdDiversion);

    return JdqRouteOverlay(
      line: route!.coordinates,
      points: points,
      degraded: route!.isStraightLineFallback,
      color: isTrailOrQuiet
          ? const Color(0xFF2D6A4F) // Forest emerald
          : const Color(0xFF0284C7), // Sky route blue
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final ApiClient _apiClient;
  final TrailsApi _trailsApi;

  NavigationNotifier({
    required ApiClient apiClient,
    TrailsApi? trailsApi,
    required NavTarget initialDestination,
  })  : _apiClient = apiClient,
        _trailsApi = trailsApi ?? TrailsApi(apiClient),
        super(NavigationState(
          origin: NavOrigin.defaultLingayen,
          destination: initialDestination,
        )) {
    initNavigation();
  }

  /// Initialization: Acquire initial GPS (or default) and load route + trails
  Future<void> initNavigation() async {
    await _acquireLocation(silent: true);
    await fetchRoute();
    await fetchNearbyTrails();
  }

  /// Acquire GPS position from device
  Future<void> acquireCurrentLocation() async => _acquireLocation(silent: false);

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
        name: 'My GPS Location',
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

  /// Fetch Sovereign route from POST /api/v1/routes or GET /api/v1/routes
  Future<void> fetchRoute() async {
    state = state.copyWith(isLoadingRoute: true, error: () => null);

    try {
      final originCoord = state.effectiveOriginPoint;
      final dest = state.destination;

      // Check if we have intermediate 'via' stops (trail stops or detours)
      final viaPoints = <Map<String, dynamic>>[];
      if (state.selectedTrail != null && state.selectedTrail!.stops.isNotEmpty) {
        for (final stop in state.selectedTrail!.stops) {
          viaPoints.add({
            'lat': stop.lat,
            'lng': stop.lng,
          });
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
          data: {
            'origin': '${originCoord.latitude},${originCoord.longitude}',
            'destination': '${dest.lat},${dest.lng}',
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
            'origin': '${originCoord.latitude},${originCoord.longitude}',
            'destination': '${dest.lat},${dest.lng}',
            'costing': state.costing.key,
            'avoid_congested': state.avoidCongested,
          },
        );
        responseData = response.data['data'] as Map<String, dynamic>;
      }

      final routeModel = RouteModel.fromJson(responseData);

      state = state.copyWith(
        route: () => routeModel,
        isLoadingRoute: false,
      );
    } catch (e) {
      debugPrint('[Navigation] Routing error: $e');
      // If backend fails, build a degraded straight-line fallback (never crash)
      final fallbackRoute = _buildStraightLineFallback(
        state.effectiveOriginPoint,
        LatLng(state.destination.lat, state.destination.lng),
      );
      state = state.copyWith(
        route: () => fallbackRoute,
        isLoadingRoute: false,
        error: () => 'Sovereign routing unavailable. Showing direct estimate.',
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
}

/// Family provider keyed by NavTarget
final navigationProvider = StateNotifierProvider.autoDispose
    .family<NavigationNotifier, NavigationState, NavTarget>(
  (ref, destination) {
    final apiClient = ref.watch(apiClientProvider);
    final trailsApi = ref.watch(trailsApiProvider);
    return NavigationNotifier(
      apiClient: apiClient,
      trailsApi: trailsApi,
      initialDestination: destination,
    );
  },
);
