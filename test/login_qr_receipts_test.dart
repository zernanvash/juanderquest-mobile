import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/login_screen.dart';
import 'package:juanderquest_app/features/qr/qr_payload_parser.dart';
import 'package:juanderquest_app/features/qr/screens/quick_qr_screen.dart';
import 'package:juanderquest_app/features/suki/models/suki_models.dart';
import 'package:juanderquest_app/features/suki/providers/suki_provider.dart';
import 'package:juanderquest_app/features/wallet/providers/transactions_provider.dart';
import 'package:juanderquest_app/features/wallet/screens/transactions_screen.dart';
import 'package:juanderquest_app/features/wallet/widgets/transaction_receipt_sheet.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(UserModel? user)
      : super(ApiClient(enableRetries: false), AuthRefreshNotifier()) {
    state = AuthState(
      user: user,
      token: user != null ? 'test-token' : null,
    );
  }
}

final _testUser = UserModel(
  id: 'u-1',
  seedId: 'juan',
  displayName: 'Juan Explorer',
  email: 'juan@example.com',
  avatarUrl: '',
  role: 'traveler',
  demoPoints: 1250,
  walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
);

final _sampleTransactions = <TransactionRecord>[
  TransactionRecord(
    receiptId: 'JDQ-NFT-award-1',
    title: 'Pangasinan Pioneer',
    subtitle: 'ERC-5192 Achievement Badge',
    category: TransactionCategory.onChain,
    amountLabel: 'NFT #42',
    isCredit: true,
    timestamp: DateTime.utc(2026, 11, 19, 8, 0),
    status: 'On-Chain',
    settlement: 'Polygon Amoy',
    txHash:
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    txUrl:
        'https://amoy.polygonscan.com/tx/0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    tokenId: '42',
    walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
  ),
  TransactionRecord(
    receiptId: 'JDQ-VCH-BANGUS50',
    title: '50 PHP Off Bangus Grill',
    subtitle: 'Bonuan Waterfront Grill',
    category: TransactionCategory.vouchers,
    amountLabel: '-250 pts',
    isCredit: false,
    timestamp: DateTime.utc(2026, 11, 18, 14, 30),
    status: 'Active',
    settlement: 'Off-Chain Voucher',
    voucherCode: 'BANGUS50',
    walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
  ),
];

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => _FakeAuthNotifier(_testUser)),
      mySukiCardsProvider.overrideWith((ref) async => const <SukiCard>[]),
      transactionsProvider.overrideWith((ref) async => _sampleTransactions),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: child,
    ),
  );
}

