import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_text.dart';
import 'tumbang_preso.dart';

/// On-screen controls for Tumbang Preso, drawn by Flutter over the AR view.
/// Plain values in, callbacks out, so it can be tested without a camera.
class TumbangPresoHud extends StatelessWidget {
  const TumbangPresoHud({
    super.key,
    required this.phase,
    required this.hits,
    required this.targetHits,
    required this.power,
    required this.sweetSpot,
    required this.distanceM,
    required this.offAimDeg,
    required this.canInView,
    required this.callout,
    required this.onPlace,
    required this.onMove,
    required this.onRestart,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.placing = false,
  });

  final TumbangPhase phase;
  final int hits;
  final int targetHits;
  final double power;
  final ({double from, double to})? sweetSpot;
  final double? distanceM;
  final double? offAimDeg;
  final bool canInView;
  final String? callout;
  final bool placing;
  final VoidCallback onPlace;
  final VoidCallback onMove;
  final VoidCallback onRestart;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final playing = phase != TumbangPhase.placing && phase != TumbangPhase.won;
    // Callouts and hints float in the middle; the bars only scroll when a tiny
    // screen with very large text cannot fit them.
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
                      if (phase == TumbangPhase.placing) _placeCard(context),
                      if (playing) _controls(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: phase != TumbangPhase.won,
              child: Center(child: _middle(context)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _top(BuildContext context) {
    return PixelPanel(
      style: PixelBoxStyle.inkDialogue,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text('TUMBANG PRESO', style: PixelType.title(context, color: PixelPalette.sun)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < targetHits; i++)
              Container(
                key: ValueKey('hit_pip_$i'),
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i < hits ? PixelPalette.sun : PixelPalette.slate,
                  border: Border.all(color: PixelPalette.paper, width: 2),
                ),
              ),
            const SizedBox(width: 4),
            Text('$hits/$targetHits', style: PixelType.numbers(context, color: PixelPalette.paper)),
          ]),
          if (distanceM != null)
            Text('LATA ${distanceM!.toStringAsFixed(1)} m', style: PixelType.small(context, color: PixelPalette.mist)),
        ],
      ),
    );
  }

  /// Which way to turn when the aim is outside the assist cone.
  String? _aimHint() {
    final d = offAimDeg;
    if (phase == TumbangPhase.placing || !canInView || d == null || d.abs() <= TumbangPresoGame.assistDeg) {
      return null;
    }
    return d < 0 ? '◀ TURN LEFT' : 'TURN RIGHT ▶';
  }

  Widget _middle(BuildContext context) {
    if (phase == TumbangPhase.won) {
      return SingleChildScrollView(child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(child: Text('PANALO!', style: PixelType.display(context, color: PixelPalette.greenDeep))),
          const SizedBox(height: 6),
          Text('You knocked the lata $targetHits times.', textAlign: TextAlign.center, style: PixelType.body(context)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            PixelButton(label: 'PLAY AGAIN', onPressed: onRestart),
            PixelButton(label: 'MOVE CAN', variant: PixelButtonVariant.secondary, onPressed: onMove),
          ]),
        ]),
      ));
    }
    final hint = _aimHint();
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
      if (phase != TumbangPhase.placing && !canInView)
        _pill(context, 'FIND THE LATA: point your phone back at it'),
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
        Text('Point at open ground 3–4 steps away, then place the lata.',
            textAlign: TextAlign.center, style: PixelType.body(context)),
        const SizedBox(height: 8),
        PixelButton(
          key: const ValueKey('place_can'),
          label: placing ? 'LOOKING FOR FLOOR…' : 'PLACE LATA',
          expand: true,
          onPressed: placing ? null : onPlace,
        ),
      ]),
    );
  }

  Widget _controls(BuildContext context) {
    final canThrow = phase == TumbangPhase.ready || phase == TumbangPhase.charging;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 26,
        child: CustomPaint(
          key: const ValueKey('power_bar'),
          painter: _PowerBarPainter(power: power, sweet: sweetSpot),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        sweetSpot == null ? 'Too close or too far: move to 2–6 m from the lata.' : 'Release in the GREEN to hit.',
        textAlign: TextAlign.center,
        style: PixelType.small(context, color: PixelPalette.paper)
            .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(1, 1))]),
      ),
      const SizedBox(height: 6),
      Listener(
        key: const ValueKey('throw_button'),
        onPointerDown: canThrow ? (_) => onHoldStart() : null,
        onPointerUp: canThrow ? (_) => onHoldEnd() : null,
        onPointerCancel: canThrow ? (_) => onHoldEnd() : null,
        child: PixelPanel(
          style: canThrow ? PixelBoxStyle.green : PixelBoxStyle.stone,
          pressed: phase == TumbangPhase.charging,
          child: SizedBox(
            height: 52,
            child: Center(
              child: FittedBox(
                child: Text(
                  phase == TumbangPhase.charging ? 'RELEASE TO THROW!' : 'HOLD TO THROW',
                  style: PixelType.title(context, color: PixelPalette.white),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Align(
        child: PixelButton(label: 'MOVE LATA', variant: PixelButtonVariant.ghost, onPressed: onMove),
      ),
    ]);
  }
}

class _PowerBarPainter extends CustomPainter {
  _PowerBarPainter({required this.power, required this.sweet});
  final double power;
  final ({double from, double to})? sweet;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = PixelPalette.ink);
    final inner = r.deflate(3);
    canvas.drawRect(inner, Paint()..color = PixelPalette.slate);
    final s = sweet;
    if (s != null) {
      canvas.drawRect(
        Rect.fromLTRB(inner.left + inner.width * s.from, inner.top, inner.left + inner.width * s.to, inner.bottom),
        Paint()..color = PixelPalette.greenMid,
      );
    }
    final fill = Rect.fromLTWH(inner.left, inner.top + inner.height * 0.3, inner.width * power, inner.height * 0.4);
    canvas.drawRect(fill, Paint()..color = PixelPalette.sun);
    final x = inner.left + inner.width * power;
    canvas.drawRect(Rect.fromLTWH(x - 2, r.top, 4, r.height), Paint()..color = PixelPalette.paper);
  }

  @override
  bool shouldRepaint(_PowerBarPainter old) => old.power != power || old.sweet != sweet;
}
