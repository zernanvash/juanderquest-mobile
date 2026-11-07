import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_text.dart';
import 'ar_minigame.dart';

/// On-screen controls for any [ArMiniGame], drawn by Flutter over the AR view
/// (same layout as the Tumbang Preso HUD). Reads the game, calls back on input.
class ArMiniGameHud extends StatelessWidget {
  const ArMiniGameHud({
    super.key,
    required this.game,
    required this.now,
    required this.pose,
    required this.callout,
    required this.onPlace,
    required this.onMove,
    required this.onRestart,
    required this.onPress,
    required this.onRelease,
    this.onSwipe,
    this.onPull,
    this.placing = false,
    this.pressed = false,
  });

  final ArMiniGame game;
  final double now;
  final ArPose? pose;
  final String? callout;
  final bool placing;
  final bool pressed;
  final VoidCallback onPlace;
  final VoidCallback onMove;
  final VoidCallback onRestart;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  /// Swipe-up throw: how far the swipe leaned from straight up, in degrees.
  final ValueChanged<double>? onSwipe;

  /// Bow string pulled back, 0..1.
  final ValueChanged<double>? onPull;

  @override
  Widget build(BuildContext context) {
    final playing = game.placed && !game.over;
    final reticle = playing ? game.reticle(now, pose) : null;
    // The aim circle sits in the true middle of the screen (where the camera looks).
    return Stack(children: [
      if (reticle != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox.square(
                key: ValueKey('reticle_$reticle'),
                dimension: 64,
                child: CustomPaint(painter: _ReticlePainter(on: reticle)),
              ),
            ),
          ),
        ),
      if (game.placed && game.blind(now))
        const Positioned.fill(
          child: IgnorePointer(child: ColoredBox(key: ValueKey('blindfold'), color: Color(0xF5000000))),
        ),
      Positioned.fill(child: _bars(context)),
    ]);
  }

  Widget _bars(BuildContext context) {
    final playing = game.placed && !game.over;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(children: [
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _top(context),
                      const Spacer(),
                      const SizedBox(height: 8),
                      if (!game.placed) _placeCard(context),
                      if (playing) _controls(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !game.over,
              child: Align(alignment: const Alignment(0, -0.35), child: _middle(context)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _top(BuildContext context) {
    final status = game.status(pose);
    return PixelPanel(
      style: PixelBoxStyle.inkDialogue,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(game.title, style: PixelType.title(context, color: PixelPalette.sun)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < game.targetHits; i++)
              Container(
                key: ValueKey('hit_pip_$i'),
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i < game.hits ? PixelPalette.sun : PixelPalette.slate,
                  border: Border.all(color: PixelPalette.paper, width: 2),
                ),
              ),
            const SizedBox(width: 4),
            Text('${game.hits}/${game.targetHits}', style: PixelType.numbers(context, color: PixelPalette.paper)),
          ]),
          if (status != null) Text(status, style: PixelType.small(context, color: PixelPalette.mist)),
        ],
      ),
    );
  }

  Widget _middle(BuildContext context) {
    if (game.over) {
      return SingleChildScrollView(
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Text(game.passed ? 'PANALO!' : 'TAPOS NA!',
                  style: PixelType.display(context, color: game.passed ? PixelPalette.greenDeep : PixelPalette.ink)),
            ),
            const SizedBox(height: 6),
            Text(game.endText, textAlign: TextAlign.center, style: PixelType.body(context)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              PixelButton(key: const ValueKey('play_again'), label: 'PLAY AGAIN', onPressed: onRestart),
              PixelButton(label: 'MOVE IT', variant: PixelButtonVariant.secondary, onPressed: onMove),
            ]),
          ]),
        ),
      );
    }
    final hint = game.placed ? game.hint(now, pose) : null;
    final children = <Widget>[
      if (callout != null)
        FittedBox(
          key: const ValueKey('callout'),
          child: Text(
            callout!,
            style: PixelType.display(context, color: PixelPalette.sun).copyWith(
              fontSize: 40,
              shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(3, 3))],
            ),
          ),
        ),
      if (game.placed && pose == null) _pill(context, 'FIND IT: point your phone back at it'),
      if (game.placed && pose != null && !game.onLine(pose!))
        _pill(context, 'BALIK SA LINYA: stand on the chalk line', key: const ValueKey('line_hint')),
      if (hint != null) _pill(context, hint, key: const ValueKey('aim_hint')),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 6),
        child: PixelPanel(
          style: PixelBoxStyle.inkDialogue,
          child: Text(text, textAlign: TextAlign.center, style: PixelType.body(context, color: PixelPalette.paper)),
        ),
      );

  Widget _placeCard(BuildContext context) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(game.placeHint, textAlign: TextAlign.center, style: PixelType.body(context)),
        const SizedBox(height: 8),
        PixelButton(
          key: const ValueKey('place_game'),
          label: placing ? 'LOOKING FOR FLOOR…' : 'STAND HERE',
          expand: true,
          onPressed: placing ? null : onPlace,
        ),
      ]),
    );
  }

  Widget _controls(BuildContext context) {
    final can = game.canPress(now) || pressed;
    final meter = game.meter(now, pose);
    final caption = game.meterCaption(now, pose);
    final hold = game.buttonMode == ArButtonMode.hold;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (meter != null)
        SizedBox(
          height: 26,
          child: CustomPaint(key: const ValueKey('meter'), painter: _MeterPainter(meter)),
        ),
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: PixelType.small(context, color: PixelPalette.paper)
              .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(1, 1))]),
        ),
      ],
      const SizedBox(height: 6),
      if (game.buttonMode == ArButtonMode.swipe)
        _SwipePad(
          key: const ValueKey('game_button'),
          enabled: can,
          label: game.buttonLabel(now),
          onSwipe: (deg) => onSwipe?.call(deg),
        )
      else if (game.buttonMode == ArButtonMode.pull)
        _BowPad(
          key: const ValueKey('game_button'),
          enabled: can,
          draw: meter?.value ?? 0,
          label: game.buttonLabel(now),
          onPress: onPress,
          onPull: (v) => onPull?.call(v),
          onRelease: onRelease,
        )
      else
        Listener(
          key: const ValueKey('game_button'),
          onPointerDown: can ? (_) => onPress() : null,
          onPointerUp: can && hold ? (_) => onRelease() : null,
          onPointerCancel: can && hold ? (_) => onRelease() : null,
          child: PixelPanel(
            style: can ? PixelBoxStyle.green : PixelBoxStyle.stone,
            pressed: pressed,
            child: SizedBox(
              height: 52,
              child: Center(
                child: FittedBox(
                  child: Text(game.buttonLabel(now), style: PixelType.title(context, color: PixelPalette.white)),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      Align(child: PixelButton(label: 'MOVE IT', variant: PixelButtonVariant.ghost, onPressed: onMove)),
    ]);
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.meter);
  final ArMeter meter;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = PixelPalette.ink);
    final inner = r.deflate(3);
    canvas.drawRect(inner, Paint()..color = PixelPalette.slate);
    final from = meter.from, to = meter.to;
    if (from != null && to != null) {
      canvas.drawRect(
        Rect.fromLTRB(inner.left + inner.width * from, inner.top, inner.left + inner.width * to, inner.bottom),
        Paint()..color = PixelPalette.greenMid,
      );
    }
    final v = meter.value.clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top + inner.height * 0.3, inner.width * v, inner.height * 0.4),
        Paint()..color = PixelPalette.sun);
    final x = inner.left + inner.width * v;
    canvas.drawRect(Rect.fromLTWH(x - 2, r.top, 4, r.height), Paint()..color = PixelPalette.paper);
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.meter != meter;
}

