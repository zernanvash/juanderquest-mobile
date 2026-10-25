import 'package:flutter/material.dart';

/// Explicit north-and-level control that remains available if the native
/// renderer's transient compass control is hidden or obscured.
class MapOrientationButton extends StatelessWidget {
  const MapOrientationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
        heroTag: 'reset_map_orientation',
        tooltip: 'Reset map north and tilt',
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D6A4F),
        onPressed: onPressed,
        child: const Icon(Icons.explore, size: 18),
      );
}
