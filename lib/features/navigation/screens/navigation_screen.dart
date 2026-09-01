import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';

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
    ref.read(navigationProvider(widget.destination).notifier).setActiveStep(stepIndex);

    if (route.coordinates.isEmpty) return;

    final ratio = stepIndex / (route.maneuvers.length > 1 ? route.maneuvers.length - 1 : 1);
    final targetIndex = (ratio * (route.coordinates.length - 1)).clamp(0, route.coordinates.length - 1).toInt();
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
              color: AppColors.woodBrown,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
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

    // 2. Destination Marker (Emerald Pin)
    markers.add(
      Marker(
        point: LatLng(widget.destination.lat, widget.destination.lng),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D6A4F),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
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
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );


    // 3. Active Step Focus Marker (Gold Target)
    if (route != null && navState.activeStepIndex != null && route.coordinates.isNotEmpty) {
      final ratio = navState.activeStepIndex! /
          (route.maneuvers.length > 1 ? route.maneuvers.length - 1 : 1);
      final targetIndex =
          (ratio * (route.coordinates.length - 1)).clamp(0, route.coordinates.length - 1).toInt();
      final activeCoord = route.coordinates[targetIndex];

      markers.add(
        Marker(
          point: activeCoord,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF582F0E), width: 2.0),
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
                  color: Color(0xFF582F0E),
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
          color: Colors.white.withOpacity(0.95),
        ),
      );

      // 2. Foreground dynamic route line
      polylineList.add(
        Polyline(
          points: route.coordinates,
          strokeWidth: 5.0,
          color: navState.avoidCongested
              ? const Color(0xFF2D6A4F) // Emerald for Tranquil Diversion
              : const Color(0xFF0284C7), // Sky Blue for Standard
        ),
      );
    }

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        titleSpacing: 0,
        title: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Text(
                    'INDEPENDENT ROUTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.12),
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: const Text(
                      'Valhalla Engine',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Route to ${widget.destination.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.woodBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.woodBrown),
            tooltip: 'Exit Navigation',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 1. Edge-to-Edge OpenStreetMap Canvas
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.destination.lat, widget.destination.lng),
              initialZoom: 13.0,
              minZoom: 6.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                subdomains: MapConfig.subdomains,
                userAgentPackageName: MapConfig.userAgentPackageName,
                maxZoom: 20,
              ),

              if (polylineList.isNotEmpty) PolylineLayer(polylines: polylineList),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Top-Left Floating Controls Card (Collapsible)
          Positioned(
            top: 10,
            left: 10,
            right: 64, // Space for right-side action buttons
            child: UiSpecContainer(
              spec: const UiSpec(
                title: 'Valhalla Routing & Anti-Crowd Diversion Controls',
                figmaLayer: '#Navigation_Control_Panel',
                dimensions: 'Max-width 360dp, Radius: 16dp, Blur: 8dp',
                dataBinding: 'navState.costing / navState.avoidCongested / route.summary',
                stateNotes: 'Multi-modal buttons (Auto, Moto, Bike, Walk) + Anti-Crowd Switch',
                uxNotes: 'Controls turn-by-turn calculation via self-hosted Azure VM Valhalla daemon.',
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.borderLowContrast),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Collapse toggle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.destination.address,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isControlsCollapsed = !_isControlsCollapsed);
                          },
                          child: Icon(
                            _isControlsCollapsed
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 20,
                            color: AppColors.woodBrown,
                          ),
                        ),
                      ],
                    ),

                    if (!_isControlsCollapsed) ...[
                      const SizedBox(height: 8),

                      // Costing Travel Modes Selector
                      Row(
                        children: TravelCosting.values.map((cost) {
                          final isSelected = navState.costing == cost;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => notifier.setCosting(cost),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2D6A4F)
                                      : AppColors.surfaceContainerLow,
                                  borderRadius: AppSpacing.roundedMd,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cost.iconEmoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        cost.label,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppColors.woodBrown,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Anti-Crowd Diversion Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF5),
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(color: const Color(0xFFFFE8A3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF2D6A4F)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Anti-Crowd Diversion',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.woodBrown,
                                      ),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Avoid tourist bottlenecks',
                                      style: TextStyle(fontSize: 8.5, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: navState.avoidCongested,
                                activeColor: const Color(0xFF2D6A4F),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (_) => notifier.toggleAvoidCongested(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Route Summary Bar
                    if (route != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF9F5),
                          borderRadius: AppSpacing.roundedSm,
                          border: Border.all(color: AppColors.borderLowContrast),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  route.summary.durationFormatted,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2D6A4F),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${route.summary.distanceKm} km)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.woodBrown,
                                  ),
                                ),
                              ],
                            ),
                            if (route.summary.hasCrowdDiversion)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2D6A4F),
                                  borderRadius: AppSpacing.roundedPill,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.eco_rounded, size: 10, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'Tranquil Route',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. Top-Right Floating Action Buttons
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                // Fit Full Route
                FloatingActionButton.small(
                  heroTag: 'fit_route_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2D6A4F),
                  onPressed: route != null ? () => _fitRouteBounds(route, userLocation) : null,
                  tooltip: 'Fit Full Route',
                  child: const Icon(Icons.explore_rounded, size: 18),
                ),
                const SizedBox(height: 8),

                // Locate User GPS
                FloatingActionButton.small(
                  heroTag: 'locate_user_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.woodBrown,
                  onPressed: navState.isLocating ? null : () => notifier.acquireCurrentLocation(),
                  tooltip: 'Acquire GPS Position',
                  child: navState.isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sunGold,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                ),
                const SizedBox(height: 8),

                // Toggle Guidance Drawer
                FloatingActionButton.small(
                  heroTag: 'toggle_drawer_btn',
                  backgroundColor: _showDirectionsDrawer ? const Color(0xFF2D6A4F) : Colors.white,
                  foregroundColor: _showDirectionsDrawer ? Colors.white : AppColors.woodBrown,
                  onPressed: () {
                    setState(() => _showDirectionsDrawer = !_showDirectionsDrawer);
                  },
                  tooltip: 'Toggle Turn Guidance',
                  child: const Icon(Icons.format_list_numbered_rounded, size: 18),
                ),
              ],
            ),
          ),

          // 4. Loading Toast
          if (navState.isLoadingRoute)
            Positioned(
              top: 180,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: AppSpacing.roundedPill,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2D6A4F),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Calculating Valhalla road network...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D6A4F),
                          ),
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
              top: 180,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: const Color(0xFFFFEEBA)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF856404)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        navState.error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => notifier.fetchRoute(),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF582F0E),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Bottom Floating Turn Guidance Drawer
          if (route != null && _showDirectionsDrawer && route.maneuvers.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: UiSpecContainer(
                spec: const UiSpec(
                  title: 'Step-by-Step Turn Maneuver Drawer',
                  figmaLayer: '#Navigation_Turn_Guidance_Drawer',
                  dimensions: 'Max-height: 260dp, Radius: 20dp, Elevation: 16dp',
                  dataBinding: 'route.maneuvers (instruction, streetName, distanceMeters)',
                  stateNotes: 'Tap step to focus camera along polyline target coordinate',
                  uxNotes: 'Includes turn guidance and street name markers.',
                ),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppSpacing.roundedXl,
                    border: Border.all(color: AppColors.borderLowContrast),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF2D6A4F)),
                              const SizedBox(width: 6),
                              Text(
                                'TURN GUIDANCE (${route.maneuvers.length} STEPS)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.woodBrown,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showDirectionsDrawer = false),
                            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Maneuvers List
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: route.maneuvers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final step = route.maneuvers[index];
                            final isSelected = navState.activeStepIndex == index;

                            return GestureDetector(
                              onTap: () => _focusStep(index, route),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2D6A4F).withOpacity(0.08)
                                      : const Color(0xFFFAF9F5),
                                  borderRadius: AppSpacing.roundedMd,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2D6A4F)
                                        : AppColors.borderLowContrast,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF2D6A4F)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2D6A4F)
                                              : AppColors.borderLowContrast,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : AppColors.woodBrown,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            step.instruction,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.woodBrown,
                                              height: 1.2,
                                            ),
                                          ),
                                          if (step.streetName != null && step.streetName!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                step.streetName!,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      step.formattedDistance,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
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
              ),
            ),
        ],
      ),
    );
  }
}
