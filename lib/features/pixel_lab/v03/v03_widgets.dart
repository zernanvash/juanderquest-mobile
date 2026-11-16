import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../spots/explore/explore_art.dart';
import '../../vote/pixel/wave3_art.dart';

/// v0.3 UI preview building blocks (Plan 101). Preview only: not used by the
/// live screens until the owner approves the look.

/// Main menu styles to compare: A keep boxes and fill them, B one pixel size
/// with smaller boxes, C no boxes (icon over a 2.5D label).
enum ProtoMenuStyle { fill, compact, noBoxes }

class ProtoMenuItem {
  const ProtoMenuItem(this.label, this.art);
  final String label;
  final PixelArt art;
}

const protoMenuItems = <ProtoMenuItem>[
  ProtoMenuItem('QUESTS', DesignerArt.questMarker),
  ProtoMenuItem('MERCHANTS', DesignerArt.salakot),
  ProtoMenuItem('VOTE', DesignerArt.juanChoice),
  ProtoMenuItem('PLAZA', DesignerArt.plazaTrophy),
  ProtoMenuItem('QUIZZES', DesignerArt.questionMark),
  ProtoMenuItem('+ SPOT', DesignerArt.spotMarker),
  ProtoMenuItem('SAVED', ExploreArt.bookmarkSaved),
  ProtoMenuItem('HISTORY', Wave3Art.list),
];

class ProtoMainMenu extends StatelessWidget {
  const ProtoMainMenu({
    super.key,
    required this.style,
    required this.onTap,
    this.labelColors = PixelText3DColors.cream,
    this.look = PixelTextLook.extruded,
    this.font,
  });

  final PixelTextLook look;
  final String? font;
  final ProtoMenuStyle style;
  final ValueChanged<String> onTap;
  final PixelText3DColors labelColors;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final uniform = protoMenuItems
        .map((e) => PixelIconFit.fitScale(e.art, 24, dpr))
        .reduce((a, b) => a < b ? a : b);
    final cells = [
      for (final item in protoMenuItems)
        switch (style) {
          ProtoMenuStyle.noBoxes => PixelText3DButton(
              item.label,
              key: ValueKey('proto_boxless_${item.label}'),
              icon: item.art,
              iconBox: 40,
              size: 14,
              colors: labelColors,
              look: look,
              font: font,
              onPressed: () => onTap(item.label),
            ),
          _ => GestureDetector(
              key: ValueKey('proto_tile_${item.label}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(item.label),
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                padding: style == ProtoMenuStyle.compact ? 1 : 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    style == ProtoMenuStyle.compact
                        ? PixelIconFit(item.art, box: 24, scale: uniform)
                        : PixelIconFit(item.art, box: 36),
                    SizedBox(height: grid.px(1)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.label,
                          maxLines: 1,
                          style: PixelType.small(context)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
        },
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 4) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = i; c < i + 4; c++) ...[
            if (c > i) SizedBox(width: grid.px(2)),
            Expanded(child: c < cells.length ? cells[c] : const SizedBox()),
          ],
        ],
      ));
      if (i + 4 < cells.length) rows.add(SizedBox(height: grid.px(2)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// A thin pixel line instead of a box border, to separate sections.
class PixelRule extends StatelessWidget {
  const PixelRule({super.key, this.color = PixelPalette.woodLight});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(3)),
      child: Container(height: grid.unit, color: color),
    );
  }
}

/// A row of whole-pixel segments (XP, progress), no box.
class PixelSegmentBar extends StatelessWidget {
  const PixelSegmentBar({
    super.key,
    required this.value,
    this.segments = 12,
    this.fill = PixelPalette.sun,
    this.empty = PixelPalette.woodMid,
  });

  final double value;
  final int segments;
  final Color fill;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final filled = (value.clamp(0.0, 1.0) * segments).round();
    return Row(
      children: [
        for (var i = 0; i < segments; i++) ...[
          if (i > 0) SizedBox(width: grid.unit),
          Expanded(
            child: Container(
              height: grid.px(3),
              color: i < filled ? fill : empty,
            ),
          ),
        ],
      ],
    );
  }
}
