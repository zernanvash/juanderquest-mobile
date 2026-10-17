import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/connection_monitor.dart';
import '../features/auth/providers/auth_provider.dart' show apiClientProvider, authProvider;
import '../features/submissions/providers/submission_provider.dart';
import '../features/app_update/providers/app_update_provider.dart' hide apiClientProvider;
import '../features/app_update/widgets/update_dialog.dart';
import 'router.dart';

class LifecycleCoordinator extends StatefulWidget {
  final Widget child;

  const LifecycleCoordinator({super.key, required this.child});

  @override
  State<LifecycleCoordinator> createState() => _LifecycleCoordinatorState();
}

class _LifecycleCoordinatorState extends State<LifecycleCoordinator> with WidgetsBindingObserver {
  DateTime? _lastResumeCheck;
  bool _promptShowing = false;
  bool _sessionSheetShowing = false;
  StreamSubscription<void>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesOnStartup();
      final container = ProviderScope.containerOf(context, listen: false);
      _sessionSubscription = container.read(apiClientProvider).onSessionExpired.listen((_) {
        _showSessionExpiredSheet();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _showSessionExpiredSheet() {
    if (_sessionSheetShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    _sessionSheetShowing = true;
    showModalBottomSheet<void>(
      context: navContext,
      isDismissible: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your session ended',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in again to continue. Your drafts and saved info are kept.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        ProviderScope.containerOf(context, listen: false)
                            .read(routerProvider)
                            .go('/login');
                      },
                      child: const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Later'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _sessionSheetShowing = false;
    });
  }

  Future<void> _checkUpdatesOnStartup() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final hasUpdate = await container.read(appUpdateProvider.notifier).checkForUpdates(silent: true);
    if (hasUpdate && mounted) {
      _promptUpdateIfReady(container);
    }
  }

  void _promptUpdateIfReady(ProviderContainer container) {
    if (_promptShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final updateState = container.read(appUpdateProvider);
    final release = updateState.latestVersion;
    if (release == null) return;

    _promptShowing = true;
    UpdateDialog.show(navContext, release).whenComplete(() {
      _promptShowing = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final container = ProviderScope.containerOf(context, listen: false);
    final monitor = container.read(connectionMonitorProvider.notifier);

    if (state == AppLifecycleState.resumed) {
      monitor.setBackgrounded(false);
      final auth = container.read(authProvider);
      if (auth.isAuthenticated) {
        container.read(authProvider.notifier).refreshProfile();
        container.read(submissionProvider.notifier).fetchSubmissions();
      }

      // Resume check throttled to 15 minutes
      final now = DateTime.now();
      if (_lastResumeCheck == null || now.difference(_lastResumeCheck!) > const Duration(minutes: 15)) {
        _lastResumeCheck = now;
        container.read(appUpdateProvider.notifier).checkForUpdates(silent: true).then((hasUpdate) {
          if (hasUpdate && mounted) {
            _promptUpdateIfReady(container);
          }
        });
      }
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      monitor.setBackgrounded(true);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

