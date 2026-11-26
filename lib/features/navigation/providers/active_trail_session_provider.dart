import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../models/route_model.dart';
import '../services/location_stream_service.dart';
import '../services/trail_notification_bridge.dart';
import 'navigation_provider.dart';

/// Live summary of an adventure that keeps running while the user is away
/// from the navigation screen (Plan 124d). Read by the Home JuanLog panel.
class ActiveTrailSessionState {
  final bool isRunning;
  final NavTarget? destination;
  final String? trailId;
  final String? trailTitle;
  final int totalStops;
  final double totalKm;
  final int rewardPoints;
  final String? nextStopName;
  final String? nextStopMunicipality;
  final int? nextStopPosition;
  final String? nextStopSpotId;
  final double? distanceToNextStopM;
  final bool isWithinStopTolerance;
  final double speedMs;

  const ActiveTrailSessionState({
    this.isRunning = false,
    this.destination,
    this.trailId,
    this.trailTitle,
    this.totalStops = 0,
    this.totalKm = 0,
    this.rewardPoints = 0,
    this.nextStopName,
    this.nextStopMunicipality,
    this.nextStopPosition,
    this.nextStopSpotId,
    this.distanceToNextStopM,
    this.isWithinStopTolerance = false,
    this.speedMs = 0,
  });

  bool get hasTrail => trailId != null && trailId!.isNotEmpty;
}

/// App-scoped owner of the live GPS stream during an adventure.
///
/// - Uses [trailBackgroundLocationSettings], so on Android the stream runs in
///   geolocator's foreground service and survives the screen turning off.
/// - Forwards every fix to the (kept-alive) [NavigationNotifier].
/// - Posts one stop-arrival notification per (trail, stop) when the user is
///   in range while the app is in the background or off the navigation screen.
/// - Only [stop] (END TRAIL) or the adventure ending stops it; leaving the
///   navigation screen does not.
class ActiveTrailSessionNotifier
    extends StateNotifier<ActiveTrailSessionState> {
  final Ref _ref;
  final bool Function() _isAppForeground;
  StreamSubscription<Position>? _sub;
  final Set<String> _notifiedStops = {};
  int _attachedScreens = 0;

  ActiveTrailSessionNotifier(this._ref, {bool Function()? isAppForeground})
      : _isAppForeground = isAppForeground ?? _defaultIsForeground,
        super(const ActiveTrailSessionState());

  static bool _defaultIsForeground() {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  bool get isListening => _sub != null;

  /// The navigation screen is visible (arrival is shown there, so no
  /// notification while the app is also in the foreground).
  void attachScreen() => _attachedScreens++;
  void detachScreen() {
    if (_attachedScreens > 0) _attachedScreens--;
  }

  /// Starts (or restarts) the live stream for [destination].
  void start(NavTarget destination) {
    unawaited(_sub?.cancel());
    final service = _ref.read(locationStreamServiceProvider);
    _sub = service
        .getPositionStream(locationSettings: trailBackgroundLocationSettings())
        .listen(
          (pos) => onFix(destination, pos),
          onError: (Object err) =>
              debugPrint('[TrailSession] Location stream error: $err'),
        );
    _publish(destination, _ref.read(navigationProvider(destination)));
  }

  /// One GPS fix. Public for tests.
  void onFix(NavTarget destination, Position pos) {
    final nav = _ref.read(navigationProvider(destination).notifier);
    nav.updatePosition(pos);
    final navState = _ref.read(navigationProvider(destination));
    if (!navState.isAdventureActive) {
      unawaited(stop(endAdventure: false));
      return;
    }
    _publish(destination, navState);

    final trail = navState.selectedTrail;
    final next = navState.nextUncheckedStop;
    if (trail == null || next == null || !navState.isWithinCheckinRadius) {
      return;
    }
    final key = '${trail.id}:${next.position}';
    if (!_notifiedStops.add(key)) return;
    if (_attachedScreens > 0 && _isAppForeground()) return;
    unawaited(_ref.read(trailNotificationBridgeProvider).showStopArrival(
          title: 'Arrived near ${next.name}!',
          body: 'Check in or record a quick JuanLog clip for ${trail.title}.',
          trailId: trail.id,
          stopPosition: next.position,
        ));
  }

  void _publish(NavTarget destination, NavigationState navState) {
    final trail = navState.selectedTrail;
    final next = navState.nextUncheckedStop;
    final pos = navState.currentPosition;
    final dist = (next != null && pos != null)
        ? Geolocator.distanceBetween(
            pos.latitude, pos.longitude, next.lat, next.lng)
        : null;
    state = ActiveTrailSessionState(
      isRunning: true,
      destination: destination,
      trailId: trail?.id,
      trailTitle: trail?.title ?? destination.name,
      totalStops: trail == null
          ? 0
          : (trail.stops.isNotEmpty ? trail.stops.length : trail.stopCount),
      totalKm: trail?.totalKm ?? 0,
      rewardPoints: navState.trailCompletionReward ?? trail?.rewardPoints ?? 0,
      nextStopName: next?.name,
      nextStopMunicipality: next?.municipality,
      nextStopPosition: next?.position,
      nextStopSpotId: next?.spotId,
      distanceToNextStopM: dist,
      isWithinStopTolerance: navState.isWithinCheckinRadius,
      speedMs: navState.currentSpeedMs,
    );
  }

  /// END TRAIL: stops GPS, clears notifications and (by default) ends the
  /// adventure on the navigation state.
  Future<void> stop({bool endAdventure = true}) async {
    final sub = _sub;
    _sub = null;
    final destination = state.destination;
    // End synchronously so the screen leaves driving mode in the same frame.
    if (endAdventure && destination != null) {
      _ref.read(navigationProvider(destination).notifier).endAdventure();
    }
    _notifiedStops.clear();
    if (mounted) state = const ActiveTrailSessionState();
    unawaited(_ref.read(trailNotificationBridgeProvider).cancelAll());
    await sub?.cancel();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    super.dispose();
  }
}

final activeTrailSessionProvider =
    StateNotifierProvider<ActiveTrailSessionNotifier, ActiveTrailSessionState>(
  (ref) => ActiveTrailSessionNotifier(ref),
);

/// Plan 124d: a stop-arrival notification tap reopens the running trail, or
/// the trail list when the app was restarted and the session is gone.
void openTrailNotificationTap(
  GoRouter router,
  ActiveTrailSessionState session,
  TrailStopTap tap,
) {
  final destination = session.destination;
  final current = router.routerDelegate.currentConfiguration.uri.path;
  if (session.isRunning && destination != null) {
    if (current != '/navigate') router.push('/navigate', extra: destination);
    return;
  }
  router.push('/trail');
}
