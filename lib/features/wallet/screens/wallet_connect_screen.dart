import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart'
    hide PrimaryButton, SecondaryButton;

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/wallet_signature_service.dart';

/// Plan 67: asked when a traveler without a wallet tries to buy or redeem.
/// Returns true when the traveler chose to connect and a wallet is now linked.
Future<bool> showConnectWalletPromptDialog(BuildContext context,
    {required String itemTitle}) async {
  final connect = await showPixelDialog<bool>(
    context: context,
    title: 'Connect a wallet',
    content: Column(
      key: const ValueKey('connect_wallet_prompt'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You can explore, earn EXP and browse the shop without a wallet. To get "$itemTitle", link a Web3 wallet to your account. Your progress stays the same.',
          style: PixelType.body(
            context,
            color: PixelPalette.slate,
          ),
        ),
      ],
    ),
    actions: [
      PixelButton(
        label: 'Not now',
        variant: PixelButtonVariant.secondary,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      PixelButton(
        key: const ValueKey('connect_wallet_prompt_yes'),
        label: 'Connect wallet',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  if (connect != true || !context.mounted) return false;
  return await context.push<bool>('/wallet/connect') ?? false;
}

/// Plan 67: link a wallet to the signed-in account, then go back with `true`.
class WalletConnectScreen extends ConsumerStatefulWidget {
  const WalletConnectScreen({super.key});

  @override
  ConsumerState<WalletConnectScreen> createState() =>
      _WalletConnectScreenState();
}

class _WalletConnectScreenState extends ConsumerState<WalletConnectScreen> {
  ReownAppKitModal? _modal;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initWallet());
  }

  Future<void> _initWallet() async {
    try {
      final modal = await WalletSignatureService.initialize(context);
      if (!mounted) {
        await modal.dispose();
        return;
      }
      setState(() => _modal = modal);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message
            : 'Wallet connection is unavailable.');
      }
    }
  }

  @override
  void dispose() {
    _modal?.dispose();
    super.dispose();
  }

  Future<void> _bind() async {
    final modal = _modal;
    final address =
        modal == null ? null : WalletSignatureService.connectedAddress(modal);
    if (modal == null || address == null) {
      setState(() => _error = 'Connect an EVM wallet first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(authProvider.notifier);
    try {
      final challenge = await notifier.requestWalletChallenge(address);
      if (challenge == null) {
        throw StateError('Could not get a wallet challenge from the API.');
      }
      final signature =
          await WalletSignatureService.signChallenge(modal, challenge);
      final ok =
          await notifier.bindWallet(address: address, signature: signature);
      if (!mounted) return;
      if (ok) {
        showPixelToast(
            context, 'Wallet linked. You can finish your purchase now.');
        context.pop(true);
        return;
      }
      setState(() =>
          _error = ref.read(authProvider).error ?? 'Could not link the wallet.');
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is StateError ? error.message : 'Signature was not completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
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
                    title: 'Connect Wallet',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(4),
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
                                'A linked wallet',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'Redeem partner vouchers, buy cosmetics, and claim test rewards and badges on Polygon Amoy. Testnet only, no real money. Your account, EXP and points stay exactly as they are.',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        if (user != null)
                          PixelPanel(
                            style: PixelBoxStyle.parchment,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName,
                                        maxLines: 2,
                                        style: PixelType.title(context),
                                      ),
                                      SizedBox(height: grid.px(1)),
                                      Text(
                                        user.email,
                                        maxLines: 2,
                                        style: PixelType.body(
                                          context,
                                          color: PixelPalette.slate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: grid.px(2)),
                                PixelChip('${user.points} pts'),
                              ],
                            ),
                          ),
                        SizedBox(height: grid.px(3)),
                        if (user?.hasBoundWallet == true)
                          PixelPanel(
                            key: const ValueKey('wallet_connect_already'),
                            style: PixelBoxStyle.green,
                            child: Text(
                              'This account already has a wallet linked.',
                              textAlign: TextAlign.center,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.white,
                              ),
                            ),
                          )
                        else ...[
                          if (_modal != null)
                            PixelPanel(
                              style: PixelBoxStyle.parchment,
                              padding: 2,
                              child: AppKitModalConnectButton(
                                appKit: _modal!,
                                context: context,
                              ),
                            ),
                          SizedBox(height: grid.px(3)),
                          PixelButton(
                            key: const ValueKey('wallet_connect_bind'),
                            label: 'Link this wallet',
                            expand: true,
                            loading: _busy,
                            onPressed: _busy || _modal == null ? null : _bind,
                          ),
                        ],
                        if (_error != null) ...[
                          SizedBox(height: grid.px(3)),
                          PixelPanel(
                            style: PixelBoxStyle.red,
                            child: Text(
                              _error!,
                              key: const ValueKey('wallet_connect_error'),
                              textAlign: TextAlign.center,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.white,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: grid.px(3)),
                        PixelButton(
                          label: 'Not now',
                          variant: PixelButtonVariant.secondary,
                          expand: true,
                          onPressed: _busy ? null : () => context.pop(false),
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
