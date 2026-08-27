import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Geometric & Geographic projection utility for World-Anchored Augmented Reality.
class SpatialMath {
  static const double degreesToRadians = math.pi / 180.0;
  static const double radiansToDegrees = 180.0 / math.pi;

  /// Calculates the Initial Forward Azimuth (Bearing) in degrees [0..360)
  /// from Traveler [fromLat], [fromLng] to Target [toLat], [toLng] via Great Circle formula.
  static double calculateBearing({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final phi1 = fromLat * degreesToRadians;
    final phi2 = toLat * degreesToRadians;
    final deltaLambda = (toLng - fromLng) * degreesToRadians;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final initialBearing = math.atan2(y, x) * radiansToDegrees;
    return (initialBearing + 360.0) % 360.0;
  }

  /// Calculates the relative angle delta in degrees [-180..+180] between
  /// the target [targetBearing] and the current device [deviceHeading].
  ///
  /// - 0°: Target is directly in front of the camera.
  /// - Negative (-90°): Target is to the user's left.
  /// - Positive (+90°): Target is to the user's right.
  /// - ±180°: Target is directly behind the user.
  static double normalizeAngleDelta(double targetBearing, double deviceHeading) {
    double diff = (targetBearing - deviceHeading) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  /// Computes the 2D screen projection of a 3D world-anchored entity.
  ///
  /// - [relativeAzimuthDeg]: Angle delta from camera heading [-180..+180].
  /// - [pitchDeg]: Camera pitch inclination [-90..+90] (0 = level horizon, positive = tilted up).
  /// - [distanceMeters]: Physical distance to target in meters.
  /// - [cameraFovDeg]: Horizontal field of view of device camera (default ~65° on Android).
  static ProjectedSpatialPoint projectWorldToScreen({
    required double relativeAzimuthDeg,
    required double pitchDeg,
    required double distanceMeters,
    required Size screenSize,
    double cameraFovDeg = 65.0,
    double verticalFovDeg = 85.0,
  }) {
    final halfWidth = screenSize.width / 2.0;
    final halfHeight = screenSize.height / 2.0;

    // Horizontal pixel offset based on Field of View (FOV)
    final horizontalPixelsPerDegree = screenSize.width / cameraFovDeg;
    final screenX = halfWidth + (relativeAzimuthDeg * horizontalPixelsPerDegree);

    // Vertical pixel offset based on camera pitch
    // When pitch is 0 (level), entity hovers slightly above center horizon
    final verticalPixelsPerDegree = screenSize.height / verticalFovDeg;
    final screenY = halfHeight - (pitchDeg * verticalPixelsPerDegree);

    // Check if the entity falls within visible viewport boundaries
    final isWithinHorizontalFov = relativeAzimuthDeg.abs() <= (cameraFovDeg / 2.0 + 10.0);
    final isWithinVerticalFov = screenY >= -50.0 && screenY <= (screenSize.height + 50.0);
    final isVisible = isWithinHorizontalFov && isWithinVerticalFov;

    // Depth scale factor: Object appears larger when closer (10m = 1.2x, 100m = 0.45x)
    final clampedDistance = distanceMeters.clamp(5.0, 150.0);
    final scale = (1.4 - (clampedDistance / 150.0) * 0.95).clamp(0.40, 1.35);

    // Opacity: smoothly fades out when very far away (> 120m)
    final opacity = (1.0 - ((distanceMeters - 80.0) / 70.0)).clamp(0.25, 1.0);

    return ProjectedSpatialPoint(
      offset: Offset(screenX, screenY),
      isVisibleInViewport: isVisible,
      relativeAzimuthDeg: relativeAzimuthDeg,
      scaleFactor: scale,
      opacity: opacity,
      distanceMeters: distanceMeters,
    );
  }
}

/// Represents the calculated screen projection result of a spatial entity.
class ProjectedSpatialPoint {
  final Offset offset;
  final bool isVisibleInViewport;
  final double relativeAzimuthDeg;
  final double scaleFactor;
  final double opacity;
  final double distanceMeters;

  const ProjectedSpatialPoint({
    required this.offset,
    required this.isVisibleInViewport,
    required this.relativeAzimuthDeg,
    required this.scaleFactor,
    required this.opacity,
    required this.distanceMeters,
  });

  /// Directional hint if the target is off-screen.
  /// Returns 'LEFT' if user needs to turn left, 'RIGHT' if right, 'BEHIND' if behind.
  String get offScreenDirectionHint {
    if (relativeAzimuthDeg.abs() > 135.0) return 'BEHIND';
    if (relativeAzimuthDeg < 0) return 'LEFT';
    return 'RIGHT';
  }
}
