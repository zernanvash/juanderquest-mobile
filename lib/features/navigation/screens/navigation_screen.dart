import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../../trail/models/trail_models.dart';
import '../../trail/services/trails_api.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';
import '../services/location_stream_service.dart';
import '../services/wakelock_service.dart';
import '../widgets/adventure_bottom_bar.dart';
import '../widgets/adventure_top_banner.dart';
import '../widgets/detour_sheet.dart';
import '../widgets/origin_picker_sheet.dart';
import '../widgets/route_preview_sheet.dart';
import '../widgets/route_preview_top_bar.dart';
import '../widgets/safety_disclaimer_sheet.dart';
import '../widgets/steps_sheet.dart';
import '../widgets/trail_offer_sheet.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final NavTarget destination;
  final String? initialTrailId;
  final String? initialFrom;

  const NavigationScreen({
    super.key,
    required this.destination,
    this.initialTrailId,
    this.initialFrom,
  });

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with WidgetsBindingObserver {
  late final JdqMap _nativeMap;
  late final Future<String> _style;
  bool _hasInitialFitted = false;
  bool _isBannerExpanded = false;
  StreamSubscription<Position>? _positionSubscription;
  JdqRouteOverlay? _lastOverlay;
  WakelockService? _wakelockService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakelockService = ref.read(wakelockServiceProvider);
    _nativeMap = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialParams();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopLiveNavigation(keepAdventureState: true);
    } else if (state == AppLifecycleState.resumed) {
      final navState = ref.read(navigationProvider(widget.destination));
      if (navState.isAdventureActive) {
        _resumeLiveNavigation();
      }
    }
  }

  void _applyInitialParams() {
    final notifier = ref.read(navigationProvider(widget.destination).notifier);

    if (widget.initialFrom != null) {
      if (widget.initialFrom == 'gps') {
        notifier.acquireCurrentLocation();
      } else {
        final originMatch = kTripOrigins.where(
          (o) =>
              o.name.toLowerCase() == widget.initialFrom!.toLowerCase() ||
              o.name.toLowerCase().contains(widget.initialFrom!.toLowerCase()),
        );
        if (originMatch.isNotEmpty) {
          final matched = originMatch.first;
          notifier.setOrigin(NavOrigin(
            name: matched.name,
            point: matched.point,
            isGps: false,
          ));
        }
      }
    }

    if (widget.initialTrailId != null) {
      ref
          .read(trailsApiProvider)
          .fetchTrail(widget.initialTrailId!)
          .then((detail) {
        if (mounted) {
          notifier.selectTrail(detail);
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _wakelockService?.disable();
    _nativeMap.dispose();
    super.dispose();
  }

  Future<void> _handleStartAdventure() async {
    final navState = ref.read(navigationProvider(widget.destination));
    final notifier = ref.read(navigationProvider(widget.destination).notifier);
    if (navState.route == null || navState.isFindingGps) return;

    final accepted =
        await SafetyDisclaimerSheet.ensureSafetyAcknowledged(context);
    if (!accepted || !mounted) return;

    final locationService = ref.read(locationStreamServiceProvider);
    final hasPermission = await locationService.checkPermission();
    if (hasPermission == LocationPermission.denied) {
      final req = await locationService.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location permission is required for live navigation.'),
            ),
          );
        }
        return;
      }
    } else if (hasPermission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Location permission is required for live navigation.'),
          ),
        );
      }
      return;
    }

    // Bug A1 (§4 rule 1): wait for a GPS fix, set origin, re-fetch route from there
    final acquired = await notifier.acquireStartFixAndFetchRoute(locationService);
    if (!acquired || !mounted) {
      if (mounted) {
        final err = ref.read(navigationProvider(widget.destination)).error;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        }
      }
      return;
    }

    await ref.read(wakelockServiceProvider).enable();
    notifier.startAdventure();

    final freshState = ref.read(navigationProvider(widget.destination));
    final startPos = freshState.currentPosition;
    final startPoint = freshState.effectiveOriginPoint;

    await _positionSubscription?.cancel();
    _positionSubscription = locationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      notifier.updatePosition(pos);
      final current = ref.read(navigationProvider(widget.destination));
      if (current.isCameraFollowing) {
        unawaited(_nativeMap.easeTo(
          LatLng(pos.latitude, pos.longitude),
          16.5,
          bearing: pos.speed > 1.0 && pos.heading >= 0 ? pos.heading : null,
          tilt: 45.0,
        ));
      }
    }, onError: (err) {
      debugPrint('[Navigation] Location stream error: $err');
    });

    unawaited(_nativeMap.easeTo(
      startPoint,
      16.5,
      bearing: startPos != null && startPos.speed > 1.0 && startPos.heading >= 0
          ? startPos.heading
          : null,
      tilt: 45.0,
    ));
  }

  Future<void> _resumeLiveNavigation() async {
    await ref.read(wakelockServiceProvider).enable();
    final locationService = ref.read(locationStreamServiceProvider);
    final notifier = ref.read(navigationProvider(widget.destination).notifier);

    await _positionSubscription?.cancel();
    _positionSubscription = locationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      notifier.updatePosition(pos);
      final current = ref.read(navigationProvider(widget.destination));
      if (current.isCameraFollowing) {
        unawaited(_nativeMap.easeTo(
          LatLng(pos.latitude, pos.longitude),
          16.5,
          bearing: pos.speed > 1.0 ? pos.heading : null,
          tilt: 45.0,
        ));
      }
    }, onError: (err) {
      debugPrint('[Navigation] Location resume error: $err');
    });
  }

  Future<void> _stopLiveNavigation({required bool keepAdventureState}) async {
    final sub = _positionSubscription;
    _positionSubscription = null;
    unawaited(sub?.cancel());
    try {
      await ref.read(wakelockServiceProvider).disable();
    } catch (_) {
      await _wakelockService?.disable();
    }
    if (!keepAdventureState && mounted) {
      ref.read(navigationProvider(widget.destination).notifier).endAdventure();
    }
  }

  Future<void> _confirmEndAdventure() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final grid = PixelGrid.of(context);
        return Container(
          decoration: const BoxDecoration(
            color: PixelPalette.paper,
            border: Border(
              top: BorderSide(color: PixelPalette.woodDeep, width: 3),
            ),
          ),
          padding: EdgeInsets.all(grid.px(3)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'END ADVENTURE?',
                  style: PixelType.title(context, color: PixelPalette.woodDeep),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Return to route planning?',
                  style: PixelType.body(context, color: PixelPalette.woodMid),
                ),
                SizedBox(height: grid.px(2)),
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        key: const ValueKey('nav_end_adventure_cancel'),
                        label: 'CANCEL',
                        variant: PixelButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      flex: 2,
                      child: PixelButton(
                        key: const ValueKey('nav_end_adventure_confirm'),
                        label: 'END ADVENTURE',
                        variant: PixelButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await _stopLiveNavigation(keepAdventureState: false);
    }
  }

  void _syncOverlay(JdqRouteOverlay? overlay) {
    if (overlay == null && _lastOverlay == null) return;
    _lastOverlay = overlay;
    unawaited(_nativeMap.setRouteOverlay(overlay));
  }

  void _fitRouteBounds(RouteModel route, LatLng? origin) {
    if (route.coordinates.isEmpty) return;

    final points = <LatLng>[...route.coordinates];
    if (origin != null) points.add(origin);
    points.add(LatLng(widget.destination.lat, widget.destination.lng));

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    unawaited(_nativeMap.fitBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
      const EdgeInsets.only(top: 140, left: 40, right: 40, bottom: 220),
    ));
  }

  void _focusStep(int stepIndex, RouteModel route) {
    ref
        .read(navigationProvider(widget.destination).notifier)
        .setActiveStep(stepIndex);

    if (route.coordinates.isEmpty) return;

    final ratio = stepIndex /
        (route.maneuvers.length > 1 ? route.maneuvers.length - 1 : 1);
    final targetIndex = (ratio * (route.coordinates.length - 1))
        .clamp(0, route.coordinates.length - 1)
        .toInt();
    final targetCoord = route.coordinates[targetIndex];

    unawaited(_nativeMap.easeTo(targetCoord, 15.5));
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider(widget.destination));
    final notifier = ref.read(navigationProvider(widget.destination).notifier);
    final route = navState.route;
    final originPoint = navState.effectiveOriginPoint;
    final overlay = navState.routeOverlay;

    _syncOverlay(overlay);

    // Auto-fit bounds on first successful route load
    if (route != null && !_hasInitialFitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route.coordinates.isNotEmpty) {
          _fitRouteBounds(route, originPoint);
          setState(() => _hasInitialFitted = true);
        }
      });
    }

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();

          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-screen Vector Map Canvas
                Listener(
                  onPointerDown: (_) {
                    if (navState.isAdventureActive &&
                        navState.isCameraFollowing) {
                      notifier.setCameraFollowing(false);
                    }
                  },
                  child: JdqMapCanvas(
                    map: _nativeMap,
                    style: _style,
                    fallback: const ColoredBox(
                      color: PixelPalette.paper,
                      child: Center(
                        child: Text(
                          'Offline Map Mode',
                          style: TextStyle(fontFamily: 'Silkscreen'),
                        ),
                      ),
                    ),
                    onFallback: () {},
                  ),
                ),

                if (!navState.isAdventureActive) ...[
                  // 2. Preview Top Bar (Back + TO destination)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: RoutePreviewTopBar(
                      toLabel: widget.destination.name,
                      onBack: canPop
                          ? () => Navigator.of(context).maybePop()
                          : null,
                    ),
                  ),

                  // 3. Preview Bottom Sheet
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: RoutePreviewSheet(
                      navState: navState,
                      onSelectCosting: notifier.setCosting,
                      onChangeOrigin: () {
                        OriginPickerSheet.show(
                          context,
                          currentOrigin: navState.origin,
                          onSelect: notifier.setOrigin,
                          avoidCongested: navState.avoidCongested,
                          onToggleAvoidCongested: notifier.toggleAvoidCongested,
                          selectedDetoursCount: navState.selectedDetours.length,
                          onOpenDetours: navState.isDirectRoute
                              ? () => _openDetours(navState, notifier)
                              : null,
                        );
                      },
                      onSelectDirect: notifier.selectDirectRoute,
                      onSelectTrail: (trail) {
                        if (trail.isUnlocked) {
                          unawaited(notifier.selectUnlockedTrail(trail.id));
                        } else {
                          _openTrailOffer(trail, notifier);
                        }
                      },
                      onInspectTrail: (trail) =>
                          _openTrailOffer(trail, notifier),
                      onOpenSteps: () {
                        if (route != null && route.maneuvers.isNotEmpty) {
                          StepsSheet.show(
                            context,
                            maneuvers: route.maneuvers,
                            activeStepIndex: navState.activeStepIndex,
                            onStepSelected: (idx) => _focusStep(idx, route),
                          );
                        }
                      },
                      onGo: () => unawaited(_handleStartAdventure()),
                      onRetry: () => notifier.fetchRoute(),
                    ),
                  ),
                ] else ...[
                  // Adventure Top Banner
                  Positioned(
                    top: grid.px(2),
                    left: grid.px(2),
                    right: grid.px(2),
                    child: AdventureTopBanner(
                      currentManeuver: navState.currentManeuver,
                      distanceToManeuverM: navState.distanceToManeuverM,
                      upcomingManeuvers: navState.upcomingManeuvers,
                      isRerouting: navState.isRerouting,
                      isExpanded: _isBannerExpanded,
                      onToggleExpand: () => setState(
                          () => _isBannerExpanded = !_isBannerExpanded),
                    ),
                  ),

                  // Loading Toast (driving only)
                  if (navState.isLoadingRoute)
                    Positioned(
                      top: grid.px(90),
                      left: grid.px(8),
                      right: grid.px(8),
                      child: Center(
                        child: PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PixelLoader(label: 'Routing', artPx: 6),
                              SizedBox(width: grid.px(2)),
                              Flexible(
                                child: Text(
                                  'Calculating Valhalla road network...',
                                  style: PixelType.body(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Error Toast Banner (driving only)
                  if (navState.error != null)
                    Positioned(
                      top: grid.px(90),
                      left: grid.px(4),
                      right: grid.px(4),
                      child: PixelPanel(
                        style: PixelBoxStyle.gold,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                navState.error!,
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.goldDeep,
                                ),
                              ),
                            ),
                            SizedBox(width: grid.px(1)),
                            PixelButton(
                              key: const ValueKey('nav_error_retry'),
                              label: 'Retry',
                              variant: PixelButtonVariant.secondary,
                              onPressed: () => notifier.fetchRoute(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Floating RE-CENTER button during adventure
                  if (!navState.isCameraFollowing)
                    Positioned(
                      bottom: grid.px(24),
                      right: grid.px(2),
                      child: PixelButton(
                        key: const ValueKey('nav_recenter'),
                        label: 'RE-CENTER',
                        variant: PixelButtonVariant.primary,
                        onPressed: () {
                          notifier.setCameraFollowing(true);
                          if (navState.currentPosition != null) {
                            unawaited(_nativeMap.easeTo(
                              LatLng(navState.currentPosition!.latitude,
                                  navState.currentPosition!.longitude),
                              16.5,
                              bearing: navState.currentPosition!.speed > 1.0
                                  ? navState.currentPosition!.heading
                                  : null,
                              tilt: 45.0,
                            ));
                          }
                        },
                      ),
                    ),

                  // Active Adventure Bottom Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AdventureBottomBar(
                      summary: route?.summary ?? const RouteSummary.empty(),
                      selectedTrail: navState.selectedTrail,
                      nextStop: navState.nextUncheckedStop,
                      totalStops: navState.totalTrailStops,
                      currentStopNumber: navState.currentStopNumber,
                      isWithinCheckinRadius: navState.isWithinCheckinRadius,
                      currentSpeedMs: navState.currentSpeedMs,
                      isCheckingIn: navState.isCheckingIn,
                      hasArrivedDirect: navState.hasArrivedDirect,
                      isTrailCompleted: navState.isTrailCompleted,
                      trailRewardPoints: navState.trailCompletionReward ?? 0,
                      onCheckIn: () => notifier.checkInCurrentStop(),
                      onOpenSteps: () {
                        if (route != null && route.maneuvers.isNotEmpty) {
                          StepsSheet.show(
                            context,
                            maneuvers: route.maneuvers,
                            activeStepIndex: navState.activeStepIndex,
                            onStepSelected: (idx) => _focusStep(idx, route),
                          );
                        }
                      },
                      onEnd: _confirmEndAdventure,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openTrailOffer(NearbyTrail trail, NavigationNotifier notifier) {
    TrailOfferSheet.show(
      context,
      trail: trail,
      onChoose: notifier.selectTrail,
    );
  }

  void _openDetours(NavigationState navState, NavigationNotifier notifier) {
    DetourSheet.show(
      context,
      availableDetours: navState.availableDetours,
      selectedDetours: navState.selectedDetours,
      onToggleDetour: notifier.toggleDetour,
      onClear: notifier.clearDetours,
    );
  }
}
