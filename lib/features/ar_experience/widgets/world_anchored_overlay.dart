import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../engine/spatial_math.dart';
import '../engine/shapes_factory.dart';
import 'ar_3d_canvas.dart';

class WorldAnchoredOverlay extends StatefulWidget {
  final ProjectedSpatialPoint point;
  final String questTitle;
  final ShapeType shapeType;
  final Color themeColor;
  final VoidCallback onTap;

  const WorldAnchoredOverlay({
    super.key,
    required this.point,
    required this.questTitle,
    this.shapeType = ShapeType.token,
    this.themeColor = const Color(0xFFFFB703),
    required this.onTap,
  });

  @override
  State<WorldAnchoredOverlay> createState() => _WorldAnchoredOverlayState();
}

class _WorldAnchoredOverlayState extends State<WorldAnchoredOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.point.isVisibleInViewport) {
      return const SizedBox.shrink();
    }

    final mesh = ShapesFactory.createShape(widget.shapeType, themeColor: widget.themeColor);
    final baseScale = 85.0 * widget.point.scaleFactor;
    final entityX = widget.point.offset.dx;
    final entityY = widget.point.offset.dy;

    return AnimatedBuilder(
      animation: _spinController,
      builder: (context, child) {
        final rotY = _spinController.value * 2 * math.pi;
        final rotX = 0.35 + 0.1 * math.sin(_spinController.value * 2 * math.pi);

        return Positioned(
          left: entityX - (baseScale * 1.5),
          top: entityY - (baseScale * 1.5),
          child: Opacity(
            opacity: widget.point.opacity,
            child: GestureDetector(
              onTap: widget.onTap,
              child: SizedBox(
                width: baseScale * 3.0,
                height: baseScale * 3.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Holographic Ground Ring / Ambient Aura
                    Container(
                      width: baseScale * 1.6,
                      height: baseScale * 1.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeColor.withOpacity(0.35),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),

                    // 2. 3D Spatial Canvas Mesh
                    Ar3dCanvas(
                      mesh: mesh,
                      rotX: rotX,
                      rotY: rotY,
                      rotZ: 0.0,
                      scale: baseScale,
                      renderStyle: RenderStyle.hybrid,
                      showShadow: true,
                    ),

                    // 3. Floating Hologram Label Card
                    Positioned(
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.78),
                          borderRadius: AppSpacing.roundedPill,
                          border: Border.all(color: widget.themeColor.withOpacity(0.6), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.point.distanceMeters.toStringAsFixed(0)}m • Tap to Claim',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.sunGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
