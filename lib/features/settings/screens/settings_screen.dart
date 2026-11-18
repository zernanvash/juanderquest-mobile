import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_release.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../dashboard/home_tips.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../../merchant/models/merchant_models.dart';
import '../../merchant/providers/merchant_hub_provider.dart';
import '../../vote/pixel/wave3_art.dart';
import '../home_town.dart';

/// Settings home: short categories that open their own pages, so a new
/// setting adds a row here instead of growing one long screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantHub = ref.watch(merchantHubStatusProvider).valueOrNull ??
        MerchantHubStatus.none;
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
                    title: tr(context, en: 'Settings', tl: 'Mga Setting'),
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _identity(context, grid, user),
                          SizedBox(height: grid.px(3)),
                          _SettingsGroup(
                              title: tr(context, en: 'ACCOUNT', tl: 'ACCOUNT'),
                              tiles: [
                                _SettingsTile(
                                  key: const ValueKey('settings_appearance'),
                                  pixelIcon: DesignerArt.navProfile,
                                  title: tr(context,
                                      en: 'Appearance',
                                      tl: 'Hitsura ng Profile'),
                                  onTap: () =>
                                      context.push('/settings/appearance'),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_home_town'),
                                  pixelIcon: DesignerArt.navHome,
                                  title: tr(context,
                                      en: 'Home town', tl: 'Sariling Bayan'),
                                  onTap: () => showHomeTownPicker(context, ref),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_interests'),
                                  pixelIcon: DesignerArt.heartLiked,
                                  title: tr(context,
                                      en: 'Travel interests',
                                      tl: 'Hilig sa Paglalakbay'),
                                  onTap: () =>
                                      context.push('/onboarding/interests'),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_wallet'),
                                  pixelIcon: DesignerArt.gem,
                                  title: tr(context,
                                      en: 'Web3 Wallet', tl: 'Web3 Wallet'),
                                  // Keeps the testnet disclosure in one word.
                                  value: user?.hasBoundWallet == true
                                      ? user!.formattedWalletAddress
                                      : 'Testnet',
                                  onTap: () => context.push('/wallet/connect'),
                                ),
                              ]),
                          _SettingsGroup(
                              title: tr(context, en: 'ACTIVITY', tl: 'GAWAIN'),
                              tiles: [
                                _SettingsTile(
                                  key: const ValueKey('settings_submissions'),
                                  pixelIcon: HomePixelArt.stampCheck,
                                  title: tr(context,
                                      en: 'My submissions',
                                      tl: 'Mga Isinumite'),
                                  onTap: () => context.push('/history'),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_affiliate'),
                                  pixelIcon: DesignerArt.salakot,
                                  title: merchantHub.label,
                                  onTap: () => context.push(merchantHub.route),
                                ),
                              ]),
                          _SettingsGroup(
                              title: tr(context, en: 'APP', tl: 'APP'),
                              tiles: [
                                _SettingsTile(
                                  key: const ValueKey('settings_language'),
                                  pixelIcon: DesignerArt.juanChoice,
                                  title:
                                      tr(context, en: 'Language', tl: 'Wika'),
                                  value: ref
                                      .watch(pixelSettingsProvider)
                                      .language
                                      .label,
                                  onTap: () =>
                                      _showLanguageDialog(context, ref),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_notifications'),
                                  pixelIcon: DesignerArt.notifBell,
                                  title: tr(context,
                                      en: 'Notifications', tl: 'Mga Abiso'),
                                  onTap: () =>
                                      context.push('/settings/notifications'),
                                ),
                                // Owner 2026-11-16: music and button sounds.
                                _SettingsTile(
                                  key: const ValueKey('settings_music'),
                                  pixelIcon: DesignerArt.questMarker,
                                  title: tr(context, en: 'Music', tl: 'Musika'),
                                  value: ref.watch(pixelSettingsProvider).music
                                      ? tr(context, en: 'On', tl: 'Bukas')
                                      : tr(context, en: 'Off', tl: 'Sarado'),
                                  onTap: () => ref
                                      .read(pixelSettingsProvider.notifier)
                                      .setMusic(!ref
                                          .read(pixelSettingsProvider)
                                          .music),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_sounds'),
                                  pixelIcon: DesignerArt.plazaTrophy,
                                  title: tr(context,
                                      en: 'Button sounds',
                                      tl: 'Tunog ng button'),
                                  value: ref.watch(pixelSettingsProvider).sounds
                                      ? tr(context, en: 'On', tl: 'Bukas')
                                      : tr(context, en: 'Off', tl: 'Sarado'),
                                  onTap: () => ref
                                      .read(pixelSettingsProvider.notifier)
                                      .setSounds(!ref
                                          .read(pixelSettingsProvider)
                                          .sounds),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_reduce_motion'),
                                  pixelIcon: DesignerArt.navMap,
                                  title: tr(context,
                                      en: 'Reduce motion',
                                      tl: 'Bawasan ang galaw'),
                                  value: ref
                                          .watch(pixelSettingsProvider)
                                          .reduceMotion
                                      ? tr(context, en: 'On', tl: 'Bukas')
                                      : tr(context, en: 'Off', tl: 'Sarado'),
                                  onTap: () => ref
                                      .read(pixelSettingsProvider.notifier)
                                      .setReduceMotion(!ref
                                          .read(pixelSettingsProvider)
                                          .reduceMotion),
                                ),
                                // v0.3.1: dark mode (plain dark-brown pages).
                                _SettingsTile(
                                  key: const ValueKey('settings_dark_mode'),
                                  pixelIcon: DesignerArt.navProfile,
                                  title: tr(context,
                                      en: 'Dark mode', tl: 'Madilim na tema'),
                                  value: ref
                                          .watch(pixelSettingsProvider)
                                          .darkMode
                                      ? tr(context, en: 'On', tl: 'Bukas')
                                      : tr(context, en: 'Off', tl: 'Sarado'),
                                  onTap: () => ref
                                      .read(pixelSettingsProvider.notifier)
                                      .setDarkMode(!ref
                                          .read(pixelSettingsProvider)
                                          .darkMode),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_text_size'),
                                  pixelIcon: DesignerArt.search,
                                  title: tr(context,
                                      en: 'Text size', tl: 'Laki ng Teksto'),
                                  value: ref
                                      .watch(pixelSettingsProvider)
                                      .textSize
                                      .label,
                                  onTap: () =>
                                      _showTextSizeDialog(context, ref),
                                ),
                                // Owner 2026-11-04: run the first-run tutorial again on Home.
                                _SettingsTile(
                                  key: const ValueKey(
                                      'settings_replay_tutorial'),
                                  pixelIcon: Wave3Art.refresh,
                                  title: tr(context,
                                      en: 'Replay tutorial',
                                      tl: 'Ulitin ang Gabay'),
                                  onTap: () async {
                                    await ref
                                        .read(
                                            homeTipsControllerProvider.notifier)
                                        .resetForReplay();
                                    if (context.mounted) {
                                      context.go('/dashboard');
                                    }
                                  },
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_updates'),
                                  pixelIcon: DesignerArt.navShop,
                                  title: tr(context,
                                      en: 'App updates', tl: 'Update ng App'),
                                  value: updateState.hasUpdate
                                      ? '$version · update'
                                      : version,
                                  highlight: updateState.hasUpdate,
                                  onTap: () =>
                                      context.push('/settings/updates'),
                                ),
                                _SettingsTile(
                                  key: const ValueKey('settings_developer'),
                                  pixelIcon: DesignerArt.navSettings,
                                  title: tr(context,
                                      en: 'Developer tools',
                                      tl: 'Developer Tools'),
                                  onTap: () =>
                                      context.push('/settings/developer'),
                                ),
                              ]),
                          _SettingsGroup(
                              title: tr(context, en: 'ABOUT', tl: 'TUNGKOL'),
                              tiles: [
                                _SettingsTile(
                                  key: const ValueKey('settings_about'),
                                  pixelIcon: DesignerArt.questionMark,
                                  title: tr(context,
                                      en: 'About JuanDerQuest & team',
                                      tl: 'Tungkol sa JuanDerQuest'),
                                  onTap: () => context.push('/about'),
                                ),
                              ]),
                          SizedBox(height: grid.px(4)),
                          PixelButton(
                            key: const ValueKey('settings_logout'),
                            label: tr(context,
                                en: 'Log Out of Account', tl: 'Mag-log Out'),
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
          CosmeticAvatar(
            name: user?.displayName ?? 'Traveler',
            imageUrl: user?.avatarUrl,
            size: grid.px(22),
            frame: user?.cosmetics?['frame']?['asset'] as Map<String, dynamic>?,
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(pixelSettingsProvider).language;
    showPixelDialog(
      context: context,
      title: tr(context, en: 'Language', tl: 'Wika'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in AppLanguage.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PixelButton(
                key: ValueKey('settings_language_${option.name}'),
                label: option == current ? '* ${option.label}' : option.label,
                variant: option == current
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  ref.read(pixelSettingsProvider.notifier).setLanguage(option);
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ),
            ),
        ],
      ),
      actions: [
        PixelButton(
          label: tr(context, en: 'Close', tl: 'Isara'),
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
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
                label: option == current ? '* ${option.label}' : option.label,
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
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(title),
            SizedBox(height: grid.px(1)),
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                Container(height: grid.unit, color: PixelPalette.paperDim),
              tiles[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.pixelIcon,
    required this.title,
    this.value,
    required this.onTap,
    this.highlight = false,
  });

  final PixelArt pixelIcon;
  final String title;

  /// Plan 93b WP-8: one line per row; only status rows show a short value.
  final String? value;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Row(
          children: [
            PixelIconFit(pixelIcon, box: 20),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.title(context),
              ),
            ),
            if (value != null) ...[
              SizedBox(width: grid.px(1)),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: PixelType.small(
                    context,
                    color:
                        highlight ? PixelPalette.greenDark : PixelPalette.slate,
                  ),
                ),
              ),
            ],
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
