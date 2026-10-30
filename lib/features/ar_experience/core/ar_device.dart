import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_optics.dart';
import 'heading_fusion.dart';

/// Native orientation stream + camera optics (Android `ArSensorBridge`).
///
/// The pose is published through a [ValueListenable] so only the AR overlay
/// repaints at sensor rate; the rest of the screen never rebuilds for it.
class ArDevice {
  static const _events = EventChannel('com.juanderquest.app/ar_pose');
  static const _methods = MethodChannel('com.juanderquest.app/ar_device');

  final HeadingFusion _fusion;
  final ValueNotifier<ArPose> pose = ValueNotifier(ArPose.unknown);
  StreamSubscription<dynamic>? _sub;
  bool _failed = false;

  ArDevice({HeadingFusion? fusion}) : _fusion = fusion ?? HeadingFusion();

  /// True when the platform has no orientation stream (tests, desktop, web).
  bool get failed => _failed;

  void start() {
    if (_sub != null) return;
    try {
      _sub = _events.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            _fusion.addEvent(event);
            pose.value = _fusion.pose;
          }
        },
        onError: (_) => _failed = true,
      );
    } on MissingPluginException {
      _failed = true;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _fusion.reset();
    pose.value = ArPose.unknown;
  }

  Future<void> dispose() async {
    await stop();
    pose.dispose();
  }

  static Future<CameraOptics> cameraOptics() async {
    try {
      final map =
          await _methods.invokeMapMethod<dynamic, dynamic>('cameraIntrinsics');
      return CameraOptics.fromMap(map) ?? CameraOptics.fallback;
    } catch (_) {
      return CameraOptics.fallback;
    }
  }

  static Future<Map<String, bool>> capabilities() async {
    try {
      final map =
          await _methods.invokeMapMethod<String, dynamic>('capabilities');
      return {
        for (final e in (map ?? const <String, dynamic>{}).entries)
          e.key: e.value == true,
      };
    } catch (_) {
      return const {};
    }
  }
}
