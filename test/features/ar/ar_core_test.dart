import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_math.dart';
import 'package:juanderquest_app/features/ar_experience/core/camera_optics.dart';
import 'package:juanderquest_app/features/ar_experience/core/heading_fusion.dart';

/// Phone held upright in portrait, camera facing [bearingDeg].
Quat uprightFacing(double bearingDeg) {
  // Upright facing north: device y -> world up, device -z -> north.
  final upright = Quat.axisAngle(const Vec3(1, 0, 0), math.pi / 2);
  // Turning clockwise by the bearing is a negative rotation about up.
  return Quat.aboutUp(-bearingDeg * math.pi / 180) * upright;
}

void main() {
  group('CameraPose', () {
    test('upright phone facing north looks at bearing 0, horizon', () {
      final pose = CameraPose(uprightFacing(0));
      expect(pose.bearing, closeTo(0, 1e-6));
      expect(pose.elevation, closeTo(0, 1e-6));
    });

    test('bearing follows the turn', () {
      for (final b in [45.0, 90.0, 180.0, 271.5]) {
        expect(CameraPose(uprightFacing(b)).bearing, closeTo(b, 1e-6));
      }
    });

    test('tilting the phone up raises the elevation', () {
      // Tilt top of phone backwards by 20° about the device x axis.
      final q = uprightFacing(0) *
          Quat.axisAngle(const Vec3(1, 0, 0), 20 * math.pi / 180);
      final pose = CameraPose(q);
      expect(pose.elevation, closeTo(20, 1e-6));
      expect(pose.bearing, closeTo(0, 1e-6));
    });
  });

  group('ArProjector', () {
    const screen = Size(360, 780);
    const projector = ArProjector(focalPx: 600, screen: screen);

    test('a point straight ahead lands in the centre', () {
      final pose = CameraPose(uprightFacing(90));
      final p = projector.project(pose, ArGeo.directionFor(90) * 3.5);
      expect(p.inFront, isTrue);
      expect(p.offset.dx, closeTo(180, 0.5));
      expect(p.offset.dy, closeTo(390, 0.5));
      expect(p.depth, closeTo(3.5, 1e-9));
    });

    test('a point to the right and above maps right and up', () {
      final pose = CameraPose(uprightFacing(0));
      // 1 m east, 0.5 m up, 4 m north.
      final p = projector.project(pose, const Vec3(1, 4, 0.5));
      expect(p.offset.dx, closeTo(180 + 600 * 1 / 4, 0.5));
      expect(p.offset.dy, closeTo(390 - 600 * 0.5 / 4, 0.5));
    });

    test('a point behind the camera is not in front', () {
      final pose = CameraPose(uprightFacing(0));
      final p = projector.project(pose, const Vec3(0, -3, 0));
      expect(p.inFront, isFalse);
      expect(p.onScreen, isFalse);
    });

    test('rolling the phone keeps an object centred when it is centred', () {
      final rolled = uprightFacing(30) *
          Quat.axisAngle(const Vec3(0, 0, 1), 25 * math.pi / 180);
      final p = projector.project(
          CameraPose(rolled), ArGeo.directionFor(30) * 3.5);
      expect(p.offset.dx, closeTo(180, 0.5));
      expect(p.offset.dy, closeTo(390, 0.5));
    });

    test('pixel size shrinks with distance', () {
      expect(projector.pixelSize(0.5, 2), closeTo(150, 1e-9));
      expect(projector.pixelSize(0.5, 4), closeTo(75, 1e-9));
    });
  });

  group('ArGeo', () {
    test('bearing and distance between two Pangasinan points', () {
      // Dagupan city hall -> ~1.11 km due north.
      final d = ArGeo.distanceMeters(16.0430, 120.3333, 16.0530, 120.3333);
      expect(d, closeTo(1112, 2));
      expect(ArGeo.bearingDegrees(16.0430, 120.3333, 16.0530, 120.3333),
          closeTo(0, 0.01));
      expect(ArGeo.bearingDegrees(16.0430, 120.3333, 16.0430, 120.3433),
          closeTo(90, 0.1));
    });

    test('deltaDegrees wraps across north', () {
      expect(ArGeo.deltaDegrees(10, 350), closeTo(20, 1e-9));
      expect(ArGeo.deltaDegrees(350, 10), closeTo(-20, 1e-9));
    });
  });

  group('CameraOptics', () {
    test('fallback camera is about 66° along the long side', () {
      expect(CameraOptics.fallback.longFovDeg, closeTo(66, 0.5));
    });

    test('4:3 stream on a tall screen uses the full long side', () {
      final f = CameraOptics.fallback
          .focalPixels(screen: const Size(360, 780), previewAspect: 4 / 3);
      // Cover-scaled preview is 780 px tall; tan(33°) ≈ 0.649.
      expect(f, closeTo(390 / (5.52 / (2 * 4.25)), 0.5));
    });

    test('16:9 stream crops the sensor short side', () {
      final f = CameraOptics.fallback
          .focalPixels(screen: const Size(360, 780), previewAspect: 16 / 9);
      final scale = 780 / (360 * 16 / 9);
      final shownLong = 360 * 16 / 9 * scale;
      expect(f, closeTo((shownLong / 2) / (5.52 / (2 * 4.25)), 0.5));
    });

    test('reads native intrinsics and orders the sides', () {
      final o = CameraOptics.fromMap({
        'focalLengthMm': 5.0,
        'sensorWidthMm': 4.8,
        'sensorHeightMm': 6.4,
      })!;
      expect(o.sensorWidthMm, 6.4);
      expect(o.sensorHeightMm, 4.8);
      expect(CameraOptics.fromMap({'focalLengthMm': 0}), isNull);
    });
  });

  group('HeadingFusion', () {
    Map<String, Object> ev(String src, Quat q, {double t = 0, double acc = 5}) =>
        {
          'src': src,
          'q': [q.x, q.y, q.z, q.w],
          'acc': acc,
          't': t,
        };

    test('north-aligns the smooth game rotation', () {
      final fusion = HeadingFusion();
      // Game frame thinks we face 0°, the compass says 70°.
      fusion.addEvent(ev('game', uprightFacing(0)));
      fusion.addEvent(ev('rot', uprightFacing(70)));
      expect(fusion.pose.source, PoseSource.game);
      expect(fusion.pose.camera.bearing, closeTo(70, 0.01));
    });

    test('a sudden compass jump is absorbed slowly', () {
      final fusion = HeadingFusion(settleSeconds: 2.5);
      fusion.addEvent(ev('game', uprightFacing(0)));
      fusion.addEvent(ev('rot', uprightFacing(0), t: 0));
      // Magnetic disturbance: compass jumps 60° for 100 ms.
      for (var i = 1; i <= 5; i++) {
        fusion.addEvent(ev('rot', uprightFacing(60), t: i * 20.0));
      }
      final b = fusion.pose.camera.bearing;
      expect(b, greaterThan(0.5));
      expect(b, lessThan(5));
    });

    test('freezes the yaw while the magnetometer is unreliable', () {
      final fusion = HeadingFusion(settleSeconds: 0.1);
      fusion.addEvent(ev('game', uprightFacing(0)));
      fusion.addEvent(ev('rot', uprightFacing(10), t: 0));
      fusion.addEvent({'src': 'status', 'mag': 0});
      for (var i = 1; i <= 50; i++) {
        fusion.addEvent(ev('rot', uprightFacing(90), t: i * 20.0));
      }
      expect(fusion.pose.camera.bearing, closeTo(10, 0.01));
      expect(fusion.pose.compassUnreliable, isTrue);
    });

    test('turning the phone moves the view immediately (gyro path)', () {
      final fusion = HeadingFusion();
      fusion.addEvent(ev('game', uprightFacing(0)));
      fusion.addEvent(ev('rot', uprightFacing(0)));
      fusion.addEvent(ev('game', uprightFacing(45)));
      expect(fusion.pose.camera.bearing, closeTo(45, 0.01));
    });

    test('without a gyroscope accel+mag is smoothed', () {
      final fusion = HeadingFusion();
      fusion.addEvent(ev('accelMag', uprightFacing(0)));
      fusion.addEvent(ev('accelMag', uprightFacing(40)));
      final b = fusion.pose.camera.bearing;
      expect(fusion.pose.source, PoseSource.accelMag);
      expect(b, greaterThan(1));
      expect(b, lessThan(40));
    });

    test('yawBetween recovers a pure rotation about up', () {
      final g = uprightFacing(12);
      final r = Quat.aboutUp(0.4) * g;
      expect(HeadingFusion.yawBetween(r, g), closeTo(0.4, 1e-9));
    });
  });
}
