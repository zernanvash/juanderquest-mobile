import 'package:flutter/material.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';
import '../navigation/widgets/nav_pixel_art.dart';
import '../navigation/widgets/ph_outline.g.dart';
import '../navigation/widgets/route_map_thumbnail.dart';

/// Pixel lab: three layouts for the navigation bottom panel (owner 2026-11-13:
/// "it feels disconnected to the UI from other pages, and its taking too much
/// space ... create options in pixel lab so we can choose"). Sample data only.
enum NavPanelLayout { slimBar, woodCard, peek }

class _SampleRoute {
  const _SampleRoute(this.title, this.eta, this.meta, this.route, this.stops,
      this.color, this.reward);
  final String title, eta, meta;
  final List<double> route, stops;
  final Color color;
  final String? reward;
}

const _routes = [
  _SampleRoute('DIRECT ROUTE', '8 MIN · 6.9 KM', 'FASTEST', kLabDirectRoute, [],
      PixelPalette.blueBright, null),
  _SampleRoute(
    'HERITAGE TRAIL',
    '5 HR 51 MIN',
    '4 STOPS · 312 KM',
    kLabTrailRoute,
    [120.4854, 16.0436, 120.2312, 16.0232, 120.2319, 16.0218],
    PixelPalette.greenBright,
    '+50 PTS',
  ),
];

class NavPanelOptionsSection extends StatelessWidget {
  const NavPanelOptionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    Widget card(
            NavPanelLayout layout, String letter, String title, String body) =>
        Padding(
          padding: EdgeInsets.only(bottom: grid.px(2)),
          child: PixelPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$letter · $title', style: PixelType.body(context)),
                const SizedBox(height: 4),
                Text(body,
                    style: PixelType.small(context, color: PixelPalette.slate)),
                const SizedBox(height: 8),
                PixelButton(
                  key: ValueKey('nav_panel_option_${letter.toLowerCase()}'),
                  label: 'Open option $letter',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => NavPanelPreview(layout: layout)),
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Drag the panel up and down: it follows your finger. Swipe the route card sideways. '
          'The small map is the real road route on a plain Philippines outline.',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(2)),
        card(NavPanelLayout.slimBar, 'A', 'Slim bar',
            'Smallest. One row: map preview, route, time and GO. Drag up for travel modes.'),
        card(NavPanelLayout.woodCard, 'B', 'Wood card',
            'Looks like the other pages: wood title strip, parchment card, bigger map preview.'),
        card(NavPanelLayout.peek, 'C', 'Peek',
            'Only time and GO until you drag up; then a wide map preview and the modes.'),
      ],
    );
  }
}

class NavPanelPreview extends StatefulWidget {
  const NavPanelPreview({super.key, required this.layout});
  final NavPanelLayout layout;

  @override
  State<NavPanelPreview> createState() => _NavPanelPreviewState();
}

class _NavPanelPreviewState extends State<NavPanelPreview> {
  final _pages = PageController();
  int _route = 0;
  int _mode = 0;
  late double _height = _min;

