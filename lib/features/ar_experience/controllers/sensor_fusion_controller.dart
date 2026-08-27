import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Represents smoothed 3D spatial device orientation from fused hardware sensors.
class SensorOrientation {
  final double headingDegrees; // 0..360 (0 = North, 90 = East, 180 = South, 270 = West)
  final double pitchDegrees;   // -90..+90 (0 = horizon, +90 = looking up, -90 = looking down)
  final double rollDegrees;    // -180..+180 (device tilt left/right)
  final bool isCalibrated;

  const SensorOrientation({
    this.headingDegrees = 0.0,
    this.pitchDegrees = 0.0,
    this.rollDegrees = 0.0,
    this.isCalibrated = false,
  });

  SensorOrientation copyWith({
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    bool? isCalibrated,
  }) {
    return SensorOrientation(
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      rollDegrees: rollDegrees ?? this.rollDegrees,
      isCalibrated: isCalibrated ?? this.isCalibrated,
    );
  }
}

/// StateNotifier that fuses Accelerometer and Magnetometer streams with Low-Pass Filtering.
class SensorFusionNotifier extends StateNotifier<SensorOrientation> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _lastAx = 0.0, _lastAy = 0.0, _lastAz = 9.8;
  double _lastMx = 0.0, _lastMy = 0.0, _lastMz = 0.0;
  double _filteredHeading = 0.0;
  double _filteredPitch = 0.0;
  double _filteredRoll = 0.0;

  static const double _filterAlpha = 0.18; // Smoothing factor (0.01 = very smooth, 1.0 = instant/raw)

  SensorFusionNotifier() : super(const SensorOrientation()) {
    _startListening();
  }

  void _startListening() {
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        _lastAx = event.x;
        _lastAy = event.y;
        _lastAz = event.z;
        _updateOrientation();
      }, onError: (_) {
        // Silently handle on devices/emulators lacking sensors
      });

      _magSub = magnetometerEventStream().listen((event) {
        _lastMx = event.x;
        _lastMy = event.y;
        _lastMz = event.z;
        _updateOrientation();
      }, onError: (_) {
        // Silently handle on devices/emulators lacking sensors
      });
    } catch (_) {
      // Fallback for non-supported platforms
    }
  }

  void _updateOrientation() {
    // 1. Calculate Roll & Pitch from Accelerometer
    final normA = math.sqrt(_lastAx * _lastAx + _lastAy * _lastAy + _lastAz * _lastAz);
    if (normA == 0) return;

    final ax = _lastAx / normA;
    final ay = _lastAy / normA;
    final az = _lastAz / normA;

    final pitchRad = math.atan2(-ay, math.sqrt(ax * ax + az * az));
    final rollRad = math.atan2(ax, az);

    final rawPitch = pitchRad * (180.0 / math.pi);
    final rawRoll = rollRad * (180.0 / math.pi);

    // 2. Tilt-Compensated Magnetometer Heading (Compass Yaw)
    final cosP = math.cos(pitchRad);
    final sinP = math.sin(pitchRad);
    final cosR = math.cos(rollRad);
    final sinR = math.sin(rollRad);

    final bX = _lastMx * cosP + _lastMy * sinP * sinR + _lastMz * sinP * cosR;
    final bY = _lastMy * cosR - _lastMz * sinR;

    double rawHeading = math.atan2(-bY, bX) * (180.0 / math.pi);
    rawHeading = (rawHeading + 360.0) % 360.0;

    // 3. Circular Low-Pass Filter on Heading to prevent 0°/360° flip artifacts
    _filteredHeading = _filterAngle(_filteredHeading, rawHeading, _filterAlpha);
    _filteredPitch += (rawPitch - _filteredPitch) * _filterAlpha;
    _filteredRoll += (rawRoll - _filteredRoll) * _filterAlpha;

    state = SensorOrientation(
      headingDegrees: _filteredHeading,
      pitchDegrees: _filteredPitch,
      rollDegrees: _filteredRoll,
      isCalibrated: true,
    );
  }

  /// Smooths circular angles across the 0° / 360° boundary.
  double _filterAngle(double current, double target, double alpha) {
    double diff = (target - current) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (current + diff * alpha + 360.0) % 360.0;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }
}

final sensorFusionProvider =
    StateNotifierProvider.autoDispose<SensorFusionNotifier, SensorOrientation>((ref) {
  return SensorFusionNotifier();
});
