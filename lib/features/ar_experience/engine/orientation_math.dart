import 'dart:math' as math;

/// Device orientation expressed in the rear camera's coordinate frame.
class RawSensorOrientation {
  final double? headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;

  const RawSensorOrientation({
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
  });
}

/// Pure accelerometer/magnetometer fusion math.
///
/// Sensor axes are x = screen right, y = screen top and z = out of the
/// display. The rear camera looks along -z. Pitch is therefore zero when an
/// upright phone points its rear camera at the horizon.
class OrientationMath {
  static const double _radiansToDegrees = 180.0 / math.pi;

  static RawSensorOrientation? calculate({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    final gravity = _Vector3(ax, ay, az).normalized;
    final magnetic = _Vector3(mx, my, mz);
    if (gravity == null || magnetic.length < 1e-6) return null;

    final pitch = math.asin((-gravity.z).clamp(-1.0, 1.0)) * _radiansToDegrees;
    final roll = math.atan2(gravity.x, gravity.y) * _radiansToDegrees;

    final magneticHorizontal = magnetic - gravity.scaled(magnetic.dot(gravity));
    final north = magneticHorizontal.normalized;

    const cameraForward = _Vector3(0.0, 0.0, -1.0);
    final forwardHorizontal =
        (cameraForward - gravity.scaled(cameraForward.dot(gravity))).normalized;

    double? heading;
    if (north != null && forwardHorizontal != null) {
      final east = north.cross(gravity).normalized;
      if (east != null) {
        heading = math.atan2(
              forwardHorizontal.dot(east),
              forwardHorizontal.dot(north),
            ) *
            _radiansToDegrees;
        heading = (heading + 360.0) % 360.0;
      }
    }

    return RawSensorOrientation(
      headingDegrees: heading,
      pitchDegrees: pitch,
      rollDegrees: _normalizeSigned(roll),
    );
  }

  static double _normalizeSigned(double degrees) {
    var value = (degrees + 180.0) % 360.0;
    if (value < 0) value += 360.0;
    return value - 180.0;
  }
}

class _Vector3 {
  final double x;
  final double y;
  final double z;

  const _Vector3(this.x, this.y, this.z);

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vector3? get normalized {
    final norm = length;
    if (norm < 1e-6) return null;
    return scaled(1.0 / norm);
  }

  double dot(_Vector3 other) => x * other.x + y * other.y + z * other.z;

  _Vector3 cross(_Vector3 other) => _Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  _Vector3 scaled(double scalar) => _Vector3(x * scalar, y * scalar, z * scalar);

  _Vector3 operator -(_Vector3 other) =>
      _Vector3(x - other.x, y - other.y, z - other.z);
}
