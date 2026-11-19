import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_particles.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/pixel/pixel_text_3d.dart';
import '../dashboard/widgets/home_command_grid.dart';

/// Pixel Lab interactive testbed for the pixel particle system and the
/// disintegrate transition from bottom nav MENU button to full MainMenu modal.
class ParticleMenuTransitionSection extends StatefulWidget {
  const ParticleMenuTransitionSection({super.key});

  @override
  State<ParticleMenuTransitionSection> createState() =>
      _ParticleMenuTransitionSectionState();
}

class _ParticleMenuTransitionSectionState
    extends State<ParticleMenuTransitionSection> with TickerProviderStateMixin {
  final PixelParticleSystem _particles = PixelParticleSystem(capacity: 280);
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _modalKey = GlobalKey();
  final GlobalKey _navButtonKey = GlobalKey();

  late final AnimationController _menuController;
  Ticker? _ticker;
  Duration? _lastTickElapsed;

  PixelDisintegrateStyle _style = PixelDisintegrateStyle.upwardEmbers;
  int _durationMs = 420;
  bool _open = false;
  double _prevProgress = 0;
  String _status = 'TAP MENU IN THE NAV BAR TO TEST';

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _durationMs),
    )..addListener(_onMenuTick);
  }

  @override
  void dispose() {
    _stopTicker();
    _menuController.removeListener(_onMenuTick);
    _menuController.dispose();
    _particles.dispose();
    super.dispose();
  }

  void _ensureTicker() {
    if (_ticker != null) {
      if (!_ticker!.isActive) {
        _lastTickElapsed = null;
        _ticker!.start();
      }
      return;
    }
    _lastTickElapsed = null;
    _ticker = createTicker((elapsed) {
      final prev = _lastTickElapsed;
      _lastTickElapsed = elapsed;
      final dt = prev == null
          ? 1 / 60.0
          : (elapsed - prev).inMicroseconds / 1000000.0;
      final stillAlive = _particles.step(dt);
      if (!stillAlive && !_menuController.isAnimating) {
        _stopTicker();
      }
    });
    _ticker!.start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _lastTickElapsed = null;
  }

  Rect? _rectInStage(GlobalKey key) {
    final stageBox =
        _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox == null ||
        targetBox == null ||
        !stageBox.hasSize ||
        !targetBox.hasSize) {
      return null;
    }
    final topLeft =
        targetBox.localToGlobal(Offset.zero, ancestor: stageBox);
    return topLeft & targetBox.size;
  }

  Rect _fallbackModalRect(Size stageSize) {
    final top = (stageSize.height - 230).clamp(12.0, stageSize.height * 0.45);
    return Rect.fromLTRB(
      12,
      top,
      (stageSize.width - 12).clamp(24.0, stageSize.width),
      (stageSize.height - 80).clamp(top + 80, stageSize.height),
    );
  }

  Offset _anchorInStage(Size stageSize) {
    final navRect = _rectInStage(_navButtonKey);
    if (navRect != null) return navRect.center;
    return Offset(stageSize.width * 0.5, stageSize.height - 34);
  }

  void _onMenuTick() {
    final cur = _menuController.value;
    final prev = _prevProgress;
    _prevProgress = cur;

    final stageBox =
        _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox != null && stageBox.hasSize) {
      final modalRect =
          _rectInStage(_modalKey) ?? _fallbackModalRect(stageBox.size);
      final anchor = _anchorInStage(stageBox.size);
      _particles.emitDisintegrateFrontier(
        modalRect: modalRect,
        anchor: anchor,
        prevProgress: prev,
        progress: cur,
        opening: _open,
        style: _style,
        maxPerStep: 20,
      );
      _ensureTicker();
    }
    if (mounted) setState(() {});
  }

  void _toggleMenu({bool? targetOpen}) {
    final next = targetOpen ?? !_open;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() {
      _open = next;
      _status = next
          ? 'OPENED · ${_styleLabel(_style)}'
          : 'DISINTEGRATED BACK TO NAV';
    });

    if (reducedMotion) {
      _menuController.value = next ? 1.0 : 0.0;
      _prevProgress = _menuController.value;
      _particles.clear();
      _stopTicker();
      return;
    }

    _menuController.duration = Duration(milliseconds: _durationMs);
    final stageBox =
        _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox != null && stageBox.hasSize) {
      final anchor = _anchorInStage(stageBox.size);
      _particles.emitBurst(
        origin: anchor,
        count: next ? 44 : 28,
        gravity: next ? 110 : -80,
        upwardBias: next ? -130 : -70,
        minSpeed: 55,
        maxSpeed: 185,
      );
      _ensureTicker();
    }

    if (next) {
      _menuController.forward(from: _menuController.value);
    } else {
      _menuController.reverse(from: _menuController.value);
    }
  }

  void _replayOpen() {
    setState(() {
      _open = false;
      _prevProgress = 0;
    });
    _menuController.value = 0;
    _toggleMenu(targetOpen: true);
  }

  void _triggerBurst() {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      setState(() => _status = 'REDUCED MOTION ACTIVE');
      return;
    }
    final stageBox =
        _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final size = stageBox?.hasSize == true ? stageBox!.size : const Size(280, 320);
    _particles.emitBurst(
      origin: Offset(size.width * 0.5, size.height * 0.45),
      count: 64,
      minSpeed: 65,
      maxSpeed: 220,
      gravity: 170,
      upwardBias: -75,
    );
    _ensureTicker();
    setState(() => _status = 'BURST · ${_particles.activeCount} PIXELS');
  }

  String _styleLabel(PixelDisintegrateStyle s) => switch (s) {
        PixelDisintegrateStyle.upwardEmbers => 'UPWARD EMBERS',
        PixelDisintegrateStyle.centerVortex => 'CENTER VORTEX',
        PixelDisintegrateStyle.edgeErode => 'EDGE ERODE',
      };

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final t = _menuController.value;
    final modalVisible = t > 0.001 || _open;
    final scrimAlpha = ((0.78 * t) * 4).round() / 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'REUSABLE PIXEL PARTICLE POOL + BAYER/GRID DISINTEGRATE WIPE '
          'FROM NAV MENU BUTTON TO THE CURRENT MAIN MENU MODAL.',
          style: PixelType.small(context, color: PixelPalette.ink),
        ),
        SizedBox(height: grid.px(2)),
        // Style chips
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final s in PixelDisintegrateStyle.values)
              PixelChip(
                _styleLabel(s),
                key: ValueKey('lab_particle_style_${s.name}'),
                style: _style == s ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                onTap: () => setState(() => _style = s),
              ),
          ],
        ),
        SizedBox(height: grid.px(1)),
        // Speed & trigger controls
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final (ms, label) in const [
              (240, 'FAST 240MS'),
              (420, 'NORMAL 420MS'),
              (1100, 'SLOW-MO 1.1S'),
            ])
              PixelChip(
                label,
                key: ValueKey('lab_particle_speed_$ms'),
                style:
                    _durationMs == ms ? PixelBoxStyle.green : PixelBoxStyle.parchment,
                textColor:
                    _durationMs == ms ? PixelPalette.white : PixelPalette.ink,
                onTap: () => setState(() => _durationMs = ms),
              ),
            PixelChip(
              'REPLAY OPEN',
              key: const ValueKey('lab_particle_replay'),
              style: PixelBoxStyle.parchment,
              onTap: _replayOpen,
            ),
            PixelChip(
              'BURST TEST',
              key: const ValueKey('lab_particle_burst'),
              style: PixelBoxStyle.parchment,
              onTap: _triggerBurst,
            ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        // Interactive nav -> modal stage
        PixelPanel(
          style: PixelBoxStyle.wood,
          padding: 1,
          child: ClipRect(
            child: SizedBox(
              key: _stageKey,
              height: 360,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Simulated behind-modal page background.
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: PixelPalette.paper,
                              padding: EdgeInsets.all(grid.px(3)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: PixelText3D(
                                      'YOUR JOURNEY',
                                      size: 14,
                                      depth: 1,
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  SizedBox(height: grid.px(1)),
                                  Text(
                                    'TAP MENU BELOW TO EXPAND OR DISINTEGRATE.',
                                    style: PixelType.small(
                                      context,
                                      color: PixelPalette.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (modalVisible)
                              Positioned.fill(
                                child: GestureDetector(
                                  key: const ValueKey('lab_particle_scrim'),
                                  onTap: () => _toggleMenu(targetOpen: false),
                                  child: ColoredBox(
                                    color: PixelPalette.ink
                                        .withValues(alpha: scrimAlpha.clamp(0.0, 0.78)),
                                  ),
                                ),
                              ),
                            if (modalVisible)
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 268),
                                  child: SingleChildScrollView(
                                    child: PixelDisintegrateMask(
                                      progress: t,
                                      style: _style,
                                      child: PixelPanel(
                                        key: _modalKey,
                                        style: PixelBoxStyle.parchment,
                                        padding: 2,
                                        child: Column(
                                          key: const ValueKey(
                                            'lab_particle_modal_card',
                                          ),
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: PixelText3D(
                                                  'Main menu',
                                                  size: 12,
                                                  depth: 1,
                                                  textAlign: TextAlign.left,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: grid.px(1)),
                                            HomeCommandGrid(
                                              nearbyQuizCount: 1,
                                              voteLive: true,
                                              onOpenQuizzes: () {
                                                _toggleMenu(targetOpen: false);
                                                setState(() =>
                                                    _status = 'TAPPED QUIZZES');
                                              },
                                              onNavigate: (route) {
                                                _toggleMenu(targetOpen: false);
                                                setState(() =>
                                                    _status = 'TAPPED $route');
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      PixelHotbar(
                        index: 0,
                        onTap: (tab) => setState(() {
                          if (_open) _toggleMenu(targetOpen: false);
                          _status = 'TAB $tab SELECTED';
                        }),
                        center: KeyedSubtree(
                          key: _navButtonKey,
                          child: PixelMenuButton(
                            key: const ValueKey('lab_particle_menu_btn'),
                            open: _open,
                            onPressed: _toggleMenu,
                          ),
                        ),
                        items: const [
                          PixelHotbarItem(
                              label: 'Home', icon: DesignerArt.navHome),
                          PixelHotbarItem(
                              label: 'Explore', icon: DesignerArt.navExplore),
                          PixelHotbarItem(
                              label: 'Shop', icon: DesignerArt.navShop),
                          PixelHotbarItem(
                              label: 'Profile', icon: DesignerArt.navProfile),
                        ],
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: PixelParticleOverlay(
                      key: const ValueKey('lab_particle_overlay'),
                      system: _particles,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: grid.px(1)),
        Text(
          _status,
          key: const ValueKey('lab_particle_status'),
          style: PixelType.small(context, color: PixelPalette.woodDeep),
        ),
      ],
    );
  }
}
