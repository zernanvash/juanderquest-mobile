import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Where the `bow_fps` arrow aims, in sprite pixels (its manifest pivot; a
  /// test keeps them equal). The HUD puts this point on the sight.
  static const bowAimX = -34.6, bowAimY = 99.1;

  /// Swipe-up throw: how far the swipe leaned from straight up, in degrees.
  final ValueChanged<double>? onSwipe;

  /// Bow string pulled back, 0..1.
  final ValueChanged<double>? onPull;

  @override
  Widget build(BuildContext context) {
    final playing = game.placed && !game.over;
    final sight = playing ? game.sight(now, pose) : null;
    final tone = playing && sight == null ? game.tone(now, pose) : null;
    final swipe = game.buttonMode == ArButtonMode.swipe;
    final badge = playing ? game.toneBadge(now, pose) : null;
    final prop = playing ? game.prop(now) : null;
    // The aim circle sits in the true middle of the screen (where the camera looks).
    return Stack(children: [
      if (sight != null) ...[
        // Pana: a first-person bow whose arrow points at the sight (Plan 77b).
        Positioned.fill(child: IgnorePointer(child: _FpsBow(sight: sight, now: now))),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(key: const ValueKey('bow_sight'), painter: _SightPainter(sight)),
          ),
        ),
        if (sight.wind != 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -64),
                  child: Text(
                    _windText(sight.wind),
                    key: const ValueKey('wind_badge'),
                    style: PixelType.small(context, color: PixelPalette.sun)
                        .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(1, 1))]),
                  ),
                ),
              ),
            ),
          ),
      ],
      if (tone != null && !swipe)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox.square(
                key: ValueKey('reticle_${tone == ArTone.on}'),
                dimension: 64,
                child: CustomPaint(painter: _ReticlePainter(tone: tone)),
              ),
            ),
          ),
        ),
      // Ring Shoot: the ball flies along this centre line (where the phone
      // points); it lights up green with a rim tick when you are lined up.
      if (playing && swipe)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('aim_line_${tone == ArTone.on}'),
              painter: _AimLinePainter(on: tone == ArTone.on),
            ),
          ),
        ),
      if (badge != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              child: Transform.translate(
                offset: const Offset(0, -56),
                child: Text(
                  badge,
                  key: const ValueKey('tone_badge'),
                  style: PixelType.small(context, color: PixelPalette.orange)
                      .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(1, 1))]),
                ),
              ),
            ),
          ),
        ),
      // Piring (Palayok): a woven-cloth vignette; the middle still peeks through.
      if (game.placed && game.blind(now))
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: ValueKey('blindfold'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.75,
                  colors: [Color(0x4014100C), Color(0xB814100C), Color(0xEB14100C)],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
      // The held prop (ball, tsinelas, stick) at the bottom of the screen.
      if (prop != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment(prop.x, prop.y),
              child: Transform.translate(
                offset: Offset(0, prop.dy - (swipe ? game.dragUp : 0)),
                child: Transform.rotate(
                  angle: prop.turn,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox.square(
                    key: ValueKey('prop_${prop.sheet}'),
                    dimension: prop.size,
                    child: _StripFrame(
                        asset: 'assets/ar_sprites/${prop.sheet}.png', frames: prop.frames, frame: prop.frame),
                  ),
                ),
              ),
            ),
          ),
        ),
      Positioned.fill(child: _bars(context)),
      // Pana and Ring Shoot: pull or swipe anywhere in the play area, not just a
      // strip at the bottom (the top bar and MOVE IT stay tappable).
      if (playing && (game.buttonMode == ArButtonMode.pull || swipe))
        Positioned.fill(
          top: MediaQuery.sizeOf(context).height * 0.18,
          bottom: 96 + MediaQuery.paddingOf(context).bottom,
          child: _GestureZone(
            key: ValueKey(swipe ? 'swipe_area' : 'pull_area'),
            pull: !swipe,
            fullArea: true,
            enabled: game.canPress(now) || pressed,
            label: game.buttonLabel(now),
            onSwipe: (deg) => onSwipe?.call(deg),
            onPress: onPress,
            onPull: (v) => onPull?.call(v),
            onRelease: onRelease,
            onDrag: (up) => game.dragUp = up,
          ),
        ),
    ]);
  }

  static String _windText(int w) => w > 0 ? 'WIND $w ${'▶' * w}' : '${'◀' * -w} WIND ${-w}';

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
      if (meter != null && game.buttonMode != ArButtonMode.pull)
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
      if (game.buttonMode == ArButtonMode.pull || game.buttonMode == ArButtonMode.swipe)
        IgnorePointer(
          key: const ValueKey('game_button'),
          child: _GestureZone(
            pull: game.buttonMode == ArButtonMode.pull,
            enabled: can,
            label: game.buttonLabel(now),
            onSwipe: (_) {},
            onPress: () {},
            onPull: (_) {},
            onRelease: () {},
          ),
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
  _ReticlePainter({required this.tone});
  final ArTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final c = switch (tone) {
      ArTone.on => PixelPalette.greenMid,
      ArTone.wait => PixelPalette.sun,
      ArTone.blocked => PixelPalette.orange,
      ArTone.idle => PixelPalette.paper,
    };
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
  bool shouldRepaint(_ReticlePainter old) => old.tone != tone;
}

