import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Geometric, Geographic, and Perspective Projection utility for World-Anchored Augmented Reality.
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
  static double normalizeAngleDelta(
      double targetBearing, double deviceHeading) {
    double diff = (targetBearing - deviceHeading) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  /// Computes the relative elevation/pitch angle delta in degrees between
  /// target altitude angle [targetElevationDeg] (typically 0° for horizon)
  /// and current device camera pitch [devicePitchDeg].
  ///
  /// When camera tilts UP (+20°), relative pitch is -20°, which moves the
  /// world entity DOWN on the screen (correct optical perspective).
  static double calculateRelativePitch({
    double targetElevationDeg = 0.0,
    required double devicePitchDeg,
  }) {
    return targetElevationDeg - devicePitchDeg;
  }

  /// Computes the 2D screen projection of a 3D world-anchored entity with
  /// true 3-DoF camera perspective (Azimuth, Pitch, and Roll compensation).
  ///
  /// - [relativeAzimuthDeg]: Angle delta from camera heading [-180..+180].
  /// - [relativePitchDeg]: Angle delta from camera pitch (target elevation - device pitch).
  /// - [rollDeg]: Device roll / sideways tilt in degrees [-180..+180].
  /// - [distanceMeters]: Physical distance to target in meters.
  /// - [screenSize]: Screen viewport dimensions.
  /// - [cameraFovDeg]: Horizontal field of view (default ~55 degrees).
  /// - [verticalFovDeg]: Vertical field of view (default ~70 degrees).
  static ProjectedSpatialPoint projectWorldToScreen({
    required double relativeAzimuthDeg,
    required double
        pitchDeg, // Relative pitch delta (targetElevation - cameraPitch)
    double rollDeg = 0.0,
    required double distanceMeters,
    required Size screenSize,
    double cameraFovDeg = 55.0,
    double verticalFovDeg = 70.0,
  }) {
    final halfWidth = screenSize.width / 2.0;
    final halfHeight = screenSize.height / 2.0;

    final yaw = relativeAzimuthDeg * degreesToRadians;
    final elevation = pitchDeg * degreesToRadians;

    // Camera-space unit direction. +x is right, +y is up, +z is forward.
    final cameraX = math.sin(yaw) * math.cos(elevation);
    final cameraY = math.sin(elevation);
    final cameraZ = math.cos(yaw) * math.cos(elevation);

    // Pinhole projection avoids the edge drift caused by linear degree-to-pixel
    // mapping. Portrait FOV defaults are intentionally narrower horizontally.
    final focalX = halfWidth / math.tan(cameraFovDeg * degreesToRadians / 2.0);
    final focalY =
        halfHeight / math.tan(verticalFovDeg * degreesToRadians / 2.0);
    final safeDepth = math.max(cameraZ, 1e-4);
    final unrotatedDx = focalX * cameraX / safeDepth;
    final unrotatedDy = -focalY * cameraY / safeDepth;

    // OrientationMath reports clockwise display roll as a negative angle.
    // Applying that signed angle here keeps a fixed world point stationary.
    final rollRad = rollDeg * degreesToRadians;
    final cosR = math.cos(rollRad);
    final sinR = math.sin(rollRad);

    final rotatedDx = unrotatedDx * cosR - unrotatedDy * sinR;
    final rotatedDy = unrotatedDx * sinR + unrotatedDy * cosR;

    final screenX = halfWidth + rotatedDx;
    final screenY = halfHeight + rotatedDy;

    // 3. Viewport Boundary & Visibility Detection
    final marginX = screenSize.width * 0.12;
    final marginY = screenSize.height * 0.12;

    final isWithinHorizontalFov =
        screenX >= -marginX && screenX <= (screenSize.width + marginX);
    final isWithinVerticalFov =
        screenY >= -marginY && screenY <= (screenSize.height + marginY);
    final isFacingForward = cameraZ > 0.01;
    final isVisible =
        isFacingForward && isWithinHorizontalFov && isWithinVerticalFov;

    // 4. Depth scale factor: Object appears larger when closer (5m = 1.35x, 150m = 0.40x)
    final clampedDistance = distanceMeters.clamp(3.0, 150.0).toDouble();
    final scale =
        (1.40 - (clampedDistance / 150.0) * 0.95).clamp(0.38, 1.40).toDouble();

    // 5. Opacity & Smooth Edge Falloff:
    // Fades smoothly as distance increases > 70m, and fades smoothly near screen boundaries
    var distanceOpacity =
        (1.0 - ((distanceMeters - 70.0) / 80.0)).clamp(0.30, 1.0).toDouble();
    final edgeRatio = math.max(
      rotatedDx.abs() / (halfWidth + marginX),
      rotatedDy.abs() / (halfHeight + marginY),
    );
    final edgeOpacity = edgeRatio <= 0.78
        ? 1.0
        : (1.0 - (edgeRatio - 0.78) / 0.22).clamp(0.0, 1.0).toDouble();
    distanceOpacity *= edgeOpacity;
    if (!isFacingForward) distanceOpacity = 0.0;

    return ProjectedSpatialPoint(
      offset: Offset(screenX, screenY),
      isVisibleInViewport: isVisible,
      relativeAzimuthDeg: relativeAzimuthDeg,
      relativePitchDeg: pitchDeg,
      rollDeg: rollDeg,
      scaleFactor: scale,
      opacity: distanceOpacity,
      distanceMeters: distanceMeters,
    );
  }
}

/// Represents the calculated screen projection result of a spatial entity.
class ProjectedSpatialPoint {
  final Offset offset;
  final bool isVisibleInViewport;
  final double relativeAzimuthDeg;
  final double relativePitchDeg;
  final double rollDeg;
  final double scaleFactor;
  final double opacity;
  final double distanceMeters;

  const ProjectedSpatialPoint({
    required this.offset,
    required this.isVisibleInViewport,
    required this.relativeAzimuthDeg,
    this.relativePitchDeg = 0.0,
    this.rollDeg = 0.0,
    required this.scaleFactor,
    required this.opacity,
    required this.distanceMeters,
  });

  /// Directional hint if the target is off-screen.
  /// Returns 'LEFT', 'RIGHT', 'UP', 'DOWN', or 'BEHIND'.
  String get offScreenDirectionHint {
    if (relativeAzimuthDeg.abs() > 120.0) return 'BEHIND';
    if (relativePitchDeg < -35.0) return 'DOWN';
    if (relativePitchDeg > 35.0) return 'UP';
    if (relativeAzimuthDeg < 0) return 'LEFT';
    return 'RIGHT';
  }

  /// Angular deviation magnitude from center crosshair (for reticle lock detection).
  double get angularDeviationFromCenter =>
      math.sqrt(relativeAzimuthDeg * relativeAzimuthDeg +
          relativePitchDeg * relativePitchDeg);

  /// Whether the entity is closely aligned within the central reticle (7.5° cone).
  bool get isInReticleLockCone =>
      isVisibleInViewport && angularDeviationFromCenter <= 7.5;
}
