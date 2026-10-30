import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/quest_model.dart';
import 'qr_scan_screen.dart';

/// A QR task the host verifies by scanning the traveler's in-app pass
/// (`scan_mode: host_scans_traveler`), instead of the traveler scanning a code.
bool isHostScanStep(QuestStepModel step) =>
    step.checkpointType == 'qr' &&
    step.verification?['scan_mode'] == 'host_scans_traveler';

/// A traveler quest pass as shown by [QuestPassSheet], or null.
String? extractQuestPass(String? raw) {
  final text = raw?.trim();
  if (text == null || !text.startsWith('JDQPASS:') || text.length > 4096) {
    return null;
  }
  return text;
}

String _dioMessage(Object error, String fallback) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
  }
  return fallback;
}

/// Traveler side: a one-use pass (valid 10 minutes) for the host to scan.
/// Pops with `true` once the host has verified the step.
class QuestPassSheet extends ConsumerStatefulWidget {
  final String questId;
  final QuestStepModel step;

  const QuestPassSheet({super.key, required this.questId, required this.step});

  @override
  ConsumerState<QuestPassSheet> createState() => _QuestPassSheetState();
}

class _QuestPassSheetState extends ConsumerState<QuestPassSheet> {
  String? _payload;
  String? _travelerName;
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
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post('/quests/${widget.questId}/steps/${widget.step.order}/qr-pass');
      final data = res.data['data'];
      if (res.data['success'] != true || data is! Map) {
        throw StateError('No pass');
      }
      if (!mounted) return;
      setState(() {
        _payload = data['qr_payload'] as String?;
        _travelerName = data['traveler_name'] as String?;
        _expiresAt = DateTime.tryParse('${data['expires_at']}');
      });
      _poll?.cancel();
      _poll =
          Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _dioMessage(error,
          'Could not create your pass. Check your connection and retry.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerified() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/quests/${widget.questId}/progress');
      final attempt = res.data['data']?['active_attempt'];
      if (attempt is! Map) return;
      final model =
          QuestAttemptModel.fromJson(Map<String, dynamic>.from(attempt));
      final step = model.steps.where((s) => s.order == widget.step.order);
      if (step.isNotEmpty && step.first.isVerified && mounted) {
        _poll?.cancel();
        Navigator.of(context).pop(true);
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
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your quest pass',
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              widget.step.title,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center),
              TextButton(onPressed: _issue, child: const Text('Retry')),
            ] else if (_payload != null) ...[
              Opacity(
                opacity: expired ? 0.25 : 1,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 2),
                  ),
                  child: QrImageView(
                    data: _payload!,
                    size: 220,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Quest pass QR code',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_travelerName != null)
                Text(_travelerName!,
                    style: AppTypography.labelLarge,
                    textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                expired
                    ? 'This pass expired. Make a new one.'
                    : 'Show this to the host. Valid for $mm:${ss.toString().padLeft(2, '0')}, one scan.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (expired)
                FilledButton.icon(
                  onPressed: _issue,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('New pass'),
                )
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Flexible(child: Text('Waiting for the host to scan…')),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Host side: scan a traveler's pass on site and verify their step.
/// Shows the outcome in a dialog. [getPosition] returns a fresh GPS fix or null.
Future<void> hostScanTravelerPass({
  required BuildContext context,
  required WidgetRef ref,
  required QuestModel quest,
  required QuestStepModel step,
  required Future<Position?> Function() getPosition,
}) async {
  final payload = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => const QrScanScreen(
        title: "Scan the traveler's quest pass",
        extract: extractQuestPass,
        rejectedMessage: 'That is not a JuanDerQuest quest pass.',
      ),
    ),
  );
  if (payload == null || !context.mounted) return;

  final pos = await getPosition();
  if (!context.mounted) return;
  if (pos == null) {
    await _showHostResult(context,
        ok: false,
        title: 'Location needed',
        message: 'Turn on location: hosts verify passes on site.');
    return;
  }
  try {
    final res = await ref.read(apiClientProvider).dio.post(
      '/quests/${quest.id}/steps/${step.order}/host-verify-qr',
      data: {
        'qr_pass_token': payload,
        'captured_lat': pos.latitude,
        'captured_lng': pos.longitude,
        'captured_accuracy': pos.accuracy,
      },
    );
    final name = res.data['data']?['traveler_name'] ?? 'the traveler';
    if (!context.mounted) return;
    await _showHostResult(context,
        ok: true,
        title: 'Verified',
        message: 'Step ${step.order} is verified for $name.');
  } catch (error) {
    if (!context.mounted) return;
    await _showHostResult(context,
        ok: false,
        title: 'Not verified',
        message:
            _dioMessage(error, 'Could not verify this pass. Please retry.'));
  }
}

Future<void> _showHostResult(BuildContext context,
    {required bool ok, required String title, required String message}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(ok ? Icons.verified_rounded : Icons.error_outline_rounded,
          color: ok ? AppColors.primary : AppColors.danger, size: 40),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
      ],
    ),
  );
}

/// Shown after finishing a quest: the reward when it was paid at once, or that it awaits review.
Future<void> showQuestFinishedDialog(BuildContext context,
    {required bool rewardAwarded, int awardedPoints = 0}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
          rewardAwarded
              ? Icons.emoji_events_rounded
              : Icons.hourglass_top_rounded,
          color: rewardAwarded ? AppColors.sunGold : AppColors.primary,
          size: 48),
      title: Text(rewardAwarded ? 'Quest complete!' : 'Quest submitted'),
      content: Text(
        rewardAwarded
            ? 'You earned +$awardedPoints points. They are already in your account.'
            : 'Nice work! Your quest is waiting for review. Your reward is granted once it is approved.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done'))
      ],
    ),
  );
}
