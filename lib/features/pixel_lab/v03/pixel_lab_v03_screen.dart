import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_theme.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../../spots/explore/explore_art.dart';
import 'v03_widgets.dart';

/// Plan 101 / v0.3.n (owner 2026-11-16: "create the UI prototype in pixel lab
/// first, new pixel labs look for the new UI ... if we agree with the look,
/// then we build 0.3.n"). A preview of the v0.3 look: no boxes, 2.5D titles
/// and buttons, pixel-perfect icons. Nothing here is wired to live data.
class PixelLabV03Screen extends StatefulWidget {
  const PixelLabV03Screen({super.key});

  @override
  State<PixelLabV03Screen> createState() => _PixelLabV03ScreenState();
}

class _PixelLabV03ScreenState extends State<PixelLabV03Screen> {
  bool _dark = false;
  ProtoMenuStyle _menu = ProtoMenuStyle.noBoxes;
  PixelTextLook _look = PixelTextLook.banded;
  String _font = PixelText3D.defaultFont;
  // Lettering colours follow the page: gold on the light page, cream on
  // dark wood (owner 2026-11-16: "dark mode and light mode toggle auto
  // selecting whats appropriate combo").
  PixelText3DColors get _colors =>
      _dark ? PixelText3DColors.cream : PixelText3DColors.gold;
  static const _lookNames = <PixelTextLook, String>{
    PixelTextLook.extruded: '2.5D',
    PixelTextLook.flat: 'FLAT OUTLINE',
    PixelTextLook.banded: 'BANDED',
    PixelTextLook.chunky: 'CHUNKY',
    PixelTextLook.shadow: 'DROP SHADOW',
  };
  int _tab = 0;
  final _done = <int>{0};
  String _last = 'NOTHING TAPPED YET';

  void _tap(String what) => setState(() => _last = 'TAPPED $what');

