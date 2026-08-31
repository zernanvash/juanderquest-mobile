import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class SpiritBubbleLevel extends StatelessWidget {
  final double pitchDegrees; // -90 .. +90
  final double rollDegrees;  // -180 .. +180
  final bool isLevel;
  final double holdProgress; // 0.0 .. 1.0

  const SpiritBubbleLevel({
    super.key,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.isLevel,
    required this.holdProgress,
  });

  @override
  Widget build(BuildContext context) {
    final targetColor = isLevel ? const Color(0xFF2D6A4F) : const Color(0xFFFFB703);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Circular Bubble Level Reticle
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Aura
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  boxShadow: [
                    BoxShadow(
                      color: targetColor.withOpacity(isLevel ? 0.45 : 0.20),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // Level Reticle Canvas
              CustomPaint(
                size: const Size(220, 220),
                painter: _BubbleLevelPainter(
                  pitch: pitchDegrees,
                  roll: rollDegrees,
                  isLevel: isLevel,
                  holdProgress: holdProgress,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Pitch & Roll Telemetry Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: AppSpacing.roundedPill,
            border: Border.all(color: targetColor.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLevel ? Icons.check_circle_rounded : Icons.screen_rotation_rounded,
                color: targetColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Pitch: ${pitchDegrees.toStringAsFixed(1)}° • Roll: ${rollDegrees.toStringAsFixed(1)}°',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleLevelPainter extends CustomPainter {
  final double pitch;
  final double roll;
  final bool isLevel;
  final double holdProgress;

  _BubbleLevelPainter({
    required this.pitch,
    required this.roll,
    required this.isLevel,
    required this.holdProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // 1. Base Reticle Rings
    final ringPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.65, ringPaint);
    canvas.drawCircle(center, radius * 0.35, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    // 2. Target Level Ring in Center
    final targetColor = isLevel ? const Color(0xFF52B788) : AppColors.sunGold;
    final targetPaint = Paint()
      ..color = targetColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, 28, targetPaint);

    // 3. Circular Hold Progress Arc
    if (holdProgress > 0) {
      final holdArcPaint = Paint()
        ..color = const Color(0xFF52B788)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 28),
        -math.pi / 2,
        holdProgress * 2 * math.pi,
        false,
        holdArcPaint,
      );
    }

    // 4. Calculate Bubble Offset (Natural Stance: Ideal pitch is ~50°, ideal roll is 0°)
    const idealPitch = 50.0;
    final deltaPitch = (pitch - idealPitch).clamp(-45.0, 45.0);
    final deltaRoll = roll.clamp(-45.0, 45.0);

    final maxPixelDist = radius - 16;
    final bubbleX = center.dx + (deltaRoll / 45.0) * maxPixelDist;
    final bubbleY = center.dy - (deltaPitch / 45.0) * maxPixelDist;

    final bubblePos = Offset(bubbleX, bubbleY);

    // 5. Render Spirit Level Bubble
    final bubblePaint = Paint()
      ..color = targetColor
      ..style = PaintingStyle.fill;

    final bubbleGlow = Paint()
      ..color = targetColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(bubblePos, 14, bubbleGlow);
    canvas.drawCircle(bubblePos, 12, bubblePaint);

    // Inner Reflection Highlight
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(Offset(bubblePos.dx - 3, bubblePos.dy - 3), 3.5, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleLevelPainter oldDelegate) {
    return oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.isLevel != isLevel ||
        oldDelegate.holdProgress != holdProgress;
  }
}