/// Where you swipe: no button, just a subtle hint and a finger showing the
/// gesture (owner 2026-11-07: "remove the button ... just put a subtle swipe to
/// shoot text with gesture swiping cursor"). Swipe up throws (Ring Shoot); with
/// [pull], drag down to pull the bow string and let go to shoot (Pana).
class _GestureZone extends StatefulWidget {
  const _GestureZone({
    super.key,
    required this.pull,
    required this.enabled,
    required this.label,
    required this.onSwipe,
    required this.onPress,
    required this.onPull,
    required this.onRelease,
    this.fullArea = false,
    this.onDrag,
  });

  /// Swipe: how far (dp) the finger is up from where it started (0 at the end).
  final ValueChanged<double>? onDrag;
  final bool pull;

  /// Covers the play area: only catches gestures, draws nothing.
  final bool fullArea;
  final bool enabled;
  final String label;
  final ValueChanged<double> onSwipe;
  final VoidCallback onPress;
  final ValueChanged<double> onPull;
  final VoidCallback onRelease;

  /// Drag this far down for a full draw (Plan 77b: comfortable for one thumb).
  static const fullPullPx = 95.0;

  /// Draw levels that click as you pass them, like a ratcheting string.
  static const notches = [0.25, 0.5, 0.75, 0.9];

  @override
  State<_GestureZone> createState() => _GestureZoneState();
}

class _GestureZoneState extends State<_GestureZone> with SingleTickerProviderStateMixin {
  late final AnimationController _hand = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Offset _d = Offset.zero;
  bool _down = false;
  bool _used = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still || _used) {
      _hand.stop();
    } else if (!_hand.isAnimating) {
      _hand.repeat();
    }
  }

  @override
  void dispose() {
    _hand.dispose();
    super.dispose();
  }

  void _start() {
    _d = Offset.zero;
    if (!widget.enabled) return;
    if (!_used) setState(() => _used = true);
    _hand.stop();
    if (widget.pull) {
      _down = true;
      _lastDraw = 0;
      widget.onPress();
    }
  }

  double _lastDraw = 0;

  void _update(DragUpdateDetails e) {
    _d += e.delta;
    if (!widget.pull) widget.onDrag?.call(math.max(0.0, -_d.dy).clamp(0.0, 80.0));
    if (!widget.pull || !_down) return;
    final v = (math.max(0.0, _d.dy) / _GestureZone.fullPullPx).clamp(0.0, 1.0);
    for (final n in _GestureZone.notches) {
      if (_lastDraw < n && v >= n) HapticFeedback.selectionClick();
    }
    _lastDraw = v;
    widget.onPull(v);
  }

  void _end() {
    if (widget.pull) {
      if (!_down) return;
      _down = false;
      widget.onRelease();
      return;
    }
    widget.onDrag?.call(0);
    // An upward flick of at least 40 px throws.
    if (widget.enabled && _d.dy < -40) widget.onSwipe(math.atan2(_d.dx, -_d.dy) * 180 / math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final up = !widget.pull;
    if (widget.fullArea) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _start(),
        onPanUpdate: _update,
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _start(),
      onPanUpdate: _update,
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: SizedBox(
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          if (!_used && widget.enabled)
            AnimatedBuilder(
              animation: _hand,
              builder: (context, child) {
                final t = Curves.easeInOut.transform((_hand.value * 1.25).clamp(0.0, 1.0));
                final dy = (up ? 30 - 60 * t : -30 + 60 * t);
                final fade = _hand.value > 0.85 ? (1 - _hand.value) / 0.15 : 1.0;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Opacity(opacity: (0.75 * fade).clamp(0.0, 1.0), child: child),
                );
              },
              child: const Icon(Icons.touch_app, size: 44, color: PixelPalette.paper, shadows: [
                Shadow(color: PixelPalette.ink, offset: Offset(2, 2)),
              ]),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              '${up ? '▲ ' : '▼ '}${widget.label}',
              textAlign: TextAlign.center,
              style: PixelType.small(context, color: widget.enabled ? PixelPalette.paper : PixelPalette.mist)
                  .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(1, 1))]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A faint aiming lane down the middle of the screen with a centre line.
class _AimLinePainter extends CustomPainter {
  const _AimLinePainter({required this.on});

  /// Lined up with the ring: green, with a rim tick across the middle.
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = (size.width / 2).floorToDouble();
    final cy = (size.height / 2).floorToDouble();
    canvas.drawRect(Rect.fromLTWH(cx - 16, 0, 32, size.height),
        Paint()..color = on ? const Color(0x2246B05A) : const Color(0x14FFFFFF));
    final dash = Paint()..color = on ? PixelPalette.greenMid : const Color(0x8CFFFFFF);
    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawRect(Rect.fromLTWH(cx - 1, y, 2, 8), dash);
    }
    if (on) canvas.drawRect(Rect.fromLTWH(cx - 20, cy - 2, 40, 4), Paint()..color = PixelPalette.greenMid);
  }

  @override
  bool shouldRepaint(_AimLinePainter old) => old.on != on;
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