/// Pixel aim circle: white, green when the target is in it.
class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.on});
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final c = on ? PixelPalette.greenMid : PixelPalette.paper;
    const px = 4.0;
    final n = (size.width / px).floor();
    final mid = (n - 1) / 2, r = n / 2 - 1.5;
    final ink = Paint()..color = PixelPalette.ink;
    final fill = Paint()..color = c;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final d = Offset(i - mid, j - mid).distance;
        if ((d - r).abs() < 0.6) {
          canvas.drawRect(Rect.fromLTWH(i * px, j * px, px, px), fill);
        } else if ((d - r).abs() < 1.4) {
          canvas.drawRect(Rect.fromLTWH(i * px, j * px, px, px), ink);
        }
      }
    }
    canvas.drawRect(Rect.fromCenter(center: size.center(Offset.zero), width: px, height: px), fill);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.on != on;
}

/// Swipe up anywhere on the pad to throw (Ring Shoot).
class _SwipePad extends StatefulWidget {
  const _SwipePad({super.key, required this.enabled, required this.label, required this.onSwipe});
  final bool enabled;
  final String label;
  final ValueChanged<double> onSwipe;

  @override
  State<_SwipePad> createState() => _SwipePadState();
}

class _SwipePadState extends State<_SwipePad> {
  Offset _d = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _d = Offset.zero,
      onPanUpdate: (e) => _d += e.delta,
      onPanEnd: (_) {
        // An upward flick of at least 40 px throws; the lean is its angle from straight up.
        if (widget.enabled && _d.dy < -40) widget.onSwipe(math.atan2(_d.dx, -_d.dy) * 180 / math.pi);
      },
      child: PixelPanel(
        style: widget.enabled ? PixelBoxStyle.green : PixelBoxStyle.stone,
        child: SizedBox(
          height: 72,
          child: Center(
            child: FittedBox(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('▲ ▲ ▲', style: PixelType.title(context, color: PixelPalette.sun)),
                Text(widget.label, style: PixelType.title(context, color: PixelPalette.white)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bow at the bottom of the screen: drag down to pull the string back,
/// let go to shoot (Pana). The picture bends with the pull.
class _BowPad extends StatefulWidget {
  const _BowPad({
    super.key,
    required this.enabled,
    required this.draw,
    required this.label,
    required this.onPress,
    required this.onPull,
    required this.onRelease,
  });
  final bool enabled;
  final double draw;
  final String label;
  final VoidCallback onPress;
  final ValueChanged<double> onPull;
  final VoidCallback onRelease;

  /// Drag this far down for a full draw.
  static const fullPullPx = 160.0;

  @override
  State<_BowPad> createState() => _BowPadState();
}

class _BowPadState extends State<_BowPad> {
  double _dy = 0;
  bool _down = false;

  void _end() {
    if (!_down) return;
    _down = false;
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        if (!widget.enabled) return;
        _dy = 0;
        _down = true;
        widget.onPress();
      },
      onPanUpdate: (e) {
        if (!_down) return;
        _dy = math.max(0, _dy + e.delta.dy);
        widget.onPull((_dy / _BowPad.fullPullPx).clamp(0.0, 1.0));
      },
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            height: 110,
            child: _StripFrame(asset: 'assets/ar_sprites/bow_draw.png', frames: 6, frame: (widget.draw * 5).round())),
        Text(widget.label,
            textAlign: TextAlign.center,
            style: PixelType.title(context, color: widget.enabled ? PixelPalette.sun : PixelPalette.mist)
                .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(2, 2))])),
      ]),
    );
  }
}

/// One frame of a horizontal pixel-art strip, drawn crisp (nearest pixel).
class _StripFrame extends StatefulWidget {
  const _StripFrame({required this.asset, required this.frames, required this.frame});
  final String asset;
  final int frames;
  final int frame;

  @override
  State<_StripFrame> createState() => _StripFrameState();
}

class _StripFrameState extends State<_StripFrame> {
  static final Map<String, ui.Image> _cache = {};
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _image = _cache[widget.asset];
    if (_image == null) _load();
  }

  Future<void> _load() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      _cache[widget.asset] = img;
      if (mounted) setState(() => _image = img);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _StripPainter(img, widget.frames, widget.frame.clamp(0, widget.frames - 1)),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image, this.frames, this.frame);
  final ui.Image image;
  final int frames;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final fw = image.width / frames, fh = image.height.toDouble();
    final k = math.min(size.width / fw, size.height / fh);
    final w = fw * k, h = fh * k;
    final dst = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
    canvas.drawImageRect(image, Rect.fromLTWH(fw * frame, 0, fw, fh), dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.frame != frame || old.image != image;
}
