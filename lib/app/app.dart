import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pixel/pixel_grid.dart';
import '../core/services/push_listener.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/device_guard.dart';
import '../features/app_update/widgets/startup_update_gate.dart';
import 'lifecycle_coordinator.dart';
import 'router.dart';

class JuanderQuestApp extends ConsumerWidget {
  const JuanderQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final pixelSettings = ref.watch(pixelSettingsProvider);

    return LifecycleCoordinator(
      child: MaterialApp.router(
        title: 'JuanDerQuest — Gamified Tourism Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => PixelScope(
          settings: pixelSettings,
          child: DeviceGuard(
            child: StartupUpdateGate(
              child: PushListener(child: child ?? const SizedBox()),
            ),
          ),
        ),
      ),
    );
  }
}

