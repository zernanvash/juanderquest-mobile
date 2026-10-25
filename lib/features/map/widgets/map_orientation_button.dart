import 'dart:math' as math;

import 'package:flutter/material.dart';

const double _orientationToleranceDegrees = 0.5;

bool mapNeedsOrientationReset(double bearing, double tilt) {
  final normalizedBearing = (bearing % 360 + 360) % 360;
  final distanceFromNorth = math.min(normalizedBearing, 360 - normalizedBearing);
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

    return FloatingActionButton.small(
      heroTag: 'reset_map_orientation',
      tooltip: 'Reset map north and tilt',
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2D6A4F),
      onPressed: onPressed,
      child: Transform.rotate(
        angle: -bearing * math.pi / 180,
        child: const Icon(Icons.navigation, size: 18),
      ),
    );
  }
}