  Color get _ink => _dark ? PixelPalette.cream : PixelPalette.ink;
  Color get _muted => _dark ? PixelPalette.woodLight : PixelPalette.slate;
  Color get _rule => _dark ? PixelPalette.woodMid : PixelPalette.woodLight;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: _dark ? PixelPalette.woodNight : PixelPalette.paper,
          body: DitherBackground(
            top: _dark ? PixelPalette.wood : PixelPalette.paper,
            bottom: _dark ? PixelPalette.woodNight : PixelPalette.parchment,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _topBar(context, grid),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(grid.px(5), grid.px(2), grid.px(5), grid.px(6)),
                      children: [
                        _controls(context, grid),
                        PixelRule(color: _rule),
                        _homePreview(context, grid),
                        PixelRule(color: _rule),
                        _lookGallery(context, grid),
                        PixelRule(color: _rule),
                        _buttons(context, grid),
                        PixelRule(color: _rule),
                        _settingsRows(context, grid),
                        PixelRule(color: _rule),
                        _textKit(context, grid),
                        SizedBox(height: grid.px(3)),
                        Center(
                          child: Text(_last,
                              key: const ValueKey('v03_last'),
                              style: PixelType.small(context, color: _muted)),
                        ),
                      ],
                    ),
                  ),
                  _hotbar(context, grid),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _topBar(BuildContext context, PixelGrid grid) => Padding(
        padding: EdgeInsets.fromLTRB(grid.px(2), grid.px(2), grid.px(4), 0),
        child: Row(
          children: [
            _iconButton('BACK', Wave3ArtBack.art, () => Navigator.of(context).maybePop()),
            SizedBox(width: grid.px(1)),
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PixelText3D('PIXEL LAB 0.3', size: 18),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _iconButton(String label, PixelArt art, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: ValueKey('v03_icon_$label'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onTap();
          },
          child: SizedBox.square(
            dimension: 48,
            child: Center(child: PixelIconFit(art, box: 32)),
          ),
        ),
      );

  Widget _label(BuildContext context, String text) => Padding(
        padding: EdgeInsets.only(bottom: PixelGrid.of(context).px(2)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: PixelText3D(text, size: 14, colors: PixelText3DColors.green, textAlign: TextAlign.left),
        ),
      );

  Widget _controls(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW OF THE v0.3 LOOK: NO BOXES, 2.5D TEXT, SHARP ICONS. NOTHING HERE IS LIVE.',
            style: PixelType.small(context, color: _muted),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelChip('LIGHT PAGE',
                  key: const ValueKey('v03_light'),
                  style: _dark ? PixelBoxStyle.parchment : PixelBoxStyle.gold,
                  onTap: () => setState(() => _dark = false)),
              PixelChip('DARK WOOD',
                  key: const ValueKey('v03_dark'),
                  style: _dark ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                  onTap: () => setState(() => _dark = true)),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final (style, label) in const [
                (ProtoMenuStyle.fill, 'MENU A'),
                (ProtoMenuStyle.compact, 'MENU B'),
                (ProtoMenuStyle.noBoxes, 'MENU C'),
              ])
                PixelChip(label,
                    key: ValueKey('v03_menu_${style.name}'),
                    style: _menu == style ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                    onTap: () => setState(() => _menu = style)),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text('MENU C LETTERING', style: PixelType.small(context, color: _muted)),
          SizedBox(height: grid.px(1)),
          _chips(grid, 'look', [
            for (final l in PixelTextLook.values)
              (_lookNames[l]!, _look == l, () => setState(() => _look = l)),
          ]),
          SizedBox(height: grid.px(1)),
          _chips(grid, 'font', [
            for (final f in PixelFonts.families)
              (f.toUpperCase(), _font == f, () => setState(() => _font = f)),
          ]),

        ],
      );

  Widget _chips(PixelGrid grid, String group, List<(String, bool, VoidCallback)> items) => Wrap(
        spacing: grid.px(1),
        runSpacing: grid.px(1),
        children: [
          for (final (label, on, tap) in items)
            PixelChip(label,
                key: ValueKey('v03_${group}_$label'),
                style: on ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                onTap: tap),
        ],
      );

  /// Every look in every font, so they can be compared side by side.
  Widget _lookGallery(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'LETTERING GALLERY'),
          Text('EVERY LOOK IN EVERY FONT. TAP ONE TO USE IT ON THE MENU ABOVE.',
              style: PixelType.small(context, color: _muted)),
          SizedBox(height: grid.px(2)),
          for (final l in PixelTextLook.values) ...[
            Text(_lookNames[l]!, style: PixelType.small(context, color: _muted)),
            Wrap(
              spacing: grid.px(3),
              runSpacing: grid.px(1),
              children: [
                for (final f in PixelFonts.families)
                  GestureDetector(
                    key: ValueKey('v03_gallery_${l.name}_$f'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _look = l;
                      _font = f;
                      _menu = ProtoMenuStyle.noBoxes;
                    }),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PixelText3D('QUESTS', size: 16, look: l, font: f, colors: _colors),
                        // Marks the combination the menu uses.
                        Container(
                          width: grid.px(16),
                          height: grid.unit * 2,
                          color: _look == l && _font == f ? PixelPalette.greenMid : const Color(0x00000000),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: grid.px(2)),
          ],
        ],
      );

  Widget _homePreview(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'HOME'),
          // Header: title and three icon buttons, no boxes.
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: PixelText3D('YOUR JOURNEY', size: 18)),
                ),
              ),
              _iconButton('SEARCH', DesignerArt.search, () => _tap('SEARCH')),
              _iconButton('ALERTS', DesignerArt.notifBell, () => _tap('ALERTS')),
              _iconButton('SETTINGS', DesignerArt.navSettings, () => _tap('SETTINGS')),
            ],
          ),
          SizedBox(height: grid.px(2)),
          // Profile strip.
          Row(
            children: [
              const PixelIconFit(DesignerArt.navProfile, box: 40),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelText3D('KZO', size: 16, colors: PixelText3DColors.cream, textAlign: TextAlign.left),
                    Text('LEVEL 204 · 10150 XP', style: PixelType.small(context, color: _muted)),
                    SizedBox(height: grid.px(1)),
                    PixelSegmentBar(value: 0.35, empty: _rule),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
              MjdqAmount(10150, idleSpin: true, scale: 1.5, style: PixelType.title(context, color: _ink)),
            ],
          ),
          SizedBox(height: grid.px(4)),
          ProtoMainMenu(
            style: _menu,
            onTap: _tap,
            look: _look,
            font: _font,
            labelColors: _colors,
          ),
          SizedBox(height: grid.px(4)),
          // Mission: text plus a 2.5D action.
          Row(
            children: [
              const PixelIconFit(DesignerArt.questMarker, box: 32),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Text('FIND A DESTINATION TO START A QUEST',
                    style: PixelType.body(context, color: _ink)),
              ),
              PixelText3DButton('EXPLORE', size: 14, onPressed: () => _tap('EXPLORE')),
            ],
          ),
          SizedBox(height: grid.px(3)),
          // Daily tasks as plain rows.
          for (final (i, task, reward) in const [
            (0, 'CHEER A PLAZA POST', '+5'),
            (1, 'READ A DESTINATION STORY', '+5'),
            (2, 'COMPLETE A QUEST STEP', '+10'),
          ])
            GestureDetector(
              key: ValueKey('v03_task_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Text(_done.contains(i) ? '✓' : '·',
                        style: PixelType.title(context,
                            color: _done.contains(i) ? PixelPalette.greenMid : _muted)),
                    SizedBox(width: grid.px(2)),
                    Expanded(
                      child: Text(task,
                          style: PixelType.small(context, color: _done.contains(i) ? _muted : _ink).copyWith(
                              decoration: _done.contains(i) ? TextDecoration.lineThrough : null)),
                    ),
                    PixelText3D(reward, size: 12, depth: 1),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _buttons(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'BUTTONS'),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: grid.px(4),
            runSpacing: grid.px(2),
            children: [
              PixelText3DButton('PLAY +25 XP', size: 18, onPressed: () => _tap('PLAY')),
              PixelText3DButton('CLAIM +5', colors: PixelText3DColors.green, onPressed: () => _tap('CLAIM')),
              PixelText3DButton('VIEW QUEST', colors: PixelText3DColors.cream, onPressed: () => _tap('VIEW QUEST')),
              PixelText3DButton('DELETE', size: 12, colors: PixelText3DColors.red, onPressed: () => _tap('DELETE')),
              const PixelText3DButton('LOCKED', size: 12, onPressed: null),
              PixelText3DButton('SAVE', size: 12, icon: ExploreArt.bookmarkSaved, onPressed: () => _tap('SAVE')),
            ],
          ),
        ],
      );

  Widget _settingsRows(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'SETTINGS ROWS'),
          for (final (art, title, value) in [
            (DesignerArt.navProfile, 'ACCOUNT', ''),
            (DesignerArt.notifBell, 'NOTIFICATIONS', ''),
            (DesignerArt.search, 'LANGUAGE', 'ENGLISH'),
            (DesignerArt.navSettings, 'TEXT SIZE', 'FOLLOW PHONE'),
          ])
            GestureDetector(
              key: ValueKey('v03_setting_$title'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _tap(title),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    PixelIconFit(art, box: 28),
                    SizedBox(width: grid.px(3)),
                    Expanded(child: Text(title, style: PixelType.body(context, color: _ink))),
                    if (value.isNotEmpty)
                      Flexible(
                        child: Text(value,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.small(context, color: _muted)),
                      ),
                    SizedBox(width: grid.px(2)),
                    Text('›', style: PixelType.title(context, color: _muted)),
                  ],
                ),
              ),
            ),
          Text('ICONS ARE TEMPORARY PICKS FROM OUR SET; v0.3 GETS ONE ICON PER ROW.',
              style: PixelType.small(context, color: _muted)),
        ],
      );

  Widget _textKit(BuildContext context, PixelGrid grid) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'TEXT'),
          const Center(child: PixelText3D('BIG TITLE', size: 24, depth: 3)),
          const Center(child: PixelText3D('SECTION TITLE', size: 16, colors: PixelText3DColors.green)),
          const Center(child: PixelText3D('SMALL LABEL', size: 12, colors: PixelText3DColors.cream, depth: 1)),
          SizedBox(height: grid.px(1)),
          Text('BODY TEXT STAYS FLAT SO LONG READING IS EASY.',
              textAlign: TextAlign.center, style: PixelType.body(context, color: _ink)),
        ],
      );

  Widget _hotbar(BuildContext context, PixelGrid grid) {
    final tabs = [
      ('HOME', DesignerArt.navHome),
      ('EXPLORE', DesignerArt.navExplore),
      ('MAP', DesignerArt.navMap),
      ('SHOP', DesignerArt.navShop),
      ('PROFILE', DesignerArt.navProfile),
    ];
    return Container(
      color: _dark ? PixelPalette.woodNight : PixelPalette.parchment,
      padding: EdgeInsets.fromLTRB(grid.px(1), grid.px(1), grid.px(1),
          grid.px(1) + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: grid.unit, color: _rule),
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('v03_tab_${tabs[i].$1}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_tab != i) pixelTick(context, sfx: 'tab');
                      setState(() => _tab = i);
                    },
                    child: Padding(
                      padding: EdgeInsets.only(top: grid.px(1)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, _tab == i ? -grid.unit : 0),
                            child: PixelIconFit(tabs[i].$2, box: 28),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: PixelText3D(
                              tabs[i].$1,
                              size: 10,
                              depth: 1,
                              colors: _tab == i ? PixelText3DColors.gold : PixelText3DColors.cream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Back arrow for the preview's top bar (no back-arrow sprite exists yet).
abstract final class Wave3ArtBack {
  static const art = PixelArt('v03Back', [
    '....00......',
    '...0jj0.....',
    '..0jj0......',
    '.0jj00000000',
    '0jjjjjjjjjj0',
    '.0jj00000000',
    '..0jj0......',
    '...0jj0.....',
    '....00......',
  ]);
}
