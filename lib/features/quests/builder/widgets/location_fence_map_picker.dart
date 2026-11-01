import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/base_tile_layer.dart';
import '../builder_models.dart';

class LocationFenceMapPicker extends StatefulWidget {
  final GeoFence fence;
  final ValueChanged<GeoFence> onChanged;
  final String pinLabel;

  const LocationFenceMapPicker({
    super.key,
    required this.fence,
    required this.onChanged,
    this.pinLabel = 'Target pin',
  });

  @override
  State<LocationFenceMapPicker> createState() => _LocationFenceMapPickerState();
}

class _LocationFenceMapPickerState extends State<LocationFenceMapPicker> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE7E5E4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.fence.lat, widget.fence.lng),
                    initialZoom: 16,
                    minZoom: 8,
                    maxZoom: 19,
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture) {
                        widget.onChanged(widget.fence.copyWith(
                          lat: pos.center.latitude,
                          lng: pos.center.longitude,
                        ));
                      }
                    },
                  ),
                  children: [
                    buildBaseTileLayer(satellite: false),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(widget.fence.lat, widget.fence.lng),
                          radius: widget.fence.radiusMeters.toDouble(),
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),
                // Center pin
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.pinLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.woodBrown,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            Icons.location_pin,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Perimeter Radius',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${widget.fence.radiusMeters} meters',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.woodBrown,
                    ),
                  ),
                ],
              ),
              Slider(
                value: widget.fence.radiusMeters.toDouble().clamp(30.0, 500.0),
                min: 30,
                max: 500,
                divisions: 47,
                activeColor: AppColors.primary,
                inactiveColor: const Color(0xFFD6D3D1),
                onChanged: (val) {
                  widget.onChanged(widget.fence.copyWith(radiusMeters: val.round()));
                },
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30 m', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('100 m (recommended)', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('500 m', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
