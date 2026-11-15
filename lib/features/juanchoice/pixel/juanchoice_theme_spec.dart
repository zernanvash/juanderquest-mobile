import 'dart:ui';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import 'juanchoice_pixel_art.dart';

enum JuanChoiceCategoryTheme {
  coastal,
  nature,
  heritage,
  culinary,
  adventure,
  spotlight,
}

class JuanChoiceThemeSpec {
  const JuanChoiceThemeSpec({
    required this.kind,
    required this.badgeLabel,
    required this.headerStyle,
    required this.ditherTop,
    required this.ditherBottom,
    required this.barColor,
    required this.leadBarColor,
    required this.headerTitleColor,
    required this.headerBodyColor,
    required this.emblem,
  });

  final JuanChoiceCategoryTheme kind;
  final String badgeLabel;
  final PixelBoxStyle headerStyle;
  final Color ditherTop;
  final Color ditherBottom;
  final Color barColor;
  final Color leadBarColor;
  final Color headerTitleColor;
  final Color headerBodyColor;
  final PixelArt emblem;

  static final _coastalRx = RegExp(
    r'\b(?:coast|coastal|beach|beaches|island|islands|sea|seas|cove|coves|water|waters|bay|bays|ocean|marine|shore|shores)\b',
  );
  static final _culinaryRx = RegExp(
    r'\b(?:food|foods|eat|eats|eating|culinary|bangus|taste|tastes|cafe|cafes|kitchen|delicacy|delicacies|market|markets|shop|shops|shopping)\b',
  );
  static final _natureRx = RegExp(
    r'\b(?:nature|natural|eco|trail|trails|park|parks|falls|waterfall|waterfalls|mountain|mountains|hill|hills|forest|forests|river|rivers|outdoor|outdoors)\b',
  );
  static final _heritageRx = RegExp(
    r'\b(?:culture|cultural|heritage|church|churches|historic|historical|history|museum|museums|town|towns|plaza|plazas|ancestral|pilgrim|pilgrimage)\b',
  );
  static final _adventureRx = RegExp(
    r'\b(?:adventure|adventures|activity|activities|wellness|sport|sports|camp|camping|stay|stays|resort|resorts|retreat|retreats)\b',
  );

  static const coastal = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.coastal,
    badgeLabel: 'COASTAL ROUND',
    headerStyle: PixelBoxStyle(
      fill: PixelPalette.blue,
      highlight: PixelPalette.blueMid,
      shade: PixelPalette.blueDeep,
    ),
    ditherTop: PixelPalette.sky,
    ditherBottom: PixelPalette.paper,
    barColor: PixelPalette.blueBright,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.white,
    headerBodyColor: PixelPalette.sky,
    emblem: JuanChoicePixelArt.waveEmblem,
  );

  static const nature = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.nature,
    badgeLabel: 'ECO & NATURE',
    headerStyle: PixelBoxStyle.green,
    ditherTop: PixelPalette.greenLight,
    ditherBottom: PixelPalette.paper,
    barColor: PixelPalette.greenBright,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.white,
    headerBodyColor: PixelPalette.greenLight,
    emblem: JuanChoicePixelArt.leafEmblem,
  );

  static const heritage = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.heritage,
    badgeLabel: 'HERITAGE ROUND',
    headerStyle: PixelBoxStyle.wood,
    ditherTop: PixelPalette.sunLight,
    ditherBottom: PixelPalette.parchment,
    barColor: PixelPalette.amber,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.paper,
    headerBodyColor: PixelPalette.cream,
    emblem: JuanChoicePixelArt.heritageEmblem,
  );

  static const culinary = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.culinary,
    badgeLabel: 'LOCAL FLAVORS',
    headerStyle: PixelBoxStyle(
      fill: PixelPalette.gold,
      highlight: PixelPalette.amber,
      shade: PixelPalette.goldDeep,
    ),
    ditherTop: PixelPalette.cream,
    ditherBottom: PixelPalette.parchment,
    barColor: PixelPalette.flame,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.white,
    headerBodyColor: PixelPalette.cream,
    emblem: JuanChoicePixelArt.culinaryEmblem,
  );

  static const adventure = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.adventure,
    badgeLabel: 'ACTIVE & STAY',
    headerStyle: PixelBoxStyle.red,
    ditherTop: PixelPalette.orangeLight,
    ditherBottom: PixelPalette.paper,
    barColor: PixelPalette.orange,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.white,
    headerBodyColor: PixelPalette.cream,
    emblem: JuanChoicePixelArt.compassEmblem,
  );

  static const spotlight = JuanChoiceThemeSpec(
    kind: JuanChoiceCategoryTheme.spotlight,
    badgeLabel: 'SPOTLIGHT VOTE',
    headerStyle: PixelBoxStyle(
      fill: PixelPalette.woodDeep,
      highlight: PixelPalette.wood,
      shade: PixelPalette.ink,
      outline: PixelPalette.sun,
    ),
    ditherTop: PixelPalette.cream,
    ditherBottom: PixelPalette.parchment,
    barColor: PixelPalette.greenBright,
    leadBarColor: PixelPalette.sun,
    headerTitleColor: PixelPalette.paper,
    headerBodyColor: PixelPalette.cream,
    emblem: DesignerArt.juanChoice,
  );

  static JuanChoiceThemeSpec fromTheme(String? theme) {
    final normalized = (theme ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return spotlight;
    if (_coastalRx.hasMatch(normalized)) return coastal;
    if (_culinaryRx.hasMatch(normalized)) return culinary;
    if (_natureRx.hasMatch(normalized)) return nature;
    if (_heritageRx.hasMatch(normalized)) return heritage;
    if (_adventureRx.hasMatch(normalized)) return adventure;
    return spotlight;
  }
}
