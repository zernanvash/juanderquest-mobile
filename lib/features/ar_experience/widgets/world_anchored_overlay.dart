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
  final bool isReticleLocked;
  final VoidCallback? onTap;

  const WorldAnchoredOverlay({
    super.key,
    required this.point,
    required this.questTitle,
    this.shapeType = ShapeType.token,
    this.themeColor = const Color(0xFFFFB703),
    this.isReticleLocked = false,
    this.onTap,
  });

  @override
  State<WorldAnchoredOverlay> createState() => _WorldAnchoredOverlayState();
}

class _WorldAnchoredOverlayState extends State<WorldAnchoredOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.point.isVisibleInViewport) {
      return const SizedBox.shrink();
    }

    final mesh = ShapesFactory.createShape(widget.shapeType, themeColor: widget.themeColor);
    final baseScale = (85.0 * widget.point.scaleFactor).clamp(35.0, 150.0);
    final entityX = widget.point.offset.dx;
    final entityY = widget.point.offset.dy;

    return AnimatedBuilder(
      animation: _motionController,
      builder: (context, child) {
        final t = _motionController.value;
        final rotY = t * 2 * math.pi;
        // Subtle tilt oscillation for 3D depth perception
        final rotX = 0.32 + 0.10 * math.sin(t * 2 * math.pi);
        // Harmonic vertical levitation bob (amplitude ~ 6dp)
        final levitationOffset = 6.0 * math.sin(t * 2 * math.pi);

        final targetColor = widget.isReticleLocked ? const Color(0xFF52B788) : widget.themeColor;

        return Positioned(
          left: entityX - (baseScale * 1.5),
          top: (entityY + levitationOffset) - (baseScale * 1.5),
          child: Opacity(
            opacity: widget.point.opacity.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: widget.isReticleLocked ? widget.onTap : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: baseScale * 3.0,
                height: baseScale * 3.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Holographic Spatial Energy Aura
                    Container(
                      width: baseScale * 1.6,
                      height: baseScale * 1.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: targetColor.withOpacity(widget.isReticleLocked ? 0.60 : 0.35),
                            blurRadius: widget.isReticleLocked ? 36 : 24,
                            spreadRadius: widget.isReticleLocked ? 8 : 4,
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

                    // 3. Floating Interactive Action Pill
                    Positioned(
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.82),
                          borderRadius: AppSpacing.roundedPill,
                          border: Border.all(
                            color: targetColor.withOpacity(0.8),
                            width: widget.isReticleLocked ? 1.8 : 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isReticleLocked ? '🎯' : '✨',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.point.distanceMeters.toStringAsFixed(0)}m • ${widget.isReticleLocked ? 'Lock Active • Tap to Capture' : 'Center target to lock'}',
                              style: GoogleFonts.plusJakartaSans(
                                color: widget.isReticleLocked ? const Color(0xFFBEEAD1) : AppColors.sunGold,
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
