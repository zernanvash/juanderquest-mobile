import 'package:flutter/material.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/pixel/pixel_text_3d.dart';
import '../spots/explore/explore_art.dart';
import '../vote/pixel/wave3_art.dart';

/// Plan 101 prototypes (owner 2026-11-16): pixel-perfect menu icons, and
/// box-less 2.5D (beveled, extruded) text for titles and buttons. Pick in the
/// Pixel lab; nothing here changes the real Home yet.
class UiPrototypesSection extends StatefulWidget {
  const UiPrototypesSection({super.key});

  @override
  State<UiPrototypesSection> createState() => _UiPrototypesSectionState();
}

enum _MenuStyle { fill, compact, noBoxes }

class _UiPrototypesSectionState extends State<UiPrototypesSection> {
  _MenuStyle _menu = _MenuStyle.noBoxes;
  String _tapped = 'TAP A BUTTON';

  static final _items = <(String, PixelArt)>[
    ('QUESTS', DesignerArt.questMarker),
    ('MERCHANTS', DesignerArt.salakot),
    ('VOTE', DesignerArt.juanChoice),
    ('PLAZA', DesignerArt.plazaTrophy),
    ('QUIZZES', DesignerArt.questionMark),
    ('+ SPOT', DesignerArt.spotMarker),
    ('SAVED', ExploreArt.bookmarkSaved),
    ('HISTORY', Wave3Art.list),
  ];

  void _tap(String label) => setState(() => _tapped = 'TAPPED $label');

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _note(context, '1 · TITLES IN 2.5D'),
        SizedBox(height: grid.px(1)),
        _dark(
          grid,
          const Column(
            children: [
              PixelText3D('YOUR JOURNEY', size: 22),
              PixelText3D('MAIN MENU', size: 18, colors: PixelText3DColors.cream),
              PixelText3D('DAILY TASKS', size: 16, colors: PixelText3DColors.green),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        _note(context, '2 · MAIN MENU: PICK ONE'),
        SizedBox(height: grid.px(1)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final (style, label) in const [
              (_MenuStyle.fill, 'A FILL BOXES'),
              (_MenuStyle.compact, 'B SMALL BOXES'),
              (_MenuStyle.noBoxes, 'C NO BOXES 2.5D'),
            ])
              PixelChip(
                label,
                key: ValueKey('proto_menu_${style.name}'),
                style: _menu == style ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                onTap: () => setState(() => _menu = style),
              ),
          ],
        ),
        SizedBox(height: grid.px(1)),
        Text(_menuHint(), style: PixelType.small(context, color: PixelPalette.slate)),
        SizedBox(height: grid.px(2)),
        switch (_menu) {
          _MenuStyle.fill => _boxedMenu(context, grid, compact: false),
          _MenuStyle.compact => _boxedMenu(context, grid, compact: true),
          _MenuStyle.noBoxes => _dark(grid, _boxlessMenu(context, grid)),
        },
        SizedBox(height: grid.px(3)),
        _note(context, '3 · BUTTONS AS 2.5D TEXT (NO BOX)'),
        SizedBox(height: grid.px(1)),
        _dark(
          grid,
          Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: grid.px(4),
                runSpacing: grid.px(2),
                children: [
                  PixelText3DButton('EXPLORE', onPressed: () => _tap('EXPLORE')),
                  PixelText3DButton('CLAIM +5',
                      colors: PixelText3DColors.green, onPressed: () => _tap('CLAIM')),
                  PixelText3DButton('VIEW QUEST',
                      colors: PixelText3DColors.cream, onPressed: () => _tap('VIEW QUEST')),
                  PixelText3DButton('LEAVE',
                      colors: PixelText3DColors.red, onPressed: () => _tap('LEAVE')),
                  const PixelText3DButton('LOCKED', onPressed: null),
                ],
              ),
              SizedBox(height: grid.px(2)),
              Text(_tapped, style: PixelType.small(context, color: PixelPalette.mist)),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        _note(context, '4 · SAME TEXT ON A LIGHT PAGE'),
        SizedBox(height: grid.px(1)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: grid.px(4),
            runSpacing: grid.px(2),
            children: [
              PixelText3DButton('EXPLORE', onPressed: () => _tap('EXPLORE')),
              PixelText3DButton('VIEW QUEST',
                  colors: PixelText3DColors.green, onPressed: () => _tap('VIEW QUEST')),
            ],
          ),
        ),
      ],
    );
  }

  String _menuHint() => switch (_menu) {
        _MenuStyle.fill =>
          'Boxes stay; every icon is enlarged to fill its box at a whole pixel scale.',
        _MenuStyle.compact =>
          'Every icon uses the same pixel size; the boxes shrink to fit them.',
        _MenuStyle.noBoxes =>
          'No boxes: big icon over a 2.5D label. Press sinks the label.',
      };

  Widget _note(BuildContext context, String text) => Text(
        text,
        style: PixelType.body(context, color: PixelPalette.woodDeep)
            .copyWith(fontWeight: FontWeight.w700),
      );

  Widget _dark(PixelGrid grid, Widget child) => PixelPanel(
        style: PixelBoxStyle.inkDialogue,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: grid.px(1)),
          child: Center(child: child),
        ),
      );

  Widget _rows(PixelGrid grid, List<Widget> cells) {
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

  Widget _boxedMenu(BuildContext context, PixelGrid grid, {required bool compact}) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // B: one scale for all icons, the largest that fits every icon in 24 dp.
    final uniform = _items
        .map((e) => PixelIconFit.fitScale(e.$2, 24, dpr))
        .reduce((a, b) => a < b ? a : b);
    return _rows(grid, [
      for (final (label, art) in _items)
        PixelPanel(
          key: ValueKey('proto_tile_$label'),
          style: PixelBoxStyle.parchment,
          padding: compact ? 1 : 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              compact
                  ? PixelIconFit(art, box: 24, scale: uniform)
                  : PixelIconFit(art, box: 36),
              SizedBox(height: grid.px(1)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1,
                    style: PixelType.small(context).copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _boxlessMenu(BuildContext context, PixelGrid grid) => _rows(grid, [
        for (final (label, art) in _items)
          PixelText3DButton(
            label,
            key: ValueKey('proto_boxless_$label'),
            icon: art,
            size: 12,
            colors: PixelText3DColors.cream,
            onPressed: () => _tap(label),
          ),
      ]);
}
