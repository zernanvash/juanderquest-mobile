import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_fusion_controller.dart';

enum CalibrationStep {
  magnetometerSweep, // Step 1: Figure-8 Compass Mapping
  horizonLevelZero, // Step 2: Pitch & Roll Horizon Alignment
  hardwareCheck, // Step 3: Camera & GPS Fix Verification
  completed, // Step 4: Calibration success
}

class CalibrationState {
  final bool isCalibrated;
  final CalibrationStep currentStep;
  final double compassProgress; // 0.0 .. 1.0
  final bool isLevel;
  final double levelHoldProgress; // 0.0 .. 1.0 (fills during 1.5s hold)
  final bool isHoldingLevel;
  final bool cameraPermissionGranted;
  final bool isGpsReady;
  final double? gpsAccuracy;
  final String? gpsStatusMessage;

  const CalibrationState({
    this.isCalibrated = false,
    this.currentStep = CalibrationStep.magnetometerSweep,
    this.compassProgress = 0.0,
    this.isLevel = false,
    this.levelHoldProgress = 0.0,
    this.isHoldingLevel = false,
    this.cameraPermissionGranted = false,
    this.isGpsReady = false,
    this.gpsAccuracy,
    this.gpsStatusMessage,
  });

  CalibrationState copyWith({
    bool? isCalibrated,
    CalibrationStep? currentStep,
    double? compassProgress,
    bool? isLevel,
    double? levelHoldProgress,
    bool? isHoldingLevel,
    bool? cameraPermissionGranted,
    bool? isGpsReady,
    double? gpsAccuracy,
    String? gpsStatusMessage,
  }) {
    return CalibrationState(
      isCalibrated: isCalibrated ?? this.isCalibrated,
      currentStep: currentStep ?? this.currentStep,
      compassProgress: compassProgress ?? this.compassProgress,
      isLevel: isLevel ?? this.isLevel,
      levelHoldProgress: levelHoldProgress ?? this.levelHoldProgress,
      isHoldingLevel: isHoldingLevel ?? this.isHoldingLevel,
      cameraPermissionGranted:
          cameraPermissionGranted ?? this.cameraPermissionGranted,
      isGpsReady: isGpsReady ?? this.isGpsReady,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      gpsStatusMessage: gpsStatusMessage ?? this.gpsStatusMessage,
    );
  }
}

class CalibrationNotifier extends StateNotifier<CalibrationState> {
  final Ref _ref;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final Set<int> _sampledMagSectors = {};
  Timer? _levelTimer;
  int _levelHoldTicks = 0;
  static const int _requiredLevelTicks = 15; // 15 * 100ms = 1.5 seconds

  CalibrationNotifier(this._ref) : super(const CalibrationState()) {
    _initSensors();
  }

  void _initSensors() {
    _magSub?.cancel();
    try {
      _magSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((event) {
        _processMagnetometerSample(event.x, event.y, event.z);
      }, onError: (_) {});
    } catch (_) {}
  }

