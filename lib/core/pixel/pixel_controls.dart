import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

void pixelTick(BuildContext context) {
  if (PixelScope.of(context).haptics) HapticFeedback.selectionClick();
}

enum PixelButtonVariant { primary, secondary, danger, ghost }

const _ghostStyle = PixelBoxStyle(
  fill: PixelPalette.paper,
  highlight: PixelPalette.paper,
  shade: PixelPalette.paperDim,
  outline: PixelPalette.ink,
  corner: 1,
  shadowPx: 0,
  bevel: false,
);

const _disabledStyle = PixelBoxStyle(
  fill: PixelPalette.paperDim,
  highlight: PixelPalette.paperDim,
  shade: PixelPalette.mist,
  outline: PixelPalette.stone,
  corner: 1,
  shadowPx: 0,
  bevel: false,
);

PixelBoxStyle _buttonStyle(PixelButtonVariant variant) => switch (variant) {
      PixelButtonVariant.primary => PixelBoxStyle.green,
      PixelButtonVariant.secondary => PixelBoxStyle.parchment,
      PixelButtonVariant.danger => PixelBoxStyle.red,
      PixelButtonVariant.ghost => _ghostStyle,
    };

Color _buttonText(PixelButtonVariant variant) => switch (variant) {
      PixelButtonVariant.primary => PixelPalette.white,
      PixelButtonVariant.secondary => PixelPalette.ink,
      PixelButtonVariant.danger => PixelPalette.white,
      PixelButtonVariant.ghost => PixelPalette.ink,
    };

