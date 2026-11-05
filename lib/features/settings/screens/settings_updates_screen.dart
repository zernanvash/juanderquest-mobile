import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_release.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/widgets/update_dialog.dart';

/// Settings -> App updates: over-the-air APK check and the installed build.
class SettingsUpdatesScreen extends ConsumerWidget {
  const SettingsUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState.status == UpdateStatus.checking;
    final version =
        '${versionLabel(updateState.installedVersionName)} (${updateState.installedVersionCode})';
    final statusLine = isChecking
        ? 'Checking server for updates...'
        : updateState.hasUpdate
            ? 'New version available (v${updateState.latestVersion?.versionName})'
            : updateState.status == UpdateStatus.error
                ? (updateState.errorMessage ??
                    'Update check failed. Tap to retry.')
                : updateState.lastCheckedAt != null
                    ? 'Up to date · Checked today'
                    : 'Tap to check for latest updates';

    Future<void> check() async {
      final hasUpdate = await ref
          .read(appUpdateProvider.notifier)
          .checkForUpdates(silent: false);
      if (!context.mounted) return;
      final current = ref.read(appUpdateProvider);
      if (hasUpdate && current.latestVersion != null) {
        UpdateDialog.show(context, current.latestVersion!);
      } else if (current.status == UpdateStatus.upToDate) {
        showPixelToast(
          context,
          'App is up to date (${versionLabel(current.installedVersionName)} · Build ${current.installedVersionCode}).',
        );
      } else if (current.status == UpdateStatus.readyToInstall &&
          current.latestVersion != null) {
        UpdateDialog.show(context, current.latestVersion!);
      } else if (current.status == UpdateStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              current.errorMessage ??
                  'Unable to check for updates. Please try again.',
            ),
            backgroundColor: PixelPalette.redDeep,
            action: SnackBarAction(
              label: 'Retry',
              textColor: PixelPalette.white,
              onPressed: () {
                ref
                    .read(appUpdateProvider.notifier)
                    .checkForUpdates(silent: false);
              },
            ),
          ),
        );
      }
    }

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'App Updates',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelPanel(
                          style: PixelBoxStyle.wood,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App System & Updates',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'Over-the-air APK releases and build version management.',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        GestureDetector(
                          key: const ValueKey('settings_updates_check'),
                          onTap: isChecking ? null : check,
                          child: PixelPanel(
                            style: PixelBoxStyle.parchment,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: grid.px(2),
                                  runSpacing: grid.px(1),
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Check for updates',
                                        style: PixelType.title(context)),
                                    PixelChip(
                                      version,
                                      style: PixelBoxStyle.slot,
                                    ),
                                  ],
                                ),
                                SizedBox(height: grid.px(1)),
                                Text(
                                  statusLine,
                                  style: PixelType.body(
                                    context,
                                    color: updateState.hasUpdate
                                        ? PixelPalette.greenDark
                                        : updateState.status ==
                                                UpdateStatus.error
                                            ? PixelPalette.redDeep
                                            : PixelPalette.slate,
                                  ),
                                ),
                                SizedBox(height: grid.px(2)),
                                if (isChecking)
                                  const Center(
                                    child: PixelLoader(
                                        label: 'Checking for updates'),
                                  )
                                else if (updateState.hasUpdate)
                                  PixelButton(
                                    key: const ValueKey(
                                        'settings_updates_button'),
                                    label: 'UPDATE',
                                    expand: true,
                                    variant: PixelButtonVariant.primary,
                                    onPressed: isChecking ? null : check,
                                  )
                                else
                                  Text(
                                    'Tap to check',
                                    style: PixelType.small(
                                      context,
                                      color: PixelPalette.greenDark,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
