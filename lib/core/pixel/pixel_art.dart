import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';

/// One sprite as palette-keyed rows: one character = one art pixel, '.' is
/// transparent. Generated from designer PNGs by tool/pixel_art/png_to_dart.py.
class PixelArt {
  const PixelArt(this.name, this.rows);

  final String name;
  final List<String> rows;

  int get width => rows.first.length;
  int get height => rows.length;

  static final Map<String, ui.Image> _cache = {};

  /// Rasterised once at 1 px per art pixel, then reused (drawn scaled with
  /// nearest-neighbour, so it stays sharp at any whole-number scale).
  ui.Image image() => _cache.putIfAbsent(name, () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final paint = Paint()..isAntiAlias = false;
        for (var y = 0; y < rows.length; y++) {
          final row = rows[y];
          for (var x = 0; x < row.length; x++) {
            final color = PixelPalette.byKey[row[x]];
            if (color == null) continue;
            paint.color = color;
            canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
          }
        }
        return recorder.endRecording().toImageSync(width, height);
      });
}

/// An animation: same-size frames played at [fps].
class PixelFrames {
  const PixelFrames(this.name, {required this.fps, required this.frames});

  final String name;
  final int fps;
  final List<PixelArt> frames;
}

/// Draws [art] so one art pixel covers exactly [scale] device pixels.
/// Whole device pixels only: no blur, no uneven pixels.
class PixelSprite extends StatelessWidget {
  const PixelSprite(this.art, {super.key, this.scale = 3, this.semanticLabel});

  final PixelArt art;

  /// Device pixels per art pixel (1 = the designer's native size on screen).
  final int scale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = Size(art.width * scale / dpr, art.height * scale / dpr);
    final sprite = _PixelSnap(child: CustomPaint(size: size, painter: _SpritePainter(art.image())));
    return semanticLabel == null ? ExcludeSemantics(child: sprite) : Semantics(label: semanticLabel, image: true, child: sprite);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.image != image;
}

/// Plays [frames] in steps (no tweening), looping or once.
class PixelAnimation extends StatefulWidget {
  const PixelAnimation(this.frames, {super.key, this.scale = 3, this.loop = true, this.playing = true, this.onDone});

  final PixelFrames frames;
  final int scale;
  final bool loop;
  final bool playing;
  final VoidCallback? onDone;

  @override
  State<PixelAnimation> createState() => _PixelAnimationState();
}

class _PixelAnimationState extends State<PixelAnimation> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  int _frame = 0;
  Duration _start = Duration.zero;
  bool _restart = true;

  @override
  void initState() {
    super.initState();
    if (widget.playing) _ticker.start();
  }

  @override
  void didUpdateWidget(PixelAnimation old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_ticker.isActive) {
      _restart = true;
      _frame = 0;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    if (_restart) {
      _start = elapsed;
      _restart = false;
    }
    final count = widget.frames.frames.length;
    var next = ((elapsed - _start).inMicroseconds * widget.frames.fps / 1e6).floor();
    if (!widget.loop && next >= count) {
      _ticker.stop();
      next = count - 1;
      widget.onDone?.call();
    }
    next %= count;
    if (next != _frame) setState(() => _frame = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PixelSprite(widget.frames.frames[_frame], scale: widget.scale);
}

/// Paints the child at a whole-device-pixel offset so sprite edges stay sharp.
class _PixelSnap extends SingleChildRenderObjectWidget {
  const _PixelSnap({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPixelSnap(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPixelSnap).dpr = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderPixelSnap extends RenderProxyBox {
  _RenderPixelSnap(this._dpr);

  double _dpr;
  set dpr(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, Offset((offset.dx * _dpr).roundToDouble() / _dpr, (offset.dy * _dpr).roundToDouble() / _dpr));
  }
}
