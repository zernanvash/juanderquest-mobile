import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

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
    if (pw.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                switch (_step) {
                  _RecoveryStep.email => 'Forgot your password?',
                  _RecoveryStep.code => 'Enter your code',
                  _RecoveryStep.password => 'Choose a new password',
                  _RecoveryStep.done => 'Password changed',
                },
                style: AppTypography.headlineSmall
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_info != null)
                Text(_info!,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              ..._fields(),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    key: const ValueKey('recovery_error'),
                    style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.lg),
              _primaryAction(),
              if (_step == _RecoveryStep.code)
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Send a new code'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_step) {
      case _RecoveryStep.email:
        return [
          TextField(
            key: const ValueKey('recovery_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case _RecoveryStep.code:
        return [
          TextField(
            key: const ValueKey('recovery_code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(
              labelText: '6-digit code',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case _RecoveryStep.password:
        return [
          TextField(
            key: const ValueKey('recovery_password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'New password (8+ characters)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('recovery_confirm'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Repeat new password',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case _RecoveryStep.done:
        return [
          const Text(
              'You can now sign in with your email and the new password.'),
        ];
    }
  }

  Widget _primaryAction() {
    return switch (_step) {
      _RecoveryStep.email => PrimaryButton(
          key: const ValueKey('recovery_send'),
          label: 'Send code',
          isLoading: _busy,
          onPressed: _busy ? null : _sendCode,
        ),
      _RecoveryStep.code => PrimaryButton(
          key: const ValueKey('recovery_verify'),
          label: 'Verify code',
          isLoading: _busy,
          onPressed: _busy ? null : _verifyCode,
        ),
      _RecoveryStep.password => PrimaryButton(
          key: const ValueKey('recovery_reset'),
          label: 'Save new password',
          isLoading: _busy,
          onPressed: _busy ? null : _reset,
        ),
      _RecoveryStep.done => PrimaryButton(
          key: const ValueKey('recovery_done'),
          label: 'Back to sign in',
          onPressed: () => context.go('/'),
        ),
    };
  }
}
