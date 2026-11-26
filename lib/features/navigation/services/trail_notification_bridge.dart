import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tap on a trail stop-arrival notification.
class TrailStopTap {
  final String trailId;
  final int stopPosition;

  const TrailStopTap({required this.trailId, required this.stopPosition});
}

/// Plan 124d: posts the local "arrived near the next stop" notification through
/// `TrailNotificationBridge.kt` (no extra plugin). Every call degrades silently
/// (notifications denied, iOS, tests).
class TrailNotificationBridge {
  static const _channel =
      MethodChannel('dev.zernanvash.juanderquest/trail_notifications');

  Future<void> showStopArrival({
    required String title,
    required String body,
    required String trailId,
    required int stopPosition,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'title': title,
        'body': body,
        'trailId': trailId,
        'stopPosition': stopPosition,
      });
    } catch (e) {
      debugPrint('[TrailNotify] show skipped: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } catch (_) {
      // Nothing to clear without the native side.
    }
  }

  /// Calls [onTap] for taps while the app runs, and once for the tap that
  /// launched the app (if any).
  Future<void> listenForTaps(void Function(TrailStopTap tap) onTap) async {
    TrailStopTap? parse(Object? raw) {
      if (raw is! Map) return null;
      final trailId = raw['trailId']?.toString() ?? '';
      if (trailId.isEmpty) return null;
      return TrailStopTap(
        trailId: trailId,
        stopPosition: (raw['stopPosition'] as num?)?.toInt() ?? 0,
      );
    }

    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onTap') {
          final tap = parse(call.arguments);
          if (tap != null) onTap(tap);
        }
        return null;
      });
      final launch =
          parse(await _channel.invokeMethod<Object?>('takeLaunchTap'));
      if (launch != null) onTap(launch);
    } catch (e) {
      debugPrint('[TrailNotify] tap listener skipped: $e');
    }
  }
}

final trailNotificationBridgeProvider =
    Provider<TrailNotificationBridge>((ref) => TrailNotificationBridge());
