/// The guided set-up before a World AR hunt (owner 2026-11-02: "a user friendly
/// calibration with easy steps and tutorial before launching the AR game").
///
/// Each step passes on the same signal the game itself needs, so "done" here
/// means the gem can really be placed:
/// 1. compass  - only when the compass reports itself unreliable: figure-8.
/// 2. floor    - ARCore is tracking and has found the ground.
/// 3. look     - enough agreeing compass samples to point the gem the right way
///               (taken while the phone is held up, so this comes after the floor).
/// 4. ready    - the hunt may place the gem.
library;

enum CalibrationStep { compass, floor, look, ready }

class ArCalibration {
  ArCalibration({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The floor must stay found this long, so a flicker doesn't count.
  static const floorHold = Duration(seconds: 1);

  /// After this long on the floor step, show the "shiny floor" tip.
  static const floorTipAfter = Duration(seconds: 10);

  /// The compass must read reliable this long; give up after [compassGiveUp].
  static const compassHold = Duration(seconds: 1);
  static const compassGiveUp = Duration(seconds: 20);

  /// Stop waiting for the heading after this long: the gem is then placed
  /// where the camera aims instead of in its real direction.
  static const lookGiveUp = Duration(seconds: 12);

  /// Samples the heading link needs (matches HeadingCalibration.ready).
  static const lookSamples = 15;

  final DateTime Function() _now;

  CalibrationStep? _step;
  DateTime? _stepStart;
  DateTime? _goodSince;
  double _progress = 0;
  bool _headingFallback = false;

  /// Null until the first [update].
  CalibrationStep? get step => _step;
  bool get done => _step == CalibrationStep.ready;

  /// 0..1 within the current step.
  double get progress => _progress;

  /// The floor step is taking long: show tips for hard floors.
  bool get floorTip =>
      _step == CalibrationStep.floor &&
      _stepStart != null &&
      _now().difference(_stepStart!) >= floorTipAfter;

  /// The compass never settled: place where the camera aims.
  bool get headingFallback => _headingFallback;

  /// Steps shown to the traveler, for "STEP n OF m".
  int get totalSteps => _hadCompassStep ? 3 : 2;
  int get stepNumber => switch (_step) {
        CalibrationStep.compass => 1,
        CalibrationStep.floor => _hadCompassStep ? 2 : 1,
        CalibrationStep.look => _hadCompassStep ? 3 : 2,
        _ => totalSteps,
      };
  bool _hadCompassStep = false;

  /// Feeds the latest signals; returns true when the step changed.
  bool update({
    required bool tracking,
    required int planes,
    required bool compassUnreliable,
    required int headingSamples,
    required bool headingReady,
  }) {
    final now = _now();
    final before = _step;
    if (_step == null) {
      _hadCompassStep = compassUnreliable;
      _go(compassUnreliable ? CalibrationStep.compass : CalibrationStep.floor,
          now);
    }
    switch (_step!) {
      case CalibrationStep.compass:
        final ok = !compassUnreliable;
        _goodSince = ok ? (_goodSince ?? now) : null;
        final held =
            _goodSince == null ? Duration.zero : now.difference(_goodSince!);
        _progress = _fraction(held, compassHold);
        if (held >= compassHold ||
            now.difference(_stepStart!) >= compassGiveUp) {
          _go(CalibrationStep.floor, now);
        }
      case CalibrationStep.floor:
        final ok = tracking && planes > 0;
        _goodSince = ok ? (_goodSince ?? now) : null;
        final held =
            _goodSince == null ? Duration.zero : now.difference(_goodSince!);
        _progress = _fraction(held, floorHold);
        if (held >= floorHold) _go(CalibrationStep.look, now);
      case CalibrationStep.look:
        _progress = (headingSamples / lookSamples).clamp(0.0, 1.0);
        if (headingReady) {
          _go(CalibrationStep.ready, now);
        } else if (now.difference(_stepStart!) >= lookGiveUp) {
          _headingFallback = true;
          _go(CalibrationStep.ready, now);
        }
      case CalibrationStep.ready:
        break;
    }
    return _step != before;
  }

  void _go(CalibrationStep s, DateTime now) {
    _step = s;
    _stepStart = now;
    _goodSince = null;
    _progress = s == CalibrationStep.ready ? 1 : 0;
  }

  static double _fraction(Duration a, Duration b) =>
      (a.inMilliseconds / b.inMilliseconds).clamp(0.0, 1.0);
}
