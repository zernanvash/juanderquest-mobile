import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class FigureEightAnimation extends StatefulWidget {
  final double progress; // 0.0 .. 1.0
  final VoidCallback? onSimulateStep;

  const FigureEightAnimation({
    super.key,
    required this.progress,
    this.onSimulateStep,
  });

  @override
  State<FigureEightAnimation> createState() => _FigureEightAnimationState();
}

class _FigureEightAnimationState extends State<FigureEightAnimation>
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Interactive Figure-8 Track Visualizer
        SizedBox(
          width: 260,
          height: 140,
          child: AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) {
              return CustomPaint(
                painter: _LemniscatePainter(
                  animValue: _motionController.value,
                  progress: widget.progress,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 2. Progress Bar & Percentage
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: AppSpacing.roundedLg,
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Compass Calibration Progress',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: GoogleFonts.epilogue(
                      color: AppColors.sunGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sunGold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LemniscatePainter extends CustomPainter {
  final double animValue;
  final double progress;

  _LemniscatePainter({
    required this.animValue,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scaleA = size.width * 0.40;
    final scaleB = size.height * 0.35;

    // 1. Draw Background Figure-8 (Lemniscate of Bernoulli: x = a*cos(t)/(1+sin^2(t)), y = a*sin(t)*cos(t)/(1+sin^2(t)))
    final trackPath = Path();
    const totalSteps = 120;

    for (int i = 0; i <= totalSteps; i++) {
      final t = (i / totalSteps) * 2 * math.pi;
      final denom = 1 + math.sin(t) * math.sin(t);
      final x = centerX + (scaleA * math.cos(t)) / denom;
      final y = centerY + (scaleB * math.sin(t) * math.cos(t) * 1.6) / denom;

      if (i == 0) {
        trackPath.moveTo(x, y);
      } else {
        trackPath.lineTo(x, y);
      }
    }

    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(trackPath, trackPaint);

    // Glowing Trail
    final glowPaint = Paint()
      ..color = AppColors.sunGold.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(trackPath, glowPaint);

    // 2. Animated Device Position along Curve
    final animT = animValue * 2 * math.pi;
    final animDenom = 1 + math.sin(animT) * math.sin(animT);
    final phoneX = centerX + (scaleA * math.cos(animT)) / animDenom;
    final phoneY = centerY + (scaleB * math.sin(animT) * math.cos(animT) * 1.6) / animDenom;

    // Phone Graphic Icon Box
    final phoneRect = Rect.fromCenter(
      center: Offset(phoneX, phoneY),
      width: 26,
      height: 36,
    );

    final phoneBg = Paint()..color = const Color(0xFF0F172A);
    final phoneBorder = Paint()
      ..color = AppColors.sunGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect, const Radius.circular(5)), phoneBg);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect, const Radius.circular(5)), phoneBorder);

    // Mini screen on phone
    final screenRect = Rect.fromCenter(
      center: Offset(phoneX, phoneY),
      width: 18,
      height: 26,
    );
    final screenPaint = Paint()..color = AppColors.sunGold.withOpacity(0.4);
    canvas.drawRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(2)), screenPaint);

    // Outer Aura Pulse on Phone
    final pulsePaint = Paint()
      ..color = AppColors.sunGold.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(phoneX, phoneY), 22, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _LemniscatePainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.progress != progress;
  }
}
