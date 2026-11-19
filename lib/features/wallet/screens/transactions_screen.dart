import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../providers/transactions_provider.dart';
import '../widgets/transaction_receipt_sheet.dart';

/// Unified Traveler Transactions & Receipts screen (`/transactions`).
/// Shows every ledger entry, redeemed voucher, and on-chain badge mint with
/// 1-tap Copy Receipt / Copy Blockchain Scan and full shareable invoice sheet.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionCategory _filter = TransactionCategory.all;

  static String _shortWallet(String address) => address.length > 14
      ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
      : address;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final txAsync = ref.watch(transactionsProvider);
    final canPop = Navigator.of(context).canPop();

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final wallet = user?.walletAddress?.trim() ?? '';
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Transactions & Receipts',
                    onBack: canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      onRefresh: () async {
                        ref.invalidate(transactionsProvider);
                        await ref.read(transactionsProvider.future);
                      },
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          grid.gutter,
                          grid.px(3),
                          grid.gutter,
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          _walletBanner(context, grid, wallet),
                          SizedBox(height: grid.px(3)),
                          _filterStrip(context, grid),
                          SizedBox(height: grid.px(3)),
                          txAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(24),
                              child: PixelLoader(label: 'Loading receipts…'),
                            ),
                            error: (err, _) => PixelPanel(
                              style: PixelBoxStyle.red,
                              padding: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Could not load transactions.',
                                    style: PixelType.body(context,
                                        color: PixelPalette.white),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  PixelButton(
                                    label: 'Retry',
                                    variant: PixelButtonVariant.secondary,
                                    onPressed: () =>
                                        ref.invalidate(transactionsProvider),
                                  ),
                                ],
                              ),
                            ),
                            data: (all) {
                              final filtered = _filter == TransactionCategory.all
                                  ? all
                                  : all
                                      .where((t) => t.category == _filter)
                                      .toList();
                              if (filtered.isEmpty) {
                                return PixelPanel(
                                  key: const ValueKey('transactions_empty'),
                                  style: PixelBoxStyle.parchment,
                                  padding: 4,
                                  child: Text(
                                    _filter == TransactionCategory.all
                                        ? 'No transactions recorded yet. Complete quests, redeem vouchers, or earn badges to get receipts here.'
                                        : 'No transactions in this category yet.',
                                    textAlign: TextAlign.center,
                                    style: PixelType.body(context,
                                        color: PixelPalette.slate),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final tx in filtered) ...[
                                    _transactionCard(context, grid, tx),
                                    SizedBox(height: grid.px(2)),
                                  ],
                                ],
                              );
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

  Widget _walletBanner(BuildContext context, PixelGrid grid, String wallet) {
    final hasWallet = wallet.isNotEmpty;
    return PixelPanel(
      style: PixelBoxStyle.wood,
      padding: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasWallet ? 'LINKED WALLET' : 'OFF-CHAIN RECEIPTS',
            style: PixelType.small(context, color: PixelPalette.sun),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            hasWallet
                ? _shortWallet(wallet)
                : 'Every reward, voucher, and vote has a shareable receipt. Link a wallet for on-chain PolygonScan proof.',
            style: PixelType.body(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              if (hasWallet) ...[
                PixelButton(
                  key: const ValueKey('transactions_copy_wallet'),
                  label: 'Copy Address',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: wallet));
                    showPixelToast(context, 'Wallet address copied.');
                  },
                ),
                PixelButton(
                  key: const ValueKey('transactions_open_wallet_scan'),
                  label: 'PolygonScan',
                  onPressed: () async {
                    final uri = Uri.parse(
                        'https://amoy.polygonscan.com/address/$wallet');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ] else
                PixelButton(
                  key: const ValueKey('transactions_link_wallet'),
                  label: 'Link Wallet',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => context.push('/wallet/connect'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterStrip(BuildContext context, PixelGrid grid) {
    const filters = [
      (TransactionCategory.all, 'All'),
      (TransactionCategory.onChain, 'On-Chain'),
      (TransactionCategory.rewards, 'Rewards'),
      (TransactionCategory.vouchers, 'Vouchers'),
      (TransactionCategory.governance, 'Votes'),
    ];
    return Wrap(
      key: const ValueKey('transactions_filter_strip'),
      spacing: grid.px(2),
      runSpacing: grid.px(1),
      children: [
        for (final (cat, label) in filters)
          PixelChip(
            label,
            key: ValueKey('tx_filter_${cat.name}'),
            style: _filter == cat ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
            onTap: () => setState(() => _filter = cat),
          ),
      ],
    );
  }

  Widget _transactionCard(
    BuildContext context,
    PixelGrid grid,
    TransactionRecord tx,
  ) {
    final quickCopyPayload = tx.txUrl ?? tx.txHash ?? tx.shareableReceiptText();
    final quickCopyLabel = tx.hasBlockchainProof ? 'COPY SCAN' : 'COPY';

    return GestureDetector(
      key: ValueKey('tx_row_${tx.receiptId}'),
      onTap: () => showTransactionReceiptSheet(context, tx),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tx.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(context, color: PixelPalette.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  tx.amountLabel,
                  style: PixelType.body(
                    context,
                    color: tx.isCredit
                        ? PixelPalette.greenDeep
                        : PixelPalette.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (tx.subtitle.isNotEmpty) ...[
              SizedBox(height: grid.px(1)),
              Text(
                tx.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ],
            SizedBox(height: grid.px(1)),
            Text(
              tx.formattedTimestamp,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PixelChip(
                  tx.status,
                  style: tx.hasBlockchainProof
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.slot,
                  textColor: tx.hasBlockchainProof
                      ? PixelPalette.white
                      : PixelPalette.ink,
                ),
                PixelChip(
                  quickCopyLabel,
                  key: ValueKey('tx_quick_copy_${tx.receiptId}'),
                  style: PixelBoxStyle.gold,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: quickCopyPayload));
                    showPixelToast(
                      context,
                      tx.hasBlockchainProof
                          ? 'Blockchain scan link copied.'
                          : 'Receipt copied.',
                    );
                  },
                ),
                PixelChip(
                  'RECEIPT ›',
                  style: PixelBoxStyle.slot,
                  onTap: () => showTransactionReceiptSheet(context, tx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
