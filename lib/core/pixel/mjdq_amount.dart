import 'package:flutter/material.dart';

import 'generated/designer_art.g.dart';
import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

/// Displays an mJDQ amount as `<number>` followed by the pixel coin sprite,
/// exposing `"<number> mJDQ"` to screen readers via [Semantics].
///
/// When [animate] is true (or [animateOnIncrease] is true and [amount] rises),
/// plays the 7-frame [DesignerArt.coinAnim] once at 10 fps and settles on
/// frame 1. Respects reduced-motion accessibility settings.
class MjdqAmount extends StatefulWidget {
  const MjdqAmount(
    this.amount, {
    super.key,
    this.sign = false,
    this.scale = 1.0,
    this.animate = false,
    this.animateOnIncrease = false,
    this.idleSpin = false,
    this.prefix,
    this.suffix,
    this.style,
    this.color,
    this.coinSize,
  });

  final int amount;
  final bool sign;
  final double scale;
  final bool animate;
  final bool animateOnIncrease;

  /// Plan 100 WP-6: the coin spins continuously (balances on Home and
  /// Profile), like the Pixel lab preview (owner 2026-11-16: "no pause").
  final bool idleSpin;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Color? color;
  final double? coinSize;

  @override
  State<MjdqAmount> createState() => _MjdqAmountState();
}

/// The coin strip turns edge-on (0) to face-on (3) and back to edge-on (6);
/// the coin rests facing front.
const _coinFront = 3;

/// One full turn from front to front: 3 4 5 6 0 1 2 3.
const _coinTurn = [3, 4, 5, 6, 0, 1, 2, 3];

/// The same turn as an endless loop at the strip's own speed (10 fps).
final _coinLoop = PixelFrames(
  'coinLoop',
  fps: DesignerArt.coinAnim.fps,
  frames: [for (final i in _coinTurn.take(7)) DesignerArt.coinAnim.frames[i]],
);

/// Owner 2026-11-16: start facing front, smooth in and out. Plays one eased
/// turn (slow, fast in the middle, slow again) instead of a flat frame rate.
class _CoinSpin extends StatefulWidget {
  const _CoinSpin({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_CoinSpin> createState() => _CoinSpinState();
}

class _CoinSpinState extends State<_CoinSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  late final Animation<double> _eased =
      CurvedAnimation(parent: _turn, curve: Curves.easeInOutSine);

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _eased,
        builder: (context, _) {
          final i = (_eased.value * (_coinTurn.length - 1)).round();
          return PixelSprite(DesignerArt.coinAnim.frames[_coinTurn[i]],
              scale: 1);
        },
      );
}

class _MjdqAmountState extends State<MjdqAmount> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playing = widget.animate;
  }

  @override
  void didUpdateWidget(MjdqAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    final triggeredByFlag = widget.animate && !oldWidget.animate;
    final triggeredByGain =
        widget.animateOnIncrease && widget.amount > oldWidget.amount;
    if (triggeredByFlag || triggeredByGain) {
      _playing = true;
    } else if (!widget.animate && !widget.animateOnIncrease) {
      _playing = false;
    }
  }

  String get _numberText {
    if (widget.sign && widget.amount > 0) return '+${widget.amount}';
    return '${widget.amount}';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final play = _playing && !reducedMotion;
    final baseStyle = widget.style ??
        PixelType.small(context, color: widget.color ?? PixelPalette.ink);
    final effectiveStyle = widget.color != null
        ? baseStyle.copyWith(color: widget.color)
        : baseStyle;
    final numText = _numberText;
    final leftText = '${widget.prefix ?? ''}$numText';
    final rightText = widget.suffix ?? '';
    final semanticLabel =
        '${widget.prefix ?? ''}$numText mJDQ${rightText.isEmpty ? '' : ' $rightText'}'
            .trim();
    final dim = widget.coinSize ?? (16.0 * widget.scale);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              leftText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: effectiveStyle,
            ),
          ),
          SizedBox(width: grid.px(1)),
          SizedBox.square(
            dimension: dim,
            child: FittedBox(
              fit: BoxFit.contain,
              child: widget.idleSpin && !reducedMotion
                  // Continuous loop from the front face; the ticker stops
                  // on off-screen routes (TickerMode).
                  ? PixelAnimation(_coinLoop, scale: 1)
                  : play
                      ? _CoinSpin(
                          onDone: () {
                            if (mounted) setState(() => _playing = false);
                          },
                        )
                      : PixelSprite(
                          DesignerArt.coinAnim.frames[_coinFront],
                          scale: 1,
                        ),
            ),
          ),
          if (rightText.isNotEmpty) ...[
            SizedBox(width: grid.px(1)),
            Flexible(
              child: Text(
                rightText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: effectiveStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A [PixelPanel]-backed chip wrapping [MjdqAmount], matching [PixelChip].
class MjdqChip extends StatelessWidget {
  const MjdqChip(
    this.amount, {
    super.key,
    this.sign = false,
    this.scale = 1.0,
    this.animate = false,
    this.animateOnIncrease = false,
    this.idleSpin = false,
    this.prefix,
    this.suffix,
    this.style = PixelBoxStyle.gold,
    this.textColor = PixelPalette.ink,
  });

  final int amount;
  final bool sign;
  final double scale;
  final bool animate;
  final bool animateOnIncrease;
  final bool idleSpin;
  final String? prefix;
  final String? suffix;
  final PixelBoxStyle style;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: style.copyWith(corner: 1, shadowPx: 0),
      padding: 2,
      child: MjdqAmount(
        amount,
        sign: sign,
        scale: scale,
        animate: animate,
        animateOnIncrease: animateOnIncrease,
        idleSpin: idleSpin,
        prefix: prefix,
        suffix: suffix,
        color: textColor,
      ),
    );
  }
}
