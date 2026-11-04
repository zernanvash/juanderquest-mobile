import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart'
    hide PrimaryButton, SecondaryButton;

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_signature_service.dart';

enum _AuthStep { signIn, signUp, verifyEmail, completeWallet }

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
  WalletLoginNeedsAccount? _pendingWallet;

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

  /// Plan 67: a wallet without an email + password account finishes it here,
  /// on sign-up and sign-in alike, before any session exists.
  void _askForAccountDetails(WalletLoginNeedsAccount pending) {
    setState(() {
      _pendingWallet = pending;
      if (_name.text.trim().isEmpty && pending.existingDisplayName != null) {
        _name.text = pending.existingDisplayName!;
      }
      _password.clear();
      _step = _AuthStep.completeWallet;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _completeWallet() async {
    final pending = _pendingWallet;
    if (pending == null) return;
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
    });
    final ok = await ref.read(authProvider.notifier).completeWalletRegistration(
          grant: pending.grant,
          walletAddress: pending.walletAddress,
          email: email,
          password: _password.text,
          displayName: _name.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = ref.read(authProvider).error ??
            'We could not finish your account. Please try again.';
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
          builder: (context, setDialogState) => Theme(
            data: AppTheme.pixel,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  padding: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShadowText(
                          'SIGN IN WITH YOUR WALLET',
                          style: PixelType.title(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Connect your wallet, then approve a sign-in message. This does not send a transaction or move tokens.',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppKitModalConnectButton(
                            appKit: modal, context: context),
                        if (walletError != null) ...[
                          const SizedBox(height: 12),
                          PixelPanel(
                            style: PixelBoxStyle.red,
                            padding: 2,
                            child: Text(
                              walletError!,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.white,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PixelButton(
                              variant: PixelButtonVariant.secondary,
                              onPressed: signing
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              label: 'Cancel',
                            ),
                            const SizedBox(width: 8),
                            PixelButton(
                              loading: signing,
                              onPressed: signing
                                  ? null
                                  : () async {
                                      final address = WalletSignatureService
                                          .connectedAddress(modal);
                                      if (address == null) {
                                        setDialogState(() => walletError =
                                            'Connect an EVM wallet first.');
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
                                            await WalletSignatureService
                                                .signChallenge(
                                                    modal, challenge);
                                        final result = await ref
                                            .read(authProvider.notifier)
                                            .loginWithWallet(
                                                address: address,
                                                signature: signature);
                                        if (result is WalletLoginFailed) {
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              signing = false;
                                              walletError = result.message;
                                            });
                                          }
                                        } else {
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }
                                          if (result
                                                  is WalletLoginNeedsAccount &&
                                              mounted) {
                                            _askForAccountDetails(result);
                                          }
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
                              label: 'Continue',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      await modal.dispose();
    }
  }

  static String _shortAddress(String address) => address.length > 14
      ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
      : address;

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
    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: PixelPalette.paperDim,
        body: DitherBackground(
          top: PixelPalette.paperDim,
          bottom: PixelPalette.paper,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: PixelPanel(
                    style: PixelBoxStyle.parchment,
                    padding: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => ShadowText(
                              'JUANDERQUEST',
                              style: PixelType.title(context,
                                  color: PixelPalette.ink),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadowText(
                          switch (_step) {
                            _AuthStep.signIn => 'WELCOME BACK',
                            _AuthStep.signUp => 'CREATE TRAVELER ACCOUNT',
                            _AuthStep.verifyEmail => 'VERIFY YOUR EMAIL',
                            _AuthStep.completeWallet => 'COMPLETE YOUR ACCOUNT'
                          },
                          textAlign: TextAlign.center,
                          style: PixelType.title(context,
                              color: PixelPalette.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          switch (_step) {
                            _AuthStep.signIn =>
                              'Sign in to continue your journey.',
                            _AuthStep.signUp =>
                              'A few details, then you’re ready to explore.',
                            _AuthStep.verifyEmail =>
                              'Enter the code we sent to ${_email.text.trim()}.',
                            _AuthStep.completeWallet =>
                              'Add an email and password so you can always get back in, even without your wallet.'
                          },
                          textAlign: TextAlign.center,
                          style: PixelType.body(context,
                              color: PixelPalette.slate),
                        ),
                        const SizedBox(height: 20),
                        if (_step == _AuthStep.completeWallet &&
                            _pendingWallet != null) ...[
                          Center(
                            child: PixelChip(
                              'Wallet ${_shortAddress(_pendingWallet!.walletAddress)} verified',
                              key: const ValueKey('auth_wallet_verified'),
                              style: PixelBoxStyle.green,
                              textColor: PixelPalette.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PixelTextField(
                            key: const ValueKey('auth_wallet_name'),
                            controller: _name,
                            label: 'Name',
                            hint: 'Your Name',
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                          ),
                          const SizedBox(height: 12),
                          PixelTextField(
                            key: const ValueKey('auth_wallet_email'),
                            controller: _email,
                            label: 'Email address',
                            hint: 'traveler@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: 12),
                          PixelTextField(
                            key: const ValueKey('auth_wallet_password'),
                            controller: _password,
                            label: 'Password (8+ characters)',
                            hint: '••••••••',
                            obscureText: !_passwordVisible,
                            autofillHints: const [AutofillHints.newPassword],
                            helperText:
                                'Already registered? Use that account\'s password to link this wallet.',
                          ),
                          const SizedBox(height: 8),
                          PixelCheckbox(
                            key: const ValueKey('auth_wallet_age'),
                            value: _ageEligible,
                            label: 'I meet the age eligibility requirement.',
                            onChanged: _busy
                                ? (_) {}
                                : (v) => setState(() => _ageEligible = v),
                          ),
                          const SizedBox(height: 6),
                          PixelCheckbox(
                            key: const ValueKey('auth_wallet_terms'),
                            value: _termsAccepted,
                            label:
                                'I agree to the terms of service and privacy notice.',
                            onChanged: _busy
                                ? (_) {}
                                : (v) => setState(() => _termsAccepted = v),
                          ),
                          const SizedBox(height: 16),
                          PixelButton(
                            key: const ValueKey('auth_complete_wallet'),
                            expand: true,
                            label: 'Finish and continue',
                            loading: _busy,
                            onPressed: _busy ? null : _completeWallet,
                          ),
                          const SizedBox(height: 8),
                          PixelButton(
                            expand: true,
                            variant: PixelButtonVariant.secondary,
                            onPressed: _busy
                                ? null
                                : () {
                                    _pendingWallet = null;
                                    _setStep(_AuthStep.signIn);
                                  },
                            label: 'Cancel',
                          ),
                        ] else if (_step != _AuthStep.verifyEmail) ...[
                          Row(
                            children: [
                              Expanded(
                                child: PixelButton(
                                  key: const ValueKey('tab_signin'),
                                  expand: true,
                                  label: 'Sign in',
                                  variant: _step == _AuthStep.signIn
                                      ? PixelButtonVariant.primary
                                      : PixelButtonVariant.secondary,
                                  onPressed: _busy
                                      ? null
                                      : () => _setStep(_AuthStep.signIn),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PixelButton(
                                  key: const ValueKey('tab_signup'),
                                  expand: true,
                                  label: 'Create account',
                                  variant: _step == _AuthStep.signUp
                                      ? PixelButtonVariant.primary
                                      : PixelButtonVariant.secondary,
                                  onPressed: _busy
                                      ? null
                                      : () => _setStep(_AuthStep.signUp),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_step == _AuthStep.signUp) ...[
                            PixelTextField(
                              key: const ValueKey('auth_display_name'),
                              controller: _name,
                              label: 'Name',
                              hint: 'Your Name',
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 12),
                          ],
                          PixelTextField(
                            key: const ValueKey('auth_email'),
                            controller: _email,
                            label: 'Email address',
                            hint: 'traveler@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: 12),
                          PixelTextField(
                            key: const ValueKey('auth_password'),
                            controller: _password,
                            label: _step == _AuthStep.signUp
                                ? 'Password (8+ characters)'
                                : 'Password',
                            hint: '••••••••',
                            obscureText: !_passwordVisible,
                            autofillHints: [
                              _step == _AuthStep.signUp
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _passwordVisible = !_passwordVisible),
                              child: Text(
                                _passwordVisible
                                    ? 'HIDE PASSWORD'
                                    : 'SHOW PASSWORD',
                                style: PixelType.small(context,
                                    color: PixelPalette.slate),
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
                                child: Text(
                                  'Forgot password?',
                                  style: PixelType.small(context,
                                      color: PixelPalette.slate),
                                ),
                              ),
                            ),
                          if (_step == _AuthStep.signUp) ...[
                            const SizedBox(height: 8),
                            PixelCheckbox(
                              key: const ValueKey('auth_age_eligibility'),
                              value: _ageEligible,
                              label: 'I meet the age eligibility requirement.',
                              onChanged: _busy
                                  ? (_) {}
                                  : (v) => setState(() => _ageEligible = v),
                            ),
                            const SizedBox(height: 6),
                            PixelCheckbox(
                              key: const ValueKey('auth_terms'),
                              value: _termsAccepted,
                              label:
                                  'I agree to the terms of service and privacy notice.',
                              onChanged: _busy
                                  ? (_) {}
                                  : (v) => setState(() => _termsAccepted = v),
                            ),
                          ],
                          const SizedBox(height: 16),
                          PixelButton(
                            key: ValueKey(_step == _AuthStep.signIn
                                ? 'auth_sign_in'
                                : 'auth_create_account'),
                            expand: true,
                            label: _step == _AuthStep.signIn
                                ? 'Sign in with email'
                                : 'Create traveler account',
                            loading: _busy,
                            onPressed: _busy
                                ? null
                                : (_step == _AuthStep.signIn
                                    ? _signIn
                                    : _register),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                  child: ColoredBox(
                                      color: PixelPalette.stone,
                                      child: SizedBox(height: 2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: PixelType.small(context,
                                      color: PixelPalette.slate),
                                ),
                              ),
                              const Expanded(
                                  child: ColoredBox(
                                      color: PixelPalette.stone,
                                      child: SizedBox(height: 2))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PixelButton(
                            key: const ValueKey('auth_wallet_sign_in'),
                            expand: true,
                            variant: PixelButtonVariant.secondary,
                            onPressed: _busy ? null : _startWalletSignIn,
                            label: 'Continue with wallet',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Wallet sign-in verifies ownership with a signature. It never sends a transaction.',
                            textAlign: TextAlign.center,
                            style: PixelType.small(context,
                                color: PixelPalette.slate),
                          ),
                        ] else ...[
                          PixelTextField(
                            key: const ValueKey('auth_email_otp'),
                            controller: _otp,
                            label: '6-digit email code',
                            hint: '123456',
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                          ),
                          const SizedBox(height: 16),
                          PixelButton(
                            key: const ValueKey('auth_verify_email'),
                            expand: true,
                            label: 'Verify and continue',
                            loading: _busy,
                            onPressed: _busy ? null : _verifyEmail,
                          ),
                          const SizedBox(height: 8),
                          PixelButton(
                            expand: true,
                            variant: PixelButtonVariant.secondary,
                            onPressed: _busy
                                ? null
                                : () => _setStep(_AuthStep.signUp),
                            label: 'Back to account details',
                          ),
                        ],
                        if (_notice != null) ...[
                          const SizedBox(height: 16),
                          PixelPanel(
                            style: PixelBoxStyle.gold,
                            padding: 2,
                            child: Text(
                              _notice!,
                              key: const ValueKey('auth_notice'),
                              textAlign: TextAlign.center,
                              style: PixelType.body(context,
                                  color: PixelPalette.ink),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          PixelPanel(
                            style: PixelBoxStyle.red,
                            padding: 2,
                            child: Text(
                              _error!,
                              key: const ValueKey('auth_error'),
                              textAlign: TextAlign.center,
                              style: PixelType.body(context,
                                  color: PixelPalette.white),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Admin tools are managed in the web dashboard. Your account can still explore here.',
                          textAlign: TextAlign.center,
                          style: PixelType.small(context,
                              color: PixelPalette.slate),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
