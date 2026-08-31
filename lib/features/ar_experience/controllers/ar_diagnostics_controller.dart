import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArDiagnosticsState {
  final bool showSolidBackground;
  final bool showCameraPreview;
  final bool showCenteredBenchmarkGem;
  final bool showWorldAnchor;
  final bool showHudReticle;
  final bool showTelemetry;
  final String cameraStatus;
  final String cameraLens;
  final String cameraPreset;
  final double previewWidth;
  final double previewHeight;
  final double aspectRatio;
  final int initDurationMs;
  final String? lastExceptionCode;
  final String commitHash;
  final String buildVersion;

  const ArDiagnosticsState({
    this.showSolidBackground = false,
    this.showCameraPreview = true,
    this.showCenteredBenchmarkGem = false,
    this.showWorldAnchor = true,
    this.showHudReticle = true,
    this.showTelemetry = true,
    this.cameraStatus = 'idle',
    this.cameraLens = 'back',
    this.cameraPreset = 'high',
    this.previewWidth = 0.0,
    this.previewHeight = 0.0,
    this.aspectRatio = 1.0,
    this.initDurationMs = 0,
    this.lastExceptionCode,
    this.commitHash = '0b54fde',
    this.buildVersion = '1.0.0 (Build 1)',
  });

  ArDiagnosticsState copyWith({
    bool? showSolidBackground,
    bool? showCameraPreview,
    bool? showCenteredBenchmarkGem,
    bool? showWorldAnchor,
    bool? showHudReticle,
    bool? showTelemetry,
    String? cameraStatus,
    String? cameraLens,
    String? cameraPreset,
    double? previewWidth,
    double? previewHeight,
    double? aspectRatio,
    int? initDurationMs,
    String? lastExceptionCode,
    String? commitHash,
    String? buildVersion,
  }) {
    return ArDiagnosticsState(
      showSolidBackground: showSolidBackground ?? this.showSolidBackground,
      showCameraPreview: showCameraPreview ?? this.showCameraPreview,
      showCenteredBenchmarkGem: showCenteredBenchmarkGem ?? this.showCenteredBenchmarkGem,
      showWorldAnchor: showWorldAnchor ?? this.showWorldAnchor,
      showHudReticle: showHudReticle ?? this.showHudReticle,
      showTelemetry: showTelemetry ?? this.showTelemetry,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      cameraLens: cameraLens ?? this.cameraLens,
      cameraPreset: cameraPreset ?? this.cameraPreset,
      previewWidth: previewWidth ?? this.previewWidth,
      previewHeight: previewHeight ?? this.previewHeight,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      initDurationMs: initDurationMs ?? this.initDurationMs,
      lastExceptionCode: lastExceptionCode ?? this.lastExceptionCode,
      commitHash: commitHash ?? this.commitHash,
      buildVersion: buildVersion ?? this.buildVersion,
    );
  }
}

final arDiagnosticsProvider =
    StateNotifierProvider<ArDiagnosticsController, ArDiagnosticsState>((ref) {
  return ArDiagnosticsController();
});

class ArDiagnosticsController extends StateNotifier<ArDiagnosticsState> {
  ArDiagnosticsController() : super(const ArDiagnosticsState());

  void toggleSolidBackground() {
    state = state.copyWith(showSolidBackground: !state.showSolidBackground);
  }

  void toggleCameraPreview() {
    state = state.copyWith(showCameraPreview: !state.showCameraPreview);
  }

  void toggleCenteredBenchmarkGem() {
    state = state.copyWith(
        showCenteredBenchmarkGem: !state.showCenteredBenchmarkGem);
  }

  void toggleWorldAnchor() {
    state = state.copyWith(showWorldAnchor: !state.showWorldAnchor);
  }

  void toggleHudReticle() {
    state = state.copyWith(showHudReticle: !state.showHudReticle);
  }

  void toggleTelemetry() {
    state = state.copyWith(showTelemetry: !state.showTelemetry);
  }

  void updateCameraTelemetry({
    required String status,
    String? lens,
    String? preset,
    double? width,
    double? height,
    double? aspectRatio,
    int? initDurationMs,
    String? exceptionCode,
  }) {
    state = state.copyWith(
      cameraStatus: status,
      cameraLens: lens,
      cameraPreset: preset,
      previewWidth: width,
      previewHeight: height,
      aspectRatio: aspectRatio,
      initDurationMs: initDurationMs,
      lastExceptionCode: exceptionCode,
    );
  }
}
