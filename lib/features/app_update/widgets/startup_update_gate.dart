import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_release.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
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

    return Theme(
      data: AppTheme.pixel,
      child: gateState.phase == GatePhase.baseRequired
          ? _BaseRequiredView(state: gateState)
          : _StartupLoadingView(state: gateState),
    );
  }
}

class _StartupLoadingView extends StatelessWidget {
  final StartupGateState state;

  const _StartupLoadingView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PixelPalette.ink,
      body: DitherBackground(
        top: PixelPalette.ink,
        bottom: PixelPalette.slate,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PixelPanel(
                    style: PixelBoxStyle.gold,
                    padding: 3,
                    child: Icon(
                      Icons.explore_rounded,
                      size: 44,
                      color: PixelPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShadowText(
                    'JUANDERQUEST',
                    textAlign: TextAlign.center,
                    style: PixelType.title(context, color: PixelPalette.sun),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Community-Powered Travel & Discovery',
                    textAlign: TextAlign.center,
                    style: PixelType.body(context, color: PixelPalette.paperDim),
                  ),
                  const SizedBox(height: 36),
                  if (state.phase == GatePhase.downloading) ...[
                    SizedBox(
                      width: 220,
                      child: PixelProgressBar(
                        value: (state.progress > 0 ? state.progress : 0.0)
                            .clamp(0.0, 1.0),
                        color: PixelPalette.sun,
                      ),
                    ),
                  ] else ...[
                    const PixelLoader(),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    state.statusMessage,
                    textAlign: TextAlign.center,
                    style: PixelType.body(
                      context,
                      color: PixelPalette.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PixelPanel(
                    style: PixelBoxStyle.slot,
                    sunken: true,
                    padding: 1,
                    child: Text(
                      '${versionLabel(state.installedVersionName)} (Build ${state.installedVersionCode})',
                      style: PixelType.small(context, color: PixelPalette.paperDim),
                    ),
                  ),
                ],
              ),
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
    final downloadUrl = state.latestVersion?.downloadUrl ??
        'https://github.com/zernanvash/juanderquest-mobile/releases/latest/download/juanderquest-latest.apk';

    return Scaffold(
      backgroundColor: PixelPalette.ink,
      body: DitherBackground(
        top: PixelPalette.ink,
        bottom: PixelPalette.slate,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PixelPanel(
                    style: PixelBoxStyle.red,
                    padding: 3,
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 40,
                      color: PixelPalette.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShadowText(
                    'PLATFORM UPDATE REQUIRED',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: PixelType.title(context, color: PixelPalette.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A new base platform version of JuanDerQuest (v${state.latestVersion?.versionName ?? 'latest'}) is required for updated native plugins and system security.',
                    textAlign: TextAlign.center,
                    style: PixelType.body(context, color: PixelPalette.paperDim),
                  ),
                  const SizedBox(height: 20),
                  if (state.latestVersion?.changelog != null &&
                      state.latestVersion!.changelog.isNotEmpty) ...[
                    PixelPanel(
                      style: PixelBoxStyle.slot,
                      sunken: true,
                      padding: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "WHAT'S NEW:",
                            style: PixelType.small(
                              context,
                              color: PixelPalette.gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.latestVersion!.changelog,
                            style: PixelType.body(
                              context,
                              color: PixelPalette.paper,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  PixelButton(
                    expand: true,
                    onPressed: () => _openDownloadUrl(context, downloadUrl),
                    label: 'DOWNLOAD BASE APK',
                    variant: PixelButtonVariant.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
