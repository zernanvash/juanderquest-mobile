import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../../merchant/suki/suki_badge_art.dart';

/// Plan 111 §6: Suki Card visual skin tokens.
/// Ships with the temporary [jdqClassic] pixel theme (built from brand palette tokens).
class SukiCardSkin {
  const SukiCardSkin({
    required this.key,
    required this.frontTop,
    required this.frontBottom,
    required this.backTop,
    required this.backBottom,
    required this.borderColor,
    required this.accentColor,
    required this.headerTextColor,
    required this.bodyTextColor,
    required this.mutedTextColor,
    required this.slotEmptyFill,
    required this.slotFilledFill,
    required this.milestoneFill,
  });

  final String key;
  final Color frontTop;
  final Color frontBottom;
  final Color backTop;
  final Color backBottom;
  final Color borderColor;
  final Color accentColor;
  final Color headerTextColor;
  final Color bodyTextColor;
  final Color mutedTextColor;
  final Color slotEmptyFill;
  final Color slotFilledFill;
  final Color milestoneFill;

  static const jdqClassic = SukiCardSkin(
    key: 'jdq_classic',
    frontTop: PixelPalette.greenDeep,
    frontBottom: PixelPalette.greenDark,
    backTop: PixelPalette.woodNight,
    backBottom: PixelPalette.woodDeep,
    borderColor: PixelPalette.sun,
    accentColor: PixelPalette.sun,
    headerTextColor: PixelPalette.cream,
    bodyTextColor: PixelPalette.paper,
    mutedTextColor: PixelPalette.greenLight,
    slotEmptyFill: PixelPalette.green,
    slotFilledFill: PixelPalette.sunLight,
    milestoneFill: PixelPalette.sun,
  );

  static SukiCardSkin byKey(String? key) => switch (key) {
        'jdq_classic' => jdqClassic,
        _ => jdqClassic,
      };
}

/// 8x8 pixel reward category icons using only [PixelPalette.byKey] entries.
abstract final class SukiTierArt {
  static const coffee = PixelArt('sukiTierCoffee', [
    '..1..1..',
    '.000000.',
    '06666660',
    '0lmmmm00',
    '0lmmmm0.',
    '0llll0..',
    '.0000...',
    '........',
  ]);

  static const drink = PixelArt('sukiTierDrink', [
    '....g...',
    '...g....',
    '.00000..',
    '.0EEEE0.',
    '.0BBBB0.',
    '.0BBBB0.',
    '.000000.',
    '........',
  ]);

  static const snack = PixelArt('sukiTierSnack', [
    '..0000..',
    '.0hhhh0.',
    '0hghhgh0',
    '0hhghhh0',
    '.000000.',
    '........',
    '........',
    '........',
  ]);

  static const meal = PixelArt('sukiTierMeal', [
    '.000000.',
    '0jjjjjj0',
    '05555550',
    '.000000.',
    '..0550..',
    '.055550.',
    '........',
    '........',
  ]);

  static const dessert = PixelArt('sukiTierDessert', [
    '...rr...',
    '..0660..',
    '.06hh60.',
    '.0pppp0.',
    '.0mmmm0.',
    '..0000..',
    '........',
    '........',
  ]);

  static const discount = PixelArt('sukiTierDiscount', [
    '..0000..',
    '.0hhhh0.',
    '0h6hh0h0',
    '0hhh0hh0',
    '0hh0hhh0',
    '0h0hh6h0',
    '.0hhhh0.',
    '..0000..',
  ]);

  static PixelArt byKey(String iconKey) => switch (iconKey) {
        'coffee' => coffee,
        'drink' => drink,
        'snack' => snack,
        'meal' => meal,
        'dessert' => dessert,
        'discount' => discount,
        'promo' => HomePixelArt.stampCheck,
        _ => SukiBadgeArt.gift,
      };
}
