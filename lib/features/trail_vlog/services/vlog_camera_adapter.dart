import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_text.dart';

/// Injectable camera abstraction for [PixelVlogRecorderSheet] so widget tests
/// can exercise capture, flip, and audio-denied fallback without hardware.
abstract class VlogCameraAdapter {
  bool get isInitialized;
  bool get isAudioEnabled;
  bool get isFrontCamera;
  String? get errorMessage;

  Future<void> initialize({
    required bool frontCamera,
    required bool enableAudio,
  });

  Future<void> startRecording();

  Future<String> stopRecording();

  Widget buildPreview(BuildContext context);

  Future<void> dispose();
}

class DeviceVlogCameraAdapter implements VlogCameraAdapter {
  CameraController? _controller;
  bool _initialized = false;
  bool _audioEnabled = true;
  bool _frontCamera = false;
  String? _errorMessage;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isAudioEnabled => _audioEnabled;

  @override
  bool get isFrontCamera => _frontCamera;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> initialize({
    required bool frontCamera,
    required bool enableAudio,
  }) async {
    await _disposeController();
    _frontCamera = frontCamera;
    _errorMessage = null;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _errorMessage = 'No camera available on this device.';
      throw StateError(_errorMessage!);
    }

    final targetDirection =
        frontCamera ? CameraLensDirection.front : CameraLensDirection.back;
    final selected = cameras.firstWhere(
      (c) => c.lensDirection == targetDirection,
      orElse: () => cameras.first,
    );

    Future<CameraController> openWithAudio(bool withAudio) async {
      final ctrl = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: withAudio,
      );
      await ctrl.initialize();
      return ctrl;
    }

    try {
      _controller = await openWithAudio(enableAudio);
      _audioEnabled = enableAudio;
    } on CameraException catch (_) {
      if (!enableAudio) rethrow;
      // Graceful fallback when microphone permission is denied: keep recording
      // silent 3s video so Chiptune BGM can fill the soundtrack.
      _controller = await openWithAudio(false);
      _audioEnabled = false;
    }

    _initialized = true;
  }

  @override
  Future<void> startRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw StateError('Camera is not ready.');
    }
    if (!ctrl.value.isRecordingVideo) {
      await ctrl.startVideoRecording();
    }
  }

  @override
  Future<String> stopRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw StateError('Camera is not ready.');
    }
    final file = await ctrl.stopVideoRecording();
    return file.path;
  }

  @override
  Widget buildPreview(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return ColoredBox(
        color: PixelPalette.woodNight,
        child: Center(
          child: Text(
            _errorMessage ?? 'STARTING CAMERA…',
            style: PixelType.small(context, color: PixelPalette.cream),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.previewSize?.height ?? 720,
          height: ctrl.value.previewSize?.width ?? 1280,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }

  Future<void> _disposeController() async {
    _initialized = false;
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        if (old.value.isRecordingVideo) {
          await old.stopVideoRecording();
        }
      } catch (_) {}
      await old.dispose();
    }
  }

  @override
  Future<void> dispose() => _disposeController();
}

final vlogCameraAdapterFactoryProvider =
    Provider<VlogCameraAdapter Function()>((ref) {
  return () => DeviceVlogCameraAdapter();
});
