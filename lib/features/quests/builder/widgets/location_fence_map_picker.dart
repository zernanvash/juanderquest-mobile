import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/base_tile_layer.dart';
import '../../../map/pixel/map_marker_art.dart';
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
  // Locked by default so a page scroll that crosses the map never moves the pin.
  bool _editing = false;

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
        PixelPanel(
          style: PixelBoxStyle.slot,
          padding: 1,
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: !_editing,
                  child: FlutterMap(
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
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  trackShape: const _PixelSliderTrackShape(),
                  thumbShape: const _PixelSliderThumbShape(),
                  activeTrackColor: PixelPalette.green,
                  inactiveTrackColor: PixelPalette.stone,
                  overlayColor: Colors.transparent,
                  thumbColor: PixelPalette.gold,
                ),
                child: Slider(
                  value:
                      widget.fence.radiusMeters.toDouble().clamp(30.0, 500.0),
                  min: 30,
                  max: 500,
                  divisions: 47,
                  onChanged: (val) {
                    widget.onChanged(
                        widget.fence.copyWith(radiusMeters: val.round()));
                  },
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

class _PixelSliderTrackShape extends RectangularSliderTrackShape {
  const _PixelSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6.0;
    final trackLeft = offset.dx + 4;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 8;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class _PixelSliderThumbShape extends SliderComponentShape {
  static const double size = 14.0;
  const _PixelSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(size, size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    context.canvas.drawRect(rect, Paint()..color = PixelPalette.gold);
    context.canvas.drawRect(
      rect,
      Paint()
        ..color = PixelPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
