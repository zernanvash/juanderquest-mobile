import 'dart:math' as math;
import 'dart:ui';

/// A 3D vector in metres. World vectors use East-North-Up (x = east,
/// y = north, z = up). Device vectors use Android's device frame (x = right
/// of the screen, y = top of the screen, z = out of the screen).
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    return l < 1e-12 ? this : Vec3(x / l, y / l, z / l);
  }

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Unit quaternion (x, y, z, w) that rotates device-frame vectors into the
/// world frame, as reported by Android rotation-vector sensors.
class Quat {
  final double x;
  final double y;
  final double z;
  final double w;

  const Quat(this.x, this.y, this.z, this.w);

  static const identity = Quat(0, 0, 0, 1);

  factory Quat.fromList(List<dynamic> v) => Quat(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      ).normalized();

  /// Rotation of [radians] about the world up axis (counter-clockwise seen
  /// from above, i.e. from east towards north).
  factory Quat.aboutUp(double radians) =>
      Quat(0, 0, math.sin(radians / 2), math.cos(radians / 2));

  /// Rotation of [radians] about an arbitrary unit [axis].
  factory Quat.axisAngle(Vec3 axis, double radians) {
    final a = axis.normalized();
    final s = math.sin(radians / 2);
    return Quat(a.x * s, a.y * s, a.z * s, math.cos(radians / 2));
  }

  Quat get conjugate => Quat(-x, -y, -z, w);

  Quat normalized() {
    final n = math.sqrt(x * x + y * y + z * z + w * w);
    return n < 1e-12 ? identity : Quat(x / n, y / n, z / n, w / n);
  }

  /// Hamilton product: applying `this * o` to a vector applies [o] first.
  Quat operator *(Quat o) => Quat(
        w * o.x + x * o.w + y * o.z - z * o.y,
        w * o.y - x * o.z + y * o.w + z * o.x,
        w * o.z + x * o.y - y * o.x + z * o.w,
        w * o.w - x * o.x - y * o.y - z * o.z,
      );

  Vec3 rotate(Vec3 v) {
    // v' = v + 2w(q × v) + 2 q × (q × v)
    final qv = Vec3(x, y, z);
    final t = _cross(qv, v) * 2;
    return v + t * w + _cross(qv, t);
  }

  /// Normalised linear interpolation along the shorter arc.
  Quat nlerp(Quat to, double t) {
    final d = x * to.x + y * to.y + z * to.z + w * to.w;
    final s = d < 0 ? -1.0 : 1.0;
    return Quat(
      x + (to.x * s - x) * t,
      y + (to.y * s - y) * t,
      z + (to.z * s - z) * t,
      w + (to.w * s - w) * t,
    ).normalized();
  }

  static Vec3 _cross(Vec3 a, Vec3 b) => Vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );
}

/// Compass and bearing helpers. Bearings are degrees clockwise from north.
class ArGeo {
  static const double earthRadiusM = 6371008.8;

  static double normalizeBearing(double deg) => (deg % 360 + 360) % 360;

  /// Signed difference `a - b` wrapped into (-180, 180].
  static double deltaDegrees(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  /// Bearing of a horizontal world direction.
  static double bearingOf(Vec3 world) =>
      normalizeBearing(math.atan2(world.x, world.y) * 180 / math.pi);

  /// Unit world vector pointing at [bearingDeg] and [elevationDeg].
  static Vec3 directionFor(double bearingDeg, {double elevationDeg = 0}) {
    final b = bearingDeg * math.pi / 180;
    final e = elevationDeg * math.pi / 180;
    return Vec3(
        math.sin(b) * math.cos(e), math.cos(b) * math.cos(e), math.sin(e));
  }

  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }

  static double bearingDegrees(
      double lat1, double lng1, double lat2, double lng2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lng2 - lng1) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    return normalizeBearing(math.atan2(y, x) * 180 / math.pi);
  }
}

/// Where the camera looks, derived from a device->world orientation.
class CameraPose {
  final Quat orientation;

  const CameraPose(this.orientation);

  /// The rear camera looks along the device's -z axis.
  Vec3 get forward => orientation.rotate(const Vec3(0, 0, -1));

  /// Compass bearing of the camera's view direction.
  double get bearing => ArGeo.bearingOf(forward);

  /// Degrees above (+) or below (-) the horizon.
  double get elevation => math.asin(forward.z.clamp(-1.0, 1.0)) * 180 / math.pi;

  /// World vector in the device frame.
  Vec3 toDevice(Vec3 world) => orientation.conjugate.rotate(world);

  /// Angle in degrees between the view direction and [world] direction.
  double angleTo(Vec3 world) {
    final c = forward.dot(world.normalized()).clamp(-1.0, 1.0);
    return math.acos(c) * 180 / math.pi;
  }
}

/// Result of projecting a world point onto the screen.
class ScreenProjection {
  final Offset offset;

  /// Distance along the view axis in metres (positive in front).
  final double depth;
  final bool inFront;
  final bool onScreen;

  const ScreenProjection({
    required this.offset,
    required this.depth,
    required this.inFront,
    required this.onScreen,
  });
}

/// Pinhole projection for a portrait screen showing the rear camera preview.
class ArProjector {
  /// Focal length in logical pixels.
  final double focalPx;
  final Size screen;

  const ArProjector({required this.focalPx, required this.screen});

  ScreenProjection project(CameraPose pose, Vec3 worldRelative) {
    final d = pose.toDevice(worldRelative);
    final depth = -d.z;
    final c = Offset(screen.width / 2, screen.height / 2);
    if (depth < 0.05) {
      return ScreenProjection(
          offset: c, depth: depth, inFront: false, onScreen: false);
    }
    final o = Offset(
      c.dx + focalPx * d.x / depth,
      c.dy - focalPx * d.y / depth,
    );
    final margin = screen.shortestSide * 0.25;
    final onScreen = o.dx > -margin &&
        o.dx < screen.width + margin &&
        o.dy > -margin &&
        o.dy < screen.height + margin;
    return ScreenProjection(
        offset: o, depth: depth, inFront: true, onScreen: onScreen);
  }

  /// On-screen size in pixels of an object [sizeM] metres wide at [depth].
  double pixelSize(double sizeM, double depth) =>
      depth <= 0 ? 0 : focalPx * sizeM / depth;
}
