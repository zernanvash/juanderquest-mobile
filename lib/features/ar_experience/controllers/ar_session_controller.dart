import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ArTier {
  surfaceSlam('Tier 1: Surface SLAM'),
  markerVision('Tier 2: Marker Vision'),
  geoSpatial('Tier 3: Geo-Spatial AR');

  final String label;
  const ArTier(this.label);
}

class ArSessionState {
  final ArTier activeTier;
  final bool isCameraActive;
  final bool isMarkerLocked;
  final bool isWithinGeofence;
  final double distanceToTargetMeters;
  final double targetBearingDegrees;
  final double relativeAzimuthDegrees;
  final String? scannedMarkerCode;
  final bool isClaimed;

  const ArSessionState({
    this.activeTier = ArTier.geoSpatial,
    this.isCameraActive = true,
    this.isMarkerLocked = false,
    this.isWithinGeofence = false,
    this.distanceToTargetMeters = 0.0,
    this.targetBearingDegrees = 0.0,
    this.relativeAzimuthDegrees = 0.0,
    this.scannedMarkerCode,
    this.isClaimed = false,
  });

  ArSessionState copyWith({
    ArTier? activeTier,
    bool? isCameraActive,
    bool? isMarkerLocked,
    bool? isWithinGeofence,
    double? distanceToTargetMeters,
    double? targetBearingDegrees,
    double? relativeAzimuthDegrees,
    String? scannedMarkerCode,
    bool? isClaimed,
  }) {
    return ArSessionState(
      activeTier: activeTier ?? this.activeTier,
      isCameraActive: isCameraActive ?? this.isCameraActive,
      isMarkerLocked: isMarkerLocked ?? this.isMarkerLocked,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      distanceToTargetMeters: distanceToTargetMeters ?? this.distanceToTargetMeters,
      targetBearingDegrees: targetBearingDegrees ?? this.targetBearingDegrees,
      relativeAzimuthDegrees: relativeAzimuthDegrees ?? this.relativeAzimuthDegrees,
      scannedMarkerCode: scannedMarkerCode ?? this.scannedMarkerCode,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }
}

class ArSessionNotifier extends StateNotifier<ArSessionState> {
  ArSessionNotifier() : super(const ArSessionState());

  void setTier(ArTier tier) {
    state = state.copyWith(activeTier: tier);
  }

  void updateTelemetry({
    required bool isWithinGeofence,
    required double distanceMeters,
    required double targetBearing,
    required double relativeAzimuth,
  }) {
    state = state.copyWith(
      isWithinGeofence: isWithinGeofence,
      distanceToTargetMeters: distanceMeters,
      targetBearingDegrees: targetBearing,
      relativeAzimuthDegrees: relativeAzimuth,
    );
  }

  void markClaimed() {
    state = state.copyWith(isClaimed: true);
  }
}

final arSessionProvider = StateNotifierProvider.autoDispose<ArSessionNotifier, ArSessionState>((ref) {
  return ArSessionNotifier();
});
