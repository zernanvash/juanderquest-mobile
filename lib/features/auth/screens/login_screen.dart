import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart'
    hide PrimaryButton, SecondaryButton;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_signature_service.dart';

enum _AuthStep { signIn, signUp, verifyEmail }

/// Traveler authentication. Admin accounts are managed in the web dashboard.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _AuthStep _step = _AuthStep.signIn;
  bool _ageEligible = false;
  bool _termsAccepted = false;
  bool _passwordVisible = false;
  String? _error;
  String? _notice;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email) || _password.text.isEmpty) {
      setState(() => _error = 'Enter a valid email and your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final ok = await ref.read(authProvider.notifier).loginWithEmail(
          email: email,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = ref.read(authProvider).error ??
            'Sign in failed. Check your email and password.';
      }
    });
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name (at least 2 characters).');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Use a password with at least 8 characters.');
      return;
    }
    if (!_ageEligible || !_termsAccepted) {
      setState(() =>
          _error = 'Confirm age eligibility and accept the terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final result = await ref.read(authProvider.notifier).registerWithEmail(
          email: email,
          password: _password.text,
          displayName: _name.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['success'] == true) {
        _step = _AuthStep.verifyEmail;
        _notice =
            'We sent a 6-digit code to $email. Check your inbox and spam folder.';
      } else {
        _error = result['error'] as String? ??
            'We could not create your account. Please try again.';
      }
    });
  }

  Future<void> _verifyEmail() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(authProvider.notifier).verifyEmailOtp(
          email: _email.text.trim(),
          code: code,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error =
            ref.read(authProvider).error ?? 'That code is invalid or expired.';
      }
    });
  }

  Future<void> _startWalletSignIn() async {
    ReownAppKitModal modal;
    try {
      modal = await WalletSignatureService.initialize(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error is StateError
          ? error.message
          : 'Wallet connection is unavailable.');
      return;
    }
    if (!mounted) {
      await modal.dispose();
      return;
    }

    String? walletError;
    var signing = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Sign in with your wallet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                      'Connect your wallet, then approve a sign-in message. This does not send a transaction or move tokens.'),
                  const SizedBox(height: AppSpacing.md),
                  AppKitModalConnectButton(appKit: modal, context: context),
                  if (walletError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(walletError!,
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    signing ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: signing
                    ? null
                    : () async {
                        final address =
                            WalletSignatureService.connectedAddress(modal);
                        if (address == null) {
                          setDialogState(() =>
                              walletError = 'Connect an EVM wallet first.');
                          return;
                        }
                        setDialogState(() {
                          signing = true;
                          walletError = null;
                        });
                        try {
                          final challenge = await ref
                              .read(authProvider.notifier)
                              .requestWalletChallenge(address);
                          if (challenge == null) {
                            throw StateError(
                                'The sign-in challenge could not be loaded. Check your connection.');
                          }
                          final signature =
                              await WalletSignatureService.signChallenge(
                                  modal, challenge);
                          final ok = await ref
                              .read(authProvider.notifier)
                              .loginWithWallet(
                                  address: address, signature: signature);
                          if (ok && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          } else if (dialogContext.mounted) {
                            setDialogState(() {
                              signing = false;
                              walletError = ref.read(authProvider).error ??
                                  'Wallet sign-in failed.';
                            });
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              signing = false;
                              walletError = error is StateError
                                  ? error.message
                                  : 'Wallet signing was cancelled or failed.';
                            });
                          }
                        }
                      },
                child: signing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      await modal.dispose();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _setStep(_AuthStep next) {
    setState(() {
      _step = next;
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return JdqScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
              child: Image.asset(
            'assets/images/logo.png',
            height: 88,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text('JuanDerQuest',
                style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.woodBrown, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: AppSpacing.lg),
          Text(
            switch (_step) {
              _AuthStep.signIn => 'Welcome back',
              _AuthStep.signUp => 'Create your traveler account',
              _AuthStep.verifyEmail => 'Verify your email'
            },
            textAlign: TextAlign.center,
            style: AppTypography.headlineSmall.copyWith(
                color: AppColors.woodBrown, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            switch (_step) {
              _AuthStep.signIn => 'Sign in to continue your journey.',
              _AuthStep.signUp =>
                'A few details, then you’re ready to explore.',
              _AuthStep.verifyEmail =>
                'Enter the code we sent to ${_email.text.trim()}.'
            },
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step != _AuthStep.verifyEmail) ...[
            SegmentedButton<_AuthStep>(
              segments: const [
                ButtonSegment(value: _AuthStep.signIn, label: Text('Sign in')),
                ButtonSegment(
                    value: _AuthStep.signUp, label: Text('Create account')),
              ],
              selected: {_step},
              onSelectionChanged:
                  _busy ? null : (selection) => _setStep(selection.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_step == _AuthStep.signUp) ...[
              TextField(
                key: const ValueKey('auth_display_name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              key: const ValueKey('auth_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('auth_password'),
              controller: _password,
              obscureText: !_passwordVisible,
              autofillHints: [
                _step == _AuthStep.signUp
                    ? AutofillHints.newPassword
                    : AutofillHints.password
              ],
              decoration: InputDecoration(
                labelText: _step == _AuthStep.signUp
                    ? 'Password (8+ characters)'
                    : 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(_passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
              ),
            ),
            if (_step == _AuthStep.signIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('auth_forgot_password'),
                  onPressed: _busy
                      ? null
                      : () => context.push(
                          '/forgot-password?email=${Uri.encodeQueryComponent(_email.text.trim())}'),
                  child: const Text('Forgot password?'),
                ),
              ),
            if (_step == _AuthStep.signUp) ...[
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const ValueKey('auth_age_eligibility'),
                contentPadding: EdgeInsets.zero,
                value: _ageEligible,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _ageEligible = value ?? false),
                title: const Text('I meet the age eligibility requirement.',
                    style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                key: const ValueKey('auth_terms'),
                contentPadding: EdgeInsets.zero,
                value: _termsAccepted,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _termsAccepted = value ?? false),
                title: const Text(
                    'I agree to the terms of service and privacy notice.',
                    style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            PrimaryButton(
              key: ValueKey(_step == _AuthStep.signIn
                  ? 'auth_sign_in'
                  : 'auth_create_account'),
              label: _step == _AuthStep.signIn
                  ? 'Sign in with email'
                  : 'Create traveler account',
              isLoading: _busy,
              onPressed: _busy
                  ? null
                  : (_step == _AuthStep.signIn ? _signIn : _register),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('OR',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textMuted))),
              const Expanded(child: Divider())
            ]),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('auth_wallet_sign_in'),
              onPressed: _busy ? null : _startWalletSignIn,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Continue with wallet'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.roundedPill)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
                'Wallet sign-in verifies ownership with a signature. It never sends a transaction.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ] else ...[
            TextField(
              key: const ValueKey('auth_email_otp'),
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                  labelText: '6-digit email code',
                  prefixIcon: Icon(Icons.mark_email_read_outlined),
                  border: OutlineInputBorder()),
            ),
            PrimaryButton(
              key: const ValueKey('auth_verify_email'),
              label: 'Verify and continue',
              isLoading: _busy,
              onPressed: _busy ? null : _verifyEmail,
            ),
            TextButton(
                onPressed: _busy ? null : () => _setStep(_AuthStep.signUp),
                child: const Text('Back to account details')),
          ],
          if (_notice != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_notice!,
                key: const ValueKey('auth_notice'),
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.primary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                key: const ValueKey('auth_error'),
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
              'Admin tools are managed in the web dashboard. Your account can still explore here.',
              textAlign: TextAlign.center,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
