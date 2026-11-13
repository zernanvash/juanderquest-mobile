import 'package:flutter/widgets.dart';

import '../../../core/pixel/pixel_art.dart';

/// Crisp 8x8 pixel icons for navigation UI (WP-1..WP-5).
abstract final class NavPixelArt {
  static const lock = PixelArt('nav_lock', [
    '..0000..',
    '.0....0.',
    '.0....0.',
    '00000000',
    '0hhhhhh0',
    '0hh00hh0',
    '0hhhhhh0',
    '00000000',
  ]);

  static const clock = PixelArt('nav_clock', [
    '..0000..',
    '.055550.',
    '05505550',
    '05505550',
    '05500050',
    '05555550',
    '.055550.',
    '..0000..',
  ]);

  static const pinRed = PixelArt('nav_pin_red', [
    '..0000..',
    '.0ssss0.',
    '0ss55ss0',
    '0ss55ss0',
    '.0ssss0.',
    '..0ss0..',
    '...00...',
    '...00...',
  ]);

  static const flagGold = PixelArt('nav_flag_gold', [
    '.00000..',
    '.0hhhh0.',
    '.0hhhhh0',
    '.0hhhh0.',
    '.00000..',
    '.0......',
    '.0......',
    '000.....',
  ]);

  static const coin = PixelArt('nav_coin', [
    '..0000..',
    '.0hhhh0.',
    '0hhiiih0',
    '0hi00ih0',
    '0hi00ih0',
    '0hhiiih0',
    '.0hhhh0.',
    '..0000..',
  ]);

  static const modeCar = PixelArt('nav_mode_car', [
    '........',
    '..0000..',
    '.055550.',
    '00000000',
    '0s0000s0',
    '00000000',
    '.00..00.',
    '........',
  ]);

  static const modeMoto = PixelArt('nav_mode_moto', [
    '........',
    '....000.',
    '..00050.',
    '.00000..',
    '00.00.00',
    '000..000',
    '.0....0.',
    '........',
  ]);

  static const modeBike = PixelArt('nav_mode_bike', [
    '........',
    '..00.00.',
    '...000..',
    '..0.0.0.',
    '000...00',
    '050...05',
    '000...00',
    '........',
  ]);

  static const modeWalk = PixelArt('nav_mode_walk', [
    '...00...',
    '...00...',
    '..0000..',
    '.0.00.0.',
    '...00...',
    '..0..0..',
    '.0....0.',
    '.0....0.',
  ]);

  static const arrowRightSmall = PixelArt('nav_arrow_right_small', [
    '....0...',
    '....00..',
    '00000h0.',
    '0hhhhhh0',
    '00000h0.',
    '....00..',
    '....0...',
    '........',
  ]);

  static const questionTile = PixelArt('nav_question_tile', [
    '..0000..',
    '.0hhhh0.',
    '0hh00hh0',
    '...0hh0.',
    '..0hh0..',
    '..000...',
    '..0hh0..',
    '..000...',
  ]);
}

/// Renders a [PixelArt] grid at a fixed logical size [size] dp with nearest-neighbour filtering.
class NavPixelIcon extends StatelessWidget {
  final PixelArt art;
  final double size;

  const NavPixelIcon(this.art, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: PixelSprite(art, scale: 2),
      ),
    );
  }
}
