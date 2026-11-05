import 'dart:async';

import 'package:flutter/material.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

class PixelProgressBar extends StatelessWidget {
  const PixelProgressBar({
    super.key,
    required this.value,
    this.segments = 10,
    this.color = PixelPalette.greenBright,
    this.height = 5,
    this.showTipGlint = false,
  });

  final double value;
  final int segments;
  final Color color;
  final int height;

  /// Plan 75k: a 1 art px sun-light cap on the leading filled segment, so XP
  /// bars read like glowing RPG gauges.
  final bool showTipGlint;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      height: grid.px(height + 2),
      child: PixelSnap(
        child: CustomPaint(
          painter: _BarPainter(
            grid,
            value.clamp(0, 1),
            segments,
            color,
            height,
            showTipGlint,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(
      this.grid, this.value, this.segments, this.color, this.h, this.glint);

  final PixelGrid grid;
  final double value;
  final int segments;
  final Color color;
  final int h;
  final bool glint;

  Rect _r(num x, num y, num w, num hh) => Rect.fromLTRB(
        grid.snap(x * grid.unit),
        grid.snap(y * grid.unit),
        grid.snap((x + w) * grid.unit),
        grid.snap((y + hh) * grid.unit),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / grid.unit).floor();
    if (cols < 4) return;
    final paint = Paint()..isAntiAlias = false;
    paint.color = PixelPalette.ink;
    for (final r in steppedRects(0, 0, cols, h + 2, 1)) {
      canvas.drawRect(_r(r.left, r.top, r.width, r.height), paint);
    }
    paint.color = PixelPalette.slate;
    canvas.drawRect(_r(1, 1, cols - 2, h), paint);
    final inner = cols - 2;
    final segW = ((inner - (segments - 1)) / segments).floor();
    final filled = (value * segments).round();
    if (segW < 1) {
      final w = (inner * value).round();
      if (w > 0) {
        paint.color = color;
        canvas.drawRect(_r(1, 1, w, h), paint);
      }
      return;
    }
    for (var i = 0; i < segments; i++) {
      final x = 1 + i * (segW + 1);
      final on = i < filled;
      paint.color = on ? color : PixelPalette.stone;
      canvas.drawRect(_r(x, 1, segW, h), paint);
      if (on) {
        paint.color = PixelPalette.white;
        canvas.drawRect(_r(x, 1, segW, 1), paint);
        paint.color = PixelPalette.ink;
        canvas.drawRect(_r(x, h, segW, 1), paint);
      }
    }
    if (glint && filled > 0 && filled <= segments) {
      final x = 1 + (filled - 1) * (segW + 1);
      paint.color = PixelPalette.sunLight;
      canvas.drawRect(_r(x + segW - 1, 1, 1, h - 1), paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.grid.unit != grid.unit ||
      old.color != color ||
      old.segments != segments ||
      old.glint != glint;
}

class PixelDialogue extends StatefulWidget {
  const PixelDialogue({
    super.key,
    required this.speaker,
    required this.lines,
    this.portrait,
    this.interval = const Duration(milliseconds: 30),
    this.animate = true,
  });

  final String speaker;
  final List<String> lines;
  final PixelArt? portrait;
  final Duration interval;
  final bool animate;

  @override
  State<PixelDialogue> createState() => _PixelDialogueState();
}

class _PixelDialogueState extends State<PixelDialogue> {
  int _line = 0;
  int _chars = 0;
  Timer? _timer;

  String get _current => widget.lines.isEmpty
      ? ''
      : widget.lines[_line.clamp(0, widget.lines.length - 1).toInt()];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _chars = 0;
    if (!widget.animate) {
      _chars = _current.length;
      return;
    }
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_chars >= _current.length) {
        timer.cancel();
        return;
      }
      setState(() => _chars++);
    });
  }

  void _advance() {
    if (widget.lines.isEmpty) return;
    if (_chars < _current.length) {
      _timer?.cancel();
      setState(() => _chars = _current.length);
      return;
    }
    setState(() => _line = (_line + 1) % widget.lines.length);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final done = _chars >= _current.length;
    final visible =
        _current.substring(0, _chars.clamp(0, _current.length).toInt());
    return Semantics(
      button: true,
      label: '${widget.speaker}: $_current',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: PixelPanel(
            style: PixelBoxStyle.inkDialogue,
            padding: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.portrait != null) ...[
                  PixelPanel(
                    style: PixelBoxStyle.inkDialogue,
                    padding: 1,
                    child: PixelSprite(widget.portrait!, scale: 3),
                  ),
                  SizedBox(width: grid.px(3)),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '* ${widget.speaker}',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.sun,
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        visible,
                        style:
                            PixelType.body(context, color: PixelPalette.paper),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Opacity(
                          opacity: done ? 1 : 0,
                          child: SizedBox(
                            width: grid.px(5),
                            height: grid.px(3),
                            child: CustomPaint(painter: _ArrowPainter(grid)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.grid);

  final PixelGrid grid;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()
      ..color = PixelPalette.paper
      ..isAntiAlias = false;
    for (var row = 0; row < 3; row++) {
      final width = 5 - row * 2;
      canvas.drawRect(
        Rect.fromLTWH(
          grid.snap(row * u),
          grid.snap(row * u),
          grid.snap(width * u),
          grid.snap(u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.grid.unit != grid.unit;
}

Future<T?> showPixelDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Close',
    barrierColor: PixelPalette.ink.withValues(alpha: 0.7),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final grid = PixelGrid.of(dialogContext);
      final buttons = actions ??
          [
            PixelButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ];
      return Center(
        child: Padding(
          padding: EdgeInsets.all(grid.px(4)),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: grid.px(150)),
              child: SingleChildScrollView(
                child: PixelPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadowText(
                        title,
                        style: PixelType.title(dialogContext),
                      ),
                      if (message != null) ...[
                        SizedBox(height: grid.px(2)),
                        Text(
                          message,
                          style: PixelType.body(
                            dialogContext,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                      if (content != null) ...[
                        SizedBox(height: grid.px(2)),
                        content,
                      ],
                      SizedBox(height: grid.px(3)),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: grid.px(2),
                        runSpacing: grid.px(2),
                        children: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void showPixelToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: PixelPalette.ink.withValues(alpha: 0),
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      content: PixelPanel(
        style: PixelBoxStyle.inkDialogue,
        padding: 2,
        child: Text(
          message,
          style: PixelType.body(context, color: PixelPalette.paper),
        ),
      ),
    ),
  );
}

class PixelLoader extends StatefulWidget {
  const PixelLoader({
    super.key,
    this.label = 'Loading',
    this.artPx = 8,
    this.color = PixelPalette.sun,
  });

  final String label;
  final int artPx;
  final Color color;

  @override
  State<PixelLoader> createState() => _PixelLoaderState();
}

class _PixelLoaderState extends State<PixelLoader> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
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
    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: grid.px(widget.artPx),
          height: grid.px(widget.artPx),
          child: CustomPaint(
            painter: _LoaderPainter(
              grid: grid,
              step: _step,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.grid, required this.step, required this.color});

  final PixelGrid grid;
  final int step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()..isAntiAlias = false;
    const points = <(int, int)>[(1, 1), (5, 1), (5, 5), (1, 5)];
    for (var i = 0; i < points.length; i++) {
      paint.color = i == step ? color : PixelPalette.slate;
      canvas.drawRect(
        Rect.fromLTWH(
          grid.snap(points[i].$1 * u),
          grid.snap(points[i].$2 * u),
          grid.snap(2 * u),
          grid.snap(2 * u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.step != step || old.color != color || old.grid.unit != grid.unit;
}

class PixelEmptyState extends StatelessWidget {
  const PixelEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final PixelArt? icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(grid.px(3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              PixelSprite(icon!, scale: 4),
              SizedBox(height: grid.px(3)),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: PixelType.title(context),
            ),
            if (message != null) ...[
              SizedBox(height: grid.px(2)),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: grid.px(3)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
