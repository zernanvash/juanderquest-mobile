import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ar_math.dart';

/// The AR task's geofence (Plan 43 `ArCfg.fence`).
class ArFence {
  final double lat;
  final double lng;
  final double radiusMeters;

  const ArFence(
      {required this.lat, required this.lng, required this.radiusMeters});
}

/// A GPS fix.
class ArFix {
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime at;

  const ArFix(
      {required this.lat,
      required this.lng,
      required this.accuracy,
      required this.at});
}

/// Pure gameplay rules (Plan 47 §2.1). GPS is only trusted to answer
/// "inside the fence?", so the object is spawned relative to the traveler.
class ArHuntRules {
  /// Same rule as the server's `withinRadius`: accuracy allowance capped at 25 m.
  static bool insideFence(ArFix fix, ArFence fence) =>
      distanceToCentre(fix, fence) <=
      fence.radiusMeters + fix.accuracy.clamp(0, 25);

  static double distanceToCentre(ArFix fix, ArFence fence) =>
      ArGeo.distanceMeters(fix.lat, fix.lng, fence.lat, fence.lng);

  static double bearingToCentre(ArFix fix, ArFence fence) =>
      ArGeo.bearingDegrees(fix.lat, fix.lng, fence.lat, fence.lng);

  /// Object distance from the traveler and height relative to the phone.
  static const double spawnDistanceM = 3.5;
  static const double spawnHeightM = -0.45;

  /// Degrees between view direction and object that count as "centred".
  static const double alignDegrees = 9;
  static const Duration holdToCollect = Duration(milliseconds: 600);

  /// Bearing for the object. Far from the centre it lies towards the
  /// landmark; near the centre it hides 35–120° to either side so the
  /// traveler has to look around for it.
  static double spawnBearing({
    required ArFix fix,
    required ArFence fence,
    required double cameraBearing,
    required math.Random rng,
  }) {
    if (distanceToCentre(fix, fence) > 25) {
      return bearingToCentre(fix, fence);
    }
    final offset = 35 + rng.nextDouble() * 85;
    final sign = rng.nextBool() ? 1 : -1;
    return ArGeo.normalizeBearing(cameraBearing + sign * offset);
  }

  /// World position of the object relative to the phone.
  static Vec3 spawnPosition(double bearingDeg) =>
      ArGeo.directionFor(bearingDeg) * spawnDistanceM +
      const Vec3(0, 0, spawnHeightM);

  /// Short direction hint, e.g. "ahead", "to your left".
  static String directionHint(double relativeDeg) {
    final a = relativeDeg.abs();
    if (a <= 20) return 'ahead';
    if (a >= 140) return 'behind you';
    return relativeDeg < 0 ? 'to your left' : 'to your right';
  }
}

enum ArHuntPhase {
  /// Waiting for a usable GPS fix.
  locating,

  /// Outside the fence: finder arrow only.
  outside,

  /// Inside the fence, asking the server for the one-time AR challenge.
  unlocking,

  /// Object spawned; traveler is looking for it.
  searching,

  /// Object centred long enough; it can be collected.
  aligned,

  /// Sending the evidence.
  submitting,

  /// Server verified the task.
  verified,

  /// Blocking error (see [ArHuntController.error]).
  failed,
}

/// Result of a server call: either data or an error code + message.
class ArServerResult<T> {
  final T? data;
  final String? code;
  final String? message;

  const ArServerResult.ok(T this.data)
      : code = null,
        message = null;
  const ArServerResult.error(this.code, this.message) : data = null;

  bool get ok => code == null;
}

class ArChallenge {
  final String token;
  final DateTime expiresAt;

  const ArChallenge({required this.token, required this.expiresAt});
}

typedef RequestChallenge = Future<ArServerResult<ArChallenge>> Function(
    ArFix fix);
typedef SubmitArEvidence = Future<ArServerResult<void>> Function(
    ArFix fix, String challengeToken);

/// Drives one AR task: finder → unlock → search → collect → verify.
class ArHuntController extends ChangeNotifier {
  final ArFence fence;
  final RequestChallenge requestChallenge;
  final SubmitArEvidence submitEvidence;
  final math.Random _rng;
  final DateTime Function() _now;

  /// GPS fixes older than this are not sent to the server.
  static const Duration maxFixAge = Duration(seconds: 20);

  ArHuntController({
    required this.fence,
    required this.requestChallenge,
    required this.submitEvidence,
    math.Random? rng,
    DateTime Function()? now,
  })  : _rng = rng ?? math.Random(),
        _now = now ?? DateTime.now;

  ArHuntPhase _phase = ArHuntPhase.locating;
  ArFix? _fix;
  ArChallenge? _challenge;
  Vec3? _objectPosition;
  DateTime? _alignedSince;
  String? _error;
  String? _errorCode;
  bool _disposed = false;

