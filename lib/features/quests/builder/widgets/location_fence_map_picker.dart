import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../map/engine/jdq_map.dart';
import '../../../map/engine/jdq_map_canvas.dart';
import '../../../map/engine/maplibre_jdq_map.dart';
import '../../../map/pixel/map_marker_art.dart';
import '../../../map/utils/admin_areas.dart';
import '../builder_models.dart';

class LocationFenceMapPicker extends ConsumerStatefulWidget {
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
  ConsumerState<LocationFenceMapPicker> createState() =>
      _LocationFenceMapPickerState();
}

class _LocationFenceMapPickerState
    extends ConsumerState<LocationFenceMapPicker> {
  late final JdqMap _map;
  late final Future<String> _style;
  // Locked by default so a page scroll that crosses the map never moves the pin.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _map = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    _map.onCameraIdle = () {
      if (!_editing) return;
      final c = _map.camera.center;
      if ((c.latitude - widget.fence.lat).abs() < 1e-6 &&
          (c.longitude - widget.fence.lng).abs() < 1e-6) {
        return;
      }
      widget.onChanged(
        widget.fence.copyWith(lat: c.latitude, lng: c.longitude),
      );
    };
    unawaited(
      _map.easeTo(
        LatLng(widget.fence.lat, widget.fence.lng),
        16,
        reducedMotion: true,
      ),
    );
    _syncFence();
  }

  @override
  void didUpdateWidget(covariant LocationFenceMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fence.lat != widget.fence.lat ||
        oldWidget.fence.lng != widget.fence.lng ||
        oldWidget.fence.radiusMeters != widget.fence.radiusMeters) {
      _syncFence();
      if (!_editing &&
          (oldWidget.fence.lat != widget.fence.lat ||
              oldWidget.fence.lng != widget.fence.lng)) {
        unawaited(
          _map.easeTo(
            LatLng(widget.fence.lat, widget.fence.lng),
            _map.camera.zoom,
            reducedMotion: true,
          ),
        );
      }
    }
  }

  void _syncFence() {
    final center = LatLng(widget.fence.lat, widget.fence.lng);
    const dist = Distance();
    final radius = widget.fence.radiusMeters.toDouble();
    final ring = <LatLng>[
      for (var deg = 0; deg <= 360; deg += 15)
        dist.offset(center, radius, deg.toDouble()),
    ];
    unawaited(_map.setFocusArea(AreaShape([AreaPolygon(ring)])));
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelPanel(
          style: PixelBoxStyle.slot,
          padding: 1,
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: !_editing,
                  child: JdqMapCanvas(
                    map: _map,
                    style: _style,
                    fallback: const ColoredBox(color: PixelPalette.paperDim),
                    onFallback: () {},
                  ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: PixelPalette.white,
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
                          const PixelSprite(
                            MapMarkerArt.spotPin,
                            scale: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: PixelButton(
                    key: const ValueKey('fence_map_move_pin'),
                    label: _editing ? 'Done' : 'Move pin',
                    style: PixelBoxStyle.wood,
                    textColor: PixelPalette.white,
                    onPressed: () => setState(() => _editing = !_editing),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Perimeter Radius',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final step in [30, 50, 100, 200, 500])
                    PixelChip(
                      '$step m',
                      style: widget.fence.radiusMeters == step
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.slot,
                      textColor: widget.fence.radiusMeters == step
                          ? PixelPalette.ink
                          : PixelPalette.slate,
                      onTap: () => widget.onChanged(
                        widget.fence.copyWith(radiusMeters: step),
                      ),
                    ),
                ],
              ),
              PixelSlider(
                key: const ValueKey('fence_radius_slider'),
                value: (widget.fence.radiusMeters.clamp(30, 500) - 30) / 470,
                divisions: 47,
                semanticLabel: 'Check-in radius',
                onChanged: (fraction) => widget.onChanged(
                  widget.fence.copyWith(
                    radiusMeters: (30 + fraction * 470).round(),
                  ),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30 m',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Flexible(
                    child: Text('100 m (recommended)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ),
                  Text('500 m',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
