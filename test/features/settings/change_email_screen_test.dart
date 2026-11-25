import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/settings/screens/change_email_screen.dart';
import 'package:juanderquest_app/features/wallet/screens/wallet_connect_screen.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.handler});

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(ApiClient apiClient, AuthState initial)
      : super(apiClient, AuthRefreshNotifier()) {
    state = initial;
  }

  String? lastAppliedToken;

  @override
  void applyUpdatedSession({
    required String token,
    required Map<String, dynamic> userJson,
  }) {
    lastAppliedToken = token;
    state = AuthState(user: UserModel.fromJson(userJson), token: token);
  }
}

void main() {
  group('Plan 120: ChangeEmailScreen & Wallet Unbind UX', () {
    testWidgets(
      'Locked state renders when user has no wallet (CONNECT WALLET visible, email form hidden)',
      (tester) async {
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.path == '/auth/email/change/eligibility') {
            return _jsonResponse({
              'success': true,
              'data': {
                'eligible': false,
                'reason': 'WALLET_REQUIRED_FOR_EMAIL_CHANGE',
                'bound_wallet_address': null,
                'current_email': 'old@example.com',
                'has_google_linked': false,
                'has_password': true,
                'cooldown_until': null,
              },
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        final router = GoRouter(
          initialLocation: '/settings/change-email',
          routes: [
            GoRoute(
              path: '/settings/change-email',
              builder: (_, __) => const ChangeEmailScreen(),
            ),
            GoRoute(
              path: '/wallet/connect',
              builder: (_, __) => const Scaffold(body: Text('Wallet Connect')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api)],
            child: MaterialApp.router(
              theme: AppTheme.pixel,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('change_email_wallet_locked')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('change_email_connect_wallet')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('change_email_input')), findsNothing);
      },
    );

    testWidgets(
      'Eligible state shows Google unlink notice, Step 1 -> Step 2 OTP + wallet sign confirm',
      (tester) async {
        final calls = <String>[];
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          calls.add('${options.method} ${options.path}');
          if (options.path == '/auth/email/change/eligibility') {
            return _jsonResponse({
              'success': true,
              'data': {
                'eligible': true,
                'reason': null,
                'bound_wallet_address':
                    '0x1234567890abcdef1234567890abcdef12345678',
                'current_email': 'old@example.com',
                'has_google_linked': true,
                'has_password': true,
                'cooldown_until': null,
              },
            });
          }
          if (options.path == '/auth/email/change/request') {
            return _jsonResponse({
              'success': true,
              'data': {
                'challenge_id': 'chal-120',
                'new_email': 'new@example.com',
                'wallet_address': '0x1234567890abcdef1234567890abcdef12345678',
                'siwe_message':
                    'JuanDerQuest Email Migration\nTo: new@example.com',
                'expires_at': '2026-11-25T12:00:00.000Z',
              },
            });
          }
          if (options.path == '/auth/email/change/confirm') {
            return _jsonResponse({
              'success': true,
              'data': {
                'token': 'fresh-jwt-120',
                'user': {
                  'id': 'u1',
                  'display_name': 'Juan',
                  'email': 'new@example.com',
                  'wallet_address':
                      '0x1234567890abcdef1234567890abcdef12345678',
                  'demo_points': 100,
                },
                'google_unlinked': true,
                'message': 'Email updated successfully.',
              },
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        final fakeAuth = _FakeAuthNotifier(
          api,
          AuthState(
            token: 'old-jwt',
            user: UserModel(
              id: 'u1',
              seedId: 'u1',
              displayName: 'Juan',
              email: 'old@example.com',
              avatarUrl: '',
              role: 'user',
              demoPoints: 100,
              walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
            ),
          ),
        );

        String? signedMessage;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              authProvider.overrideWith((ref) => fakeAuth),
            ],
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: ChangeEmailScreen(
                signMessageOverride: (msg) async {
                  signedMessage = msg;
                  return '0xdeadbeef';
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('change_email_google_notice')),
            findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('change_email_input')),
            'new@example.com');
        await tester.tap(find.byKey(const ValueKey('change_email_send_code')));
        await tester.pumpAndSettle();

        expect(calls, contains('POST /auth/email/change/request'));
        expect(find.byKey(const ValueKey('change_email_otp_input')),
            findsOneWidget);

        await tester.enterText(
            find.byKey(const ValueKey('change_email_otp_input')), '654321');
        await tester.tap(find.byKey(const ValueKey('change_email_confirm')));
        await tester.pumpAndSettle();

        expect(
            signedMessage, 'JuanDerQuest Email Migration\nTo: new@example.com');
        expect(calls, contains('POST /auth/email/change/confirm'));
        expect(fakeAuth.lastAppliedToken, 'fresh-jwt-120');
        expect(fakeAuth.state.user?.email, 'new@example.com');
      },
    );

    testWidgets(
      'Zero overflows on 320x568 and 568x320 at 2.0x text scale',
      (tester) async {
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.path == '/auth/email/change/eligibility') {
            return _jsonResponse({
              'success': true,
              'data': {
                'eligible': true,
                'reason': null,
                'bound_wallet_address':
                    '0x1234567890abcdef1234567890abcdef12345678',
                'current_email': 'very.long.traveler.email@example.com',
                'has_google_linked': true,
                'has_password': true,
                'cooldown_until': null,
              },
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        for (final size in [const Size(320, 568), const Size(568, 320)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [apiClientProvider.overrideWithValue(api)],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: MaterialApp(
                  theme: AppTheme.pixel,
                  home: ChangeEmailScreen(key: ValueKey('ce_$size')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'WalletConnectScreen shows friendly message on 409 OTHER_SIGNIN_REQUIRED_BEFORE_WALLET_UNBIND',
      (tester) async {
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.method == 'DELETE' &&
              options.path == '/auth/wallet/unbind') {
            return _jsonResponse({
              'success': false,
              'error': {
                'code': 'OTHER_SIGNIN_REQUIRED_BEFORE_WALLET_UNBIND',
                'message':
                    "Verify your email and keep a password or Google sign-in linked before unlinking your wallet so you don't lose access to your account.",
              },
            }, status: 409);
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        final fakeAuth = _FakeAuthNotifier(
          api,
          AuthState(
            token: 'jwt-120',
            user: UserModel(
              id: 'u1',
              seedId: 'u1',
              displayName: 'Juan',
              email: 'old@example.com',
              avatarUrl: '',
              role: 'user',
              demoPoints: 100,
              walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              authProvider.overrideWith((ref) => fakeAuth),
            ],
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: const WalletConnectScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('wallet_connect_unbind')));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const ValueKey('wallet_connect_error')), findsOneWidget);
        expect(
          find.textContaining('Verify your email and keep a password'),
          findsOneWidget,
        );
      },
    );
  });
}
