import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';

void main() {
  group('UserModel Web3 Extension Tests', () {
    test('correctly parses user with bound wallet address and formatting', () {
      final user = UserModel.fromJson({
        'id': 'user-123',
        'seed_id': 'traveler-juan',
        'display_name': 'Juan Dela Cruz',
        'email': 'juan@juanderquest.local',
        'avatar_url': 'https://example.com/avatar.png',
        'role': 'user',
        'demo_points': 150,
        'wallet_address': '0x71C8363820F80E68370520C5C330938F48420E40',
        'mjdq_balance': 150000,
        'jdq_governance_balance': 25,
        'scout_reputation': 350,
      });

      expect(user.hasBoundWallet, isTrue);
      expect(user.walletAddress, '0x71C8363820F80E68370520C5C330938F48420E40');
      expect(user.formattedWalletAddress, '0x71C8...0E40');
      expect(user.mjdqBalance, 150000);
      expect(user.jdqGovernanceBalance, 25);
    });

    test('correctly handles user without bound wallet (off-chain mode)', () {
      final user = UserModel.fromJson({
        'id': 'user-offchain',
        'seed_id': 'guest:anon-1',
        'display_name': 'Guest Explorer',
        'email': 'guest@juanderquest.local',
        'role': 'user',
        'demo_points': 50,
      });

      expect(user.hasBoundWallet, isFalse);
      expect(user.walletAddress, isNull);
      expect(user.formattedWalletAddress, isNull);
      expect(user.mjdqBalance, 50000);
    });

    test('copyWith updates walletAddress cleanly', () {
      final user = UserModel(
        id: 'u1',
        seedId: 'seed-1',
        displayName: 'Traveler',
        email: 't@test.local',
        avatarUrl: '',
        role: 'user',
        demoPoints: 100,
      );

      expect(user.hasBoundWallet, isFalse);
      final boundUser = user.copyWith(walletAddress: '0x1111222233334444555566667777888899990000');
      expect(boundUser.hasBoundWallet, isTrue);
      expect(boundUser.walletAddress, '0x1111222233334444555566667777888899990000');
      expect(boundUser.formattedWalletAddress, '0x1111...0000');
    });
  });

  final dummyStats = ProfileStatsModel(
    completedQuestsCount: 3,
    pendingSubmissionsCount: 1,
    totalPointsEarned: 150,
    ecoPioneerState: BadgeState.earned,
    heritageKeeperState: BadgeState.earned,
    foodExplorerState: BadgeState.inProgress,
  );

  group('ProfileScreen Web3 Section Widget Tests', () {
    testWidgets('renders Link MetaMask button when traveler has no bound wallet', (tester) async {
      final unboundUser = UserModel(
        id: 'user-unbound',
        seedId: 'unbound-scout',
        displayName: 'Unbound Scout',
        email: 'unbound@scout.ph',
        avatarUrl: '',
        role: 'user',
        demoPoints: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(
                  AuthState(user: unboundUser, token: 'fake-token'),
                )),
            profileStatsProvider.overrideWithValue(dummyStats),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Web3 & Blockchain Identity'), findsOneWidget);
      expect(find.text('Off-Chain Demo Account'), findsOneWidget);
      expect(find.text('Link MetaMask / EVM Wallet'), findsOneWidget);
    });

    testWidgets('renders verified wallet badge and address when traveler has bound wallet', (tester) async {
      final boundUser = UserModel(
        id: 'user-bound',
        seedId: 'bound-scout',
        displayName: 'Bound Scout',
        email: 'bound@scout.ph',
        avatarUrl: '',
        role: 'user',
        demoPoints: 200,
        walletAddress: '0x71C8363820F80E68370520C5C330938F48420E40',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(
                  AuthState(user: boundUser, token: 'fake-token'),
                )),
            profileStatsProvider.overrideWithValue(dummyStats),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Web3 & Blockchain Identity'), findsOneWidget);
      expect(find.text('Web3 Passport Linked'), findsOneWidget);
      expect(find.text('0x71C8...0E40'), findsOneWidget);
      expect(find.text('Unlink Wallet'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
