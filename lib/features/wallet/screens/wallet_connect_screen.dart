import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart'
    hide PrimaryButton, SecondaryButton;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/wallet_signature_service.dart';

/// Plan 67: asked when a traveler without a wallet tries to buy or redeem.
/// Returns true when the traveler chose to connect and a wallet is now linked.
Future<bool> showConnectWalletPromptDialog(BuildContext context,
    {required String itemTitle}) async {
  final connect = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('connect_wallet_prompt'),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      title: const Text('Connect a wallet to continue'),
      content: Text(
          'You can explore, earn EXP and browse the shop without a wallet. To get "$itemTitle", link a Web3 wallet to your account. Your progress stays the same.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now')),
        FilledButton(
            key: const ValueKey('connect_wallet_prompt_yes'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Connect wallet')),
      ],
    ),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Wallet linked. You can finish your purchase now.')));
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
    return JdqScaffold(
      appBar: AppBar(title: const Text('Connect wallet')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (user != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(user.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(user.email,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('${user.points} pts',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.woodBrown)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
              'A linked wallet lets you redeem partner vouchers, buy cosmetics, and claim test rewards and badges on Polygon Amoy (testnet, no real money). Your account, EXP and points stay exactly as they are.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          if (user?.hasBoundWallet == true)
            Text('This account already has a wallet linked.',
                key: const ValueKey('wallet_connect_already'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.primary))
          else ...[
            if (_modal != null)
              AppKitModalConnectButton(appKit: _modal!, context: context),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const ValueKey('wallet_connect_bind'),
              label: 'Link this wallet',
              icon: Icons.link_rounded,
              isLoading: _busy,
              onPressed: _busy || _modal == null ? null : _bind,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                key: const ValueKey('wallet_connect_error'),
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton(
              onPressed: _busy ? null : () => context.pop(false),
              child: const Text('Not now')),
        ],
      ),
    );
  }
}
