import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_release.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../dashboard/home_tips.dart';

/// Settings home: short categories that open their own pages, so a new
/// setting adds a row here instead of growing one long screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final updateState = ref.watch(appUpdateProvider);
    final version =
        '${versionLabel(updateState.installedVersionName)} (${updateState.installedVersionCode})';
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
                    title: 'Explorer Settings',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _identity(context, grid, user),
                          SizedBox(height: grid.px(3)),
                          _SettingsGroup(title: 'ACCOUNT', tiles: [
                            _SettingsTile(
                              key: const ValueKey('settings_appearance'),
                              icon: 'A',
                              title: 'Appearance',
                              subtitle:
                                  'Profile banners, frames, titles and name colours',
                              onTap: () => context.push('/settings/appearance'),
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_interests'),
                              icon: 'I',
                              title: 'Travel interests',
                              subtitle: 'Tune which destinations we recommend',
                              onTap: () =>
                                  context.push('/onboarding/interests'),
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_wallet'),
                              icon: 'W',
                              title: 'Web3 Wallet',
                              subtitle: user?.hasBoundWallet == true
                                  ? 'Linked ${user!.formattedWalletAddress}'
                                  : 'Off-chain demo account · Tap to link',
                              onTap: () => context.push('/wallet/connect'),
                            ),
                          ]),
                          _SettingsGroup(title: 'ACTIVITY', tiles: [
                            _SettingsTile(
                              key: const ValueKey('settings_submissions'),
                              icon: 'S',
                              title: 'My submissions',
                              subtitle:
                                  'Status of your quest and spot submissions',
                              onTap: () => context.push('/history'),
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_affiliate'),
                              icon: 'M',
                              title: 'Merchant affiliate',
                              subtitle:
                                  'Apply to take part in tourism promotions',
                              onTap: () => context.push('/affiliate'),
                            ),
                          ]),
                          _SettingsGroup(title: 'APP', tiles: [
                            _SettingsTile(
                              key: const ValueKey('settings_text_size'),
                              icon: 'T',
                              title: 'Text size',
                              subtitle: ref
                                  .watch(pixelSettingsProvider)
                                  .textSize
                                  .label,
                              onTap: () => _showTextSizeDialog(context, ref),
                            ),
                            // Owner 2026-11-04: run the first-run tutorial again on Home.
                            _SettingsTile(
                              key: const ValueKey('settings_replay_tutorial'),
                              icon: 'R',
                              title: 'Replay tutorial',
                              subtitle: 'Juan shows you around Home again',
                              onTap: () async {
                                await ref
                                    .read(homeTipsControllerProvider.notifier)
                                    .resetForReplay();
                                if (context.mounted) context.go('/dashboard');
                              },
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_updates'),
                              icon: 'U',
                              title: 'App updates',
                              subtitle: updateState.hasUpdate
                                  ? '$version · update available'
                                  : version,
                              highlight: updateState.hasUpdate,
                              onTap: () => context.push('/settings/updates'),
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_developer'),
                              icon: 'D',
                              title: 'Developer tools',
                              subtitle: ref.watch(designerGuideProvider)
                                  ? 'Designer guide is on'
                                  : 'Designer guide and diagnostics',
                              onTap: () => context.push('/settings/developer'),
                            ),
                          ]),
                          _SettingsGroup(title: 'ABOUT', tiles: [
                            _SettingsTile(
                              key: const ValueKey('settings_about'),
                              icon: 'J',
                              title: 'About JuanDerQuest & team',
                              subtitle:
                                  'Universidad de Dagupan capstone authors',
                              onTap: () => context.push('/about'),
                            ),
                            _SettingsTile(
                              key: const ValueKey('settings_governance'),
                              icon: 'G',
                              title: 'Governance prototype',
                              subtitle:
                                  'Separate from JuanChoice community voting',
                              onTap: () => context.push('/vote'),
                            ),
                          ]),
                          SizedBox(height: grid.px(4)),
                          PixelButton(
                            key: const ValueKey('settings_logout'),
                            label: 'Log Out of Account',
                            variant: PixelButtonVariant.danger,
                            expand: true,
                            onPressed: () async {
                              // Stop this phone receiving the account's notifications first,
                              // while the session can still authenticate the request.
                              await ref
                                  .read(pushServiceProvider)
                                  .unregisterDevice();
                              ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/');
                            },
                          ),
                        ],
                      ),
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

  Widget _identity(BuildContext context, PixelGrid grid, dynamic user) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelPanel(
            style: PixelBoxStyle.gold,
            padding: 1,
            child: CosmeticAvatar(
              name: user?.displayName ?? 'Traveler',
              imageUrl: user?.avatarUrl,
              size: grid.px(22),
              frame:
                  user?.cosmetics?['frame']?['asset'] as Map<String, dynamic>?,
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Juan Dela Cruz',
                  maxLines: 2,
                  style: PixelType.title(context),
                ),
                Text(
                  user?.email ?? 'juan@juanderquest.ph',
                  maxLines: 2,
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                Text(
                  'Pangasinan Explorer',
                  maxLines: 2,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.greenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTextSizeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(pixelSettingsProvider).textSize;
    showPixelDialog(
      context: context,
      title: 'Text size',
      message:
          'Choose how text scales across the app. Follow phone adapts automatically to your system font setting.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in PixelTextSize.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PixelButton(
                key: ValueKey('settings_text_size_${option.name}'),
                label: option == current
                    ? '* ${option.label}'
                    : option.label,
                variant: option == current
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  ref.read(pixelSettingsProvider.notifier).setTextSize(option);
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ),
            ),
          ],
        ],
      ),
      actions: [
        PixelButton(
          label: 'Close',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Padding(
      padding: EdgeInsets.only(top: grid.px(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Divider(height: grid.px(1), color: PixelPalette.mist),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: grid.px(2),
          vertical: grid.px(2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelPanel(
              style: PixelBoxStyle.slot,
              padding: 1,
              child: SizedBox(
                width: grid.px(10),
                child: Text(
                  icon,
                  textAlign: TextAlign.center,
                  style: PixelType.title(context),
                ),
              ),
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PixelType.title(context)),
                  Text(
                    subtitle,
                    style: PixelType.body(
                      context,
                      color: highlight
                          ? PixelPalette.greenDark
                          : PixelPalette.slate,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: grid.px(1)),
            Text(
              '>',
              style: PixelType.title(context, color: PixelPalette.woodMid),
            ),
          ],
        ),
      ),
    );
  }
}
