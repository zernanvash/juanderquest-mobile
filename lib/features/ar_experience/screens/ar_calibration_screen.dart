import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/designer_guide.dart';
import '../controllers/calibration_controller.dart';
import '../controllers/sensor_fusion_controller.dart';
import '../widgets/figure_eight_animation.dart';
import '../widgets/spirit_bubble_level.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_3d_canvas.dart';

class ArCalibrationScreen extends ConsumerStatefulWidget {
  final String? returnTo;

  const ArCalibrationScreen({super.key, this.returnTo});

  @override
  ConsumerState<ArCalibrationScreen> createState() =>
      _ArCalibrationScreenState();
}

class _ArCalibrationScreenState extends ConsumerState<ArCalibrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _finishAndNavigate() {
    ref.read(calibrationProvider.notifier).completeCalibration();
    final target = widget.returnTo ?? '/quests';
    if (context.mounted) {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calibState = ref.watch(calibrationProvider);
    final sensorOrientation = ref.watch(sensorFusionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/quests');
            }
          },
        ),
        title: Text(
          'AR Sensor Calibration',
          style: GoogleFonts.epilogue(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(calibrationProvider.notifier)
                  .simulateInstantCalibration();
            },
            child: Text(
              'Demo Pass',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.sunGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Step Indicator Wizard
                      _buildStepProgressHeader(calibState.currentStep),
                      const SizedBox(height: 20),

                      // 2. Active Step Content
                      Expanded(
                        child: Center(
                          child: _buildCurrentStepContent(
                              calibState, sensorOrientation),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Bottom Action Deck
                      _buildBottomActionButtons(calibState),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepProgressHeader(CalibrationStep currentStep) {
    final stepIndex = currentStep.index;

    return UiSpecContainer(
      spec: const UiSpec(
        title: 'AR Calibration Step Indicator',
        figmaLayer: '#AR_Calibration_Stepper',
        dimensions: 'Width: 100%, Height: 44dp',
        dataBinding: 'calibrationProvider.currentStep',
        stateNotes:
            'Step 1 (Compass) -> Step 2 (Horizon) -> Step 3 (Permissions) -> Success',
        uxNotes:
            'Step wizard with animated Figure-8, dual-axis spirit bubble level, and sensor check.',
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepDot(0, 'Compass', stepIndex >= 0, stepIndex == 0),
            _buildStepDivider(stepIndex >= 1),
            _buildStepDot(1, 'Horizon', stepIndex >= 1, stepIndex == 1),
            _buildStepDivider(stepIndex >= 2),
            _buildStepDot(2, 'Sensors', stepIndex >= 2, stepIndex == 2),
            _buildStepDivider(stepIndex >= 3),
            _buildStepDot(3, 'Ready', stepIndex >= 3, stepIndex == 3),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDot(
      int index, String label, bool isCompleted, bool isCurrent) {
    final color = isCompleted ? AppColors.sunGold : Colors.white24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? AppColors.sunGold
                : (isCompleted
                    ? const Color(0xFF2D6A4F)
                    : const Color(0xFF1E293B)),
            border: Border.all(color: color, width: isCurrent ? 2.0 : 1.0),
          ),
          child: Center(
            child: isCompleted && !isCurrent
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color:
                          isCurrent ? const Color(0xFF582F0E) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isCurrent ? Colors.white : Colors.white60,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      color: isActive ? AppColors.sunGold : Colors.white12,
    );
  }

  Widget _buildCurrentStepContent(
      CalibrationState state, SensorOrientation sensor) {
    switch (state.currentStep) {
      case CalibrationStep.magnetometerSweep:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Step 1: Calibrate Compass Heading',
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Wave your phone in an infinity (∞) Figure-8 motion in the air to calibrate the magnetometer against magnetic drift.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FigureEightAnimation(
              progress: state.compassProgress,
            ),
          ],
        );

      case CalibrationStep.horizonLevelZero:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Step 2: Horizon Level & Tilt Zeroing',
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hold phone upright in a natural AR viewing stance. Align the bubble inside the center target ring for 1.5 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SpiritBubbleLevel(
              pitchDegrees: sensor.pitchDegrees,
              rollDegrees: sensor.rollDegrees,
              isLevel: state.isLevel,
              holdProgress: state.levelHoldProgress,
            ),
          ],
        );

      case CalibrationStep.hardwareCheck:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Step 3: Hardware & Satellites Verification',
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifying camera lens preview and GPS satellite lock for accurate quest location radius validation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildHardwareStatusRow(
                    icon: Icons.camera_alt_rounded,
                    title: 'AR Camera Lens',
                    status: state.cameraPermissionGranted
                        ? 'Ready (Authorized)'
                        : 'Checking...',
                    isReady: state.cameraPermissionGranted,
                  ),
                  const Divider(height: 20, color: Colors.white12),
                  _buildHardwareStatusRow(
                    icon: Icons.gps_fixed_rounded,
                    title: 'GPS Geolocation',
                    status:
                        state.gpsStatusMessage ?? 'Acquiring satellite fix...',
                    isReady: state.isGpsReady,
                  ),
                ],
              ),
            ),
          ],
        );

      case CalibrationStep.completed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  return Ar3dCanvas(
                    mesh: ShapesFactory.createShape(ShapeType.token,
                        themeColor: AppColors.sunGold),
                    rotX: 0.35,
                    rotY: _celebrationController.value * 2 * 3.14159265,
                    rotZ: 0.0,
                    scale: 90.0,
                    renderStyle: RenderStyle.hybrid,
                    showShadow: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sensors Aligned & Calibrated!',
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sunGold.withOpacity(0.18),
                borderRadius: AppSpacing.roundedPill,
                border: Border.all(color: AppColors.sunGold, width: 1.5),
              ),
              child: Text(
                'Compass and spatial tracking are ready',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.sunGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your magnetometer, horizon level, and GPS sensors are now synchronized with Pangasinan coordinates.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildHardwareStatusRow({
    required IconData icon,
    required String title,
    required String status,
    required bool isReady,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isReady
                ? const Color(0xFF2D6A4F).withOpacity(0.2)
                : Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isReady ? const Color(0xFF52B788) : AppColors.sunGold,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  color: isReady ? const Color(0xFF52B788) : Colors.white60,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isReady ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: isReady ? const Color(0xFF52B788) : AppColors.sunGold,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildBottomActionButtons(CalibrationState state) {
    switch (state.currentStep) {
      case CalibrationStep.magnetometerSweep:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref
                    .read(calibrationProvider.notifier)
                    .advanceStep(CalibrationStep.horizonLevelZero),
                child: Text('Skip Sweep',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70, fontSize: 12)),
              ),
            ),
          ],
        );

      case CalibrationStep.horizonLevelZero:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref
                    .read(calibrationProvider.notifier)
                    .advanceStep(CalibrationStep.hardwareCheck),
                child: Text('Manual Level',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70, fontSize: 12)),
              ),
            ),
          ],
        );

      case CalibrationStep.hardwareCheck:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: state.cameraPermissionGranted && state.isGpsReady
              ? () =>
                  ref.read(calibrationProvider.notifier).completeCalibration()
              : null,
          child: Text(
            'Confirm & Complete Calibration',
            style:
                GoogleFonts.epilogue(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        );

      case CalibrationStep.completed:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.sunGold,
            foregroundColor: const Color(0xFF582F0E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _finishAndNavigate,
          icon: const Icon(Icons.view_in_ar_rounded, size: 20),
          label: Text(
            'Launch AR Viewfinder',
            style:
                GoogleFonts.epilogue(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        );
    }
  }
}