  ArHuntPhase get phase => _phase;
  ArFix? get fix => _fix;
  Vec3? get objectPosition => _objectPosition;
  String? get error => _error;
  String? get errorCode => _errorCode;

  double? get distanceToCentre =>
      _fix == null ? null : ArHuntRules.distanceToCentre(_fix!, fence);
  double? get bearingToCentre =>
      _fix == null ? null : ArHuntRules.bearingToCentre(_fix!, fence);

  bool get canCollect => _phase == ArHuntPhase.aligned;

  /// New GPS fix from the location stream.
  Future<void> onFix(ArFix fix, {required double cameraBearing}) async {
    _fix = fix;
    switch (_phase) {
      case ArHuntPhase.locating:
      case ArHuntPhase.outside:
        if (ArHuntRules.insideFence(fix, fence)) {
          await _unlock(cameraBearing);
        } else {
          _set(ArHuntPhase.outside);
        }
        break;
      case ArHuntPhase.failed:
        // A GPS error clears itself once the traveler is back inside.
        if (_errorCode == 'GPS_RADIUS_EXCEEDED' &&
            ArHuntRules.insideFence(fix, fence)) {
          _clearError();
          await _unlock(cameraBearing);
        } else {
          notifyListeners();
        }
        break;
      default:
        notifyListeners();
    }
  }

  /// Camera moved: update whether the object is centred.
  void onCamera(CameraPose camera) {
    final pos = _objectPosition;
    if (pos == null) return;
    if (_phase != ArHuntPhase.searching && _phase != ArHuntPhase.aligned) {
      return;
    }
    final centred = camera.angleTo(pos) <= ArHuntRules.alignDegrees;
    if (!centred) {
      _alignedSince = null;
      if (_phase == ArHuntPhase.aligned) _set(ArHuntPhase.searching);
      return;
    }
    final now = _now();
    _alignedSince ??= now;
    if (_phase == ArHuntPhase.searching &&
        now.difference(_alignedSince!) >= ArHuntRules.holdToCollect) {
      _set(ArHuntPhase.aligned);
    }
  }

  /// Traveler tapped the object / "Collect".
  Future<void> collect() async {
    if (_phase != ArHuntPhase.aligned) return;
    final fix = _fix;
    final challenge = _challenge;
    if (fix == null || challenge == null) return;
    if (_now().difference(fix.at) > maxFixAge) {
      _fail('STALE_GPS',
          'Waiting for a fresh GPS reading. Hold still for a moment and try again.');
      return;
    }
    _set(ArHuntPhase.submitting);
    final result = await submitEvidence(fix, challenge.token);
    if (_disposed) return;
    if (result.ok) {
      _set(ArHuntPhase.verified);
      return;
    }
    if (result.code == 'CHALLENGE_TOKEN_EXPIRED' ||
        result.code == 'CHALLENGE_NONCE_REUSED') {
      // Get a fresh token and let the traveler collect again.
      _challenge = null;
      final retried = await requestChallenge(fix);
      if (_disposed) return;
      if (retried.ok) {
        _challenge = retried.data;
        _set(ArHuntPhase.aligned);
        return;
      }
      _fail(retried.code, retried.message);
      return;
    }
    _fail(result.code, result.message);
  }

  /// Retry after a failure (e.g. network).
  Future<void> retry({required double cameraBearing}) async {
    _clearError();
    final fix = _fix;
    if (fix == null) {
      _set(ArHuntPhase.locating);
      return;
    }
    if (_challenge != null && _objectPosition != null) {
      _set(ArHuntPhase.searching);
      return;
    }
    await onFix(fix, cameraBearing: cameraBearing);
  }

  Future<void> _unlock(double cameraBearing) async {
    _set(ArHuntPhase.unlocking);
    final fix = _fix!;
    final result = await requestChallenge(fix);
    if (_disposed) return;
    if (!result.ok) {
      _fail(result.code, result.message);
      return;
    }
    _challenge = result.data;
    final bearing = ArHuntRules.spawnBearing(
        fix: fix, fence: fence, cameraBearing: cameraBearing, rng: _rng);
    _objectPosition = ArHuntRules.spawnPosition(bearing);
    _alignedSince = null;
    _set(ArHuntPhase.searching);
  }

  void _fail(String? code, String? message) {
    _errorCode = code ?? 'UNKNOWN';
    _error = message ?? 'Something went wrong. Please try again.';
    _set(ArHuntPhase.failed);
  }

  void _clearError() {
    _error = null;
    _errorCode = null;
  }

  void _set(ArHuntPhase p) {
    _phase = p;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
