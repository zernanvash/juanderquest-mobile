import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

/// Pixel art assets and widgets for map markers, tools, clusters, and reticle.
abstract final class MapMarkerArt {
  // TEMPORARY until Clarissa's art (spot pin 16x16, selected variant on Clarissa's list)
  static const spotPin = PixelArt('mapSpotPin', [
    '.....000000.....',
    '...00mmmmmm00...',
    '..0mmmmmmmmmm0..',
    '..0mm000000mm0..',
    '.0mm0pppppp0mm0.',
    '.0mm0pppppp0mm0.',
    '.0mm0pppppp0mm0.',
    '.0mm0pppppp0mm0.',
    '..0mm000000mm0..',
    '..0mmmmmmmmmm0..',
    '...00mmmmmm00...',
    '....00mmmm00....',
    '.....00mm00.....',
    '......0mm0......',
    '.......00.......',
    '................',
  ]);

  /// 8x8 blue "you are here" dot with white outline.
  static const youAreHere = PixelArt('mapYouAreHere', [
    '..6666..',
    '.6AAAA6.',
    '6AAAAAA6',
    '6AAAAAA6',
    '6AAAAAA6',
    '6AAAAAA6',
    '.6AAAA6.',
    '..6666..',
  ]);

  /// North / orientation reset tool icon (16x16).
  static const iconCompass = PixelArt('mapIconCompass', [
    '.......00.......',
    '......0ss0......',
    '.....0ssss0.....',
    '....0ssssss0....',
    '...0ssssssss0...',
    '..0ssssssssss0..',
    '.0ssssssssssss0.',
    '0000000000000000',
    '.06666666666660.',
    '..066666666660..',
    '...0666666660...',
    '....06666660....',
    '.....066660.....',
    '......0660......',
    '.......00.......',
    '................',
  ]);

  /// Satellite tool icon (16x16).
  static const iconSatellite = PixelArt('mapIconSatellite', [
    '................',
    '.....0000.......',
    '....066660......',
    '...06666660.....',
    '..0666006660....',
    '.06600..00660...',
    '.060......060...',
    '060...00...060..',
    '060..0hh0..060..',
    '.060..00..060...',
    '.0660....0660...',
    '..0660000660....',
    '...06666660.....',
    '....066660......',
    '.....0000.......',
    '................',
  ]);

  /// Add Pin / destination tool icon (16x16).
  static const iconAddPin = PixelArt('mapIconAddPin', [
    '.....0000.......',
    '...00hhhh00.....',
    '..0hhhhhhhh0....',
    '..0hh0000hh0....',
    '.0hh0....0hh0...',
    '.0hh0.00.0hh0...',
    '.0hh00hh00hh0...',
    '.0hhhhhh00hh0...',
    '..0hhhh0..00....',
    '..0hhhh00000....',
    '...00hhhh00.....',
    '....00hh00......',
    '.....0000.......',
    '......00........',
    '................',
    '................',
  ]);

  /// My Location / GPS target icon (16x16).
  static const iconLocateMe = PixelArt('mapIconLocateMe', [
    '.......00.......',
    '.......0A.......',
    '....00000000....',
    '...0AAAAAAAA0...',
    '..0AA000000AA0..',
    '.0AA0......0AA0.',
    '.0AA0..00..0AA0.',
    '00AA0.0AA0.0AA00',
    '00AA0.0AA0.0AA00',
    '.0AA0..00..0AA0.',
    '.0AA0......0AA0.',
    '..0AA000000AA0..',
    '...0AAAAAAAA0...',
    '....00000000....',
    '.......0A.......',
    '.......00.......',
  ]);

  /// Fit bounds tool icon (16x16).
  static const iconFitBounds = PixelArt('mapIconFitBounds', [
    '000000....000000',
    '099990....099990',
    '099000....000990',
    '090..........090',
    '090..........090',
    '000..........000',
    '................',
    '................',
    '................',
    '................',
    '000..........000',
    '090..........090',
    '090..........090',
    '099000....000990',
    '099990....099990',
    '000000....000000',
  ]);

  /// Refresh coordinates tool icon (16x16).
  static const iconRefresh = PixelArt('mapIconRefresh', [
    '......000000....',
    '....00mmmmmm00..',
    '...0mmmm0000000.',
    '..0mmm00mmmmmmm0',
    '.0mmm0..0mmmmmm0',
    '.0mmm0...000000.',
    '.0mmm0..........',
    '.0mmm0..........',
    '.0mmm0..........',
    '.000000...0mmm0.',
    '0mmmmmm0..0mmm0.',
    '0mmmmmmm00mmm0..',
    '.0000000mmmm0...',
    '..00mmmmmm00....',
    '....000000......',
    '................',
  ]);

