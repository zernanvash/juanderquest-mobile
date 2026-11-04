import 'package:flutter/material.dart';

import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_text.dart';

/// Full-width pixel button with custom [PixelBoxStyle] (e.g. gold, green, wood)
/// for celebration scenes.
class CelebrationButton extends StatefulWidget {
  const CelebrationButton({
    super.key,
    required this.label,
    this.onPressed,
    required this.style,
    required this.textColor,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PixelBoxStyle style;
  final Color textColor;
  final bool expand;

  @override
  State<CelebrationButton> createState() => _CelebrationButtonState();
}

class _CelebrationButtonState extends State<CelebrationButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final boxStyle = widget.style.copyWith(shadowPx: 1);

    final content = Center(
      widthFactor: widget.expand ? null : 1,
      heightFactor: 1,
      child: ShadowText(
        widget.label,
        style: PixelType.body(context, color: widget.textColor).copyWith(
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _down = false);
                  pixelTick(context);
                  widget.onPressed!();
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: PixelPanel(
              style: boxStyle,
              padding: 2,
              pressed: _down,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
