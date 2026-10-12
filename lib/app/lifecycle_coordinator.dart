import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/submissions/providers/submission_provider.dart';
import '../features/app_update/providers/app_update_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesOnStartup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    if (state == AppLifecycleState.resumed) {
      final container = ProviderScope.containerOf(context, listen: false);
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
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

