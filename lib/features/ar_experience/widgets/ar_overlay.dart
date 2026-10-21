import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ar_hunt.dart';
import '../core/ar_math.dart';
import '../core/heading_fusion.dart';
import '../engine/mesh3d.dart';
import 'ar_3d_canvas.dart';

/// Where the AR object is on screen this frame.
class ArScreenObject {
  final bool visible;
  final Offset center;
  final double sizePx;

  /// Horizontal angle to the object when it is off screen (negative = left).
  final double relativeDeg;

  const ArScreenObject({
    required this.visible,
    required this.center,
    required this.sizePx,
    required this.relativeDeg,
  });

  static const double minSize = 56;
  static const double maxSize = 260;

  /// Builds the screen object from a projection; [relativeDeg] is used only
  /// when the object is off screen.
  factory ArScreenObject.from(
      ScreenProjection p, double sizePx, double relativeDeg) {
    final visible = p.inFront && p.onScreen;
    return ArScreenObject(
      visible: visible,
      center: p.offset,
      sizePx: sizePx.clamp(minSize, maxSize),
      relativeDeg: relativeDeg,
    );
  }

  /// True when the object sits inside the centre ring.
  bool centredOn(Size screen, {double ringRadius = 60}) =>
      visible &&
      (center - Offset(screen.width / 2, screen.height / 2)).distance <=
          ringRadius;
}

/// Compass AR: projects a world-relative object with the fused orientation.
class CompassObjectProjector extends ValueNotifier<ArScreenObject?> {
  final ValueListenable<ArPose> pose;
  Vec3? position;
  double focalPx;
  Size screen;

  CompassObjectProjector({
    required this.pose,
    required this.focalPx,
    required this.screen,
    this.position,
  }) : super(null) {
    pose.addListener(update);
  }

  void update() {
    final pos = position;
    final p = pose.value;
    if (pos == null || !p.hasData) {
      value = null;
      return;
    }
    final camera = p.camera;
    final projector = ArProjector(focalPx: focalPx, screen: screen);
    final proj = projector.project(camera, pos);
    value = ArScreenObject.from(
      proj,
      projector.pixelSize(ArObjectLayer.objectSizeM, proj.depth),
      ArGeo.deltaDegrees(ArGeo.bearingOf(pos), camera.bearing),
    );
  }

  @override
  void dispose() {
    pose.removeListener(update);
    super.dispose();
  }
}

/// Draws the AR object at its screen position, or an edge arrow towards it
/// when it is off screen. Rebuilds only when the projection changes.
class ArObjectLayer extends StatefulWidget {
  final ValueListenable<ArScreenObject?> object;
  final Mesh3D mesh;
  final Color color;
  final bool collectable;
  final VoidCallback onTap;

  /// Real-world size of the object in metres.
  static const double objectSizeM = 0.55;

  const ArObjectLayer({
    super.key,
    required this.object,
    required this.mesh,
    required this.color,
    required this.collectable,
    required this.onTap,
  });

  @override
  State<ArObjectLayer> createState() => _ArObjectLayerState();
}

class _ArObjectLayerState extends State<ArObjectLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ArScreenObject?>(
      valueListenable: widget.object,
      builder: (context, o, _) {
        if (o == null) return const SizedBox.shrink();
        if (!o.visible) {
          return _EdgeHint(relativeDeg: o.relativeDeg, color: widget.color);
        }
        final size = o.sizePx;
        return Stack(children: [
          Positioned(
            left: o.center.dx - size,
            top: o.center.dy - size,
            width: size * 2,
            height: size * 2,
            child: GestureDetector(
              key: const ValueKey('ar_object'),
              behavior: HitTestBehavior.translucent,
              onTap: widget.collectable ? widget.onTap : null,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  final t = _spin.value * 2 * math.pi;
                  return Stack(alignment: Alignment.center, children: [
                    Container(
                      width: size * 1.1,
                      height: size * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.collectable
                                    ? const Color(0xFF52B788)
                                    : widget.color)
                                .withValues(alpha: 0.45),
                            blurRadius: size * 0.35,
                            spreadRadius: size * 0.05,
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, math.sin(t) * size * 0.05),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Ar3dCanvas(
                          mesh: widget.mesh,
                          rotX: 0.35,
                          rotY: t,
                          rotZ: 0.08,
                          scale: size * 0.42,
                          renderStyle: RenderStyle.hybrid,
                          showShadow: false,
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _EdgeHint extends StatelessWidget {
  final double relativeDeg;
  final Color color;

  const _EdgeHint({required this.relativeDeg, required this.color});

  @override
  Widget build(BuildContext context) {
    final left = relativeDeg < 0;
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          key: const ValueKey('ar_edge_hint'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: color,
            size: 30,
          ),
        ),
      ),
    );
  }
}

/// Centre ring; turns green when the object is centred and collectable.
class ArReticle extends StatelessWidget {
  final bool active;
  final double size;

  const ArReticle({super.key, required this.active, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? const Color(0xFF52B788)
                  : Colors.white.withValues(alpha: 0.7),
              width: active ? 4 : 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Outside the fence: an arrow pointing at the fence centre plus distance.
class ArFinder extends StatelessWidget {
  final ValueListenable<ArPose> pose;
  final double bearingToTarget;
  final double distanceMeters;
  final double radiusMeters;

  const ArFinder({
    super.key,
    required this.pose,
    required this.bearingToTarget,
    required this.distanceMeters,
    required this.radiusMeters,
  });

  static String formatDistance(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km'
      : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final toGo = math.max(0.0, distanceMeters - radiusMeters);
    return ValueListenableBuilder<ArPose>(
      valueListenable: pose,
      builder: (context, p, _) {
        final relative = p.hasData
            ? ArGeo.deltaDegrees(bearingToTarget, p.camera.bearing)
            : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: relative * math.pi / 180,
              child: const Icon(Icons.navigation_rounded,
                  key: ValueKey('ar_finder_arrow'),
                  size: 96,
                  color: Color(0xFFFFB703)),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDistance(toGo)} to go',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              p.hasData
                  ? 'The AR area is ${ArHuntRules.directionHint(relative)}'
                  : 'Walk towards the AR area',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}
