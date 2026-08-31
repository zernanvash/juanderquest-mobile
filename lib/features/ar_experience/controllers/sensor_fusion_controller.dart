import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../engine/orientation_math.dart';

/// Smoothed rear-camera orientation from accelerometer and magnetometer data.
class SensorOrientation {
  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final bool isCalibrated;
  final bool hasHardwareSensors;
  final bool isHeadingReliable;

  const SensorOrientation({
    this.headingDegrees = 0.0,
    this.pitchDegrees = 0.0,
    this.rollDegrees = 0.0,
    this.isCalibrated = false,
    this.hasHardwareSensors = false,
    this.isHeadingReliable = false,
  });

  SensorOrientation copyWith({
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    bool? isCalibrated,
    bool? hasHardwareSensors,
    bool? isHeadingReliable,
  }) {
    return SensorOrientation(
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      rollDegrees: rollDegrees ?? this.rollDegrees,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      hasHardwareSensors: hasHardwareSensors ?? this.hasHardwareSensors,
      isHeadingReliable: isHeadingReliable ?? this.isHeadingReliable,
    );
  }
}

/// Fuses device sensors into a stable rear-camera pose.
///
/// Filtering is time-aware, so behavior does not change with sensor stream
/// frequency. Rate limiting rejects isolated magnetic spikes while a dynamic
/// time constant keeps deliberate movement responsive.
class SensorFusionNotifier extends StateNotifier<SensorOrientation> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _lastAx = 0.0;
  double _lastAy = 0.0;
  double _lastAz = 9.8;
  double _lastMx = 0.0;
  double _lastMy = 0.0;
  double _lastMz = 0.0;

  double _filteredHeading = 0.0;
  double _filteredPitch = 0.0;
  double _filteredRoll = 0.0;
  double _pitchReference = 0.0;
  double _rollReference = 0.0;

  bool _hasAccelerometer = false;
  bool _hasMagnetometer = false;
  bool _hasOrientationSample = false;
  DateTime? _lastUpdateAt;

  SensorFusionNotifier() : super(const SensorOrientation()) {
    _startListening();
  }

  void _startListening() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((event) {
        _lastAx = event.x;
        _lastAy = event.y;
        _lastAz = event.z;
        _hasAccelerometer = true;
        _updateOrientation();
      }, onError: (_) {});

      _magSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((event) {
        _lastMx = event.x;
        _lastMy = event.y;
        _lastMz = event.z;
        _hasMagnetometer = true;
        _updateOrientation();
      }, onError: (_) {});
    } catch (_) {
      // Unsupported platforms remain in an explicit no-sensor state.
    }
  }

  void _updateOrientation() {
    if (!_hasAccelerometer || !_hasMagnetometer) return;

    final raw = OrientationMath.calculate(
      ax: _lastAx,
      ay: _lastAy,
      az: _lastAz,
      mx: _lastMx,
      my: _lastMy,
      mz: _lastMz,
    );
    if (raw == null) return;

    final now = DateTime.now();
    final elapsed = _lastUpdateAt == null
        ? 1.0 / 60.0
        : now.difference(_lastUpdateAt!).inMicroseconds /
            Duration.microsecondsPerSecond;
    final dt = elapsed.clamp(1.0 / 240.0, 0.10).toDouble();
    _lastUpdateAt = now;

    if (!_hasOrientationSample) {
      _filteredHeading = raw.headingDegrees ?? 0.0;
      _filteredPitch = raw.pitchDegrees;
      _filteredRoll = raw.rollDegrees;
      _hasOrientationSample = true;
    } else {
      if (raw.headingDegrees != null) {
        _filteredHeading = _filterAngle(_filteredHeading, raw.headingDegrees!, dt);
      }
      _filteredPitch = _filterLinear(_filteredPitch, raw.pitchDegrees, dt);
      _filteredRoll = _filterSignedAngle(_filteredRoll, raw.rollDegrees, dt);
    }

    state = SensorOrientation(
      headingDegrees: _filteredHeading,
      pitchDegrees: _filteredPitch - _pitchReference,
      rollDegrees: _normalizeSigned(_filteredRoll - _rollReference),
      isCalibrated: true,
      hasHardwareSensors: true,
      isHeadingReliable: raw.headingDegrees != null,
    );
  }

  double _filterAngle(double current, double target, double dt) {
    var diff = (target - current) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    if (diff.abs() < 0.20) return current;

    final maxStep = 420.0 * dt;
    final boundedDiff = diff.clamp(-maxStep, maxStep).toDouble();
    final alpha = _adaptiveAlpha(diff.abs() / dt, dt);
    return (current + boundedDiff * alpha + 360.0) % 360.0;
  }

  double _filterSignedAngle(double current, double target, double dt) {
    final normalizedCurrent = (current + 360.0) % 360.0;
    final normalizedTarget = (target + 360.0) % 360.0;
    return _normalizeSigned(_filterAngle(normalizedCurrent, normalizedTarget, dt));
  }

  double _filterLinear(double current, double target, double dt) {
    final diff = target - current;
    if (diff.abs() < 0.15) return current;

    final maxStep = 300.0 * dt;
    final boundedDiff = diff.clamp(-maxStep, maxStep).toDouble();
    return current + boundedDiff * _adaptiveAlpha(diff.abs() / dt, dt);
  }

  double _adaptiveAlpha(double velocityDegreesPerSecond, double dt) {
    final tau = velocityDegreesPerSecond < 4.0
        ? 0.35
        : velocityDegreesPerSecond < 45.0
            ? 0.18
            : 0.08;
    return 1.0 - math.exp(-dt / tau);
  }

  double _normalizeSigned(double degrees) {
    var value = (degrees + 180.0) % 360.0;
    if (value < 0) value += 360.0;
    return value - 180.0;
  }

  /// Captures the current natural holding pose as the optical horizon.
  void setLevelReference() {
    if (!_hasOrientationSample) return;
    _pitchReference = _filteredPitch;
    _rollReference = _filteredRoll;
    state = state.copyWith(pitchDegrees: 0.0, rollDegrees: 0.0);
  }

  void clearLevelReference() {
    _pitchReference = 0.0;
    _rollReference = 0.0;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }
}

// Kept alive for the app session so calibration is retained in AR.
final sensorFusionProvider =
    StateNotifierProvider<SensorFusionNotifier, SensorOrientation>((ref) {
  return SensorFusionNotifier();
});
