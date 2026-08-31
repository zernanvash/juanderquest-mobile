import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ArRadarCompassHud extends StatelessWidget {
  final double deviceHeading;
  final double targetBearing;
  final double relativeAzimuth;
  final double relativePitch;
  final double distanceMeters;
  final bool isVisibleInFov;

  const ArRadarCompassHud({
    super.key,
    required this.deviceHeading,
    required this.targetBearing,
    required this.relativeAzimuth,
    this.relativePitch = 0.0,
    required this.distanceMeters,
    required this.isVisibleInFov,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Radar & Distance Telemetry Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: AppSpacing.roundedPill,
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 360° Mini Radar
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(
                    painter: _MiniRadarPainter(
                      deviceHeading: deviceHeading,
                      targetBearing: targetBearing,
                      relativeAzimuth: relativeAzimuth,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Distance & Heading Telemetry Text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${distanceMeters.toStringAsFixed(0)}m',
                          style: GoogleFonts.epilogue(
                            color: AppColors.sunGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${targetBearing.toStringAsFixed(0)}° ${_getCardinalDirection(targetBearing)})',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isVisibleInFov ? '🎯 Target in Viewfinder' : '🧭 Turn towards marker',
                      style: GoogleFonts.plusJakartaSans(
                        color: isVisibleInFov ? const Color(0xFF52B788) : Colors.white70,
                        fontSize: 9.5,
                        fontWeight: isVisibleInFov ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. Off-Screen Directional Indicator Chevrons
        if (!isVisibleInFov) ...[
          const SizedBox(height: 8),
          _buildOffScreenIndicator(context),
        ],
      ],
    );
  }

  Widget _buildOffScreenIndicator(BuildContext context) {
    final isBehind = relativeAzimuth.abs() > 120.0;
    final isLeft = relativeAzimuth < 0;
    final angleAbs = relativeAzimuth.abs().toStringAsFixed(0);

    String label;
    IconData icon;

    if (isBehind) {
      label = 'Turn Around ($angleAbs°)';
      icon = Icons.u_turn_left_rounded;
    } else if (relativePitch < -30.0) {
      label = 'Tilt Down (${relativePitch.abs().toStringAsFixed(0)}°)';
      icon = Icons.arrow_downward_rounded;
    } else if (relativePitch > 30.0) {
      label = 'Tilt Up (${relativePitch.abs().toStringAsFixed(0)}°)';
      icon = Icons.arrow_upward_rounded;
    } else if (isLeft) {
      label = 'Turn Left $angleAbs°';
      icon = Icons.arrow_back_ios_rounded;
    } else {
      label = 'Turn Right $angleAbs°';
      icon = Icons.arrow_forward_ios_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.92),
        borderRadius: AppSpacing.roundedPill,
        border: Border.all(color: AppColors.sunGold.withOpacity(0.6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.sunGold, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    final idx = ((bearing + 22.5) % 360) ~/ 45;
    return directions[idx];
  }
}

class _MiniRadarPainter extends CustomPainter {
  final double deviceHeading;
  final double targetBearing;
  final double relativeAzimuth;

  _MiniRadarPainter({
    required this.deviceHeading,
    required this.targetBearing,
    required this.relativeAzimuth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Radar Circle Background
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);

    // 2. Camera Field of View (FOV) Sector (65°)
    final fovPaint = Paint()
      ..color = AppColors.sunGold.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 - (65 * math.pi / 360),
      65 * math.pi / 180,
      true,
      fovPaint,
    );

    // 3. North Indicator ('N' Red Dot)
    final northAngleRad = (-deviceHeading - 90) * math.pi / 180;
    final northPt = Offset(
      center.dx + (radius - 5) * math.cos(northAngleRad),
      center.dy + (radius - 5) * math.sin(northAngleRad),
    );
    final northPaint = Paint()..color = const Color(0xFFD90429);
    canvas.drawCircle(northPt, 2.5, northPaint);

    // 4. Target Waypoint Dot
    final targetAngleRad = (relativeAzimuth - 90) * math.pi / 180;
    final targetPt = Offset(
      center.dx + (radius - 4) * math.cos(targetAngleRad),
      center.dy + (radius - 4) * math.sin(targetAngleRad),
    );

    final targetPaint = Paint()..color = AppColors.sunGold;
    canvas.drawCircle(targetPt, 3.5, targetPaint);

    // Pulsing Target Ring
    final pulsePaint = Paint()
      ..color = AppColors.sunGold.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(targetPt, 5.5, pulsePaint);

    // 5. User Center Dot
    final userPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 2.0, userPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter oldDelegate) {
    return oldDelegate.deviceHeading != deviceHeading ||
        oldDelegate.targetBearing != targetBearing ||
        oldDelegate.relativeAzimuth != relativeAzimuth;
  }
}
