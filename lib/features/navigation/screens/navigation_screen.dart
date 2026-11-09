import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../../trail/models/trail_models.dart';
import '../../trail/services/trails_api.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';
import '../widgets/origin_picker_sheet.dart';
import '../widgets/route_deck.dart';
import '../widgets/steps_sheet.dart';

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

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late final JdqMap _nativeMap;
  late final Future<String> _style;
  bool _isControlsCollapsed = false;
  bool _showDirectionsDrawer = true;
  bool _hasInitialFitted = false;
  JdqRouteOverlay? _lastOverlay;

  @override
  void initState() {
    super.initState();
    _nativeMap = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialParams();
    });
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
      ref.read(trailsApiProvider).fetchTrail(widget.initialTrailId!).then((detail) {
        if (mounted) {
          notifier.selectTrail(detail);
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _nativeMap.dispose();
    super.dispose();
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
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelAppBar(
                  title: 'Navigation',
                  onBack:
                      canPop ? () => Navigator.of(context).maybePop() : null,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Vector Map Canvas
                      JdqMapCanvas(
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

                      // 2. Top Controls & Docked Action Buttons
                      Positioned(
                        top: grid.px(2),
                        left: grid.px(2),
                        right: grid.px(2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _controlsPanel(
                              context,
                              grid,
                              navState,
                              notifier,
                              route,
                            ),
                            SizedBox(height: grid.px(1)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: grid.px(1),
                                runSpacing: grid.px(1),
                                alignment: WrapAlignment.end,
                                children: [
                                  PixelButton(
                                    key: const ValueKey('nav_fit_route'),
                                    label: 'Fit',
                                    variant: PixelButtonVariant.secondary,
                                    onPressed: route != null
                                        ? () => _fitRouteBounds(
                                            route, originPoint)
                                        : null,
                                  ),
                                  if (route?.isStraightLineFallback != true)
                                    PixelButton(
                                      key: const ValueKey('nav_locate'),
                                      label: 'Locate',
                                      variant: PixelButtonVariant.secondary,
                                      loading: navState.isLocating,
                                      onPressed: navState.isLocating
                                          ? null
                                          : () => notifier
                                              .acquireCurrentLocation(),
                                    ),
                                  if (!_showDirectionsDrawer &&
                                      route != null &&
                                      !route.isStraightLineFallback &&
                                      route.maneuvers.isNotEmpty)
                                    PixelButton(
                                      key: const ValueKey('nav_toggle_steps'),
                                      label: 'Steps',
                                      variant: PixelButtonVariant.secondary,
                                      onPressed: () {
                                        setState(() =>
                                            _showDirectionsDrawer = true);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Loading Toast
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
                                  const PixelLoader(
                                      label: 'Routing', artPx: 6),
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

                      // 4. Error Toast Banner
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

                      // 5. Bottom floating turn guidance (legacy drawer if active)
                      if (route != null &&
                          !route.isStraightLineFallback &&
                          _showDirectionsDrawer &&
                          route.maneuvers.isNotEmpty)
                        Positioned(
                          bottom: grid.px(36),
                          left: grid.px(2),
                          right: grid.px(2),
                          child:
                              _directionsDrawer(context, grid, navState, route),
                        ),

                      // 6. Bottom Deck (Direct Route + Nearby Trails) & Pinned Action Bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: PixelPalette.paper.withValues(alpha: 0.95),
                            border: const Border(
                              top: BorderSide(
                                color: PixelPalette.woodDeep,
                                width: 2,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: grid.px(1)),
                                // Horizontal Deck (<= 84 dp tall)
                                RouteDeck(
                                  state: navState,
                                  notifier: notifier,
                                ),
                                SizedBox(height: grid.px(1)),
                                // Pinned Bottom Action Bar
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: grid.px(2),
                                    vertical: grid.px(1),
                                  ),
                                  child: Row(
                                    children: [
                                      PixelButton(
                                        key: const ValueKey(
                                            'nav_steps_bar_button'),
                                        label:
                                            'STEPS (${route?.maneuvers.length ?? 0})',
                                        variant: PixelButtonVariant.secondary,
                                        onPressed: route != null &&
                                                route.maneuvers.isNotEmpty
                                            ? () {
                                                StepsSheet.show(
                                                  context,
                                                  maneuvers: route.maneuvers,
                                                  activeStepIndex:
                                                      navState.activeStepIndex,
                                                  onStepSelected: (idx) =>
                                                      _focusStep(idx, route),
                                                );
                                              }
                                            : null,
                                      ),
                                      SizedBox(width: grid.px(1)),
                                      Expanded(
                                        child: PixelButton(
                                          key: const ValueKey(
                                              'nav_start_adventure'),
                                          label: 'START ADVENTURE',
                                          variant: PixelButtonVariant.primary,
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Live turn-by-turn navigation is coming next.',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _controlsPanel(
    BuildContext context,
    PixelGrid grid,
    NavigationState navState,
    NavigationNotifier notifier,
    RouteModel? route,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route?.isStraightLineFallback == true
                          ? 'Distance estimate'
                          : 'Valhalla Engine',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.greenDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // FROM / TO rows
                    Row(
                      children: [
                        const PixelChip('FROM', style: PixelBoxStyle.parchment),
                        SizedBox(width: grid.px(1)),
                        Expanded(
                          child: InkWell(
                            key: const ValueKey('nav_origin_selector'),
                            onTap: () {
                              OriginPickerSheet.show(
                                context,
                                currentOrigin: navState.origin,
                                onSelect: notifier.setOrigin,
                              );
                            },
                            child: Text(
                              navState.origin.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.body(context,
                                  color: PixelPalette.woodDeep),
                            ),
                          ),
                        ),
                        InkWell(
                          key: const ValueKey('nav_swap_origin'),
                          onTap: notifier.swapOriginAndDestination,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'SWAP',
                              style: PixelType.small(context,
                                  color: PixelPalette.goldDeep),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const PixelChip('TO', style: PixelBoxStyle.parchment),
                        SizedBox(width: grid.px(1)),
                        Expanded(
                          child: Text(
                            widget.destination.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.body(context,
                                color: PixelPalette.woodNight),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(1)),
              PixelButton(
                key: const ValueKey('nav_toggle_controls'),
                label: _isControlsCollapsed ? 'Show' : 'Hide',
                variant: PixelButtonVariant.secondary,
                onPressed: () => setState(
                    () => _isControlsCollapsed = !_isControlsCollapsed),
              ),
            ],
          ),
          if (!_isControlsCollapsed) ...[
            SizedBox(height: grid.px(1)),
            PixelSegmented(
              items: TravelCosting.values.map((cost) {
                switch (cost) {
                  case TravelCosting.auto:
                    return 'Drive';
                  case TravelCosting.motorcycle:
                    return 'Moto';
                  case TravelCosting.bicycle:
                    return 'Bike';
                  case TravelCosting.pedestrian:
                    return 'Eco';
                }
              }).toList(),
              selectedIndex: TravelCosting.values.indexOf(navState.costing),
              onChanged: (index) =>
                  notifier.setCosting(TravelCosting.values[index]),
            ),
            SizedBox(height: grid.px(1)),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUIET ROADS', style: PixelType.body(context)),
                      Text(
                        'Avoid tourist bottlenecks',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                PixelSwitch(
                  key: const ValueKey('nav_anti_crowd'),
                  value: navState.avoidCongested,
                  semanticLabel: 'Anti-Crowd Diversion',
                  onChanged: (_) => notifier.toggleAvoidCongested(),
                ),
              ],
            ),
          ],
          if (route != null && !route.isStraightLineFallback) ...[
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  route.summary.durationFormatted,
                  style: PixelType.title(
                    context,
                    color: PixelPalette.greenDark,
                  ),
                ),
                Text(
                  '(${route.summary.distanceKm} km)',
                  style: PixelType.body(context, color: PixelPalette.wood),
                ),
                if (route.summary.hasCrowdDiversion)
                  const PixelChip(
                    'Tranquil route',
                    style: PixelBoxStyle.parchment,
                  ),
              ],
            ),
          ] else if (route != null && route.isStraightLineFallback) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'ESTIMATE · ${route.summary.distanceKm.toStringAsFixed(0)} KM',
              style: PixelType.body(
                context,
                color: PixelPalette.goldDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _directionsDrawer(
    BuildContext context,
    PixelGrid grid,
    NavigationState navState,
    RouteModel route,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: grid.px(100)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TURN GUIDANCE (${route.maneuvers.length} STEPS)',
                    style: PixelType.small(context),
                  ),
                ),
                PixelButton(
                  key: const ValueKey('nav_close_steps'),
                  label: 'Close',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () =>
                      setState(() => _showDirectionsDrawer = false),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: route.maneuvers.length,
                separatorBuilder: (_, __) => SizedBox(height: grid.px(1)),
                itemBuilder: (context, index) {
                  final step = route.maneuvers[index];
                  final isSelected = navState.activeStepIndex == index;
                  return GestureDetector(
                    key: ValueKey('nav_step_$index'),
                    onTap: () => _focusStep(index, route),
                    child: PixelPanel(
                      style: isSelected
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.parchment,
                      padding: 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PixelChip('${index + 1}'),
                          SizedBox(width: grid.px(1)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.instruction,
                                  style: PixelType.body(
                                    context,
                                    color: isSelected
                                        ? PixelPalette.woodDeep
                                        : PixelPalette.ink,
                                  ),
                                ),
                                if (step.streetName != null &&
                                    step.streetName!.isNotEmpty)
                                  Text(
                                    step.streetName!,
                                    style: PixelType.small(
                                      context,
                                      color: isSelected
                                          ? PixelPalette.woodDeep
                                          : PixelPalette.slate,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: grid.px(1)),
                          Text(
                            step.formattedDistance,
                            style: PixelType.small(
                              context,
                              color: isSelected
                                  ? PixelPalette.woodDeep
                                  : PixelPalette.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
