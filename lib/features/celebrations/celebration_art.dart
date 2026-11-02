// TEMPORARY until Clarissa's art
import '../../core/pixel/pixel_art.dart';

abstract final class CelebrationArt {
  /// Temporary 16x16 closed chest
  static const chestClosed = PixelArt('tempChestClosed', [
    '................',
    '................',
    '................',
    '..000000000000..',
    '.0mmmmmmmmmmmm0.',
    '.0mnnnnnnnnnnm0.',
    '.0mmmmmmmmmmmm0.',
    '0000000hh0000000',
    '0mmmmm0hh0mmmmm0',
    '0mmmmmm00mmmmmm0',
    '0mmmmmmmmmmmmmm0',
    '0mnnnnnnnnnnnnm0',
    '0mmmmmmmmmmmmmm0',
    '0llllllllllllll0',
    '0000000000000000',
    '................',
  ]);

  /// Temporary 16x16 open chest
  static const chestOpen = PixelArt('tempChestOpen', [
    '..000000000000..',
    '.0mmmmmmmmmmmm0.',
    '.0mnnnnnnnnnnm0.',
    '.00000000000000.',
    '................',
    '...h..h..h..h...',
    '..h6hh6hh6hh6h..',
    '0000000000000000',
    '0hhhhhhhhhhhhhh0',
    '0mmmmmm00mmmmmm0',
    '0mmmmmmmmmmmmmm0',
    '0mnnnnnnnnnnnnm0',
    '0mmmmmmmmmmmmmm0',
    '0llllllllllllll0',
    '0000000000000000',
    '................',
  ]);

  /// Temporary 8x8 coin
  static const smallCoin = PixelArt('tempSmallCoin', [
    '..0000..',
    '.0hhhff0',
    '0hh6hhf0',
    '0hh6hhf0',
    '0hhhhhf0',
    '0hhhhff0',
    '.0ffff0.',
    '..0000..',
  ]);
}