class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PixelButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.iconScale = 3,
    this.style,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final PixelButtonVariant variant;
  final PixelArt? icon;
  final bool expand;
  final bool loading;
  final int iconScale;
  final PixelBoxStyle? style;
  final Color? textColor;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final style = enabled
        ? (widget.style ?? _buttonStyle(widget.variant)).copyWith(shadowPx: 1)
        : _disabledStyle;
    final textColor = enabled
        ? (widget.textColor ?? _buttonText(widget.variant))
        : PixelPalette.slate;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          _SteppedDots(color: textColor),
          SizedBox(width: grid.px(2)),
        ] else if (widget.icon != null) ...[
          PixelSprite(widget.icon!, scale: widget.iconScale),
          SizedBox(width: grid.px(2)),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ShadowText(
              widget.label,
              style: PixelType.body(context, color: textColor).copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.loading ? '${widget.label} loading' : widget.label,
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
              style: style,
              padding: 2,
              pressed: _down,
              child: Center(
                widthFactor: widget.expand ? null : 1,
                heightFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelIconButton extends StatefulWidget {
  const PixelIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.style = PixelBoxStyle.parchment,
    this.iconScale = 3,
    this.iconHeight,
  });

  final PixelArt icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final PixelBoxStyle style;
  final int iconScale;
  final double? iconHeight;

  @override
  State<PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<PixelIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scale = widget.iconHeight == null
        ? widget.iconScale
        : (widget.iconHeight! *
                MediaQuery.devicePixelRatioOf(context) /
                widget.icon.height)
            .round()
            .clamp(1, 64)
            .toInt();
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: PixelPanel(
              style: enabled ? widget.style : _disabledStyle,
              padding: 2,
              pressed: _down,
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: PixelSprite(widget.icon, scale: scale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelChip extends StatelessWidget {
  const PixelChip(
    this.label, {
    super.key,
    this.style = PixelBoxStyle.gold,
    this.icon,
    this.textColor = PixelPalette.ink,
    this.onTap,
    this.iconScale = 3,
  });

  final String label;
  final PixelBoxStyle style;
  final PixelArt? icon;
  final Color textColor;
  final VoidCallback? onTap;
  final int iconScale;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final child = PixelPanel(
      style: style.copyWith(corner: 1, shadowPx: onTap == null ? 0 : 1),
      padding: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            PixelSprite(icon!, scale: iconScale),
            SizedBox(width: grid.px(1)),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: PixelType.small(context, color: textColor),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () {
            pixelTick(context);
            onTap!();
          },
          child: child,
        ),
      ),
    );
  }
}

class PixelSwitch extends StatelessWidget {
  const PixelSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      toggled: value,
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onChanged(!value);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: SizedBox(
                width: grid.px(22),
                height: grid.px(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PixelPanel(
                        style:
                            value ? PixelBoxStyle.green : PixelBoxStyle.stone,
                        sunken: true,
                        padding: 0,
                        child: const SizedBox(),
                      ),
                    ),
                    Positioned(
                      left: value ? grid.px(11) : grid.px(1),
                      top: grid.px(1),
                      width: grid.px(10),
                      height: grid.px(10),
                      child: const PixelPanel(
                        style: PixelBoxStyle.parchment,
                        padding: 0,
                        child: SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelCheckbox extends StatelessWidget {
  const PixelCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final box = SizedBox(
      width: grid.px(14),
      height: grid.px(14),
      child: PixelPanel(
        style: PixelBoxStyle.slot,
        sunken: true,
        padding: 1,
        child: SizedBox(
          width: grid.px(10),
          height: grid.px(10),
          child: value
              ? CustomPaint(painter: _CheckPainter(grid))
              : const SizedBox(),
        ),
      ),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        if (label != null) ...[
          SizedBox(width: grid.px(2)),
          Flexible(
            child: Text(label!, style: PixelType.body(context)),
          ),
        ],
      ],
    );
    return Semantics(
      checked: value,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onChanged(!value);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class PixelRadio extends StatelessWidget {
  const PixelRadio({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final bool selected;
  final VoidCallback onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final box = SizedBox(
      width: grid.px(14),
      height: grid.px(14),
      child: PixelPanel(
        style: PixelBoxStyle.slot,
        sunken: true,
        padding: 1,
        child: Center(
          child: selected
              ? SizedBox(
                  width: grid.px(6),
                  height: grid.px(6),
                  child: const PixelPanel(
                    style: PixelBoxStyle.green,
                    padding: 0,
                    child: SizedBox(),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        if (label != null) ...[
          SizedBox(width: grid.px(2)),
          Flexible(child: Text(label!, style: PixelType.body(context))),
        ],
      ],
    );
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onChanged();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class PixelSegmented extends StatelessWidget {
  const PixelSegmented({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(SizedBox(width: grid.px(1)));
      final selected = i == selectedIndex;
      children.add(
        Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: items[i],
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  pixelTick(context);
                  onChanged(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: PixelPanel(
                    style: selected
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.slot.copyWith(
                            outline: PixelPalette.stone,
                          ),
                    sunken: !selected,
                    padding: 1,
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        items[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: PixelType.small(
                          context,
                          color:
                              selected ? PixelPalette.ink : PixelPalette.slate,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

class PixelSlider extends StatelessWidget {
  const PixelSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.divisions = 10,
    this.color = PixelPalette.green,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final int divisions;
  final Color color;
  final String? semanticLabel;

  void _emit(BuildContext context, double fraction) {
    final snap = (fraction.clamp(0, 1) * divisions).round() / divisions;
    onChanged?.call(snap);
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final enabled = onChanged != null;
    final current = value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      slider: true,
      enabled: enabled,
      label: semanticLabel,
      value: '${(current * 100).round()} percent',
      increasedValue: '${math.min(100, (current * 100).round() + 10)} percent',
      decreasedValue: '${math.max(0, (current * 100).round() - 10)} percent',
      onIncrease: enabled
          ? () => _emit(context, (current * divisions + 1) / divisions)
          : null,
      onDecrease: enabled
          ? () => _emit(context, (current * divisions - 1) / divisions)
          : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: grid.px(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: enabled
                    ? (details) => _emit(
                          context,
                          details.localPosition.dx / constraints.maxWidth,
                        )
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (details) => _emit(
                          context,
                          details.localPosition.dx / constraints.maxWidth,
                        )
                    : null,
                child: CustomPaint(
                  painter: _SliderPainter(
                    grid: grid,
                    value: current,
                    divisions: divisions,
                    color: enabled ? color : PixelPalette.stone,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SteppedDots extends StatefulWidget {
  const _SteppedDots({required this.color});

  final Color color;

  @override
  State<_SteppedDots> createState() => _SteppedDotsState();
}

class _SteppedDotsState extends State<_SteppedDots> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      width: grid.px(10),
      height: grid.px(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            SizedBox(
              width: grid.px(2),
              height: grid.px(2),
              child: ColoredBox(
                color: i == _step
                    ? widget.color
                    : widget.color.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.grid);

  final PixelGrid grid;

  static const _points = <(int, int)>[
    (0, 4),
    (1, 5),
    (2, 6),
    (3, 5),
    (4, 4),
    (5, 3),
    (6, 2),
    (7, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()
      ..color = PixelPalette.greenBright
      ..isAntiAlias = false;
    for (final point in _points) {
      canvas.drawRect(
        Rect.fromLTWH(
          grid.snap((point.$1 + 1) * u),
          grid.snap((point.$2 + 1) * u),
          grid.snap(u),
          grid.snap(u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.grid.unit != grid.unit;
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.grid,
    required this.value,
    required this.divisions,
    required this.color,
  });

  final PixelGrid grid;
  final double value;
  final int divisions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final cols = (size.width / u).floor();
    final rows = (size.height / u).floor();
    if (cols < 16 || rows < 8) return;
    final paint = Paint()..isAntiAlias = false;
    void rect(int x, int y, int w, int h, Color c, int steps) {
      paint.color = c;
      for (final r in steppedRects(x, y, w, h, steps)) {
        canvas.drawRect(
          Rect.fromLTRB(
            grid.snap(r.left * u),
            grid.snap(r.top * u),
            grid.snap(r.right * u),
            grid.snap(r.bottom * u),
          ),
          paint,
        );
      }
    }

    const thumbW = 10;
    final trackW = cols - thumbW;
    final trackY = (rows - 6) ~/ 2;
    rect(0, trackY, trackW, 6, PixelPalette.ink, 1);
    rect(1, trackY + 1, trackW - 2, 4, PixelPalette.paperDim, 0);
    final filled = ((trackW - 2) * value).round().clamp(0, trackW - 2).toInt();
    if (filled > 0) {
      rect(1, trackY + 1, filled, 4, color, 0);
      rect(1, trackY + 1, filled, 1, PixelPalette.white, 0);
      rect(1, trackY + 4, filled, 1, PixelPalette.ink, 0);
    }
    final thumbX =
        (value * (cols - thumbW)).round().clamp(0, cols - thumbW).toInt();
    final thumbY = (rows - 14) ~/ 2;
    rect(thumbX, thumbY, thumbW, 14, PixelPalette.ink, 1);
    rect(thumbX + 1, thumbY + 1, thumbW - 2, 12, PixelPalette.paper, 0);
    rect(thumbX + 1, thumbY + 1, thumbW - 2, 1, PixelPalette.white, 0);
    rect(thumbX + 1, thumbY + 12, thumbW - 2, 1, PixelPalette.mist, 0);
    final steps = divisions;
    for (var i = 1; i < steps; i++) {
      final x = (trackW - 2) * i / steps;
      rect(1 + x.round(), trackY + 2, 1, 2, PixelPalette.stone, 0);
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.value != value ||
      old.grid.unit != grid.unit ||
      old.divisions != divisions ||
      old.color != color;
}
