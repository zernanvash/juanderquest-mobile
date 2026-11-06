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

  @override
  Widget build(BuildContext context) {
    final playing = game.placed && !game.won;
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
      Positioned.fill(child: _bars(context)),
    ]);
  }

  Widget _bars(BuildContext context) {
    final playing = game.placed && !game.won;
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
              ignoring: !game.won,
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
    if (game.won) {
      return SingleChildScrollView(
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(child: Text('PANALO!', style: PixelType.display(context, color: PixelPalette.greenDeep))),
            const SizedBox(height: 6),
            Text(game.wonText, textAlign: TextAlign.center, style: PixelType.body(context)),
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
          label: placing ? 'LOOKING FOR FLOOR…' : game.placeLabel,
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
