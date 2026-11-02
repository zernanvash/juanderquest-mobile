import 'dart:math' as math;

/// Turns a real-world point (latitude/longitude) into a position in ARCore's
/// world space, so the AR object spawns at a place, not "in front of the phone".
///
/// ARCore tracks the camera's position and turn inside its own frame, but that
/// frame has no idea where north is. We learn the link once:
///  * heading: compare the compass bearing of the camera with the camera's yaw in
///    ARCore (averaged over a short window, [HeadingCalibration]);
///  * position: the GPS fix at the same moment marks where the camera is.
/// After that, ARCore's own tracking keeps the object fixed while you walk.
/// (ARCore Geospatial anchors would replace both steps where VPS exists.)
class GeoAnchor {
  static const double _metersPerDegLat = 111320;

  /// East/north offset in metres from (lat, lng) to (tLat, tLng). Equirectangular:
  /// accurate to centimetres over the few hundred metres an AR quest covers.
  static ({double east, double north}) enuOffset(
      double lat, double lng, double tLat, double tLng) {
    final north = (tLat - lat) * _metersPerDegLat;
    final east =
        (tLng - lng) * _metersPerDegLat * math.cos(lat * math.pi / 180);
    return (east: east, north: north);
  }

  /// Compass bearing (0 = north, clockwise) and distance of an east/north offset.
  static ({double bearing, double distance}) polar(double east, double north) {
    final b = math.atan2(east, north) * 180 / math.pi;
    return (
      bearing: (b + 360) % 360,
      distance: math.sqrt(east * east + north * north)
    );
  }

  /// Camera position in ARCore world space from a column-major view matrix.
  static ({double x, double y, double z}) cameraPosition(List<double> v) {
    final t = [v[12], v[13], v[14]];
    double c(int i) =>
        -(v[i * 4] * t[0] + v[i * 4 + 1] * t[1] + v[i * 4 + 2] * t[2]);
    return (x: c(0), y: c(1), z: c(2));
  }

  /// The camera's viewing direction in ARCore world space.
  static ({double x, double y, double z}) cameraForward(List<double> v) =>
      (x: -v[2], y: -v[6], z: -v[10]);

  /// Yaw of the camera's horizontal viewing direction in ARCore space, degrees
  /// clockwise from ARCore's -Z axis (ARCore is right-handed, Y up). Null when
  /// the camera points almost straight up or down (no reliable heading).
  static double? cameraYaw(List<double> view) {
    final f = cameraForward(view);
    final h = math.sqrt(f.x * f.x + f.z * f.z);
    if (h < 0.35) return null;
    final yaw = math.atan2(f.x, -f.z) * 180 / math.pi;
    return (yaw + 360) % 360;
  }

  /// ARCore world (x, z) of a target at compass [bearing] and [distance] metres
  /// from the camera position [camX], [camZ], given the calibrated
  /// [headingOffset] = compass bearing − ARCore yaw.
  static ({double x, double z}) localPoint({
    required double camX,
    required double camZ,
    required double bearing,
    required double distance,
    required double headingOffset,
  }) {
    final yaw = (bearing - headingOffset) * math.pi / 180;
    return (
      x: camX + distance * math.sin(yaw),
      z: camZ - distance * math.cos(yaw)
    );
  }
}

/// Circular mean of (compass bearing − ARCore yaw) samples. The compass is
/// noisy and a passing metal object bends it, so a single reading is not
/// enough; [spread] tells how much the samples disagree (degrees).
class HeadingCalibration {
  final List<double> _samples = [];
  final int window;

  HeadingCalibration({this.window = 40});

  int get count => _samples.length;

  void reset() => _samples.clear();

  void add({required double compassBearing, required double arYaw}) {
    var d = (compassBearing - arYaw) % 360;
    if (d < 0) d += 360;
    _samples.add(d);
    if (_samples.length > window) _samples.removeAt(0);
  }

  /// Mean offset in degrees [0, 360), or null with no samples.
  double? get offset {
    if (_samples.isEmpty) return null;
    var sx = 0.0, sy = 0.0;
    for (final d in _samples) {
      sx += math.cos(d * math.pi / 180);
      sy += math.sin(d * math.pi / 180);
    }
    final m = math.atan2(sy, sx) * 180 / math.pi;
    return (m + 360) % 360;
  }

  /// Circular standard deviation of the samples in degrees.
  double get spread {
    if (_samples.length < 2) return 180;
    var sx = 0.0, sy = 0.0;
    for (final d in _samples) {
      sx += math.cos(d * math.pi / 180);
      sy += math.sin(d * math.pi / 180);
    }
    final r = math.sqrt(sx * sx + sy * sy) / _samples.length;
    if (r >= 1) return 0;
    return math.sqrt(-2 * math.log(r)) * 180 / math.pi;
  }

  /// Enough agreeing samples to place by.
  bool get ready => count >= 15 && spread <= 12;
}
