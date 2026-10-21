import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/world_ar.dart';

/// Column-major perspective matrix like ARCore's getProjectionMatrix.
List<double> perspective(
        {double a = 2.0, double b = 1.0, double n = 0.05, double f = 100}) =>
    [
      a, 0, 0, 0, //
      0, b, 0, 0, //
      0, 0, -(f + n) / (f - n), -1, //
      0, 0, -2 * f * n / (f - n), 0,
    ];

const identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

List<double> anchorAt(double x, double y, double z) =>
    [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];

void main() {
  const screen = Size(400, 800);

  test('parses a native frame', () {
    final f = WorldArFrame.fromMap({
      'state': 'tracking',
      'reason': 'none',
      'planes': 2,
      'view': identity,
      'proj': perspective(),
      'anchor': anchorAt(0, -1, -3),
    });
    expect(f.tracking, isTrue);
    expect(f.planes, 2);
    expect(f.anchor, hasLength(16));
    expect(WorldArFrame.fromMap({'state': 'paused'}).tracking, isFalse);
  });

  test('an anchor straight ahead (after the lift) is in the centre', () {
    final f = WorldArFrame(
      state: 'tracking',
      reason: 'none',
      planes: 1,
      view: identity,
      proj: perspective(),
      anchor: anchorAt(0, -WorldProjection.liftM, -3),
    );
    final p = WorldProjection.project(f, screen)!;
    expect(p.inFront, isTrue);
    expect(p.offset.dx, closeTo(200, 0.01));
    expect(p.offset.dy, closeTo(400, 0.01));
    expect(p.depth, closeTo(3, 1e-9));
  });

  test('an anchor to the right maps right and reports its angle', () {
    final f = WorldArFrame(
      state: 'tracking',
      reason: 'none',
      planes: 1,
      view: identity,
      proj: perspective(a: 2.0),
      anchor: anchorAt(1, -WorldProjection.liftM, -2),
    );
    final p = WorldProjection.project(f, screen)!;
    // ndc x = a * x / depth = 2 * 1 / 2 = 1 -> right edge.
    expect(p.offset.dx, closeTo(400, 0.01));
    expect(WorldProjection.relativeDegrees(f), closeTo(26.565, 0.01));
    expect(WorldProjection.focalPx(f, screen), closeTo(400, 1e-9));
  });

  test('an anchor behind the camera is not drawn in front', () {
    final f = WorldArFrame(
      state: 'tracking',
      reason: 'none',
      planes: 1,
      view: identity,
      proj: perspective(),
      anchor: anchorAt(0, 0, 3),
    );
    expect(WorldProjection.project(f, screen)!.inFront, isFalse);
  });

  test('no anchor or no tracking means nothing to draw', () {
    expect(
        WorldProjection.project(
            const WorldArFrame(
                state: 'paused', reason: 'excessive_motion', planes: 0),
            screen),
        isNull);
    expect(
        const WorldArFrame(
                state: 'paused', reason: 'insufficient_light', planes: 0)
            .trackingHint,
        contains('dark'));
  });
}
