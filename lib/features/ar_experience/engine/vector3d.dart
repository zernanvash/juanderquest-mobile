import 'dart:math' as math;

/// Lightweight 3D Vector with projection and transformation utilities.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  static const Vector3D zero = Vector3D(0, 0, 0);

  Vector3D operator +(Vector3D other) => Vector3D(x + other.x, y + other.y, z + other.z);
  Vector3D operator -(Vector3D other) => Vector3D(x - other.x, y - other.y, z - other.z);
  Vector3D operator *(double scalar) => Vector3D(x * scalar, y * scalar, z * scalar);
  Vector3D operator /(double scalar) => Vector3D(x / scalar, y / scalar, z / scalar);

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  Vector3D cross(Vector3D other) {
    return Vector3D(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D normalize() {
    final len = length;
    if (len == 0) return Vector3D.zero;
    return Vector3D(x / len, y / len, z / len);
  }

  /// Rotates the vector around the X axis by [angleRad] radians.
  Vector3D rotateX(double angleRad) {
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    return Vector3D(
      x,
      y * cosA - z * sinA,
      y * sinA + z * cosA,
    );
  }

  /// Rotates the vector around the Y axis by [angleRad] radians.
  Vector3D rotateY(double angleRad) {
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    return Vector3D(
      x * cosA + z * sinA,
      y,
      -x * sinA + z * cosA,
    );
  }

  /// Rotates the vector around the Z axis by [angleRad] radians.
  Vector3D rotateZ(double angleRad) {
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    return Vector3D(
      x * cosA - y * sinA,
      x * sinA + y * cosA,
      z,
    );
  }

  /// Rotates by Euler angles [rotX], [rotY], [rotZ].
  Vector3D rotate(double rotX, double rotY, double rotZ) {
    return rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
  }

  /// Projects 3D coordinate to 2D screen coordinate with camera perspective.
  math.Point<double> project({
    required double fov,
    required double cameraDistance,
    required double screenWidth,
    required double screenHeight,
  }) {
    final distance = cameraDistance + z;
    if (distance <= 0.1) {
      return math.Point(screenWidth / 2, screenHeight / 2);
    }
    final factor = fov / distance;
    final px = x * factor + screenWidth / 2;
    final py = -y * factor + screenHeight / 2; // Invert Y for screen coordinates
    return math.Point(px, py);
  }

  @override
  String toString() => 'Vector3D($x, $y, $z)';
}