  void _processMagnetometerSample(double x, double y, double z) {
    if (state.currentStep != CalibrationStep.magnetometerSweep) return;

    final norm = math.sqrt(x * x + y * y + z * z);
    if (norm < 5.0) return; // ignore zero/invalid readings

    // Divide 3D sphere into 12 angular sectors
    final azimuth = (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
    final elevation =
        (math.asin((z / norm).clamp(-1.0, 1.0)) * 180.0 / math.pi);

    final azimuthSector = (azimuth ~/ 45); // 0..7
    final elevationSector =
        elevation > 20 ? 1 : (elevation < -20 ? -1 : 0); // -1, 0, 1
    final sectorId = azimuthSector * 3 + (elevationSector + 1);

    _sampledMagSectors.add(sectorId);
    final progress = (_sampledMagSectors.length / 10.0).clamp(0.0, 1.0);

    state = state.copyWith(compassProgress: progress);

    if (progress >= 1.0) {
      advanceStep(CalibrationStep.horizonLevelZero);
    }
  }

  void processOrientation(SensorOrientation orientation) {
    if (state.currentStep != CalibrationStep.horizonLevelZero) return;
    if (!orientation.hasHardwareSensors || !orientation.isHeadingReliable) {
      return;
    }

    final isWithinLevelBounds = orientation.pitchDegrees.abs() <= 15.0 &&
        orientation.rollDegrees.abs() <= 10.0;

    if (isWithinLevelBounds) {
      if (!state.isHoldingLevel) {
        state = state.copyWith(isLevel: true, isHoldingLevel: true);
        _startLevelHoldTimer();
      }
    } else {
      if (state.isHoldingLevel) {
        _cancelLevelHoldTimer();
        state = state.copyWith(
            isLevel: false, isHoldingLevel: false, levelHoldProgress: 0.0);
      }
    }
  }

  void _startLevelHoldTimer() {
    _levelTimer?.cancel();
    _levelHoldTicks = 0;
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _levelHoldTicks++;
      final progress = (_levelHoldTicks / _requiredLevelTicks).clamp(0.0, 1.0);
      state = state.copyWith(levelHoldProgress: progress);

      if (_levelHoldTicks >= _requiredLevelTicks) {
        timer.cancel();
        _ref.read(sensorFusionProvider.notifier).setLevelReference();
        advanceStep(CalibrationStep.hardwareCheck);
      }
    });
  }

  void _cancelLevelHoldTimer() {
    _levelTimer?.cancel();
    _levelHoldTicks = 0;
  }

  void advanceStep(CalibrationStep nextStep) {
    _cancelLevelHoldTimer();
    state = state.copyWith(currentStep: nextStep);
    if (nextStep == CalibrationStep.hardwareCheck) {
      unawaited(verifyHardwarePermissions());
    }
  }

  Future<void> verifyHardwarePermissions() async {
    state =
        state.copyWith(gpsStatusMessage: 'Checking camera & GPS satellites...');

    // 1. Camera
    final cameraStatus = await Permission.camera.request();
    final cameraOk = cameraStatus.isGranted;

    // 2. GPS Location
    bool gpsOk = false;
    double? accuracy;
    String? statusMsg;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var locPermission = await Geolocator.checkPermission();
        if (locPermission == LocationPermission.denied) {
          locPermission = await Geolocator.requestPermission();
        }

        if (locPermission == LocationPermission.whileInUse ||
            locPermission == LocationPermission.always) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 4),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }

          if (pos != null) {
            accuracy = pos.accuracy;
            gpsOk = pos.accuracy > 0 && pos.accuracy <= 100.0;
            statusMsg = gpsOk
                ? 'GPS Locked (±${pos.accuracy.toStringAsFixed(1)}m accuracy)'
                : 'GPS accuracy is too low (±${pos.accuracy.toStringAsFixed(1)}m)';
          } else {
            statusMsg = 'Location enabled (Acquiring satellite fix)';
          }
        } else {
          statusMsg = 'Location permission is required';
        }
      } else {
        statusMsg = 'Location services are disabled';
      }
    } catch (_) {
      gpsOk = false;
      statusMsg = 'Unable to verify a GPS fix';
    }

    state = state.copyWith(
      cameraPermissionGranted: cameraOk,
      isGpsReady: gpsOk,
      gpsAccuracy: accuracy,
      gpsStatusMessage: statusMsg,
    );
  }

  void completeCalibration({bool force = false}) {
    _cancelLevelHoldTimer();
    if (!force && (!state.cameraPermissionGranted || !state.isGpsReady)) return;

    state = state.copyWith(
      isCalibrated: true,
      currentStep: CalibrationStep.completed,
      compassProgress: 1.0,
      levelHoldProgress: 1.0,
      isLevel: true,
      isGpsReady: force ? true : state.isGpsReady,
    );
  }

  /// Demo helper to instantly complete calibration (for testing/emulators)
  void simulateInstantCalibration() {
    _sampledMagSectors.clear();
    for (int i = 0; i < 12; i++) {
      _sampledMagSectors.add(i);
    }
    completeCalibration(force: true);
  }

  void resetCalibration() {
    _cancelLevelHoldTimer();
    _sampledMagSectors.clear();
    _ref.read(sensorFusionProvider.notifier).clearLevelReference();
    state = const CalibrationState();
    _initSensors();
  }

  @override
  void dispose() {
    _cancelLevelHoldTimer();
    _magSub?.cancel();
    super.dispose();
  }
}

final calibrationProvider =
    StateNotifierProvider<CalibrationNotifier, CalibrationState>((ref) {
  final notifier = CalibrationNotifier(ref);
  ref.listen<SensorOrientation>(sensorFusionProvider, (_, next) {
    notifier.processOrientation(next);
  });
  return notifier;
});
