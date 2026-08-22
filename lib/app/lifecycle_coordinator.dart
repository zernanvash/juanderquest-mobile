import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/submissions/providers/submission_provider.dart';
import '../features/app_update/providers/app_update_provider.dart';
import '../features/app_update/widgets/update_dialog.dart';

class LifecycleCoordinator extends StatefulWidget {
  final Widget child;

  const LifecycleCoordinator({super.key, required this.child});

  @override
  State<LifecycleCoordinator> createState() => _LifecycleCoordinatorState();
}

class _LifecycleCoordinatorState extends State<LifecycleCoordinator> with WidgetsBindingObserver {
  bool _hasPromptedUpdateThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAutoUpdate() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final hasUpdate = await container.read(appUpdateProvider.notifier).checkForUpdates(silent: true);
    if (mounted && hasUpdate && !_hasPromptedUpdateThisSession) {
      _hasPromptedUpdateThisSession = true;
      final updateState = container.read(appUpdateProvider);
      if (updateState.latestVersion != null) {
        UpdateDialog.show(context, updateState.latestVersion!);
      }
    }
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
      _checkAutoUpdate();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
