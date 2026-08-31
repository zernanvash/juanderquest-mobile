import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/engine/orientation_math.dart';

void main() {
  group('OrientationMath rear-camera frame', () {
    test('upright phone facing north is level at zero heading', () {
      final orientation = OrientationMath.calculate(
        ax: 0,
        ay: 9.81,
        az: 0,
        mx: 0,
        my: 0,
        mz: -50,
      );

      expect(orientation, isNotNull);
      expect(orientation!.headingDegrees, closeTo(0, 0.01));
      expect(orientation.pitchDegrees, closeTo(0, 0.01));
      expect(orientation.rollDegrees, closeTo(0, 0.01));
    });

    test('upright phone facing east reports 90 degree heading', () {
      final orientation = OrientationMath.calculate(
        ax: 0,
        ay: 9.81,
        az: 0,
        mx: -50,
        my: 0,
        mz: 0,
      );

      expect(orientation!.headingDegrees, closeTo(90, 0.01));
    });

    test('camera pitch is measured from the horizon', () {
      final sine = math.sin(math.pi / 6);
      final cosine = math.cos(math.pi / 6);
      final orientation = OrientationMath.calculate(
        ax: 0,
        ay: 9.81 * cosine,
        az: -9.81 * sine,
        mx: 0,
        my: -50 * sine,
        mz: -50 * cosine,
      );

      expect(orientation!.headingDegrees, closeTo(0, 0.01));
      expect(orientation.pitchDegrees, closeTo(30, 0.01));
    });

    test('clockwise display roll uses a negative signed angle', () {
      final sine = math.sin(math.pi / 6);
      final cosine = math.cos(math.pi / 6);
      final orientation = OrientationMath.calculate(
        ax: -9.81 * sine,
        ay: 9.81 * cosine,
        az: 0,
        mx: 0,
        my: 0,
        mz: -50,
      );

      expect(orientation!.rollDegrees, closeTo(-30, 0.01));
      expect(orientation.headingDegrees, closeTo(0, 0.01));
    });

    test('heading becomes unreliable when camera points vertically', () {
      final orientation = OrientationMath.calculate(
        ax: 0,
        ay: 0,
        az: -9.81,
        mx: 0,
        my: 50,
        mz: 0,
      );

      expect(orientation!.pitchDegrees, closeTo(90, 0.01));
      expect(orientation.headingDegrees, isNull);
    });

    test('invalid accelerometer vector produces no orientation', () {
      expect(
        OrientationMath.calculate(
          ax: 0,
          ay: 0,
          az: 0,
          mx: 0,
          my: 0,
          mz: -50,
        ),
        isNull,
      );
    });
  });
}
