import '../../../core/pixel/pixel_art.dart';

abstract final class ManeuverArrowArt {
  static const straight = PixelArt('nav_arrow_straight', [
    '....DD....',
    '...DYYD...',
    '..DYYYYD..',
    '.DYYYYYYD.',
    '..DDYYDD..',
    '....YY....',
    '....YY....',
    '....YY....',
    '....YY....',
    '....DD....',
  ]);

  static const right = PixelArt('nav_arrow_right', [
    '.......D..',
    '......DYD.',
    '....DDYYYD',
    '..DDYYYYYD',
    '.DYYDDYYYD',
    '.DYYD.DYD.',
    '.DYYD..D..',
    '.DYYD.....',
    '.DYYD.....',
    '..DD......',
  ]);

  static const left = PixelArt('nav_arrow_left', [
    '..D.......',
    '.DYD......',
    'DYYYDD....',
    'DYYYYYDD..',
    'DYYDDYYD..',
    '.DYD.DYYD.',
    '..D..DYYD.',
    '.....DYYD.',
    '.....DYYD.',
    '......DD..',
  ]);

  static const slightRight = PixelArt('nav_arrow_slight_right', [
    '.....DDDD.',
    '....DYYYYD',
    '....DYYD..',
    '...DYYD...',
    '...DYYD...',
    '..DYYD....',
    '..DYYD....',
    '.DYYD.....',
    '.DYYD.....',
    '..DD......',
  ]);

  static const slightLeft = PixelArt('nav_arrow_slight_left', [
    '.DDDD.....',
    'DYYYYD....',
    '..DYYD....',
    '...DYYD...',
    '...DYYD...',
    '....DYYD..',
    '....DYYD..',
    '.....DYYD.',
    '.....DYYD.',
    '......DD..',
  ]);

  static const uTurn = PixelArt('nav_arrow_u_turn', [
    '..DDDD....',
    '.DYYYYD...',
    'DYYDDYYD..',
    'DYYD.DYYD.',
    'DYYD.DYD..',
    'DYYDDYYD..',
    'DYYYYYYD..',
    '.DYYYYD...',
    '..DYYD....',
    '...DD.....',
  ]);

  static const arrive = PixelArt('nav_arrow_arrive', [
    '.DDDDD....',
    '.DYYYD....',
    '.DYYYYD...',
    '.DYYYD....',
    '.DDDDD....',
    '.D........',
    '.D........',
    '.D........',
    'DDDD......',
    'DDDD......',
  ]);

  static PixelArt fromInstruction(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('arrive') || lower.contains('destination')) {
      return arrive;
    }
    if (lower.contains('u-turn') || lower.contains('uturn')) {
      return uTurn;
    }
    if (lower.contains('bear right') ||
        lower.contains('slight right') ||
        lower.contains('keep right')) {
      return slightRight;
    }
    if (lower.contains('bear left') ||
        lower.contains('slight left') ||
        lower.contains('keep left')) {
      return slightLeft;
    }
    if (lower.contains('right')) {
      return right;
    }
    if (lower.contains('left')) {
      return left;
    }
    return straight;
  }
}
