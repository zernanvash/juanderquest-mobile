import '../../../core/pixel/pixel_art.dart';

/// Hand-crafted pixel emblems and ballot seal for JuanChoice category themes.
/// Keys map to [PixelPalette.byKey]; `.` is transparent.
abstract final class JuanChoicePixelArt {
  /// 16x16 Coastal & Islands emblem: sun over ocean waves.
  static const waveEmblem = PixelArt('jcWaveEmblem', [
    '......0000......',
    '....00hhhh00....',
    '...0hhhhhhhh0...',
    '..0hh66hhhhhh0..',
    '..0hhhhhhhhhh0..',
    '..00ffffffff00..',
    '....00000000....',
    '..00EEEEEEEE00..',
    '.0CCBBBBBBBBCC0.',
    '0BB66BBCCBB66BB0',
    '0BBBBBBBBBBBBBB0',
    '0AAzzzzAAzzzzAA0',
    '0zzzzzzzzzzzzzz0',
    '.00zz000000zz00.',
    '................',
    '................',
  ]);

  /// 16x16 Nature & Eco emblem: mountain peak and leaf.
  static const leafEmblem = PixelArt('jcLeafEmblem', [
    '.......00.......',
    '......0cc0......',
    '.....0caac0.....',
    '....0ca6aac0....',
    '...0caaa9aac0...',
    '..0caaa999aac0..',
    '..0aa999998aa0..',
    '..099988888890..',
    '...0888777880...',
    '....00877800....',
    '......0770......',
    '..00..0770..00..',
    '.09a0.0770.0a90.',
    '.08800077000880.',
    '..000000000000..',
    '................',
  ]);

  /// 16x16 Culture & Heritage emblem: colonial bell arch.
  static const heritageEmblem = PixelArt('jcHeritageEmblem', [
    '......0000......',
    '.....0hhhh0.....',
    '....0h66hhh0....',
    '...0000000000...',
    '..0nnnmmmmmmn0..',
    '.0nn00000000nn0.',
    '.0n0jjhhhhjj0n0.',
    '.0n0jhhhhhhj0n0.',
    '.0n0jhh66hhj0n0.',
    '.0n0jhhhhhhj0n0.',
    '.0n00ffffff00n0.',
    '.0mm000hh000mm0.',
    '.0mm00000000mm0.',
    '0llllmmmmmmllll0',
    '0000000000000000',
    '................',
  ]);

  /// 16x16 Culinary & Local Eats emblem: golden bangus / harvest bowl.
  static const culinaryEmblem = PixelArt('jcCulinaryEmblem', [
    '................',
    '.....000000.....',
    '...00jjhhjj00...',
    '..0j66hhhhhhf0..',
    '.0jhhhhhhhhhff0.',
    '00hhhh06hhhff0h0',
    '0hhhhhhffhhh0hh0',
    '0ffhhhhhhhhff0f0',
    '.0ffffffffffff0.',
    '..00dddddddd00..',
    '...0mmmmmmmm0...',
    '..0jjjjjjjjjj0..',
    '..0pppppppppp0..',
    '...0000000000...',
    '................',
    '................',
  ]);

  /// 16x16 Adventure & Wellness emblem: compass rose.
  static const compassEmblem = PixelArt('jcCompassEmblem', [
    '.......00.......',
    '......0hh0......',
    '.....0h66h0.....',
    '....0hhffhh0....',
    '..00000ff00000..',
    '.0jjj00ff00sss0.',
    '.0j6j0ffff0s6s0.',
    '0jjff66hh66ssrr0',
    '0jjff66hh66ssrr0',
    '.0jff0ffff0srr0.',
    '.0jjj00rr00rrr0.',
    '..00000rr00000..',
    '....0ssrrss0....',
    '.....0ssss0.....',
    '......0ss0......',
    '.......00.......',
  ]);

  /// 12x12 Wax stamp checkmark seal for the traveler's chosen candidate.
  static const stampSeal = PixelArt('jcStampSeal', [
    '...000000...',
    '..0hhhhhh0..',
    '.0hh6666hh0.',
    '0hh666666hh0',
    '0hh66666hhf0',
    '0hf6666hhff0',
    '0hhf66hhfff0',
    '0hhhfhhffff0',
    '0hhhhhfffff0',
    '.0ffffffff0.',
    '..0ffffff0..',
    '...000000...',
  ]);
}
