import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';

/// v0.3.1 dark mode (owner 2026-11-18: "use the concept in pixel lab 0.3,
/// but the current brown background should just be plain dark brown").
/// Light pages turn plain dark brown; panels keep their own colours; page
/// lettering turns from gold to cream. [PixelSurface] tells widgets below
/// whether they sit on a dark page or on a light panel.
class PixelSurface extends InheritedWidget {
  const PixelSurface({super.key, required this.dark, required super.child});

  final bool dark;

  /// The plain dark brown of a dark-mode page.
  static const darkPage = PixelPalette.wood;

  static bool isDark(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PixelSurface>()?.dark ?? false;

  /// Owner 2026-11-18 (v0.3.3): dark mode is off until it is redone ("it
  /// dont look good, we have this fixed later"). The switch is gone from
  /// Settings and a saved "on" is ignored.
  static const available = false;

  /// True when the user turned dark mode on (and dark mode is available).
  static bool darkMode(BuildContext context) =>
      available && PixelScope.of(context).darkMode;

  @override
  bool updateShouldNotify(PixelSurface oldWidget) => oldWidget.dark != dark;
}
