import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart'
    hide PrimaryButton, SecondaryButton;

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/wallet_signature_service.dart';
import '../providers/profile_stats_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isFollowing = false;

  Color? _cosmeticColor(dynamic value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  Map<String, dynamic>? _cosmeticAsset(
      Map<String, dynamic>? cosmetics, String slot) {
    final item = cosmetics?[slot];
    if (item is! Map || item['asset'] is! Map) return null;
    return Map<String, dynamic>.from(item['asset'] as Map);
  }

  Widget _buildAvatarWidget(
    BuildContext context,
    PixelGrid grid,
    String? avatarUrl,
    String displayName,
  ) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'J';
    return SizedBox(
      width: grid.px(42),
      height: grid.px(42),
      child: ClipRect(
        child: isValidUrl
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _avatarFallback(context, initial),
              )
            : _avatarFallback(context, initial),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String initial) {
    return DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.greenDeep,
      child: Center(
        child: Text(
          initial,
          style: PixelType.title(context, color: PixelPalette.paper),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);

    final isMine = widget.username == null ||
        widget.username == currentUser?.id ||
        widget.username == currentUser?.seedId ||
        (currentUser != null &&
            widget.username == currentUser.handle.replaceFirst('@', ''));

    final displayName = isMine
        ? (currentUser?.displayName ?? 'Juan Dela Cruz')
        : (widget.username ?? 'Pangasinan Explorer');

    final displayHandle = isMine
        ? (currentUser?.handle ?? '@demo-traveler')
        : '@${widget.username}';
    final cosmetics = isMine ? currentUser?.cosmetics : null;
    final titleAsset = _cosmeticAsset(cosmetics, 'title');
    final nameColorAsset = _cosmeticAsset(cosmetics, 'nameColor');

    final pointsBalance = currentUser?.points ?? stats.pointsBalance;
    final level = (pointsBalance / 50).floor() + 1;

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
                    title: isMine ? 'Traveler Passport' : 'Explorer Profile',
                    onBack: canPop && !isMine
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      if (isMine)
                        PixelIconButton(
                          icon: DesignerArt.notifBell,
                          semanticLabel: 'Notifications',
                          onPressed: () => context.push('/notifications'),
                        ),
                      if (isMine)
                        PixelIconButton(
                          icon: DesignerArt.navSettings,
                          semanticLabel: 'Explorer Settings',
                          onPressed: () => context.push('/settings'),
                        ),
                    ],
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
                        _identity(
                            context,
                            grid,
                            isMine,
                            displayName,
                            displayHandle,
                            currentUser,
                            cosmetics,
                            titleAsset,
                            nameColorAsset,
                            level,
                            pointsBalance),
                        SizedBox(height: grid.px(4)),
                        if (isMine) ...[
                          _sectionTitle(context, 'Web3 & Blockchain Identity',
                              'Link any EVM or Web3 wallet to preserve your passport across devices.'),
                          SizedBox(height: grid.px(2)),
                          _walletCard(context, grid, currentUser),
                          SizedBox(height: grid.px(4)),
                          _sectionTitle(context, 'Traveler Statistics',
                              'Your quest completions, submissions, and reward points balance.'),
                          SizedBox(height: grid.px(2)),
                          _stats(context, grid, stats, pointsBalance),
                          SizedBox(height: grid.px(4)),
                        ],
                        _sectionTitle(context, 'Community & Ecosystem',
                            'Compete in regional sprints and explore research pillars.'),
                        SizedBox(height: grid.px(2)),
                        _links(context, grid, isMine),
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

  Widget _identity(
    BuildContext context,
    PixelGrid grid,
    bool isMine,
    String displayName,
    String displayHandle,
    UserModel? currentUser,
    Map<String, dynamic>? cosmetics,
    Map<String, dynamic>? titleAsset,
    Map<String, dynamic>? nameColorAsset,
    int level,
    int pointsBalance,
  ) {
    final nameColor = _cosmeticColor(nameColorAsset?['color']);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMine)
            SizedBox(
              height: grid.px(36),
              child: const DitherBackground(
                top: PixelPalette.greenMid,
                bottom: PixelPalette.greenDeep,
              ),
            ),
          if (isMine) SizedBox(height: grid.px(2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelPanel(
                style: PixelBoxStyle.gold,
                padding: 1,
                child: _buildAvatarWidget(
                  context,
                  grid,
                  isMine ? currentUser?.avatarUrl : null,
                  displayName,
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      style:
                          PixelType.title(context).copyWith(color: nameColor),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      displayHandle,
                      maxLines: 2,
                      style: PixelType.body(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    if ((titleAsset?['text']?.toString() ?? '').isNotEmpty) ...[
                      SizedBox(height: grid.px(1)),
                      PixelPanel(
                        style: PixelBoxStyle.gold.copyWith(
                          corner: 1,
                          shadowPx: 0,
                        ),
                        padding: 1,
                        child: Text(
                          titleAsset!['text'].toString(),
                          maxLines: 2,
                          style: PixelType.small(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip('Level $level Explorer',
                  style: PixelBoxStyle.green, textColor: PixelPalette.white),
              PixelChip('$pointsBalance mJDQ'),
            ],
          ),
          if (!isMine) ...[
            SizedBox(height: grid.px(3)),
            PixelButton(
              key: const ValueKey('profile_follow'),
              label: _isFollowing ? 'Following' : 'Follow Scout',
              onPressed: () {
                setState(() => _isFollowing = !_isFollowing);
                showPixelToast(
                  context,
                  _isFollowing
                      ? 'Now following $displayName.'
                      : 'Unfollowed $displayName.',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PixelType.title(context)),
        SizedBox(height: PixelGrid.of(context).px(1)),
        Text(
          subtitle,
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      ],
    );
  }

  Widget _stats(
    BuildContext context,
    PixelGrid grid,
    ProfileStatsModel stats,
    int pointsBalance,
  ) {
    return Column(
      children: [
        _metric(context, grid, 'Reward points balance', '$pointsBalance PTS',
            PixelBoxStyle.gold),
        SizedBox(height: grid.px(2)),
        Row(
          children: [
            Expanded(
              child: _metric(context, grid, 'Completed',
                  '${stats.completedQuests}', PixelBoxStyle.green),
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: _metric(context, grid, 'Submissions',
                  '${stats.totalSubmissions}', PixelBoxStyle.wood),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    PixelGrid grid,
    String label,
    String value,
    PixelBoxStyle style,
  ) {
    final dark = style == PixelBoxStyle.wood;
    final textColor = dark ? PixelPalette.white : PixelPalette.ink;
    return PixelPanel(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PixelType.small(context, color: textColor),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            value,
            style: PixelType.title(context, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _walletCard(BuildContext context, PixelGrid grid, UserModel? user) {
    if (user == null) return const SizedBox.shrink();
    final hasWallet = user.hasBoundWallet;

    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWallet
                          ? 'Web3 Passport Linked'
                          : 'Off-Chain Demo Account',
                      style: PixelType.title(context),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      hasWallet
                          ? 'Wallet address linked to account'
                          : 'No Web3 Wallet Linked Yet',
                      style: PixelType.body(
                        context,
                        color: hasWallet
                            ? PixelPalette.greenDark
                            : PixelPalette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
              PixelChip(
                hasWallet ? 'Verified' : 'Off-chain',
                style: hasWallet ? PixelBoxStyle.green : PixelBoxStyle.gold,
                textColor: hasWallet ? PixelPalette.white : PixelPalette.ink,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          if (hasWallet) ...[
            PixelPanel(
              style: PixelBoxStyle.slot,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      user.formattedWalletAddress ?? user.walletAddress ?? '',
                      style: PixelType.numbers(context),
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('profile_copy_wallet'),
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: user.walletAddress ?? ''));
                      showPixelToast(
                          context, 'Wallet address copied to clipboard.');
                    },
                    child: Padding(
                      padding: EdgeInsets.all(grid.px(2)),
                      child: Text(
                        'Copy',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.greenDeep,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(2)),
            Text(
              'This address can sign in to your traveler account. Demo points remain off-chain and are not wallet tokens.',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                key: const ValueKey('profile_unlink_wallet'),
                label: 'Unlink Wallet',
                variant: PixelButtonVariant.danger,
                onPressed: () => _confirmUnbindWallet(context),
              ),
            ),
          ] else ...[
            Text(
              'You are playing with off-chain demo points (\$mJDQ). Link an EVM wallet for signature-based account sign-in; this does not unlock on-chain rewards or voting.',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(3)),
            PixelButton(
              key: const ValueKey('profile_link_wallet'),
              label: 'Link Web3 / EVM Wallet',
              expand: true,
              onPressed: () => _showWalletBindingModal(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _links(BuildContext context, PixelGrid grid, bool isMine) {
    Widget row(String title, String subtitle, String route,
        {ValueKey<String>? key}) {
      return GestureDetector(
        key: key,
        onTap: () => context.push(route),
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PixelType.title(context)),
                    SizedBox(height: grid.px(1)),
                    Text(
                      subtitle,
                      style: PixelType.body(context, color: PixelPalette.slate),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
              Text(
                '>',
                style: PixelType.title(context, color: PixelPalette.woodMid),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        row('Saved Destinations', 'Places you bookmarked for later', '/saved',
            key: const ValueKey('profile_saved')),
        SizedBox(height: grid.px(2)),
        row('The Trail', 'Personalized route suggestions · Coming soon',
            '/trail',
            key: const ValueKey('profile_trail')),
        SizedBox(height: grid.px(2)),
        row('Leaderboard',
            'View top explorers, rankings, and sprint leaderboards.', '/plaza',
            key: const ValueKey('profile_leaderboard')),
        // Owner 2026-11-05: Shop is a tab now and Settings is the gear in the
        // header, so their rows here were removed.
      ],
    );
  }

  Future<void> _showWalletBindingModal(BuildContext context) async {
    ReownAppKitModal modal;
    try {
      modal = await WalletSignatureService.initialize(context);
    } catch (e) {
      if (context.mounted) {
        showPixelToast(
          context,
          e is StateError
              ? e.message
              : 'Wallet connection is unavailable. Please try again.',
        );
      }
      return;
    }
    if (!context.mounted) {
      await modal.dispose();
      return;
    }
    bool isSubmitting = false;
    String? modalError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final grid = PixelGrid.of(context);
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              grid.px(3),
              grid.px(3),
              grid.px(3),
              grid.px(3) + bottomInset,
            ),
            child: SingleChildScrollView(
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Link Web3 Wallet', style: PixelType.title(context)),
                    SizedBox(height: grid.px(1)),
                    Text(
                      'Progressive Web3 Passport Binding',
                      style: PixelType.body(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    SizedBox(height: grid.px(2)),
                    Text(
                      'A wallet signature links this address for account recovery. Your demo points remain off-chain; no tokens are minted or transferred.',
                      style: PixelType.body(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    SizedBox(height: grid.px(2)),
                    AppKitModalConnectButton(appKit: modal, context: context),
                    SizedBox(height: grid.px(2)),
                    Text(
                      'Connect any Web3 wallet (MetaMask, Coinbase, Trust, Rainbow, etc.), approve the connection, then sign the one-time authentication message to link your wallet.',
                      style: PixelType.body(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    if (modalError != null) ...[
                      SizedBox(height: grid.px(2)),
                      Text(
                        modalError!,
                        style: PixelType.body(context, color: PixelPalette.red),
                      ),
                    ],
                    SizedBox(height: grid.px(3)),
                    PixelButton(
                      key: const ValueKey('profile_bind_wallet'),
                      label: 'Bind Wallet to Passport',
                      expand: true,
                      loading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final addr =
                                  WalletSignatureService.connectedAddress(
                                      modal);
                              if (addr == null) {
                                setSheetState(() => modalError =
                                    'Connect an EVM wallet first.');
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                modalError = null;
                              });

                              bool ok = false;
                              try {
                                final challenge = await ref
                                    .read(authProvider.notifier)
                                    .requestWalletChallenge(addr);
                                if (challenge == null) {
                                  throw StateError(
                                      'Could not get a wallet challenge from the API.');
                                }
                                final signature =
                                    await WalletSignatureService.signChallenge(
                                        modal, challenge);
                                ok = await ref
                                    .read(authProvider.notifier)
                                    .bindWallet(
                                      address: addr,
                                      signature: signature,
                                    );
                              } catch (e) {
                                if (sheetCtx.mounted) {
                                  setSheetState(() => modalError =
                                      e is StateError
                                          ? e.message
                                          : 'Signature was not completed.');
                                }
                              }

                              if (sheetCtx.mounted) {
                                if (ok) {
                                  Navigator.of(sheetCtx).pop();
                                  showPixelToast(context,
                                      'Wallet successfully linked to your passport!');
                                } else {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    modalError ??=
                                        ref.read(authProvider).error ??
                                            'Failed to bind wallet.';
                                  });
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    await modal.dispose();
  }

  void _confirmUnbindWallet(BuildContext context) {
    showPixelDialog<void>(
      context: context,
      title: 'Unlink Web3 wallet?',
      message:
          'Your account will revert to off-chain mode. You can link this or another wallet at any time.',
      actions: [
        PixelButton(
          label: 'Cancel',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        PixelButton(
          key: const ValueKey('profile_confirm_unlink'),
          label: 'Unlink',
          variant: PixelButtonVariant.danger,
          onPressed: () async {
            Navigator.of(context).pop();
            final ok = await ref.read(authProvider.notifier).unbindWallet();
            if (context.mounted) {
              showPixelToast(
                context,
                ok
                    ? 'Wallet unlinked successfully.'
                    : 'Failed to unlink wallet.',
              );
            }
          },
        ),
      ],
    );
  }
}
