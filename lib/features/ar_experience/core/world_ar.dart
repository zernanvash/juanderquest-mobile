import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ar_math.dart';

/// ARCore status on this phone.
enum WorldArAvailability { installed, installable, unsupported, checking }

class WorldArSupport {
  static const _channel = MethodChannel('com.juanderquest.app/arcore');

  /// Asks ARCore whether this phone supports it. The first answer can be
  /// "checking" (ARCore queries Play); poll briefly until it settles.
  static Future<WorldArAvailability> check({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final a = await _once();
      if (a != WorldArAvailability.checking ||
          DateTime.now().isAfter(deadline)) {
        return a == WorldArAvailability.checking
            ? WorldArAvailability.unsupported
            : a;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  static Future<WorldArAvailability> _once() async {
    try {
      final s = await _channel.invokeMethod<String>('availability');
      return switch (s) {
        'installed' => WorldArAvailability.installed,
        'installable' => WorldArAvailability.installable,
        'checking' => WorldArAvailability.checking,
        _ => WorldArAvailability.unsupported,
      };
    } catch (_) {
      return WorldArAvailability.unsupported;
    }
  }

  /// Opens the Play Store flow for "Google Play Services for AR".
  static Future<bool> requestInstall() async {
    try {
      final s = await _channel.invokeMethod<String>('requestInstall');
      return s == 'installed';
    } catch (_) {
      return false;
    }
  }
}

/// World AR is opt-in (Settings → Developer → AR diagnostics) until it has
/// been verified on real phones.
class WorldArPrefs {
  static const _key = 'jdq_world_ar_enabled';
  static const _storage = FlutterSecureStorage();

  static Future<bool> enabled() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      await _storage.write(key: _key, value: value ? 'true' : 'false');
    } catch (_) {}
  }
}

/// One ARCore frame as sent by the native `ArCoreView`.
class WorldArFrame {
  /// `tracking`, `paused` or `stopped`.
  final String state;

  /// ARCore's tracking-failure reason, e.g. `insufficient_light`.
  final String reason;
  final int planes;

  /// Column-major 4×4 matrices; null while not tracking.
  final List<double>? view;
  final List<double>? proj;

  /// Column-major pose of the placed anchor; null if none or not tracking.
  final List<double>? anchor;
  final String? error;

  const WorldArFrame({
    required this.state,
    required this.reason,
    required this.planes,
    this.view,
    this.proj,
    this.anchor,
    this.error,
  });

  bool get tracking => state == 'tracking' && view != null && proj != null;

  static List<double>? _matrix(Object? v) =>
      v is List && v.length == 16 ? [for (final e in v) (e as num).toDouble()] : null;

  factory WorldArFrame.fromMap(Map<dynamic, dynamic> m) => WorldArFrame(
        state: '${m['state'] ?? 'stopped'}',
        reason: '${m['reason'] ?? 'none'}',
        planes: (m['planes'] as num?)?.toInt() ?? 0,
        view: _matrix(m['view']),
        proj: _matrix(m['proj']),
        anchor: _matrix(m['anchor']),
        error: m['error'] as String?,
      );

  /// Traveler-facing hint for why tracking is poor.
  String get trackingHint => switch (reason) {
        'insufficient_light' => 'Too dark. Find more light.',
        'excessive_motion' => 'Move your phone more slowly.',
        'insufficient_features' =>
          'Point at the ground with some texture (grass, tiles, sand).',
        'camera_unavailable' => 'Another app is using the camera.',
        _ => 'Move your phone slowly to scan the ground.',
      };
}

/// Projects the anchored object with ARCore's own camera matrices.
class WorldProjection {
  /// How far above the anchor (on the ground) the object floats, in metres.
  static const double liftM = 0.35;

  /// Column-major 4×4 × vec4.
  static List<double> _mul(List<double> m, List<double> v) => [
        for (var r = 0; r < 4; r++)
          m[r] * v[0] + m[4 + r] * v[1] + m[8 + r] * v[2] + m[12 + r] * v[3],
      ];

  /// Screen position of the anchored object, or null when there is no anchor.
  static ScreenProjection? project(WorldArFrame frame, Size screen) {
    final a = frame.anchor;
    if (!frame.tracking || a == null) return null;
    final world = [a[12], a[13] + liftM, a[14], 1.0];
    final eye = _mul(frame.view!, world);
    final clip = _mul(frame.proj!, eye);
    final depth = -eye[2];
    if (clip[3] <= 0.05 || depth <= 0.05) {
      return ScreenProjection(
        offset: Offset(screen.width / 2, screen.height / 2),
        depth: depth,
        inFront: false,
        onScreen: false,
      );
    }
    final nx = clip[0] / clip[3];
    final ny = clip[1] / clip[3];
    final o = Offset((nx + 1) / 2 * screen.width, (1 - ny) / 2 * screen.height);
    final margin = screen.shortestSide * 0.25;
    return ScreenProjection(
      offset: o,
      depth: depth,
      inFront: true,
      onScreen: o.dx > -margin &&
          o.dx < screen.width + margin &&
          o.dy > -margin &&
          o.dy < screen.height + margin,
    );
  }

  /// Horizontal focal length in logical pixels.
  static double focalPx(WorldArFrame frame, Size screen) =>
      (frame.proj?[0] ?? 1.5) * screen.width / 2;

  /// Signed horizontal angle (degrees) from the view direction to the object,
  /// negative = to the left. Used for the off-screen edge hint.
  static double relativeDegrees(WorldArFrame frame) {
    final a = frame.anchor;
    final v = frame.view;
    if (a == null || v == null) return 0;
    final eye = _mul(v, [a[12], a[13] + liftM, a[14], 1.0]);
    return math.atan2(eye[0], -eye[2]) * 180 / math.pi;
  }
}

/// Frames from one native ArCoreView, published for the overlay.
class WorldArSession {
  final int viewId;
  final ValueNotifier<WorldArFrame?> frame = ValueNotifier(null);
  late final MethodChannel _methods =
      MethodChannel('com.juanderquest.app/arcore_view_$viewId');
  StreamSubscription<dynamic>? _sub;

  WorldArSession(this.viewId) {
    _sub = EventChannel('com.juanderquest.app/arcore_frames_$viewId')
        .receiveBroadcastStream()
        .listen((e) {
      if (e is Map) frame.value = WorldArFrame.fromMap(e);
    }, onError: (_) {});
  }

  Future<bool> placeAnchor() async {
    try {
      return await _methods.invokeMethod<bool>('placeAnchor') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAnchor() async {
    try {
      await _methods.invokeMethod<bool>('clearAnchor');
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    frame.dispose();
  }
}
