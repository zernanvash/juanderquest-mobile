import '../../core/pixel/pixel_art.dart';

abstract final class PlazaArt {
  /// Team review v0.3.10 ("change the refresh icon"): two clockwise arrows,
  /// the common refresh/sync shape (the old ring read as a plain circle).
  static const refresh = PixelArt('plazaRefresh', [
    '................',
    '.....000000.....',
    '....0gggggg0....',
    '...0gggggggg0...',
    '..0ggg0000gg000.',
    '..0gg0...0ggggg0',
    '..0g0.....0ggg0.',
    '.0ggg0.....0g0..',
    '0ggggg0...0gg0..',
    '.000gg0000ggg0..',
    '...0gggggggg0...',
    '....0gggggg0....',
    '.....000000.....',
    '................',
  ]);
}
