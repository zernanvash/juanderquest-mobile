import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connection_monitor.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Non-blocking connectivity strip mounted above every screen's content.
/// Hidden while online; dismissible only in the `degraded` state.
class ConnectionBanner extends ConsumerStatefulWidget {
  const ConnectionBanner({super.key});

  @override
  ConsumerState<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends ConsumerState<ConnectionBanner> {
  bool _degradedDismissed = false;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _syncCountdownTimer(ConnectionStatus status) {
    final needsTicker = status == ConnectionStatus.serverUnreachable ||
        status == ConnectionStatus.serverRestarting;
    if (needsTicker && _countdownTimer == null) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionMonitorProvider);
    final monitor = ref.read(connectionMonitorProvider.notifier);

    ref.listen<ConnectionStatus>(connectionMonitorProvider, (previous, next) {
      if (next != ConnectionStatus.degraded) {
        _degradedDismissed = false;
      }
    });

    _syncCountdownTimer(status);

    if (status == ConnectionStatus.online) {
      return const SizedBox.shrink();
    }
    if (status == ConnectionStatus.degraded && _degradedDismissed) {
      return const SizedBox.shrink();
    }

    final (icon, copy, color, background) = switch (status) {
      ConnectionStatus.offline => (
          Icons.cloud_off_rounded,
          "You're offline. Showing saved info.",
          AppColors.woodBrown,
          AppColors.surfaceContainerLow,
        ),
      ConnectionStatus.serverRestarting => (
          Icons.sync_rounded,
          'JuanDerQuest is restarting… reconnecting',
          AppColors.primaryDark,
          AppColors.successBg,
        ),
      ConnectionStatus.serverUnreachable => (
          Icons.cloud_off_rounded,
          monitor.secondsUntilRetry != null
              ? "Can't reach JuanDerQuest right now. Retrying in ${monitor.secondsUntilRetry}s"
              : "Can't reach JuanDerQuest right now.",
          const Color(0xFF7D5800),
          const Color(0xFFFFF3E8),
        ),
      ConnectionStatus.degraded => (
          Icons.speed_rounded,
          'Slow connection — things may take longer',
          Colors.blueGrey.shade700,
          const Color(0xFFECEFF1),
        ),
      ConnectionStatus.online => (Icons.check_rounded, '', AppColors.woodBrown, AppColors.surfaceContainerLow),
    };

    return Material(
      color: background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 6),
          child: Row(
            children: [
              if (status == ConnectionStatus.serverRestarting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  copy,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status == ConnectionStatus.serverUnreachable)
                TextButton(
                  onPressed: monitor.retryNow,
                  child: const Text('Retry now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              if (status == ConnectionStatus.degraded)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Dismiss',
                  onPressed: () => setState(() => _degradedDismissed = true),
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
