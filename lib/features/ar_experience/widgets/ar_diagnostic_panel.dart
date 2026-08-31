import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/ar_diagnostics_controller.dart';

class ArDiagnosticPanel extends ConsumerWidget {
  const ArDiagnosticPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagState = ref.watch(arDiagnosticsProvider);
    final controller = ref.read(arDiagnosticsProvider.notifier);

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, right: 8.0),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.85),
              foregroundColor: AppColors.sunGold,
            ),
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'AR Diagnostics & Layer Isolation',
            onPressed: () => _showDiagnosticsSheet(context, diagState, controller),
          ),
        ),
      ),
    );
  }

  void _showDiagnosticsSheet(
    BuildContext context,
    ArDiagnosticsState state,
    ArDiagnosticsController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final liveState = ref.watch(arDiagnosticsProvider);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers_outlined,
                              color: AppColors.sunGold, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'AR Layer Diagnostics',
                            style: GoogleFonts.epilogue(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.sunGold, width: 0.5),
                        ),
                        child: Text(
                          'Commit ${liveState.commitHash}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.sunGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Camera status telemetry card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera Hardware Status:',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.sunGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${liveState.cameraStatus.toUpperCase()} • Lens: ${liveState.cameraLens} • Preset: ${liveState.cameraPreset}',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.white),
                        ),
                        if (liveState.previewWidth > 0)
                          Text(
                            'Resolution: ${liveState.previewWidth.toInt()}x${liveState.previewHeight.toInt()} (${liveState.aspectRatio.toStringAsFixed(2)}:1) • Init: ${liveState.initDurationMs}ms',
                            style: AppTypography.bodySmall
                                .copyWith(color: Colors.white70),
                          ),
                        if (liveState.lastExceptionCode != null)
                          Text(
                            'Error: ${liveState.lastExceptionCode}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.danger),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Independent Layer Toggles
                  _buildToggleTile(
                    title: '1. Solid Test Background',
                    subtitle: 'Tests Flutter 2D composition without camera',
                    value: liveState.showSolidBackground,
                    onChanged: (_) => controller.toggleSolidBackground(),
                  ),
                  _buildToggleTile(
                    title: '2. Live Camera Preview Texture',
                    subtitle: 'Renders physical CameraPreview feed',
                    value: liveState.showCameraPreview,
                    onChanged: (_) => controller.toggleCameraPreview(),
                  ),
                  _buildToggleTile(
                    title: '3. Centered 3D Benchmark Gem',
                    subtitle: 'Validates 3D rasterization without spatial math',
                    value: liveState.showCenteredBenchmarkGem,
                    onChanged: (_) => controller.toggleCenteredBenchmarkGem(),
                  ),
                  _buildToggleTile(
                    title: '4. World-Anchored Spatial Overlay',
                    subtitle: 'Projects 3D mesh at GPS azimuth/pitch',
                    value: liveState.showWorldAnchor,
                    onChanged: (_) => controller.toggleWorldAnchor(),
                  ),
                  _buildToggleTile(
                    title: '5. Reticle & HUD Overlay',
                    subtitle: 'Shows scanning crosshair & mini radar',
                    value: liveState.showHudReticle,
                    onChanged: (_) => controller.toggleHudReticle(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(
          color: Colors.white60,
        ),
      ),
      activeColor: AppColors.sunGold,
      value: value,
      onChanged: onChanged,
    );
  }
}
