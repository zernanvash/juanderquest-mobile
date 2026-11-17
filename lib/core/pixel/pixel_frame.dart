import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';

/// A cosmetic panel frame drawn from PNG pieces (Plan 104b). Owner
/// 2026-11-17: a bought frame dresses only the Home player card and the
/// Passport header.
///
/// The pieces live in `assets/frames/<name>/` and are made by a script in
/// `tool/pixel_art/frames/` (see `make_bamboo.py`). One PNG pixel is one
/// art pixel:
///  * `edge-top/bottom.png` are [edge] tall and repeat left to right;
///    `edge-left/right.png` are [edge] wide and repeat top to bottom;
///  * `corner-*.png` are [corner] square and are drawn last, over the edges;
///  * `fill.png` tiles inside the [edge] inset.
class PixelFrameSkin {
  const PixelFrameSkin({
    required this.name,
    required this.edge,
    required this.corner,
    required this.text,
    required this.textSoft,
    required this.accent,
  });

  final String name;

  /// Edge thickness in art pixels (content is inset by this much).
  final int edge;

  /// Corner piece size in art pixels.
  final int corner;

  /// Text colours that read on this frame's fill.
  final Color text;
  final Color textSoft;
  final Color accent;

  /// The `{token:…}` names for [PixelText.rich] that match [accent] and
  /// [text] ('ink' is not a token, so it falls back to the base colour).
  String get accentToken => 'gold';
  String get textToken => 'ink';

  String get dir => 'assets/frames/$name';

  static const bamboo = PixelFrameSkin(
    name: 'bamboo',
    edge: 10,
    corner: 32,
    text: PixelPalette.ink,
    textSoft: PixelPalette.slate,
    accent: PixelPalette.gold,
  );

  static const all = <PixelFrameSkin>[bamboo];

  static PixelFrameSkin? byName(Object? name) {
    for (final skin in all) {
      if (skin.name == name) return skin;
    }
    return null;
  }

  /// The frame for the player card / Passport header: the Pixel Lab preview
  /// if one is picked, else the equipped frame cosmetic's `asset.panel`.
  static PixelFrameSkin? resolve(
    String? preview,
    Map<String, dynamic>? cosmetics,
  ) {
    if (preview != null) return byName(preview);
    final item = cosmetics?['frame'];
    if (item is! Map || item['asset'] is! Map) return null;
    return byName((item['asset'] as Map)['panel']);
  }
}

/// Pixel Lab → Panel frames: try a frame on the player card and Passport
/// header before it is in the shop. Not saved.
final panelFramePreviewProvider = StateProvider<String?>((ref) => null);

class _FrameImages {
  _FrameImages(this.pieces);
  final Map<String, ui.Image> pieces;
  ui.Image operator [](String name) => pieces[name]!;
}

const _pieceNames = <String>[
  'corner-tl',
  'corner-tr',
  'corner-bl',
  'corner-br',
  'edge-top',
  'edge-bottom',
  'edge-left',
  'edge-right',
  'fill',
];

final _cache = <String, Future<_FrameImages>>{};

