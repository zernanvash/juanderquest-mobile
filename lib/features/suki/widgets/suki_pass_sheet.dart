import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_text.dart';
import '../providers/suki_provider.dart';

/// Plan 107: the customer's 2-minute, one-scan pass for staff-scan shops.
/// Pops with the updated card (or `true`) once staff have recorded today's visit.
class SukiPassSheet extends ConsumerStatefulWidget {
  const SukiPassSheet(
      {super.key, required this.programId, required this.shopName});

  final String programId;
  final String shopName;

  @override
  ConsumerState<SukiPassSheet> createState() => _SukiPassSheetState();
}

class _SukiPassSheetState extends ConsumerState<SukiPassSheet> {
  String? _pass;
  DateTime? _expiresAt;
  String? _error;
  bool _loading = true;
  Timer? _poll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _issue();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final expiresAt = _expiresAt;
      // An expired pass can no longer be scanned: stop polling until a new one.
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        _poll?.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(sukiApiProvider).pass(widget.programId);
      if (!mounted) return;
      setState(() {
        _pass = result.pass;
        _expiresAt = result.expiresAt;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } catch (error) {
      if (mounted) setState(() => _error = sukiErrorText(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    try {
      final status =
          await ref.read(sukiApiProvider).passStatus(widget.programId);
      if (status.visitedToday && mounted) {
        _poll?.cancel();
        Navigator.of(context).pop(status.card ?? true);
      }
    } catch (_) {
      // Keep showing the pass; the next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _expiresAt?.difference(DateTime.now());
    final expired = remaining != null && remaining.isNegative;
    final mm = remaining == null || expired ? 0 : remaining.inMinutes;
    final ss = remaining == null || expired ? 0 : remaining.inSeconds % 60;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, en: 'Your Suki pass', tl: 'Ang Suki pass mo'),
                style: PixelType.title(context), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(widget.shopName,
                style: PixelType.body(context, color: PixelPalette.slate),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: PixelLoader(
                    label: tr(context,
                        en: 'Creating your pass',
                        tl: 'Ginagawa ang pass mo')),
              )
            else if (_error != null) ...[
              Text(_error!,
                  key: const ValueKey('suki_pass_error'),
                  style: PixelType.body(context, color: PixelPalette.redDeep),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              PixelButton(
                label: tr(context, en: 'Retry', tl: 'Subukang muli'),
                variant: PixelButtonVariant.secondary,
                onPressed: _issue,
              ),
            ] else if (_pass != null) ...[
              Opacity(
                opacity: expired ? 0.25 : 1,
                child: PixelPanel(
                  style: PixelBoxStyle.slot,
                  padding: 2,
                  child: QrImageView(
                    data: _pass!,
                    size: 220,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Suki pass QR code',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                expired
                    ? tr(context,
                        en: 'This pass expired. Make a new one.',
                        tl: 'Expired na ang pass. Gumawa ng bago.')
                    : tr(context,
                        en: 'Show this to the staff. Valid for $mm:${ss.toString().padLeft(2, '0')}, one scan.',
                        tl: 'Ipakita sa staff. $mm:${ss.toString().padLeft(2, '0')} pa, isang scan.'),
                key: const ValueKey('suki_pass_countdown'),
                style: PixelType.small(context, color: PixelPalette.slate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (expired)
                PixelButton(
                  label: tr(context, en: 'New pass', tl: 'Bagong pass'),
                  onPressed: _issue,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