  double get _min => switch (widget.layout) {
        NavPanelLayout.slimBar => 112,
        NavPanelLayout.woodCard => 176,
        NavPanelLayout.peek => 84,
      };
  double get _max => switch (widget.layout) {
        NavPanelLayout.slimBar => 216,
        NavPanelLayout.woodCard => 280,
        NavPanelLayout.peek => 316,
      };

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) =>
      setState(() => _height = (_height - d.delta.dy).clamp(_min, _max));

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final up = v.abs() > 300 ? v < 0 : _height > (_min + _max) / 2;
    setState(() => _height = up ? _max : _min);
  }

  Widget _handle() => Center(
        child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 6),
            color: PixelPalette.woodDeep),
      );

  Widget _go({double width = 76, double height = 52}) => SizedBox(
        width: width,
        height: height,
        child: PixelPanel(
          style: PixelBoxStyle.green,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_route == 0 ? 'GO' : 'START',
                  style: PixelType.body(context, color: PixelPalette.paper)),
            ),
          ),
        ),
      );

  Widget _modes() {
    const labels = ['DRIVE', 'MOTO', 'BIKE', 'WALK'];
    const arts = [
      NavPixelArt.modeCar,
      NavPixelArt.modeMoto,
      NavPixelArt.modeBike,
      NavPixelArt.modeWalk
    ];
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: GestureDetector(
                key: ValueKey('nav_panel_mode_$i'),
                onTap: () => setState(() => _mode = i),
                child: SizedBox(
                  height: 44,
                  child: PixelPanel(
                    style: _mode == i
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.parchment,
                    pressed: _mode == i,
                    padding: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NavPixelIcon(arts[i], size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(labels[i],
                                style: PixelType.small(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _routeCard(_SampleRoute r,
      {required double thumb, bool wide = false}) {
    if (wide) {
      return Stack(
        children: [
          Positioned.fill(
              child: RouteMapThumbnail(
                  route: r.route, stops: r.stops, lineColor: r.color)),
          Positioned(
              left: 6,
              bottom: 6,
              child: PixelChip(r.title, style: PixelBoxStyle.parchment)),
          if (r.reward != null)
            Positioned(right: 6, top: 6, child: PixelChip(r.reward!)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: thumb,
          height: thumb,
          child: RouteMapThumbnail(
              route: r.route, stops: r.stops, lineColor: r.color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.title, style: PixelType.body(context)),
                Text(r.eta, style: PixelType.small(context)),
                Text(r.meta,
                    style: PixelType.small(context, color: PixelPalette.slate)),
              ],
            ),
          ),
        ),
        if (r.reward != null) PixelChip(r.reward!),
      ],
    );
  }

  Widget _carousel(
          {required double height, required double thumb, bool wide = false}) =>
      SizedBox(
        height: height,
        child: PageView(
          key: const ValueKey('nav_panel_carousel'),
          controller: _pages,
          onPageChanged: (i) => setState(() => _route = i),
          children: [
            for (final r in _routes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _routeCard(r, thumb: thumb, wide: wide),
              ),
          ],
        ),
      );

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _routes.length; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: BoxDecoration(
                color: i == _route ? PixelPalette.ink : PixelPalette.paper,
                border: Border.all(color: PixelPalette.ink, width: 1.5),
              ),
            ),
        ],
      );

  Widget _subLine() => Row(
        children: [
          Expanded(
            child: Text(
              'ARRIVE 6:13 PM · FROM MY LOCATION',
              style: PixelType.small(context, color: PixelPalette.slate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('CHANGE',
              style: PixelType.small(context)
                  .copyWith(decoration: TextDecoration.underline)),
        ],
      );

  List<Widget> _body() {
    final r = _routes[_route];
    switch (widget.layout) {
      case NavPanelLayout.slimBar:
        return [
          _handle(),
          Row(
            children: [
              Expanded(child: _carousel(height: 56, thumb: 56)),
              const SizedBox(width: 8),
              _go(),
            ],
          ),
          _dots(),
          const SizedBox(height: 4),
          _modes(),
          const SizedBox(height: 8),
          _subLine(),
        ];
      case NavPanelLayout.woodCard:
        return [
          PixelPanel(
            style: PixelBoxStyle.wood,
            padding: 2,
            child: Row(
              children: [
                const NavPixelIcon(NavPixelArt.clock, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.eta,
                    style: PixelType.body(context, color: PixelPalette.paper),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(width: 28, height: 4, color: PixelPalette.woodLight),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _carousel(height: 72, thumb: 72),
          _dots(),
          _go(width: double.infinity, height: 48),
          const SizedBox(height: 8),
          _modes(),
          const SizedBox(height: 8),
          _subLine(),
        ];
      case NavPanelLayout.peek:
        return [
          _handle(),
          Row(
            children: [
              const NavPixelIcon(NavPixelArt.clock, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.eta, style: PixelType.body(context)),
                        Text(r.title,
                            style: PixelType.small(context,
                                color: PixelPalette.slate)),
                      ],
                    ),
                  ),
                ),
              ),
              _go(height: 48),
            ],
          ),
          const SizedBox(height: 8),
          _carousel(height: 120, thumb: 0, wide: true),
          _dots(),
          _modes(),
          const SizedBox(height: 8),
          _subLine(),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _routes[_route];
    return Scaffold(
      backgroundColor: PixelPalette.blueLight,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RouteMapThumbnail(
                  route: r.route,
                  stops: r.stops,
                  lineColor: r.color,
                  border: false),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: PixelPanel(
                padding: 2,
                child: Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey('nav_panel_back'),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Text('<', style: PixelType.body(context)),
                      ),
                    ),
                    NavPixelIcon(
                        _route == 0 ? NavPixelArt.pinRed : NavPixelArt.flagGold,
                        size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _route == 0
                            ? 'TO TONDALIGAN BEACH'
                            : 'HERITAGE TRAIL · 4 STOPS',
                        style: PixelType.body(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _height,
              child: GestureDetector(
                key: const ValueKey('nav_panel_sheet'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _drag,
                onVerticalDragEnd: _dragEnd,
                child: PixelPanel(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _body()),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