Future<_FrameImages> _load(PixelFrameSkin skin, AssetBundle bundle) {
  return _cache.putIfAbsent(skin.name, () async {
    final out = <String, ui.Image>{};
    for (final name in _pieceNames) {
      final data = await bundle.load('${skin.dir}/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      out[name] = (await codec.getNextFrame()).image;
    }
    return _FrameImages(out);
  });
}

/// A panel dressed in [skin]. Same job as [PixelPanel]: [padding] art px of
/// space inside the frame's edge.
class PixelFramedPanel extends StatefulWidget {
  const PixelFramedPanel({
    super.key,
    required this.skin,
    required this.child,
    this.padding = PixelPanel.sectionPadding,
  });

  final PixelFrameSkin skin;
  final Widget child;
  final int padding;

  @override
  State<PixelFramedPanel> createState() => _PixelFramedPanelState();
}

class _PixelFramedPanelState extends State<PixelFramedPanel> {
  _FrameImages? _images;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(PixelFramedPanel old) {
    super.didUpdateWidget(old);
    if (old.skin.name != widget.skin.name) {
      _images = null;
      _start();
    }
  }

  void _start() {
    final skin = widget.skin;
    _load(skin, DefaultAssetBundle.of(context)).then((images) {
      if (mounted && widget.skin.name == skin.name) {
        setState(() => _images = images);
      }
    }, onError: (Object e) {
      // A missing piece leaves the panel unframed, never broken.
      debugPrint('PixelFramedPanel: ${skin.name}: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final inset = grid.px(widget.skin.edge + widget.padding);
    return CustomPaint(
      painter: _FramePainter(
        skin: widget.skin,
        images: _images,
        unit: grid.unit,
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: widget.child,
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.skin, required this.images, required this.unit});

  final PixelFrameSkin skin;
  final _FrameImages? images;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final im = images;
    final u = unit;
    final cols = (size.width / u).floor();
    final rows = (size.height / u).floor();
    final e = skin.edge;
    final c = skin.corner;
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    if (im == null) {
      // Until the pieces load, a plain fill in the frame's place.
      canvas.drawRect(
        Rect.fromLTWH(e * u, e * u, (cols - 2 * e) * u, (rows - 2 * e) * u),
        paint..color = PixelPalette.parchment,
      );
      return;
    }

    // Draws [w] x [h] art px of [image] from its top left at art (x, y).
    void piece(ui.Image image, int x, int y, int w, int h) {
      if (w <= 0 || h <= 0) return;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Rect.fromLTWH(x * u, y * u, w * u, h * u),
        paint,
      );
    }

    final fill = im['fill'];
    for (var y = e; y < rows - e; y += fill.height) {
      for (var x = e; x < cols - e; x += fill.width) {
        piece(fill, x, y, math.min(fill.width, cols - e - x),
            math.min(fill.height, rows - e - y));
      }
    }
    final top = im['edge-top'], bottom = im['edge-bottom'];
    for (var x = e; x < cols - e; x += top.width) {
      final n = math.min(top.width, cols - e - x);
      piece(top, x, 0, n, e);
      piece(bottom, x, rows - e, n, e);
    }
    final left = im['edge-left'], right = im['edge-right'];
    for (var y = e; y < rows - e; y += left.height) {
      final n = math.min(left.height, rows - e - y);
      piece(left, 0, y, e, n);
      piece(right, cols - e, y, e, n);
    }
    piece(im['corner-tl'], 0, 0, c, c);
    piece(im['corner-tr'], cols - c, 0, c, c);
    piece(im['corner-bl'], 0, rows - c, c, c);
    piece(im['corner-br'], cols - c, rows - c, c, c);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.images != images || old.unit != unit || old.skin != skin;
}

/// One edge of a frame as a strip across the full width: the art border on
/// the static bars (owner 2026-11-17: "for the static panels, like the bottom
/// nav bar, add the borders we were planning … we can add art border in top
/// bar too"). [piece] is `edge-top` (a border along a bar's top, as on the
/// bottom nav) or `edge-bottom` (under the top bar). Its height is reserved
/// before the art loads, so nothing jumps.
class PixelFrameStrip extends StatefulWidget {
  const PixelFrameStrip({
    super.key,
    this.skin = PixelFrameSkin.bamboo,
    this.piece = 'edge-top',
  });

  final PixelFrameSkin skin;
  final String piece;

  @override
  State<PixelFrameStrip> createState() => _PixelFrameStripState();
}

class _PixelFrameStripState extends State<PixelFrameStrip> {
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final skin = widget.skin;
    final piece = widget.piece;
    _load(skin, DefaultAssetBundle.of(context)).then((images) {
      if (mounted && widget.skin.name == skin.name && widget.piece == piece) {
        setState(() => _image = images[piece]);
      }
    }, onError: (Object e) {
      debugPrint('PixelFrameStrip: ${skin.name}: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      height: grid.px(widget.skin.edge),
      width: double.infinity,
      child: CustomPaint(
        painter: _StripPainter(_image, grid.unit, widget.skin.edge),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image, this.unit, this.edge);

  final ui.Image? image;
  final double unit;
  final int edge;

  @override
  void paint(Canvas canvas, Size size) {
    final im = image;
    if (im == null) return;
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    final cols = (size.width / unit).ceil();
    for (var x = 0; x < cols; x += im.width) {
      final n = math.min(im.width, cols - x);
      canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, n.toDouble(), edge.toDouble()),
        Rect.fromLTWH(x * unit, 0, n * unit, edge * unit),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.image != image || old.unit != unit || old.edge != edge;
}

@visibleForTesting
void debugClearPixelFrameCache() => _cache.clear();
