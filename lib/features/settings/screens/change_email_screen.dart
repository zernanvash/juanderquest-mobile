import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/wallet_signature_service.dart';

class _EmailEligibility {
  const _EmailEligibility({
    required this.eligible,
    this.reason,
    this.boundWalletAddress,
    this.currentEmail,
    this.hasGoogleLinked = false,
    this.hasPassword = false,
    this.cooldownUntil,
  });

  final bool eligible;
  final String? reason;
  final String? boundWalletAddress;
  final String? currentEmail;
  final bool hasGoogleLinked;
  final bool hasPassword;
  final String? cooldownUntil;

  factory _EmailEligibility.fromJson(Map<String, dynamic> json) =>
      _EmailEligibility(
        eligible: json['eligible'] == true,
        reason: json['reason'] as String?,
        boundWalletAddress: json['bound_wallet_address'] as String?,
        currentEmail: json['current_email'] as String?,
        hasGoogleLinked: json['has_google_linked'] == true,
        hasPassword: json['has_password'] == true,
        cooldownUntil: json['cooldown_until'] as String?,
      );
}

String _shortWallet(String? address) {
  if (address == null || address.length < 12) return address ?? '';
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}

String _apiErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    final err = data is Map ? data['error'] : null;
    final msg = err is Map ? err['message'] as String? : null;
    if (msg != null && msg.trim().isNotEmpty) return msg;
  }
  return fallback;
}

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key, this.signMessageOverride});

  /// Optional test hook for signing the server-issued `siwe_message`.
  final Future<String> Function(String siweMessage)? signMessageOverride;

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _newEmailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _actionError;
  _EmailEligibility? _eligibility;

  // Step 2 state (after /request succeeds)
  String? _challengeId;
  String? _siweMessage;
  String? _pendingNewEmail;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _newEmailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _loadEligibility() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/auth/email/change/eligibility');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) {
        throw StateError('Unexpected eligibility response.');
      }
      if (!mounted) return;
      setState(() {
        _eligibility =
            _EmailEligibility.fromJson(Map<String, dynamic>.from(data));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _apiErrorMessage(
          e,
          tr(context,
              en: 'Could not check email settings. Try again.',
              tl: 'Hindi masuri ang email settings. Subukang muli.'),
        );
      });
    }
  }

  Future<void> _requestCode({bool isResend = false}) async {
    final targetEmail =
        isResend ? (_pendingNewEmail ?? '') : _newEmailCtrl.text.trim();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      setState(() {
        _actionError = tr(context,
            en: 'Enter a valid email address.',
            tl: 'Maglagay ng wastong email address.');
      });
      return;
    }

    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final res = await ref.read(apiClientProvider).dio.post(
        '/auth/email/change/request',
        data: {'new_email': targetEmail},
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) throw StateError('Invalid server response.');
      if (!mounted) return;
      setState(() {
        _challengeId = data['challenge_id'] as String?;
        _siweMessage = data['siwe_message'] as String?;
        _pendingNewEmail = (data['new_email'] as String?) ?? targetEmail;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = _apiErrorMessage(
          e,
          tr(context,
              en: 'Could not send verification code.',
              tl: 'Hindi maipadala ang verification code.'),
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _signSiweMessage(String siweMessage) async {
    if (widget.signMessageOverride != null) {
      return await widget.signMessageOverride!(siweMessage);
    }
    final modal = await WalletSignatureService.initialize(context);
    final address = await WalletSignatureService.ensureConnected(modal);
    if (address == null) {
      throw StateError('Wallet connection was cancelled.');
    }
    return await WalletSignatureService.signChallenge(modal, siweMessage);
  }

  Future<void> _confirmChange() async {
    final challengeId = _challengeId;
    final siweMessage = _siweMessage;
    final otp = _otpCtrl.text.trim();
    if (challengeId == null || siweMessage == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _actionError = tr(context,
            en: 'Enter the 6-digit verification code.',
            tl: 'Ilagay ang 6-digit verification code.');
      });
      return;
    }

    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final signature = await _signSiweMessage(siweMessage);
      final res = await ref.read(apiClientProvider).dio.post(
        '/auth/email/change/confirm',
        data: {
          'challenge_id': challengeId,
          'otp_code': otp,
          'wallet_signature': signature,
        },
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) throw StateError('Invalid confirm response.');
      final token = data['token'] as String?;
      final userJson = data['user'];
      if (token != null && userJson is Map) {
        ref.read(authProvider.notifier).applyUpdatedSession(
              token: token,
              userJson: Map<String, dynamic>.from(userJson),
            );
      }
      if (!mounted) return;
      showPixelToast(
        context,
        tr(context,
            en: 'Email updated successfully.',
            tl: 'Matagumpay na na-update ang email.'),
      );
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = _apiErrorMessage(
          e,
          e is StateError
              ? e.message
              : tr(context,
                  en: 'Could not confirm email change.',
                  tl: 'Hindi makumpirma ang pagpapalit ng email.'),
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title:
                      tr(context, en: 'Change Email', tl: 'Palitan ang Email'),
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      grid.gutter,
                      grid.px(3),
                      grid.gutter,
                      grid.px(8) + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: _buildBody(context, grid),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBody(BuildContext context, PixelGrid grid) {
    if (_loading) {
      return const Center(child: PixelLoader(label: 'Checking'));
    }
    if (_loadError != null || _eligibility == null) {
      return PixelPanel(
        style: PixelBoxStyle.red,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _loadError ?? 'Could not load.',
              style: PixelType.body(context, color: PixelPalette.white),
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              label: tr(context, en: 'Retry', tl: 'Subukan muli'),
              variant: PixelButtonVariant.ghost,
              onPressed: _loadEligibility,
            ),
          ],
        ),
      );
    }

    final elig = _eligibility!;

    if (!elig.eligible && elig.reason == 'WALLET_REQUIRED_FOR_EMAIL_CHANGE') {
      return PixelPanel(
        key: const ValueKey('change_email_wallet_locked'),
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                context,
                en: 'Connect a blockchain wallet first to change your account email.',
                tl: 'Magkonekta muna ng blockchain wallet bago palitan ang iyong email.',
              ),
              style: PixelType.body(context, color: PixelPalette.ink),
            ),
            SizedBox(height: grid.px(3)),
            PixelButton(
              key: const ValueKey('change_email_connect_wallet'),
              label: 'CONNECT WALLET',
              expand: true,
              onPressed: () async {
                await context.push('/wallet/connect');
                if (mounted) await _loadEligibility();
              },
            ),
          ],
        ),
      );
    }

    if (!elig.eligible && elig.reason == 'EMAIL_CHANGE_COOLDOWN') {
      return PixelPanel(
        key: const ValueKey('change_email_cooldown'),
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                context,
                en: 'Email change cooldown active.',
                tl: 'May cooldown pa sa pagpapalit ng email.',
              ),
              style: PixelType.body(context, color: PixelPalette.ink),
            ),
            if (elig.cooldownUntil != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                tr(
                  context,
                  en: 'Next change available after: ${elig.cooldownUntil}',
                  tl: 'Susunod na pagpapalit pagkatapos ng: ${elig.cooldownUntil}',
                ),
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, en: 'Current email', tl: 'Kasalukuyang email'),
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              Text(
                elig.currentEmail ?? 'Not set',
                style: PixelType.body(context, color: PixelPalette.ink),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(1),
                runSpacing: grid.px(1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr(context, en: 'Wallet:', tl: 'Wallet:'),
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                  PixelChip(_shortWallet(elig.boundWalletAddress)),
                ],
              ),
            ],
          ),
        ),
        if (elig.hasGoogleLinked) ...[
          SizedBox(height: grid.px(2)),
          PixelPanel(
            key: const ValueKey('change_email_google_notice'),
            style: PixelBoxStyle.gold,
            child: Text(
              tr(
                context,
                en: 'Changing your email will unlink your old Google Sign-In. Your wallet and password will keep working.',
                tl: 'Maaalis ang lumang Google Sign-In kapag pinalitan ang email. Gagana pa rin ang wallet at password mo.',
              ),
              style: PixelType.small(context, color: PixelPalette.ink),
            ),
          ),
        ],
        SizedBox(height: grid.px(3)),
        if (_challengeId == null) ...[
          PixelTextField(
            key: const ValueKey('change_email_input'),
            controller: _newEmailCtrl,
            label: tr(context, en: 'New email', tl: 'Bagong email'),
            hint: 'traveler@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: grid.px(3)),
          PixelButton(
            key: const ValueKey('change_email_send_code'),
            label: 'SEND CODE',
            expand: true,
            loading: _busy,
            onPressed: _busy ? null : () => _requestCode(),
          ),
        ] else ...[
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    context,
                    en: 'Enter the 6-digit code sent to ${_pendingNewEmail ?? ''}',
                    tl: 'Ilagay ang 6-digit code na ipinadala sa ${_pendingNewEmail ?? ''}',
                  ),
                  style: PixelType.small(context, color: PixelPalette.ink),
                ),
                SizedBox(height: grid.px(2)),
                PixelTextField(
                  key: const ValueKey('change_email_otp_input'),
                  controller: _otpCtrl,
                  label: tr(context, en: '6-digit code', tl: '6-digit code'),
                  hint: '123456',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  key: const ValueKey('change_email_confirm'),
                  label: 'SIGN WITH WALLET & CONFIRM',
                  expand: true,
                  loading: _busy,
                  onPressed: _busy ? null : _confirmChange,
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  key: const ValueKey('change_email_resend'),
                  label: _resendSeconds > 0
                      ? 'Resend code (${_resendSeconds}s)'
                      : 'Resend code',
                  variant: PixelButtonVariant.ghost,
                  expand: true,
                  onPressed: _busy || _resendSeconds > 0
                      ? null
                      : () => _requestCode(isResend: true),
                ),
              ],
            ),
          ),
        ],
        if (_actionError != null) ...[
          SizedBox(height: grid.px(2)),
          PixelPanel(
            key: const ValueKey('change_email_error'),
            style: PixelBoxStyle.red,
            child: Text(
              _actionError!,
              style: PixelType.small(context, color: PixelPalette.white),
            ),
          ),
        ],
      ],
    );
  }
}