void main() {
  group('QR payload parser', () {
    test('detects Suki standee, app links, wallet addresses, and checkpoints',
        () {
      expect(
        parseQuickQrPayload(
            'https://juanderquest.app/suki/prog-1?v=2&s=0123456789abcdef'),
        isA<SukiStandeeQr>(),
      );
      expect(
        parseQuickQrPayload('https://juanderquest.app/explore/hundred-islands'),
        isA<SpotLinkQr>()
            .having((e) => e.slug, 'slug', equals('hundred-islands')),
      );
      expect(
        parseQuickQrPayload('https://juanderquest.app/quests/q-99'),
        isA<QuestLinkQr>().having((e) => e.questId, 'questId', equals('q-99')),
      );
      expect(
        parseQuickQrPayload('https://juanderquest.app/profile/juan'),
        isA<ProfileLinkQr>()
            .having((e) => e.handle, 'handle', equals('juan')),
      );
      expect(
        parseQuickQrPayload(
            'ethereum:0x1234567890abcdef1234567890abcdef12345678@80002'),
        isA<WalletAddressQr>().having(
          (e) => e.address,
          'address',
          equals('0x1234567890abcdef1234567890abcdef12345678'),
        ),
      );
      expect(
        parseQuickQrPayload('CHECKPOINT-DAGUPAN-01'),
        isA<CheckpointCodeQr>()
            .having((e) => e.code, 'code', equals('CHECKPOINT-DAGUPAN-01')),
      );
      expect(parseQuickQrPayload('   '), isNull);
    });
  });

  group('Transactions bundle parser & receipt formatting', () {
    test('merges ledger, on-chain badges, and vouchers newest-first', () {
      final list = parseTransactionsBundle(
        ledgerData: {
          'governance_ledger': [
            {
              'id': 'g-1',
              'reason': 'proposal_vote',
              'amount_mjdq': -50,
              'created_at': '2026-11-17T10:00:00Z',
            },
          ],
          'system_ledger': [
            {
              'id': 's-1',
              'reason': 'quest_reward',
              'amount': 200,
              'created_at': '2026-11-19T12:00:00Z',
            },
          ],
        },
        badgesData: {
          'walletAddress': '0x1234567890abcdef1234567890abcdef12345678',
          'chain': {'name': 'Polygon Amoy', 'badgeContract': '0xabc'},
          'badges': [
            {
              'awardId': 'aw-7',
              'title': 'Pioneer',
              'state': 'on_chain',
              'tokenId': '7',
              'txHash': '0xdeadbeef',
              'txUrl': 'https://amoy.polygonscan.com/tx/0xdeadbeef',
              'awardedAt': '2026-11-18T09:00:00Z',
            },
          ],
        },
        vouchersData: [
          {
            'code': 'VCH-1',
            'offerTitle': 'Free Coffee',
            'merchantName': 'Cafe Lingayen',
            'costPoints': 100,
            'redeemedAt': '2026-11-16T08:00:00Z',
          },
        ],
      );

      expect(list.length, 4);
      expect(list.first.receiptId, 'JDQ-SYS-s-1');
      expect(list[1].receiptId, 'JDQ-NFT-aw-7');
      expect(list[1].hasBlockchainProof, isTrue);
      expect(list[1].shareableReceiptText(),
          contains('https://amoy.polygonscan.com/tx/0xdeadbeef'));
      expect(list[2].category, TransactionCategory.governance);
      expect(list[3].voucherCode, 'VCH-1');
    });
  });

  group('LoginScreen polish', () {
    testWidgets('inline SHOW/HIDE toggle and compact Forgot password? link',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      // Inline SHOW/HIDE toggle exists; no bulky SHOW PASSWORD button.
      expect(find.byKey(const ValueKey('auth_toggle_password')), findsOneWidget);
      expect(find.text('SHOW'), findsOneWidget);
      expect(find.text('SHOW PASSWORD'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('auth_toggle_password')));
      await tester.pump();
      expect(find.text('HIDE'), findsOneWidget);

      expect(find.byKey(const ValueKey('auth_forgot_password')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_wallet_sign_in')), findsOneWidget);
    });
  });

  group('QuickQrScreen & TransactionsScreen UI and overflow', () {
    for (final (label, size) in const [
      ('320x568 @2.0x', Size(320, 568)),
      ('568x320 @2.0x', Size(568, 320)),
    ]) {
      testWidgets('QuickQrScreen scan & my tabs no overflow ($label)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: _wrap(const QuickQrScreen(enableCamera: false)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('quick_qr_tab_scan')), findsOneWidget);
        expect(find.byKey(const ValueKey('quick_qr_tab_my')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('quick_qr_tab_my')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('quick_qr_passport_image')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('TransactionsScreen & ReceiptSheet no overflow ($label)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: _wrap(const TransactionsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final rowFinder = find.byKey(const ValueKey('tx_row_JDQ-NFT-award-1'));
        await tester.scrollUntilVisible(
          rowFinder,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(rowFinder, findsOneWidget);

        // Open receipt bottom sheet for the on-chain item.
        await tester.tap(rowFinder);
        await tester.pumpAndSettle();

        expect(find.byType(TransactionReceiptSheet), findsOneWidget);
        expect(find.byKey(const ValueKey('receipt_blockchain_panel')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('receipt_copy_tx_hash')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('receipt_copy_scan_url')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('receipt_copy_all')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
