import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../pixel/map_marker_art.dart';
import '../pixel/pixel_scope_fallback.dart';

const double _orientationToleranceDegrees = 0.5;

bool mapNeedsOrientationReset(double bearing, double tilt) {
  final normalizedBearing = (bearing % 360 + 360) % 360;
  final distanceFromNorth =
      math.min(normalizedBearing, 360 - normalizedBearing);
  return distanceFromNorth > _orientationToleranceDegrees ||
      tilt.abs() > _orientationToleranceDegrees;
}

/// Explicit north-and-level control for correcting a rotated or tilted map.
class MapOrientationButton extends StatelessWidget {
  const MapOrientationButton({
    super.key,
    required this.bearing,
    required this.tilt,
    required this.onPressed,
  });

  final double bearing;
  final double tilt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!mapNeedsOrientationReset(bearing, tilt)) {
      return const SizedBox.shrink();
    }

    return PixelScopeFallback(
      child: Builder(
        builder: (ctx) => Tooltip(
          message: 'Reset map north and tilt',
          child: Semantics(
            button: true,
            label: 'Reset map north and tilt',
            child: GestureDetector(
              onTap: () {
                pixelTick(ctx);
                onPressed();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  padding: 2,
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Transform.rotate(
                      angle: -bearing * math.pi / 180,
                      child: const PixelSprite(MapMarkerArt.iconCompass, scale: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
