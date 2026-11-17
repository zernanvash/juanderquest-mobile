import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/game_audio.dart';
import '../core/pixel/pixel_box.dart';
import '../core/pixel/pixel_grid.dart';
import '../core/services/push_listener.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/device_guard.dart';
import '../core/widgets/in_app_banner.dart';
import '../features/app_update/widgets/startup_update_gate.dart';
import 'lifecycle_coordinator.dart';
import 'router.dart';

class JuanderQuestApp extends ConsumerWidget {
  const JuanderQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final pixelSettings = ref.watch(pixelSettingsProvider);
    GameAudio.instance.configure(
      music: pixelSettings.music,
      sounds: pixelSettings.sounds,
    );

    return LifecycleCoordinator(
      child: MaterialApp.router(
        title: 'JuanDerQuest — Gamified Tourism Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => PixelScope(
          settings: pixelSettings,
          // Owner 2026-11-17: section panels carry the texture app-wide.
          child: PixelPanelTexture(
            child: DeviceGuard(
              child: StartupUpdateGate(
                child: InAppBannerHost(
                  child: PushListener(child: child ?? const SizedBox()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
