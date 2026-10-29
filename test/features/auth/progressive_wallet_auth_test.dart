// Plan 67: wallet sign-in asks for email + password before a session exists.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/data/auth_session_store.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';

class _MemoryStore implements AuthSessionStore {
  StoredAuthSession? saved;
  @override
  Future<StoredAuthSession?> read() async => saved;
  @override
  Future<void> write(StoredAuthSession session) async => saved = session;
  @override
  Future<void> clear() async => saved = null;
}

const _user = <String, dynamic>{
  'id': 'wallet-user',
  'display_name': 'Wallet Scout',
  'email': 'scout@example.com',
  'wallet_address': '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
};

({AuthNotifier notifier, _MemoryStore store, List<RequestOptions> sent})
    _setup(Map<String, dynamic> Function(RequestOptions) reply) {
  final api = ApiClient(enableRetries: false);
  final sent = <RequestOptions>[];
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    sent.add(o);
    h.resolve(Response(requestOptions: o, statusCode: 200, data: reply(o)));
  }));
  final store = _MemoryStore();
  return (
    notifier: AuthNotifier(api, AuthRefreshNotifier(), null, store),
    store: store,
    sent: sent,
  );
}

void main() {
  test('a new wallet gets a completion grant and no session', () async {
    final t = _setup((_) => {
          'success': true,
          'data': {
            'status': 'requires_account_completion',
            'account_completion_required': true,
            'wallet_address': _user['wallet_address'],
            'wallet_onboarding_grant': 'grant-1',
            'existing_display_name': 'Old Scout',
          },
        });
    final result = await t.notifier
        .loginWithWallet(address: _user['wallet_address'], signature: '0xsig');
    expect(result, isA<WalletLoginNeedsAccount>());
    final pending = result as WalletLoginNeedsAccount;
    expect(pending.grant, 'grant-1');
    expect(pending.existingDisplayName, 'Old Scout');
    expect(t.notifier.state.isAuthenticated, isFalse);
    expect(t.store.saved, isNull);
  });

  test('completing the account signs in with the wallet and email bound',
      () async {
    final t = _setup((_) => {
          'success': true,
          'data': {'status': 'authenticated', 'token': 'jwt-1', 'user': _user},
        });
    final ok = await t.notifier.completeWalletRegistration(
      grant: 'grant-1',
      walletAddress: _user['wallet_address'],
      email: ' Scout@Example.com ',
      password: 'ScoutPass123',
      displayName: 'Wallet Scout',
    );
    expect(ok, isTrue);
    expect(t.notifier.state.isAuthenticated, isTrue);
    expect(t.notifier.state.user!.hasBoundWallet, isTrue);
    expect(t.sent.single.path, '/auth/wallet/complete-registration');
    expect(t.sent.single.data, containsPair('email', 'scout@example.com'));
    expect(t.sent.single.data, containsPair('wallet_onboarding_grant', 'grant-1'));
  });

  test('a complete wallet account signs straight in', () async {
    final t = _setup((_) => {
          'success': true,
          'data': {
            'status': 'authenticated',
            'account_completion_required': false,
            'token': 'jwt-2',
            'user': _user,
          },
        });
    final result = await t.notifier
        .loginWithWallet(address: _user['wallet_address'], signature: '0xsig');
    expect(result, isA<WalletLoginAuthenticated>());
    expect(t.store.saved?.token, 'jwt-2');
  });
}
