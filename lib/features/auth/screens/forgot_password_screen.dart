import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/password_strength.dart';
import '../widgets/password_strength_meter.dart';

enum _RecoveryStep { email, code, password, done }

/// Email → 6-digit code → new password, same flow as the web
/// (`/auth/password/forgot`, `/verify-code`, `/reset`). Plan 47 B4.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _RecoveryStep _step = _RecoveryStep.email;
  String? _grant;
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Dio get _dio => ref.read(apiClientProvider).dio;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String _message(Object e, String fallback) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['error'] is Map) {
        final m = (body['error'] as Map)['message'];
        if (m is String && m.isNotEmpty) return m;
      }
      if (e.response?.statusCode == 429) {
        return 'Too many attempts. Wait a minute and try again.';
      }
    }
    return fallback;
  }

  Future<void> _run(Future<void> Function() action, String fallback) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e, fallback));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter the email you signed up with.');
      return;
    }
    await _run(() async {
      await _dio.post('/auth/password/forgot', data: {'email': email});
      if (!mounted) return;
      setState(() {
        _step = _RecoveryStep.code;
        _info = 'If an account uses $email, a 6-digit code is on its way. '
            'Check your inbox and spam folder.';
      });
    }, 'The code could not be sent. Check your connection.');
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    await _run(() async {
      final res = await _dio.post('/auth/password/verify-code',
          data: {'email': _email.text.trim(), 'code': code});
      final data = res.data is Map ? res.data['data'] : null;
      final grant = data is Map ? data['reset_grant'] : null;
      if (grant is! String) throw StateError('no grant');
      if (!mounted) return;
      setState(() {
        _grant = grant;
        _step = _RecoveryStep.password;
        _info = null;
      });
    }, 'That code is wrong or has expired.');
  }

  Future<void> _reset() async {
    final pw = _password.text;
    if (!PasswordCheck.of(pw, email: _email.text.trim()).isStrongEnough) {
      setState(() => _error =
          'Choose a stronger password: tick every item in the list below it.');
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    await _run(() async {
      await _dio.post('/auth/password/reset',
          data: {'reset_grant': _grant, 'new_password': pw});
      if (!mounted) return;
      setState(() => _step = _RecoveryStep.done);
    }, 'The reset window expired. Request a new code.');
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelAppBar(
                  title: 'RESET PASSWORD',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: PixelPanel(
                          style: PixelBoxStyle.parchment,
                          padding: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ShadowText(
                                switch (_step) {
                                  _RecoveryStep.email => 'FORGOT YOUR PASSWORD?',
                                  _RecoveryStep.code => 'ENTER YOUR CODE',
                                  _RecoveryStep.password => 'CHOOSE A NEW PASSWORD',
                                  _RecoveryStep.done => 'PASSWORD CHANGED',
                                },
                                style: PixelType.title(context),
                              ),
                              const SizedBox(height: 8),
                              if (_info != null) ...[
                                Text(
                                  _info!,
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ..._fields(),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                PixelPanel(
                                  style: PixelBoxStyle.red,
                                  padding: 2,
                                  child: Text(
                                    _error!,
                                    key: const ValueKey('recovery_error'),
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.white,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _primaryAction(),
                              if (_step == _RecoveryStep.code) ...[
                                const SizedBox(height: 12),
                                PixelButton(
                                  expand: true,
                                  variant: PixelButtonVariant.secondary,
                                  onPressed: _busy ? null : _sendCode,
                                  label: 'Send a new code',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_step) {
      case _RecoveryStep.email:
        return [
          PixelTextField(
            plainFont: true,
            key: const ValueKey('recovery_email'),
            controller: _email,
            label: 'Email',
            hint: 'traveler@example.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ];
      case _RecoveryStep.code:
        return [
          PixelTextField(
            plainFont: true,
            key: const ValueKey('recovery_code'),
            controller: _code,
            label: '6-digit code',
            hint: '123456',
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
          ),
        ];
      case _RecoveryStep.password:
        return [
          PixelTextField(
            plainFont: true,
            key: const ValueKey('recovery_password'),
            controller: _password,
            label: 'New password',
            hint: '••••••••',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          PasswordStrengthMeter(
            check: PasswordCheck.of(_password.text, email: _email.text.trim()),
          ),
          const SizedBox(height: 12),
          PixelTextField(
            plainFont: true,
            key: const ValueKey('recovery_confirm'),
            controller: _confirm,
            label: 'Repeat new password',
            hint: '••••••••',
            obscureText: true,
          ),
        ];
      case _RecoveryStep.done:
        return [
          Text(
            'You can now sign in with your email and the new password.',
            style: PixelType.body(context, color: PixelPalette.ink),
          ),
        ];
    }
  }

  Widget _primaryAction() {
    return switch (_step) {
      _RecoveryStep.email => PixelButton(
          key: const ValueKey('recovery_send'),
          expand: true,
          label: 'Send code',
          loading: _busy,
          onPressed: _busy ? null : _sendCode,
        ),
      _RecoveryStep.code => PixelButton(
          key: const ValueKey('recovery_verify'),
          expand: true,
          label: 'Verify code',
          loading: _busy,
          onPressed: _busy ? null : _verifyCode,
        ),
      _RecoveryStep.password => PixelButton(
          key: const ValueKey('recovery_reset'),
          expand: true,
          label: 'Save new password',
          loading: _busy,
          onPressed: _busy ? null : _reset,
        ),
      _RecoveryStep.done => PixelButton(
          key: const ValueKey('recovery_done'),
          expand: true,
          label: 'Back to sign in',
          onPressed: () => context.go('/'),
        ),
    };
  }
}
