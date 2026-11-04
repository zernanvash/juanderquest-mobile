import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_release.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/app_version_info.dart';
import '../providers/app_update_provider.dart';

class UpdateDialog extends ConsumerWidget {
  final AppVersionInfo versionInfo;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
  });

  static Future<void> show(BuildContext context, AppVersionInfo versionInfo) {
    return showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !versionInfo.forceUpdate,
        child: UpdateDialog(versionInfo: versionInfo),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final isDownloading = updateState.status == UpdateStatus.downloading;
    final isInstalling = updateState.status == UpdateStatus.installing;

    return Theme(
      data: AppTheme.pixel,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 3,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: PixelPanel(
                      style: PixelBoxStyle.gold,
                      padding: 2,
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 32,
                        color: PixelPalette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShadowText(
                    'UPDATE AVAILABLE!',
                    textAlign: TextAlign.center,
                    style: PixelType.title(context, color: PixelPalette.ink),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: PixelPanel(
                      style: PixelBoxStyle.slot,
                      sunken: true,
                      padding: 1,
                      child: Text(
                        '${versionLabel(updateState.installedVersionName)} → ${versionLabel(versionInfo.versionName)}',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (versionInfo.changelog.isNotEmpty) ...[
                    Text(
                      "WHAT'S NEW:",
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: PixelPanel(
                        style: PixelBoxStyle.slot,
                        sunken: true,
                        padding: 2,
                        child: SingleChildScrollView(
                          child: Text(
                            versionInfo.changelog,
                            style: PixelType.body(
                              context,
                              color: PixelPalette.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isDownloading) ...[
                    PixelProgressBar(
                      value: (updateState.downloadProgress > 0
                              ? updateState.downloadProgress / 100
                              : 0.0)
                          .clamp(0.0, 1.0),
                      color: PixelPalette.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Downloading update: ${updateState.downloadProgress}%',
                      textAlign: TextAlign.center,
                      style: PixelType.body(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isInstalling) ...[
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: PixelLoader(),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Launching Android installer...',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (updateState.isReadyToInstall) ...[
                    PixelPanel(
                      style: PixelBoxStyle.green,
                      padding: 2,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: PixelPalette.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Package downloaded and ready to install.',
                              style: PixelType.body(
                                context,
                                color: PixelPalette.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (updateState.status == UpdateStatus.error &&
                      updateState.errorMessage != null) ...[
                    PixelPanel(
                      style: PixelBoxStyle.red,
                      padding: 2,
                      child: Text(
                        updateState.errorMessage!,
                        style: PixelType.body(
                          context,
                          color: PixelPalette.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      if (!versionInfo.forceUpdate &&
                          !isDownloading &&
                          !isInstalling) ...[
                        Expanded(
                          child: PixelButton(
                            expand: true,
                            label: 'Later',
                            variant: PixelButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: versionInfo.forceUpdate ? 1 : 2,
                        child: PixelButton(
                          expand: true,
                          label: isDownloading
                              ? 'Downloading...'
                              : isInstalling
                                  ? 'Installing...'
                                  : updateState.isReadyToInstall
                                      ? 'Install Now'
                                      : 'Update Now',
                          variant: PixelButtonVariant.primary,
                          loading: isDownloading || isInstalling,
                          onPressed: isDownloading || isInstalling
                              ? null
                              : () => ref
                                  .read(appUpdateProvider.notifier)
                                  .startDownloadAndInstall(),
                        ),
                      ),
                    ],
                  ),
                  if (updateState.isReadyToInstall &&
                      !isDownloading &&
                      !isInstalling) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => ref
                            .read(appUpdateProvider.notifier)
                            .startDownloadAndInstall(forceRedownload: true),
                        child: Text(
                          'Re-download update package',
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
