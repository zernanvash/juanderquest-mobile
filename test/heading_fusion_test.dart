import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_math.dart';
import 'package:juanderquest_app/features/ar_experience/core/heading_fusion.dart';

List<double> _q(Quat q) => [q.x, q.y, q.z, q.w];

void main() {
  // Game vector fixed at identity; the compass (rotation vector) says yaw = [rad].
  void feed(HeadingFusion f, double rad, double tMs) {
    f.addEvent({'src': 'game', 'q': _q(Quat.identity), 't': tMs});
    f.addEvent({'src': 'rot', 'q': _q(Quat.aboutUp(rad)), 't': tMs, 'acc': 5});
  }

  double yaw(HeadingFusion f) =>
      HeadingFusion.yawBetween(f.pose.orientation, Quat.identity);

  test('unlocked, the scene follows a wandering compass', () {
    final f = HeadingFusion();
    feed(f, 0.0, 0);
    for (var t = 20; t <= 10000; t += 20) {
      feed(f, 0.5, t.toDouble());
    }
    expect(yaw(f), closeTo(0.5, 0.02));
  });

  test('locked, compass changes no longer move the scene (no drift)', () {
    final f = HeadingFusion();
    feed(f, 0.2, 0);
    expect(yaw(f), closeTo(0.2, 1e-9));
    f.lockHeading();
    for (var t = 20; t <= 10000; t += 20) {
      feed(f, 0.2 + 0.3 * math.sin(t / 700), t.toDouble());
    }
    expect(yaw(f), closeTo(0.2, 1e-9));

    f.unlockHeading();
    for (var t = 10020; t <= 20000; t += 20) {
      feed(f, 0.6, t.toDouble());
    }
    expect(yaw(f), closeTo(0.6, 0.02));
  });

  test('reset clears the lock', () {
    final f = HeadingFusion()..lockHeading();
    f.reset();
    expect(f.headingLocked, isFalse);
  });
}
