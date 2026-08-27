import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/route_model.dart';

/// Default fallback coordinate: Lingayen Provincial Capitol, Pangasinan
const LatLng kDefaultOrigin = LatLng(16.0218, 120.2319);

/// State for the sovereign Valhalla turn-by-turn navigation engine
class NavigationState {
  final LatLng? userLocation;
  final NavTarget destination;
  final TravelCosting costing;
  final bool avoidCongested;
  final RouteModel? route;
  final bool isLoadingRoute;
  final bool isLocating;
  final String? error;
  final int? activeStepIndex;

  const NavigationState({
    this.userLocation,
    required this.destination,
    this.costing = TravelCosting.auto,
    this.avoidCongested = true,
    this.route,
    this.isLoadingRoute = false,
    this.isLocating = false,
    this.error,
    this.activeStepIndex,
  });

  NavigationState copyWith({
    LatLng? userLocation,
    NavTarget? destination,
    TravelCosting? costing,
    bool? avoidCongested,
    RouteModel? Function()? route,
    bool? isLoadingRoute,
    bool? isLocating,
    String? Function()? error,
    int? Function()? activeStepIndex,
  }) {
    return NavigationState(
      userLocation: userLocation ?? this.userLocation,
      destination: destination ?? this.destination,
      costing: costing ?? this.costing,
      avoidCongested: avoidCongested ?? this.avoidCongested,
      route: route != null ? route() : this.route,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      isLocating: isLocating ?? this.isLocating,
      error: error != null ? error() : this.error,
      activeStepIndex: activeStepIndex != null ? activeStepIndex() : this.activeStepIndex,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final ApiClient _apiClient;

  NavigationNotifier({
    required ApiClient apiClient,
    required NavTarget initialDestination,
  })  : _apiClient = apiClient,
        super(NavigationState(destination: initialDestination)) {
    initNavigation();
  }

  /// Initialize GPS capture and fetch initial route
  Future<void> initNavigation() async {
    await acquireCurrentLocation();
    await fetchRoute();
  }

  /// Acquire real-time device GPS coordinates with graceful fallback to Lingayen Capitol
  Future<void> acquireCurrentLocation() async {
    state = state.copyWith(isLocating: true, error: () => null);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          userLocation: kDefaultOrigin,
          isLocating: false,
          error: () => 'GPS disabled. Using Lingayen Capitol as default origin.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          userLocation: kDefaultOrigin,
          isLocating: false,
          error: () => 'GPS permission denied. Using Lingayen Capitol as origin.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      state = state.copyWith(
        userLocation: LatLng(position.latitude, position.longitude),
        isLocating: false,
      );
    } catch (e) {
      debugPrint('[Navigation] Location acquisition note: $e');
      state = state.copyWith(
        userLocation: state.userLocation ?? kDefaultOrigin,
        isLocating: false,
        error: () => 'Using Lingayen Capitol as origin.',
      );
    }
  }

  /// Fetch calculated route from Azure VM Valhalla daemon via backend REST API
  Future<void> fetchRoute() async {
    final origin = state.userLocation ?? kDefaultOrigin;
    final dest = state.destination;

    state = state.copyWith(isLoadingRoute: true, error: () => null);

    try {
      final response = await _apiClient.dio.get(
        '/routes',
        queryParameters: {
          'start_lat': origin.latitude,
          'start_lng': origin.longitude,
          'end_lat': dest.lat,
          'end_lng': dest.lng,
          'costing': state.costing.key,
          'avoid_congested': state.avoidCongested,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final routeData = response.data['data'] as Map<String, dynamic>;
        final route = RouteModel.fromJson(routeData);

        state = state.copyWith(
          route: () => route,
          isLoadingRoute: false,
          activeStepIndex: () => null,
        );
      } else {
        throw Exception(response.data['error']?['message'] ?? 'Failed to compute route');
      }
    } catch (e) {
      debugPrint('[Navigation] Error fetching route: $e');
      state = state.copyWith(
        isLoadingRoute: false,
        error: () => 'Could not calculate navigation route. Please check connection.',
      );
    }
  }

  /// Change travel costing mode (auto, motorcycle, bicycle, pedestrian)
  void setCosting(TravelCosting costing) {
    if (state.costing == costing) return;
    state = state.copyWith(costing: costing);
    fetchRoute();
  }

  /// Toggle anti-crowd diversion avoidance polygons
  void toggleAvoidCongested() {
    state = state.copyWith(avoidCongested: !state.avoidCongested);
    fetchRoute();
  }

  /// Focus active maneuver step
  void setActiveStep(int? index) {
    state = state.copyWith(activeStepIndex: () => index);
  }

  /// Update destination and re-route
  void updateDestination(NavTarget newDest) {
    state = state.copyWith(
      destination: newDest,
      activeStepIndex: () => null,
    );
    fetchRoute();
  }
}

/// Family provider keyed by NavTarget
final navigationProvider = StateNotifierProvider.autoDispose
    .family<NavigationNotifier, NavigationState, NavTarget>(
  (ref, destination) {
    final apiClient = ref.watch(apiClientProvider);
    return NavigationNotifier(
      apiClient: apiClient,
      initialDestination: destination,
    );
  },
);