/// The first-person bow (Plan 77b): placed so the arrow's line points at the
/// sight in the middle of the screen; pulls closer and bends with the draw,
/// trembles at full draw, kicks up on release and shows an empty bow until the
/// next arrow is nocked.
class _FpsBow extends StatelessWidget {
  const _FpsBow({required this.sight, required this.now});
  final ArSight sight;
  final double now;

  static const frameW = 240.0, frameH = 360.0;
  static const aimX = ArMiniGameHud.bowAimX, aimY = ArMiniGameHud.bowAimY;
  static const frames = 7, emptyFrame = 6;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final d = sight.draw;
    final k = math.min(size.width * 0.55, 260.0) / frameW * (1 + 0.06 * d);
    var dy = 18 * d;
    var dx = 0.0;
    if (d >= 0.9) dx = (now * 16).floor().isEven ? 1 : -1; // string tension
    if (!sight.loaded && sight.sinceRelease < 0.12) dy -= 8 * (1 - sight.sinceRelease / 0.12); // recoil
    final frame = sight.loaded ? (d * 5).round() : emptyFrame;
    return Stack(children: [
      Positioned(
        key: const ValueKey('fps_bow'),
        left: size.width / 2 - aimX * k + dx,
        top: size.height / 2 - aimY * k + dy,
        width: frameW * k,
        height: frameH * k,
        child: _StripFrame(asset: 'assets/ar_sprites/bow_fps.png', frames: frames, frame: frame),
      ),
    ]);
  }
}

/// Bow sight: four corner brackets that close in as you draw (64 to 32 px),
/// gold at full draw, green on the target; a centre dot and a pin where the
/// arrow will land (drop and wind).
class _SightPainter extends CustomPainter {
  _SightPainter(this.sight);
  final ArSight sight;

  /// Rough degrees-to-pixels for a phone camera (about 62 degrees across the
  /// screen height in portrait).
  static const _fovDeg = 62.0;

  @override
  void paint(Canvas canvas, Size size) {
    const px = 4.0;
    final c = size.center(Offset.zero);
    final colour = sight.onTarget ? PixelPalette.greenMid : (sight.draw >= 0.9 ? PixelPalette.sun : PixelPalette.paper);
    final half = ((64 - 32 * sight.draw) / 2 / px).round() * px;
    final ink = Paint()..color = PixelPalette.ink;
    final fill = Paint()..color = colour;
    void block(double x, double y, Paint p) => canvas.drawRect(Rect.fromLTWH(x, y, px, px), p);
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final x = c.dx + sx * half - (sx > 0 ? px : 0);
        final y = c.dy + sy * half - (sy > 0 ? px : 0);
        for (var i = 0; i < 3; i++) {
          block(x - sx * i * px, y, i == 2 ? ink : fill);
          block(x, y - sy * i * px, i == 2 ? ink : fill);
        }
      }
    }
    block(c.dx - px / 2, c.dy - px / 2, fill);
    // Landing pin.
    final perDeg = size.height / _fovDeg;
    final pin = c + Offset(sight.pinRightDeg * perDeg, sight.pinDownDeg * perDeg);
    canvas.drawRect(Rect.fromCenter(center: pin, width: px * 2 + 2, height: px * 2 + 2), ink);
    canvas.drawRect(
        Rect.fromCenter(center: pin, width: px * 2 - 2, height: px * 2 - 2), Paint()..color = PixelPalette.sun);
  }

  @override
  bool shouldRepaint(_SightPainter old) => old.sight != sight;
}
