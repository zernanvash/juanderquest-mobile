import '../../../core/pixel/pixel_art.dart';

/// Plan 107 §5 badges, drawn in the brand palette (no external assets).
/// Keys match `achievement_definitions.badge_icon`.
abstract final class SukiBadgeArt {
  /// `suki_card` (badge "Suki"): a loyalty card with filled visit slots.
  static const sukiCard = PixelArt('sukiCard', [
    '................',
    '................',
    '.llllllllllllll.',
    '.lmmmmmmmmmmmml.',
    '.lmjjjjjmmmmmml.',
    '.lmmmmmmmmmmmml.',
    '.lppppppppppppl.',
    '.lphhphhphhp33l.',
    '.lpeepeepeep33l.',
    '.lppppppppppppl.',
    '.lphhphhp33p33l.',
    '.lpeepeep33p33l.',
    '.lppppppppppppl.',
    '.llllllllllllll.',
    '................',
    '................',
  ]);

  /// `suki_regular` (badge "Barangay Regular"): a sari-sari store front.
  static const sukiRegular = PixelArt('sukiRegular', [
    '................',
    '................',
    '.llllllllllllll.',
    '.s66ss66ss66ss6.',
    '.s66ss66ss66ss6.',
    '..s..6..s..6....',
    '..nnnnnnnnnnnn..',
    '..nEEEEnnmmmmn..',
    '..nECCEnnmmmmn..',
    '..nEEEEnnmmhmn..',
    '..nnnnnnnmmmmn..',
    '..nnnnnnnmmmmn..',
    '.llllllllllllll.',
    '................',
    '................',
    '................',
  ]);

  /// `suki_towns` (badge "Suki ng Bayan"): three town pins on a trail.
  static const sukiTowns = PixelArt('sukiTowns', [
    '................',
    '.......aa.......',
    '......a66a......',
    '......aaaa......',
    '..ss...aa.......',
    '.s66s..aa...AA..',
    '.ssss...a..A66A.',
    '..ss.......AAAA.',
    '..ss........AA..',
    '...s........AA..',
    '.............A..',
    '........o.......',
    '..o....o..o..o..',
    '...o.o......o...',
    '................',
    '................',
  ]);

  /// A small gift for the card's reward slot and scan results.
  static const gift = PixelArt('sukiGift', [
    '..h..h..',
    '...hh...',
    'sssshsss',
    'sssshsss',
    '.ssshss.',
    '.ssshss.',
    '.ssshss.',
    '.ssshss.',
  ]);

  /// Badge icon key or achievement id -> art.
  static const byKey = <String, PixelArt>{
    'suki_card': sukiCard,
    'suki_regular': sukiRegular,
    'suki_towns': sukiTowns,
    'suki_first_card': sukiCard,
    'suki_three_shops': sukiRegular,
    'suki_three_towns': sukiTowns,
  };
}
