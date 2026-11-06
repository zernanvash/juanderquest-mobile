// flutter_map's dashed pattern constructor validates its segment list at runtime.
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/map_config.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';
import '../widgets/route_fallback_notice_card.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final NavTarget destination;

  const NavigationScreen({
    super.key,
    required this.destination,
  });

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _isControlsCollapsed = false;
  bool _showDirectionsDrawer = true;
  bool _hasInitialFitted = false;

  void _fitRouteBounds(RouteModel route, LatLng? origin) {
    if (route.coordinates.isEmpty) return;

    final points = <LatLng>[...route.coordinates];
    if (origin != null) points.add(origin);
    points.add(LatLng(widget.destination.lat, widget.destination.lng));

    if (points.length == 1) {
      _mapController.move(points.first, 14.0);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.only(
          top: 120,
          left: 40,
          right: 40,
          bottom: 240,
        ),
      ),
    );
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

    _mapController.move(targetCoord, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider(widget.destination));
    final notifier = ref.read(navigationProvider(widget.destination).notifier);
    final route = navState.route;
    final userLocation = navState.userLocation;

    // Auto-fit bounds on first successful route load
    if (route != null && !_hasInitialFitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route.coordinates.isNotEmpty) {
          _fitRouteBounds(route, userLocation);
          setState(() => _hasInitialFitted = true);
        }
      });
    }

    final markers = <Marker>[];

    // 1. Origin Marker (Rocket / Start Point)
    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFAF9F5), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.my_location_rounded,
                color: Color(0xFFFFB703),
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Destination Marker (Terra Cotta Pin)
    markers.add(
      Marker(
        point: LatLng(widget.destination.lat, widget.destination.lng),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF8B3A2B),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFAF9F5), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.flag_rounded,
              color: Color(0xFFFAF9F5),
              size: 20,
            ),
          ),
        ),
      ),
    );

    // 3. Active Step Focus Marker (Wood Brown Target)
    if (route != null &&
        navState.activeStepIndex != null &&
        route.coordinates.isNotEmpty) {
      final ratio = navState.activeStepIndex! /
          (route.maneuvers.length > 1 ? route.maneuvers.length - 1 : 1);
      final targetIndex = (ratio * (route.coordinates.length - 1))
          .clamp(0, route.coordinates.length - 1)
          .toInt();
      final activeCoord = route.coordinates[targetIndex];

      markers.add(
        Marker(
          point: activeCoord,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF582F0E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFAF9F5), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${navState.activeStepIndex! + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFAF9F5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final polylineList = <Polyline>[];
    if (route != null && route.coordinates.isNotEmpty) {
      // 1. Casing polyline for shadow & high contrast against roads
      polylineList.add(
        Polyline(
          points: route.coordinates,
          strokeWidth: 8.0,
          color: Colors.white
              .withOpacity(route.isStraightLineFallback ? 0.55 : 0.95),
          pattern: route.isStraightLineFallback
              ? StrokePattern.dashed(segments: [8, 8])
              : StrokePattern.solid(),
        ),
      );

      // 2. Foreground dynamic route line
      polylineList.add(
        Polyline(
          points: route.coordinates,
          strokeWidth: route.isStraightLineFallback ? 4.0 : 5.0,
          pattern: route.isStraightLineFallback
              ? StrokePattern.dashed(segments: [8, 8])
              : StrokePattern.solid(),
          color: route.isStraightLineFallback
              ? const Color(0xFFD97706) // Amber for fallback
              : const Color(0xFF0284C7), // Sky Blue for Standard
        ),
      );
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
              children: [
                PixelAppBar(
                  title: 'Navigation',
                  onBack:
                      canPop ? () => Navigator.of(context).maybePop() : null,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // 1. Edge-to-Edge OpenStreetMap Canvas
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                              widget.destination.lat, widget.destination.lng),
                          initialZoom: 13.0,
                          minZoom: MapConfig.minZoom,
                          maxZoom: MapConfig.maxZoom,
                          cameraConstraint: CameraConstraint.contain(
                            bounds: LatLngBounds(
                              const LatLng(
                                  MapConfig.phMinLat, MapConfig.phMinLng),
                              const LatLng(
                                  MapConfig.phMaxLat, MapConfig.phMaxLng),
                            ),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          buildBaseTileLayer(),

                          if (polylineList.isNotEmpty)
                            PolylineLayer(polylines: polylineList),
                          MarkerLayer(markers: markers),

                          // OSM policy compliance: keep visible attribution on the canvas.
                          RichAttributionWidget(
                            showFlutterMapAttribution: false,
                            alignment: AttributionAlignment.bottomRight,
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () async {
                                  try {
                                    await launchUrl(
                                      Uri.parse(
                                          'https://www.openstreetmap.org/copyright'),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {
                                    // Attribution link is best-effort; the text itself stays visible.
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 2. Top Controls & Docked Action Buttons
                      Positioned(
                        top: grid.px(5),
                        left: grid.px(5),
                        right: grid.px(5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _controlsPanel(
                                context, grid, navState, notifier, route),
                            SizedBox(height: grid.px(2)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: grid.px(2),
                                runSpacing: grid.px(1),
                                alignment: WrapAlignment.end,
                                children: [
                                  PixelButton(
                                    key: const ValueKey('nav_fit_route'),
                                    label: 'Fit',
                                    variant: PixelButtonVariant.secondary,
                                    onPressed: route != null
                                        ? () =>
                                            _fitRouteBounds(route, userLocation)
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

                      // 4. Loading Toast
                      if (navState.isLoadingRoute)
                        Positioned(
                          top: grid.px(90),
                          left: grid.px(10),
                          right: grid.px(10),
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

                      // 5. Error Toast Banner
                      if (navState.error != null)
                        Positioned(
                          top: grid.px(90),
                          left: grid.px(10),
                          right: grid.px(10),
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
                                SizedBox(width: grid.px(2)),
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

                      // 6. Bottom Floating Turn Guidance Drawer
                      if (route != null && route.isStraightLineFallback)
                        Positioned(
                          bottom: grid.px(3),
                          left: grid.px(3),
                          right: grid.px(3),
                          child: RouteFallbackNoticeCard(
                            route: route,
                            destination:
                                '${widget.destination.lat},${widget.destination.lng}',
                          ),
                        ),
                      if (route != null &&
                          !route.isStraightLineFallback &&
                          _showDirectionsDrawer &&
                          route.maneuvers.isNotEmpty)
                        Positioned(
                          bottom: grid.px(3),
                          left: grid.px(3),
                          right: grid.px(3),
                          child:
                              _directionsDrawer(context, grid, navState, route),
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
                    Text(
                      widget.destination.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context, color: PixelPalette.slate),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
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
            SizedBox(height: grid.px(2)),
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
            SizedBox(height: grid.px(2)),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Anti-Crowd Diversion',
                          style: PixelType.body(context)),
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
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(2),
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
                  const PixelChip('Tranquil route',
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white),
              ],
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
        constraints: BoxConstraints(maxHeight: grid.px(130)),
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
            SizedBox(height: grid.px(2)),
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
                      style:
                          isSelected ? PixelBoxStyle.green : PixelBoxStyle.slot,
                      padding: 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PixelChip('${index + 1}'),
                          SizedBox(width: grid.px(2)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.instruction,
                                  style: PixelType.body(
                                    context,
                                    color: isSelected
                                        ? PixelPalette.white
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
                                          ? PixelPalette.cream
                                          : PixelPalette.slate,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: grid.px(2)),
                          Text(
                            step.formattedDistance,
                            style: PixelType.small(
                              context,
                              color: isSelected
                                  ? PixelPalette.white
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
