import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_particles.dart';
import 'main_menu_panel.dart';

/// The main menu over the page (owner 2026-11-16): the page dims, and the
/// menu assembles out of pixel embers rising from the MENU button (agy's
/// particle system, "Upward Embers" at 420 ms), then dissolves back into it
/// on close. Reduced motion: the menu just appears and disappears.
class MainMenuOverlay extends StatefulWidget {
  const MainMenuOverlay({super.key, required this.open, required this.onClose});

  final bool open;
  final VoidCallback onClose;

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay>
    with TickerProviderStateMixin {
  static const _style = PixelDisintegrateStyle.upwardEmbers;
  static const _duration = Duration(milliseconds: 420);

  final _particles = PixelParticleSystem(capacity: 280);
  final _stageKey = GlobalKey();
  final _panelKey = GlobalKey();
  late final AnimationController _t;
  Ticker? _ticker;
  Duration? _last;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onTick);
    if (widget.open) _t.value = 1;
    _prev = _t.value;
  }

  @override
  void didUpdateWidget(MainMenuOverlay old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) _animate(widget.open);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    _particles.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _animate(bool open) {
    if (_still) {
      _t.value = open ? 1 : 0;
      _prev = _t.value;
      _particles.clear();
      return;
    }
    final stage = _stageBox();
    if (stage != null) {
      _particles.emitBurst(
        origin: _anchor(stage.size),
        count: open ? 44 : 28,
        gravity: open ? 110 : -80,
        upwardBias: open ? -130 : -70,
        minSpeed: 55,
        maxSpeed: 185,
      );
      _runParticles();
    }
    open ? _t.forward() : _t.reverse();
  }

  RenderBox? _stageBox() {
    final b = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    return b != null && b.hasSize ? b : null;
  }

  // The MENU button sits just below this overlay, in the middle of the bar.
  Offset _anchor(Size s) => Offset(s.width / 2, s.height);

  Rect _panelRect(RenderBox stage) {
    final p = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (p != null && p.hasSize) {
      return p.localToGlobal(Offset.zero, ancestor: stage) & p.size;
    }
    final s = stage.size;
    return Rect.fromLTRB(12, s.height * 0.55, s.width - 12, s.height - 12);
  }

  void _onTick() {
    final cur = _t.value;
    final stage = _stageBox();
    if (stage != null) {
      _particles.emitDisintegrateFrontier(
        modalRect: _panelRect(stage),
        anchor: _anchor(stage.size),
        prevProgress: _prev,
        progress: cur,
        opening: widget.open,
        style: _style,
        maxPerStep: 20,
      );
      _runParticles();
    }
    _prev = cur;
    if (mounted) setState(() {});
  }

  void _runParticles() {
    _ticker ??= createTicker((elapsed) {
      final prev = _last;
      _last = elapsed;
      final dt = prev == null ? 1 / 60 : (elapsed - prev).inMicroseconds / 1e6;
      if (!_particles.step(dt) && !_t.isAnimating) {
        _ticker!.stop();
        _last = null;
      }
    });
    if (!_ticker!.isActive) {
      _last = null;
      _ticker!.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t.value;
    final visible = t > 0 || widget.open;
    return Stack(
      key: _stageKey,
      children: [
        if (visible) ...[
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.open,
              child: GestureDetector(
                key: const ValueKey('main_menu_scrim'),
                onTap: widget.onClose,
                child: ColoredBox(
                  color: PixelPalette.ink.withValues(alpha: 0.78 * t),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                ignoring: !widget.open,
                child: PixelDisintegrateMask(
                  progress: t,
                  style: _style,
                  child: KeyedSubtree(
                    key: _panelKey,
                    child: MainMenuPanel(onClose: widget.onClose),
                  ),
                ),
              ),
            ),
          ),
        ],
        Positioned.fill(child: PixelParticleOverlay(system: _particles)),
      ],
    );
  }
}
