import 'dart:math' as math;

import 'ar_math.dart';

/// Which sensor currently drives the pose.
enum PoseSource { game, rotation, accelMag, none }

/// One fused orientation sample.
class ArPose {
  final Quat orientation;
  final PoseSource source;

  /// Estimated compass error in degrees; null when unknown.
  final double? headingAccuracyDeg;

  /// Android magnetic accuracy status 0..3 (3 = high); null when unknown.
  final int? magneticStatus;

  const ArPose({
    required this.orientation,
    required this.source,
    this.headingAccuracyDeg,
    this.magneticStatus,
  });

  static const unknown =
      ArPose(orientation: Quat.identity, source: PoseSource.none);

  bool get hasData => source != PoseSource.none;

  CameraPose get camera => CameraPose(orientation);

  /// True when the compass is too unreliable to point at a real place.
  bool get compassUnreliable {
    if (source == PoseSource.none) return true;
    if (magneticStatus != null && magneticStatus! <= 1) return true;
    final acc = headingAccuracyDeg;
    return acc != null && acc > 35;
  }
}

/// Combines the smooth game-rotation vector (no magnetic jumps, arbitrary yaw)
/// with the north-referenced rotation vector.
///
/// Output = aboutUp(yawOffset) * game. The yaw offset follows the rotation
/// vector slowly (time constant [settleSeconds]) and is frozen while the
/// compass is unreliable, so a passing car or metal railing can't yank the
/// scene around. Without a gyroscope the rotation vector (or accel+mag) is
/// used directly with light smoothing.
///
/// [lockHeading] freezes the yaw offset once an object has been placed: its
/// bearing was fixed in this frame, so any later compass correction would only
/// slide it across the scene (owner 2026-10-31: "the object is drifting").
/// The gyro-based game vector alone drifts far less than a compass wanders.
class HeadingFusion {
  final double settleSeconds;

  HeadingFusion({this.settleSeconds = 2.5});

  Quat? _game;
  Quat? _rot;
  Quat? _smoothed;
  double? _yawOffset;
  double? _lastRotT;
  double? _headingAcc;
  int? _magStatus;
  PoseSource _source = PoseSource.none;
  bool _headingLocked = false;

  bool get headingLocked => _headingLocked;

  /// Stops compass corrections until [unlockHeading]; the gyro keeps tracking.
  void lockHeading() => _headingLocked = true;

  void unlockHeading() => _headingLocked = false;

  ArPose get pose {
    final q = _current();
    if (q == null) return ArPose.unknown;
    return ArPose(
      orientation: q,
      source: _source,
      headingAccuracyDeg: _headingAcc,
      magneticStatus: _magStatus,
    );
  }

  void reset() {
    _game = null;
    _rot = null;
    _smoothed = null;
    _yawOffset = null;
    _lastRotT = null;
    _headingAcc = null;
    _magStatus = null;
    _source = PoseSource.none;
    _headingLocked = false;
  }

  /// Feeds one event from the native `ar_pose` channel.
  void addEvent(Map<dynamic, dynamic> e) {
    final src = e['src'];
    if (src == 'status') {
      _magStatus = (e['mag'] as num?)?.toInt();
      return;
    }
    final raw = e['q'];
    if (raw is! List || raw.length < 4) return;
    final q = Quat.fromList(raw);
    final t = (e['t'] as num?)?.toDouble() ?? 0;
    switch (src) {
      case 'game':
        _game = q;
        _source = PoseSource.game;
        break;
      case 'rot':
        final acc = (e['acc'] as num?)?.toDouble();
        _headingAcc = (acc != null && acc >= 0) ? acc : null;
        _onRotation(q, t);
        if (_game == null) {
          _source = PoseSource.rotation;
          _smoothed = (_smoothed ?? q).nlerp(q, 0.35);
        }
        break;
      case 'accelMag':
        _source = PoseSource.accelMag;
        _smoothed = (_smoothed ?? q).nlerp(q, 0.18);
        break;
    }
  }

  void _onRotation(Quat rot, double tMs) {
    _rot = rot;
    final game = _game;
    if (game == null) return;
    final target = yawBetween(rot, game);
    final previous = _yawOffset;
    if (previous == null) {
      _yawOffset = target;
      _lastRotT = tMs;
      return;
    }
    final dt = _lastRotT == null
        ? 0.02
        : ((tMs - _lastRotT!) / 1000).clamp(0.0, 0.5).toDouble();
    _lastRotT = tMs;
    if (_headingLocked) return;
    final magLow = _magStatus != null && _magStatus! <= 1;
    final accLow = _headingAcc != null && _headingAcc! > 35;
    if (magLow || accLow) return;
    final alpha = 1 - math.exp(-dt / settleSeconds);
    _yawOffset = previous + _wrapRad(target - previous) * alpha;
  }

  Quat? _current() {
    final game = _game;
    if (game != null) {
      final offset = _yawOffset;
      // Until the compass has spoken, keep the game frame as-is.
      return offset == null ? game : (Quat.aboutUp(offset) * game).normalized();
    }
    return _smoothed ?? _rot;
  }

  /// Yaw (radians, about world up) that turns [game] into [rot]:
  /// rot ≈ aboutUp(yaw) * game.
  static double yawBetween(Quat rot, Quat game) {
    final d = rot * game.conjugate;
    return _wrapRad(2 * math.atan2(d.z, d.w));
  }

  static double _wrapRad(double a) {
    var r = (a + math.pi) % (2 * math.pi);
    if (r < 0) r += 2 * math.pi;
    return r - math.pi;
  }
}
