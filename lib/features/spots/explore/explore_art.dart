import '../../../core/pixel/pixel_art.dart';

/// Pixel art assets for the explore feed.
/// All colors mapped to PixelPalette.byKey.
abstract final class ExploreArt {
  /// 7x7 small map pin for town chips (wood style)
  static const pin = PixelArt('explorePin', [
    '..lll..',
    '.lmmml.',
    'lm000ml',
    'lmm0mml',
    '.lmmml.',
    '..lml..',
    '...l...',
  ]);

  /// 7x7 small report flag for feed card headers
  static const flag = PixelArt('exploreFlag', [
    '.ssss..',
    '.rssr..',
    '.ssss..',
    '.0.....',
    '.0.....',
    '.0.....',
    '000....',
  ]);

  /// 7x8 bookmark (saved / filled) in sun gold
  static const bookmarkSaved = PixelArt('bookmarkSaved', [
    'hhhhhhh',
    'hhhhhhh',
    'hhhhhhh',
    'hhhhhhh',
    'hhhhhhh',
    'hhhhhhh',
    'hh.h.hh',
    'h...h.h',
  ]);

  /// 7x8 bookmark (unsaved / outline) in slate/mist
  static const bookmarkUnsaved = PixelArt('bookmarkUnsaved', [
    '1111111',
    '1.....1',
    '1.....1',
    '1.....1',
    '1.....1',
    '1.....1',
    '11.1.11',
    '1...1.1',
  ]);

  /// 16x8 Nature/Coast placeholder strip
  static const natureStrip = PixelArt('stripNature', [
    '................',
    '....88......99..',
    '...8aa8....9bb9.',
    '..8aaaa8..9bbbb9',
    'AA.8aa8.AA9bbbb9',
    'AAAA..AAAAAAAAAA',
    'EEEEEEEEEEEEEEEE',
    'EEEEEEEEEEEEEEEE',
  ]);

  /// 16x8 Heritage/Church placeholder strip
  static const heritageStrip = PixelArt('stripHeritage', [
    '.......ll.......',
    '......lmml......',
    '.....lmmmml.....',
    '.....l.mm.l.....',
    '....llmmmmll....',
    '....l00mm00l....',
    '...ll00mm00ll...',
    '..llllllllllll..',
  ]);

  /// 16x8 Food/Culinary placeholder strip
  static const foodStrip = PixelArt('stripFood', [
    '.....ee..ee.....',
    '....ehheehhe....',
    '....ehheehhe....',
    '...dehhhhhhed...',
    '..deeeeeeeeeed..',
    '..dddddddddddd..',
    '...dddddddddd...',
    '.....dddddd.....',
  ]);

  /// 16x8 Activities/Adventure placeholder strip
  static const activitiesStrip = PixelArt('stripActivities', [
    '....ss..........',
    '...rssr.........',
    '....ss..........',
    '....0...........',
    '...000..77......',
    '..00.00.7aa7....',
    '.00...007aaaa7..',
    '7777777777777777',
  ]);

  /// 16x8 Wellness/Spa placeholder strip
  static const wellnessStrip = PixelArt('stripWellness', [
    '.......hh.......',
    '.....hhiihh.....',
    '...hhiiiiihh....',
    '...hhiiiiihh....',
    '.....hhiihh.....',
    '.......hh.......',
    '..99.......99...',
    '.9aa9.....9aa9..',
  ]);

  /// Resolves the category illustration sprite from a category name.
  static PixelArt categoryStrip(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('histor') ||
        cat.contains('church') ||
        cat.contains('heritage') ||
        cat.contains('cultur')) {
      return heritageStrip;
    }
    if (cat.contains('food') ||
        cat.contains('eat') ||
        cat.contains('culinary') ||
        cat.contains('drink')) {
      return foodStrip;
    }
    if (cat.contains('activit') ||
        cat.contains('trail') ||
        cat.contains('adventure') ||
        cat.contains('sport')) {
      return activitiesStrip;
    }
    if (cat.contains('wellness') ||
        cat.contains('spa') ||
        cat.contains('relax') ||
        cat.contains('health')) {
      return wellnessStrip;
    }
    return natureStrip;
  }
}
