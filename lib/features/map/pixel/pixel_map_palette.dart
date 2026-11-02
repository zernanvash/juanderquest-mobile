import 'dart:ui';

import '../../../core/pixel/generated/pixel_palette.g.dart';

/// Single palette color definition for the pixel map shader.
class PixelMapPaletteColor {
  const PixelMapPaletteColor({
    required this.name,
    required this.color,
    required this.r,
    required this.g,
    required this.b,
  });

  final String name;
  final Color color;
  final double r;
  final double g;
  final double b;
}

/// The 19 JuanderQuest brand-palette colours used by `shaders/pixel_map.frag`.
///
/// Guaranteed to match [PixelPalette] constants — verified by unit tests so no
/// unapproved colours can sneak in.
abstract final class PixelMapPalette {
  static const colors = <PixelMapPaletteColor>[
    // Land and urban
    PixelMapPaletteColor(name: 'paper', color: PixelPalette.paper, r: 0.980, g: 0.976, b: 0.961),
    PixelMapPaletteColor(name: 'paperDim', color: PixelPalette.paperDim, r: 0.890, g: 0.886, b: 0.875),
    PixelMapPaletteColor(name: 'cream', color: PixelPalette.cream, r: 1.000, g: 0.973, b: 0.882),
    PixelMapPaletteColor(name: 'parchment', color: PixelPalette.parchment, r: 0.969, g: 0.922, b: 0.882),
    PixelMapPaletteColor(name: 'mist', color: PixelPalette.mist, r: 0.757, g: 0.784, b: 0.761),
    PixelMapPaletteColor(name: 'stone', color: PixelPalette.stone, r: 0.443, g: 0.475, b: 0.451),
    // Roads and labels
    PixelMapPaletteColor(name: 'white', color: PixelPalette.white, r: 1.000, g: 1.000, b: 1.000),
    PixelMapPaletteColor(name: 'slate', color: PixelPalette.slate, r: 0.255, g: 0.282, b: 0.267),
    PixelMapPaletteColor(name: 'ink', color: PixelPalette.ink, r: 0.051, g: 0.106, b: 0.165),
    // Water
    PixelMapPaletteColor(name: 'sky', color: PixelPalette.sky, r: 0.878, g: 0.949, b: 0.996),
    PixelMapPaletteColor(name: 'blueLight', color: PixelPalette.blueLight, r: 0.859, g: 0.918, b: 0.996),
    PixelMapPaletteColor(name: 'blue', color: PixelPalette.blue, r: 0.106, g: 0.286, b: 0.396),
    // Parks and fields
    PixelMapPaletteColor(name: 'greenLight', color: PixelPalette.greenLight, r: 0.757, g: 0.925, b: 0.831),
    PixelMapPaletteColor(name: 'green', color: PixelPalette.green, r: 0.247, g: 0.400, b: 0.325),
    PixelMapPaletteColor(name: 'greenDark', color: PixelPalette.greenDark, r: 0.153, g: 0.306, b: 0.235),
    // Sand and beaches
    PixelMapPaletteColor(name: 'sunLight', color: PixelPalette.sunLight, r: 1.000, g: 0.871, b: 0.663),
    PixelMapPaletteColor(name: 'woodLight', color: PixelPalette.woodLight, r: 0.769, g: 0.612, b: 0.431),
    // Highlights
    PixelMapPaletteColor(name: 'sun', color: PixelPalette.sun, r: 1.000, g: 0.718, b: 0.012),
    PixelMapPaletteColor(name: 'orange', color: PixelPalette.orange, r: 0.902, g: 0.494, b: 0.133),
  ];
}
