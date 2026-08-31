import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/update_classification.dart';
import '../providers/startup_update_controller.dart';

class StartupUpdateGate extends ConsumerWidget {
  final Widget child;

  const StartupUpdateGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateState = ref.watch(startupUpdateControllerProvider);

    // If gate is ready, render main application
    if (gateState.isReady) {
      return child;
    }

    // If a base platform release is required, show the base-required screen
    if (gateState.phase == GatePhase.baseRequired) {
      return _BaseRequiredView(state: gateState);
    }

    // Default: Render the startup splash & update gate loading screen
    return _StartupLoadingView(state: gateState);
  }
}

class _StartupLoadingView extends StatelessWidget {
  final StartupGateState state;

  const _StartupLoadingView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing JuanDerQuest Badge
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.sunGold, Color(0xFFD97706)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sunGold.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.explore_rounded,
                      size: 48,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                Text(
                  'JuanDerQuest',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pangasinan Tourism & Discovery',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),

                // Progress Indicator & Status Message
                if (state.phase == GatePhase.downloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 200,
                      height: 6,
                      child: LinearProgressIndicator(
                        value: state.progress > 0 ? state.progress : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sunGold),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.sunGold),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Live status text
                Text(
                  state.statusMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // Version tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'v${state.installedVersionName} (Build ${state.installedVersionCode})',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BaseRequiredView extends StatelessWidget {
  final StartupGateState state;

  const _BaseRequiredView({required this.state});

  Future<void> _openDownloadUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open download link: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadUrl = state.latestVersion?.downloadUrl ?? 'https://jdq.zernanvash.dev/download/juanderquest-latest.apk';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.danger, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 40,
                      color: AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Platform Update Required',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A new base platform version of JuanDerQuest (v${state.latestVersion?.versionName ?? 'latest'}) is required for updated native plugins and system security.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.latestVersion?.changelog != null && state.latestVersion!.changelog.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What\'s New:',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.sunGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),
                        Text(
                          state.latestVersion!.changelog,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunGold,
                      foregroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openDownloadUrl(context, downloadUrl),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text(
                      'Download Base APK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
