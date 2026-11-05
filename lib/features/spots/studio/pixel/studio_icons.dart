import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/placeholder_art.dart';
import '../../explore/explore_art.dart';

/// Pixel icons used by the Spot Discovery Studio and its map pin card.
abstract final class StudioIcons {
  static const camera = PixelArt('studioCamera', [
    '................',
    '...0000000000...',
    '..0hhhhhhhhhh0..',
    '.0h0000000000h0.',
    '.0h0hhhhhhhh0h0.',
    '.0h0h0eeee0h0h0.',
    '.0h0h0eeee0h0h0.',
    '.0h0hhhhhhhh0h0.',
    '.0h0000000000h0.',
    '..0hhhhhhhhhh0..',
    '...0000000000...',
    '................',
  ]);

  static const gallery = PixelArt('studioGallery', [
    '................',
    '..000000000000..',
    '..0hhhhhhhhhh0..',
    '..0h00000000h0..',
    '..0h00hh0000h0..',
    '..0h0h99h000h0..',
    '..0h000h9000h0..',
    '..0h00hhh900h0..',
    '..0h00000000h0..',
    '..0hhhhhhhhhh0..',
    '..000000000000..',
    '................',
  ]);

  static const video = PixelArt('studioVideo', [
    '................',
    '..0000000000....',
    '..0hhhhhhhh000..',
    '..0h0000000h00..',
    '..0h0eeee00h00..',
    '..0h0eeee00h00..',
    '..0h0000000h00..',
    '..0hhhhhhhh0000.',
    '..0000000000.000',
    '.............0..',
    '................',
  ]);

  static const close = PixelArt('studioClose', [
    '00...00',
    '000.000',
    '.00000.',
    '..000..',
    '.00000.',
    '000.000',
    '00...00',
  ]);

  static const pin = PixelArt('studioPin', [
    '...000...',
    '..0hhh0..',
    '.0hhhhh0.',
    '.0hhehh0.',
    '.0hhehh0.',
    '.0hhhhh0.',
    '..0hhh0..',
    '..0hhh0..',
    '..0hhh0..',
    '...0h0...',
    '...0h0...',
    '....0....',
    '....0....',
  ]);

  static const edit = PixelArt('studioEdit', [
    '....000',
    '...0hh0',
    '..0hh0.',
    '.0hh0..',
    '0hh0...',
    '000....',
    '0......',
  ]);

  static PixelArt forCategory(String id) => switch (id) {
        'eat_drink' => ExploreArt.foodStrip,
        'nature_outdoors' => ExploreArt.natureStrip,
        'culture_heritage' => ExploreArt.heritageStrip,
        'activities_wellness' => ExploreArt.activitiesStrip,
        'shopping_local' => DesignerArt.navShop,
        'stay' => PlaceholderArt.home,
        _ => ExploreArt.natureStrip,
      };
}
