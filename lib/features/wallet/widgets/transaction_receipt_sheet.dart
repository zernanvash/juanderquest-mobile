import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/transactions_provider.dart';

/// Opens a shareable digital invoice / receipt sheet for any transaction, with
/// 1-tap Copy Receipt, Share Proof, and (when on-chain) Copy Tx Hash / Copy
/// PolygonScan Link / Open Explorer.
Future<void> showTransactionReceiptSheet(
  BuildContext context,
  TransactionRecord record,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PixelPalette.parchment,
    builder: (_) => Theme(
      data: AppTheme.pixel,
      child: TransactionReceiptSheet(record: record),
    ),
  );
}

class TransactionReceiptSheet extends StatelessWidget {
  const TransactionReceiptSheet({super.key, required this.record});

  final TransactionRecord record;

  static String _shortHash(String hash) => hash.length > 18
      ? '${hash.substring(0, 10)}…${hash.substring(hash.length - 8)}'
      : hash;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showPixelToast(context, 'Could not open browser link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final scanUrl = record.txUrl ??
        (record.txHash != null && record.txHash!.isNotEmpty
            ? 'https://amoy.polygonscan.com/tx/${record.txHash}'
            : null);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          grid.gutter,
          grid.px(3),
          grid.gutter,
          grid.px(5),
        ),
        child: Column(
          key: const ValueKey('transaction_receipt_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TRANSACTION RECEIPT',
                    style: PixelType.title(context, color: PixelPalette.ink),
                  ),
                ),
                SizedBox(width: grid.px(2)),
                PixelChip(
                  record.status,
                  style: record.hasBlockchainProof
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.gold,
                  textColor: record.hasBlockchainProof
                      ? PixelPalette.white
                      : PixelPalette.ink,
                ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            PixelPanel(
              style: PixelBoxStyle.slot,
              padding: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    record.title,
                    style: PixelType.title(context, color: PixelPalette.ink),
                  ),
                  if (record.subtitle.isNotEmpty) ...[
                    SizedBox(height: grid.px(1)),
                    Text(
                      record.subtitle,
                      style: PixelType.small(context, color: PixelPalette.slate),
                    ),
                  ],
                  SizedBox(height: grid.px(2)),
                  Text(
                    record.amountLabel,
                    style: PixelType.title(
                      context,
                      color: record.isCredit
                          ? PixelPalette.greenDeep
                          : PixelPalette.ink,
                    ),
                  ),
                  SizedBox(height: grid.px(2)),
                  const ColoredBox(
                    color: PixelPalette.stone,
                    child: SizedBox(height: 1),
                  ),
                  SizedBox(height: grid.px(2)),
                  _row(context, 'Receipt ID', record.receiptId, copyable: true),
                  _row(context, 'Date', record.formattedTimestamp),
                  _row(context, 'Settlement', record.settlement),
                  if (record.voucherCode != null &&
                      record.voucherCode!.isNotEmpty)
                    _row(context, 'Voucher Code', record.voucherCode!,
                        copyable: true),
                  if (record.walletAddress != null &&
                      record.walletAddress!.isNotEmpty)
                    _row(
                      context,
                      'Wallet',
                      _shortHash(record.walletAddress!),
                      copyValue: record.walletAddress!,
                      copyable: true,
                    ),
                  if (record.tokenId != null && record.tokenId!.isNotEmpty)
                    _row(context, 'Token ID', '#${record.tokenId}'),
                ],
              ),
            ),
            if (record.hasBlockchainProof) ...[
              SizedBox(height: grid.px(3)),
              PixelPanel(
                key: const ValueKey('receipt_blockchain_panel'),
                style: PixelBoxStyle.wood,
                padding: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'BLOCKCHAIN PROOF',
                      style: PixelType.title(context, color: PixelPalette.paper),
                    ),
                    SizedBox(height: grid.px(1)),
                    if (record.txHash != null && record.txHash!.isNotEmpty)
                      SelectableText(
                        record.txHash!,
                        style:
                            PixelType.small(context, color: PixelPalette.cream),
                      ),
                    SizedBox(height: grid.px(2)),
                    Wrap(
                      spacing: grid.px(2),
                      runSpacing: grid.px(2),
                      children: [
                        if (record.txHash != null && record.txHash!.isNotEmpty)
                          PixelButton(
                            key: const ValueKey('receipt_copy_tx_hash'),
                            label: 'Copy Tx Hash',
                            variant: PixelButtonVariant.secondary,
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: record.txHash!));
                              showPixelToast(context, 'Tx hash copied.');
                            },
                          ),
                        if (scanUrl != null)
                          PixelButton(
                            key: const ValueKey('receipt_copy_scan_url'),
                            label: 'Copy Scan Link',
                            variant: PixelButtonVariant.secondary,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: scanUrl));
                              showPixelToast(
                                  context, 'PolygonScan link copied.');
                            },
                          ),
                        if (scanUrl != null)
                          PixelButton(
                            key: const ValueKey('receipt_open_scan'),
                            label: 'Open PolygonScan',
                            onPressed: () => _openUrl(context, scanUrl),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: grid.px(3)),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('receipt_copy_all'),
                    label: 'Copy Receipt',
                    variant: PixelButtonVariant.secondary,
                    expand: true,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: record.shareableReceiptText()),
                      );
                      showPixelToast(context, 'Receipt copied to clipboard.');
                    },
                  ),
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('receipt_share'),
                    label: 'Share Proof',
                    expand: true,
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(text: record.shareableReceiptText()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool copyable = false,
    String? copyValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyable
                  ? () {
                      Clipboard.setData(
                          ClipboardData(text: copyValue ?? value));
                      showPixelToast(context, '$label copied.');
                    }
                  : null,
              child: Text(
                copyable ? '$value  [COPY]' : value,
                textAlign: TextAlign.right,
                style: PixelType.small(
                  context,
                  color: copyable ? PixelPalette.greenDeep : PixelPalette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
