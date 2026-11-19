import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

enum TransactionCategory {
  all,
  onChain,
  rewards,
  vouchers,
  governance,
}

class TransactionRecord {
  const TransactionRecord({
    required this.receiptId,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.amountLabel,
    required this.isCredit,
    required this.timestamp,
    required this.status,
    required this.settlement,
    this.txHash,
    this.txUrl,
    this.tokenId,
    this.tokenUrl,
    this.contractAddress,
    this.walletAddress,
    this.voucherCode,
  });

  final String receiptId;
  final String title;
  final String subtitle;
  final TransactionCategory category;
  final String amountLabel;
  final bool isCredit;
  final DateTime timestamp;
  final String status;
  final String settlement;
  final String? txHash;
  final String? txUrl;
  final String? tokenId;
  final String? tokenUrl;
  final String? contractAddress;
  final String? walletAddress;
  final String? voucherCode;

  bool get hasBlockchainProof =>
      (txHash != null && txHash!.isNotEmpty) ||
      (txUrl != null && txUrl!.isNotEmpty);

  String get formattedTimestamp {
    final local = timestamp.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Formatted invoice/proof text suitable for clipboard copy or sharing.
  String shareableReceiptText() {
    final lines = <String>[
      '=== JUANDERQUEST TRANSACTION RECEIPT ===',
      'Receipt ID: $receiptId',
      'Item: $title',
      if (subtitle.isNotEmpty) 'Details: $subtitle',
      'Amount: $amountLabel',
      'Status: $status',
      'Settlement: $settlement',
      'Date: $formattedTimestamp',
      if (voucherCode != null && voucherCode!.isNotEmpty)
        'Voucher Code: $voucherCode',
      if (walletAddress != null && walletAddress!.isNotEmpty)
        'Wallet: $walletAddress',
      if (tokenId != null && tokenId!.isNotEmpty) 'Token ID: #$tokenId',
      if (txHash != null && txHash!.isNotEmpty) 'Tx Hash: $txHash',
      if (txUrl != null && txUrl!.isNotEmpty) 'Blockchain Scan: $txUrl',
      '========================================',
    ];
    return lines.join('\n');
  }
}

DateTime _parseDate(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

String _humanizeReason(String raw) {
  final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  if (cleaned.isEmpty) return 'Ledger Transaction';
  return cleaned
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

TransactionCategory _categoryForLedgerReason(String reason) {
  final lower = reason.toLowerCase();
  if (lower.contains('vote') ||
      lower.contains('proposal') ||
      lower.contains('governance') ||
      lower.contains('juanchoice')) {
    return TransactionCategory.governance;
  }
  if (lower.contains('voucher') ||
      lower.contains('redeem') ||
      lower.contains('cosmetic') ||
      lower.contains('shop')) {
    return TransactionCategory.vouchers;
  }
  return TransactionCategory.rewards;
}

/// Pure parser so unit tests can verify normalization & sorting without network.
List<TransactionRecord> parseTransactionsBundle({
  Map<String, dynamic>? ledgerData,
  Map<String, dynamic>? badgesData,
  List<dynamic>? vouchersData,
  String? fallbackWallet,
}) {
  final items = <TransactionRecord>[];

  // 1. Governance & System Ledger entries (/wallet/ledger)
  if (ledgerData != null) {
    final govList = ledgerData['governance_ledger'];
    if (govList is List) {
      for (final raw in govList) {
        if (raw is! Map) continue;
        final id = '${raw['id'] ?? raw['entry_id'] ?? ''}';
        final reason = '${raw['reason'] ?? raw['type'] ?? 'ledger_entry'}';
        final amountMjdq = (raw['amount_mjdq'] as num?)?.toInt() ?? 0;
        final isCredit = amountMjdq >= 0;
        final sign = isCredit ? '+' : '';
        final refId = '${raw['reference_id'] ?? raw['proposal_id'] ?? ''}';
        items.add(
          TransactionRecord(
            receiptId: id.isNotEmpty ? 'JDQ-GOV-$id' : 'JDQ-GOV-${items.length + 1}',
            title: _humanizeReason(reason),
            subtitle: refId.isNotEmpty ? 'Ref: $refId' : 'Governance & points ledger',
            category: _categoryForLedgerReason(reason),
            amountLabel: '$sign$amountMjdq mJDQ',
            isCredit: isCredit,
            timestamp: _parseDate(raw['created_at']),
            status: 'Confirmed',
            settlement: 'Off-Chain Ledger',
            walletAddress: fallbackWallet,
          ),
        );
      }
    }

    final sysList = ledgerData['system_ledger'];
    if (sysList is List) {
      for (final raw in sysList) {
        if (raw is! Map) continue;
        final id = '${raw['id'] ?? ''}';
        final reason = '${raw['reason'] ?? raw['type'] ?? 'reward'}';
        final points = (raw['amount'] ?? raw['points'] ?? raw['delta'] ?? 0) as num;
        final isCredit = points >= 0;
        final sign = isCredit ? '+' : '';
        items.add(
          TransactionRecord(
            receiptId: id.isNotEmpty ? 'JDQ-SYS-$id' : 'JDQ-SYS-${items.length + 1}',
            title: _humanizeReason(reason),
            subtitle: '${raw['description'] ?? 'Traveler ledger entry'}',
            category: _categoryForLedgerReason(reason),
            amountLabel: '$sign${points.toInt()} pts',
            isCredit: isCredit,
            timestamp: _parseDate(raw['created_at']),
            status: 'Confirmed',
            settlement: 'Off-Chain Ledger',
            walletAddress: fallbackWallet,
          ),
        );
      }
    }
  }

  // 2. On-chain Soulbound Badges (/me/chain/badges)
  if (badgesData != null) {
    final chain = badgesData['chain'] is Map
        ? Map<String, dynamic>.from(badgesData['chain'] as Map)
        : const <String, dynamic>{};
    final chainName = '${chain['name'] ?? 'Polygon Amoy'}';
    final contract = chain['badgeContract']?.toString();
    final wallet = badgesData['walletAddress']?.toString() ?? fallbackWallet;
    final badges = badgesData['badges'];
    if (badges is List) {
      for (final raw in badges) {
        if (raw is! Map) continue;
        final awardId = '${raw['awardId'] ?? raw['achievementId'] ?? ''}';
        final txHash = raw['txHash']?.toString();
        final txUrl = raw['txUrl']?.toString();
        final tokenId = raw['tokenId']?.toString();
        final tokenUrl = raw['tokenUrl']?.toString();
        final state = '${raw['state'] ?? 'queued'}';
        final statusLabel = switch (state) {
          'on_chain' => 'On-Chain',
          'minting' => 'Minting',
          'queued' => 'Queued',
          'pending_wallet' => 'Needs Wallet',
          'revoked' => 'Revoked',
          'failed' => 'Failed',
          _ => 'Recorded',
        };
        items.add(
          TransactionRecord(
            receiptId: awardId.isNotEmpty ? 'JDQ-NFT-$awardId' : 'JDQ-NFT-${items.length + 1}',
            title: '${raw['title'] ?? 'Soulbound Badge'}',
            subtitle: '${raw['description'] ?? 'ERC-5192 Achievement Badge'}',
            category: TransactionCategory.onChain,
            amountLabel: tokenId != null ? 'NFT #$tokenId' : 'Soulbound Badge',
            isCredit: true,
            timestamp: _parseDate(raw['awardedAt']),
            status: statusLabel,
            settlement: txHash != null && txHash.isNotEmpty
                ? chainName
                : '$chainName (Pending)',
            txHash: txHash,
            txUrl: txUrl,
            tokenId: tokenId,
            tokenUrl: tokenUrl,
            contractAddress: contract,
            walletAddress: raw['recipient']?.toString() ?? wallet,
          ),
        );
      }
    }
  }

  // 3. Redeemed Vouchers (/me/redemptions -> data.items[])
  if (vouchersData != null) {
    for (final raw in vouchersData) {
      if (raw is! Map) continue;
      final voucher = raw['voucher'] is Map ? raw['voucher'] as Map : const {};
      final merchantObj =
          raw['merchant'] is Map ? raw['merchant'] as Map : const {};
      final code = '${raw['code'] ?? raw['redemption_code'] ?? ''}';
      final merchant =
          '${merchantObj['name'] ?? raw['merchantName'] ?? raw['merchant_name'] ?? raw['partner_label'] ?? 'Partner Shop'}';
      final title =
          '${voucher['title'] ?? raw['offerTitle'] ?? raw['offer_title'] ?? raw['title'] ?? 'Partner Voucher'}';
      final cost = ((raw['cost_points'] ?? raw['costPoints'] ?? 0) as num).toInt();
      final usedAt = raw['used_at'] ?? raw['usedAt'];
      items.add(
        TransactionRecord(
          receiptId: code.isNotEmpty
              ? 'JDQ-VCH-$code'
              : 'JDQ-VCH-${raw['id'] ?? items.length + 1}',
          title: title,
          subtitle: merchant,
          category: TransactionCategory.vouchers,
          amountLabel: cost > 0 ? '-$cost pts' : 'Voucher',
          isCredit: false,
          timestamp: _parseDate(
              raw['created_at'] ?? raw['redeemedAt'] ?? raw['redeemed_at']),
          status: usedAt != null ? 'Used' : 'Active',
          settlement: 'Off-Chain Voucher',
          voucherCode: code.isNotEmpty ? code : null,
          walletAddress: fallbackWallet,
        ),
      );
    }
  }

  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
}

final transactionsProvider =
    FutureProvider.autoDispose<List<TransactionRecord>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return const [];
  final dio = ref.read(apiClientProvider).dio;

  Future<Map<String, dynamic>?> fetchMap(String path) async {
    try {
      final res = await dio.get(path);
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['success'] == true &&
          res.data['data'] is Map) {
        return Map<String, dynamic>.from(res.data['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>?> fetchList(String path) async {
    try {
      final res = await dio.get(path);
      if (res.statusCode == 200 && res.data is Map && res.data['success'] == true) {
        final data = res.data['data'];
        if (data is List) return data;
        if (data is Map && data['items'] is List) {
          return data['items'] as List;
        }
        if (data is Map && data['vouchers'] is List) {
          return data['vouchers'] as List;
        }
      }
    } catch (_) {}
    return null;
  }

  final results = await Future.wait<dynamic>([
    fetchMap('/wallet/ledger'),
    fetchMap('/me/chain/badges'),
    fetchList('/me/redemptions'),
  ]);

  return parseTransactionsBundle(
    ledgerData: results[0] as Map<String, dynamic>?,
    badgesData: results[1] as Map<String, dynamic>?,
    vouchersData: results[2] as List<dynamic>?,
    fallbackWallet: authState.user?.walletAddress,
  );
});
