import 'dart:async';

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

  /// Plan 100 WP-6: replay the coin spin every [idleSpinEvery] (balances on
  /// Home and Profile), so the coin is visibly alive.
  final bool idleSpin;
  static const idleSpinEvery = Duration(seconds: 4);
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Color? color;
  final double? coinSize;

  @override
  State<MjdqAmount> createState() => _MjdqAmountState();
}

class _MjdqAmountState extends State<MjdqAmount> {
  bool _playing = false;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    _playing = widget.animate;
    _syncIdle();
  }

  void _syncIdle() {
    if (widget.idleSpin && _idle == null) {
      _idle = Timer.periodic(MjdqAmount.idleSpinEvery, (_) {
        // Off-screen routes and reduced motion keep the coin still.
        if (!mounted ||
            _playing ||
            !TickerMode.of(context) ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
          return;
        }
        setState(() => _playing = true);
      });
    } else if (!widget.idleSpin) {
      _idle?.cancel();
      _idle = null;
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MjdqAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    final triggeredByFlag = widget.animate && !oldWidget.animate;
    final triggeredByGain =
        widget.animateOnIncrease && widget.amount > oldWidget.amount;
    if (triggeredByFlag || triggeredByGain) {
      _playing = true;
    } else if (!widget.animate &&
        !widget.animateOnIncrease &&
        !widget.idleSpin) {
      _playing = false;
    }
    _syncIdle();
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
    final effectiveStyle =
        widget.color != null ? baseStyle.copyWith(color: widget.color) : baseStyle;
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
              child: play
                  ? PixelAnimation(
                      DesignerArt.coinAnim,
                      scale: 1,
                      loop: false,
                      playing: true,
                      onDone: () {
                        if (mounted) setState(() => _playing = false);
                      },
                    )
                  : PixelSprite(DesignerArt.coinAnim.frames.first, scale: 1),
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