  /// Close X icon (16x16).
  static const iconClose = PixelArt('mapIconClose', [
    '00............00',
    '000..........000',
    '.000........000.',
    '..000......000..',
    '...000....000...',
    '....000..000....',
    '.....000000.....',
    '......0000......',
    '......0000......',
    '.....000000.....',
    '....000..000....',
    '...000....000...',
    '..000......000..',
    '.000........000.',
    '000..........000',
    '00............00',
  ]);
}

/// Selected marker animation wrapper:
/// Sits on a 1-art-px [PixelPalette.sun] frame and hops 2 art px in 2 discrete steps at 8 fps.
/// No tweening, whole art pixels only.
class PixelSelectedMarkerHopper extends StatefulWidget {
  const PixelSelectedMarkerHopper({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  State<PixelSelectedMarkerHopper> createState() =>
      _PixelSelectedMarkerHopperState();
}

class _PixelSelectedMarkerHopperState extends State<PixelSelectedMarkerHopper> {
  Timer? _hopTimer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    if (widget.selected) _startHop();
  }

  @override
  void didUpdateWidget(covariant PixelSelectedMarkerHopper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _startHop();
    } else if (!widget.selected && oldWidget.selected) {
      _stopHop();
    }
  }

  void _startHop() {
    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 2);
    });
  }

  void _stopHop() {
    _hopTimer?.cancel();
    _hopTimer = null;
    _step = 0;
  }

  @override
  void dispose() {
    _stopHop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.selected) return widget.child;
    final grid = PixelGrid.of(context);
    final hopY = _step == 1 ? -grid.px(2) : 0.0;

    return Transform.translate(
      offset: Offset(0, hopY),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: PixelPalette.sun, width: grid.unit),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Cluster marker: a parchment notched chip with the count in Silkscreen bold.
/// Displays '9+' above 9, adhering to the hotbar badge rule.
class PixelClusterChip extends StatelessWidget {
  const PixelClusterChip({
    super.key,
    required this.count,
    required this.onTap,
    this.hasQuest = false,
  });

  final int count;
  final VoidCallback onTap;
  final bool hasQuest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final label = count > 9 ? '9+' : '$count';

    return Semantics(
      button: true,
      label: '$count destinations, zoom in',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          pixelTick(context);
          onTap();
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: grid.px(16),
            minHeight: grid.px(16),
          ),
          child: PixelPanel(
            style: hasQuest
                ? PixelBoxStyle.gold
                : PixelBoxStyle.parchment,
            padding: 1,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: PixelType.small(
                  context,
                  color: hasQuest ? PixelPalette.ink : PixelPalette.wood,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pixel crosshair reticle: ink crosshair with white outline, stepped.
class PixelCrosshairReticle extends StatelessWidget {
  const PixelCrosshairReticle({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return IgnorePointer(
      child: Center(
        child: CustomPaint(
          size: Size(grid.px(20), grid.px(20)),
          painter: _PixelCrosshairPainter(grid.unit),
        ),
      ),
    );
  }
}

class _PixelCrosshairPainter extends CustomPainter {
  _PixelCrosshairPainter(this.unit);

  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = (size.width / 2 / unit).round() * unit;
    final cy = (size.height / 2 / unit).round() * unit;

    final paintWhite = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.white;

    final paintInk = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.ink;

    // Draw white outline rects (outer border)
    // Horizontal crosshair: length 16 art px, thickness 3 art px
    canvas.drawRect(
      Rect.fromLTWH(cx - unit * 8, cy - unit * 1.5, unit * 16, unit * 3),
      paintWhite,
    );
    // Vertical crosshair: length 16 art px, thickness 3 art px
    canvas.drawRect(
      Rect.fromLTWH(cx - unit * 1.5, cy - unit * 8, unit * 3, unit * 16),
      paintWhite,
    );

    // Draw inner ink crosshair (thickness 1 art px)
    canvas.drawRect(
      Rect.fromLTWH(cx - unit * 7, cy - unit * 0.5, unit * 14, unit * 1),
      paintInk,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - unit * 0.5, cy - unit * 7, unit * 1, unit * 14),
      paintInk,
    );

    // Center hole: 2x2 art px transparent/white dot
    canvas.drawRect(
      Rect.fromLTWH(cx - unit * 1, cy - unit * 1, unit * 2, unit * 2),
      paintWhite,
    );
  }

  @override
  bool shouldRepaint(_PixelCrosshairPainter old) => old.unit != unit;
}
