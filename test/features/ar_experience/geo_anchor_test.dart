import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/geo_anchor.dart';

/// Column-major view matrix for a camera at [pos] looking along yaw [yawDeg]
/// (clockwise from ARCore -Z), level with the ground.
List<double> viewFor(List<double> pos, double yawDeg) {
  final a = yawDeg * math.pi / 180;
  // Camera axes in world space: right, up, back (= -forward).
  final f = [math.sin(a), 0.0, -math.cos(a)];
  final r = [math.cos(a), 0.0, math.sin(a)];
  const u = [0.0, 1.0, 0.0];
  final b = [-f[0], -f[1], -f[2]];
  double dot(List<double> x, List<double> y) => x[0] * y[0] + x[1] * y[1] + x[2] * y[2];
  // View = [R^T | -R^T p]; rows of R^T are the camera axes.
  final m = List<double>.filled(16, 0);
  for (var c = 0; c < 3; c++) {
    m[c * 4 + 0] = r[c];
    m[c * 4 + 1] = u[c];
    m[c * 4 + 2] = b[c];
  }
  m[12] = -dot(r, pos);
  m[13] = -dot(u, pos);
  m[14] = -dot(b, pos);
  m[15] = 1;
  return m;
}

void main() {
  test('east/north offset and polar form', () {
    final o = GeoAnchor.enuOffset(16.0, 120.0, 16.001, 120.0);
    expect(o.north, closeTo(111.32, 0.01));
    expect(o.east, closeTo(0, 1e-9));
    final p = GeoAnchor.polar(10, 0);
    expect(p.bearing, closeTo(90, 1e-9));
    expect(p.distance, closeTo(10, 1e-9));
    expect(GeoAnchor.polar(-5, -5).bearing, closeTo(225, 1e-9));
  });

  test('camera position and yaw from a view matrix', () {
    for (final yaw in [0.0, 45.0, 90.0, 200.0, 359.0]) {
      final v = viewFor([1, 1.5, -3], yaw);
      final c = GeoAnchor.cameraPosition(v);
      expect(c.x, closeTo(1, 1e-9));
      expect(c.y, closeTo(1.5, 1e-9));
      expect(c.z, closeTo(-3, 1e-9));
      expect(GeoAnchor.cameraYaw(v), closeTo(yaw, 1e-6));
    }
  });

  test('a target due east lands to the east once the heading is known', () {
    // Camera looks along ARCore -Z, and the compass says that is north (offset 0).
    final p = GeoAnchor.localPoint(camX: 2, camZ: 5, bearing: 90, distance: 10, headingOffset: 0);
    expect(p.x, closeTo(12, 1e-9));
    expect(p.z, closeTo(5, 1e-9));
    // Same target when ARCore's -Z actually points east (offset 90): straight ahead.
    final q = GeoAnchor.localPoint(camX: 0, camZ: 0, bearing: 90, distance: 10, headingOffset: 90);
    expect(q.x, closeTo(0, 1e-9));
    expect(q.z, closeTo(-10, 1e-9));
  });

  test('heading calibration averages across north and reports spread', () {
    final c = HeadingCalibration();
    for (var i = 0; i < 20; i++) {
      c.add(compassBearing: i.isEven ? 2 : 358, arYaw: 0);
    }
    expect(c.offset! < 0.5 || c.offset! > 359.5, isTrue);
    expect(c.spread, lessThan(3));
    expect(c.ready, isTrue);

    final noisy = HeadingCalibration();
    for (var i = 0; i < 20; i++) {
      noisy.add(compassBearing: i.isEven ? 60 : 300, arYaw: 0);
    }
    expect(noisy.ready, isFalse);
  });
}
