import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/engine/spatial_math.dart';

void main() {
  group('SpatialMath Great Circle & Bearing Tests', () {
    test('Calculates accurate bearing between Alaminos and Hundred Islands', () {
      // Alaminos City: 16.1560° N, 119.9810° E
      // Hundred Islands: 16.2045° N, 120.0435° E
      final bearing = SpatialMath.calculateBearing(
        fromLat: 16.1560,
        fromLng: 119.9810,
        toLat: 16.2045,
        toLng: 120.0435,
      );

      // Expected forward azimuth is approximately ~48.7° (North-East)
      expect(bearing, greaterThan(45.0));
      expect(bearing, lessThan(55.0));
    });

    test('Calculates accurate Cardinal Bearings (North, East, South, West)', () {
      // Due North
      final north = SpatialMath.calculateBearing(fromLat: 0.0, fromLng: 0.0, toLat: 1.0, toLng: 0.0);
      expect(north, closeTo(0.0, 0.01));

      // Due East
      final east = SpatialMath.calculateBearing(fromLat: 0.0, fromLng: 0.0, toLat: 0.0, toLng: 1.0);
      expect(east, closeTo(90.0, 0.01));

      // Due South
      final south = SpatialMath.calculateBearing(fromLat: 1.0, fromLng: 0.0, toLat: 0.0, toLng: 0.0);
      expect(south, closeTo(180.0, 0.01));

      // Due West
      final west = SpatialMath.calculateBearing(fromLat: 0.0, fromLng: 1.0, toLat: 0.0, toLng: 0.0);
      expect(west, closeTo(270.0, 0.01));
    });

    test('Normalizes angle delta across 359° <-> 0° circular boundaries', () {
      // Target at 10°, Heading at 350° -> Delta is +20° (Right)
      final deltaRight = SpatialMath.normalizeAngleDelta(10.0, 350.0);
      expect(deltaRight, closeTo(20.0, 0.01));

      // Target at 350°, Heading at 10° -> Delta is -20° (Left)
      final deltaLeft = SpatialMath.normalizeAngleDelta(350.0, 10.0);
      expect(deltaLeft, closeTo(-20.0, 0.01));

      // Target at 180°, Heading at 0° -> Delta is 180° (Directly behind)
      final deltaBehind = SpatialMath.normalizeAngleDelta(180.0, 0.0);
      expect(deltaBehind.abs(), closeTo(180.0, 0.01));
    });

    test('Projects 3D spatial points to screen coordinates with depth scaling and roll compensation', () {
      const screenSize = Size(360, 800);

      // Target directly centered in front of camera (0° azimuth, 0° pitch) at 20m
      final point = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: 0.0,
        pitchDeg: 0.0,
        rollDeg: 0.0,
        distanceMeters: 20.0,
        screenSize: screenSize,
      );

      expect(point.isVisibleInViewport, isTrue);
      expect(point.offset.dx, closeTo(180.0, 1.0)); // Centered horizontally
      expect(point.offset.dy, closeTo(400.0, 1.0)); // Centered vertically
      expect(point.scaleFactor, greaterThan(1.0));   // Close distance = larger scale
      expect(point.opacity, closeTo(1.0, 0.01));
      expect(point.isInReticleLockCone, isTrue);
    });

    test('Correctly calculates optical pitch perspective when device tilts up/down', () {
      // When target is at horizon (0°) and camera tilts UP (+20°), relative pitch is -20°
      final relativePitch = SpatialMath.calculateRelativePitch(
        targetElevationDeg: 0.0,
        devicePitchDeg: 20.0,
      );
      expect(relativePitch, closeTo(-20.0, 0.01));

      const screenSize = Size(360, 800);
      final point = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: 0.0,
        pitchDeg: relativePitch,
        distanceMeters: 20.0,
        screenSize: screenSize,
      );

      // Moving camera up must render the horizon object lower on screen (dy > 400)
      expect(point.offset.dy, greaterThan(400.0));
    });

    test('Keeps signed camera roll compensation consistent', () {
      const screenSize = Size(360, 800);
      final point = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: 10.0,
        pitchDeg: 0.0,
        rollDeg: -30.0,
        distanceMeters: 20.0,
        screenSize: screenSize,
      );

      expect(point.offset.dx, greaterThan(screenSize.width / 2));
      expect(point.offset.dy, lessThan(screenSize.height / 2));
    });

    test('Identifies off-screen directional hints correctly', () {
      const screenSize = Size(360, 800);

      // Target is 80° to the right (outside 65° FOV)
      final pointRight = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: 80.0,
        pitchDeg: 0.0,
        distanceMeters: 50.0,
        screenSize: screenSize,
      );

      expect(pointRight.isVisibleInViewport, isFalse);
      expect(pointRight.offScreenDirectionHint, 'RIGHT');

      // Target is -80° to the left
      final pointLeft = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: -80.0,
        pitchDeg: 0.0,
        distanceMeters: 50.0,
        screenSize: screenSize,
      );

      expect(pointLeft.isVisibleInViewport, isFalse);
      expect(pointLeft.offScreenDirectionHint, 'LEFT');

      // Target is 160° behind
      final pointBehind = SpatialMath.projectWorldToScreen(
        relativeAzimuthDeg: 160.0,
        pitchDeg: 0.0,
        distanceMeters: 50.0,
        screenSize: screenSize,
      );

      expect(pointBehind.isVisibleInViewport, isFalse);
      expect(pointBehind.offScreenDirectionHint, 'BEHIND');
    });
  });
}
