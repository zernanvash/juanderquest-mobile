import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/update_repository_impl.dart';

import '../domain/update_classification.dart';
import '../domain/update_repository.dart';
import '../models/app_version_info.dart';

final updateRepositoryProvider = Provider<IUpdateRepository>((ref) {
  return UpdateRepositoryImpl();
});


final startupUpdateControllerProvider = StateNotifierProvider<StartupUpdateController, StartupGateState>((ref) {
  final repository = ref.watch(updateRepositoryProvider);
  return StartupUpdateController(repository);
});

class StartupUpdateController extends StateNotifier<StartupGateState> {
  final IUpdateRepository _repository;

  StartupUpdateController(this._repository) : super(const StartupGateState()) {
    initStartupGate();
  }

  Future<void> initStartupGate() async {
    // APK base releases and Shorebird patches apply to Android, not the web
    // build. Browsers cannot read the GitHub release asset across origins.
    if (kIsWeb) {
      state = state.copyWith(
        phase: GatePhase.ready,
        statusMessage: 'Ready',
        progress: 1.0,
      );
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      state = state.copyWith(
        installedVersionName: packageInfo.version,
        installedVersionCode: buildNumber,
        phase: GatePhase.checking,
        statusMessage: 'Connecting to JuanDerQuest...',
      );

      // Step 1: Query backend compatibility with bounded timeout (2.5s)
      AppVersionInfo? versionInfo;
      try {
        versionInfo = await _repository
            .fetchBackendVersionMetadata(timeout: const Duration(milliseconds: 2500))
            .timeout(const Duration(milliseconds: 3000), onTimeout: () => null);
      } catch (e) {
        debugPrint('[StartupUpdateController] Network check timed out or failed: $e');
      }

      if (versionInfo != null) {
        state = state.copyWith(latestVersion: versionInfo);

        // Check if a native base release is strictly required
        // baseReleaseRequired describes the available release; an already
        // compatible installed base must never be blocked by that flag.
        if (versionInfo.minimumBaseVersionCode > buildNumber) {
          state = state.copyWith(
            phase: GatePhase.baseRequired,
            statusMessage: 'A new base platform update is required to continue.',
            isMandatory: true,
          );
          return;
        }
      }

      // Step 2: The optional patch adapter is unavailable in ordinary APKs.
      state = state.copyWith(statusMessage: 'Checking update compatibility...');
      bool patchAvailable = false;
      try {
        patchAvailable = await _repository.isDartPatchAvailable();
      } catch (e) {
        debugPrint('[StartupUpdateController] Shorebird check error: $e');
      }

      if (patchAvailable) {
        state = state.copyWith(
          phase: GatePhase.downloading,
          statusMessage: 'Downloading live patch...',
          progress: 0.1,
        );

        final downloaded = await _repository.downloadAndInstallDartPatch(
          onProgress: (p) => state = state.copyWith(progress: p),
        );

        if (downloaded) {
          state = state.copyWith(
            phase: GatePhase.restartRequired,
            statusMessage: 'Restarting to apply update...',
            progress: 1.0,
          );

          // Trigger controlled process restart after brief visual cue
          await Future.delayed(const Duration(milliseconds: 800));
          await _repository.restartApp();
          return;
        }
      }

      // Content delivery remains disabled until signed bundles can be
      // verified and atomically installed. Manifest metadata alone is not an update.

      // Step 4: Ready to enter application
      state = state.copyWith(
        phase: GatePhase.ready,
        statusMessage: 'Ready',
        progress: 1.0,
      );
    } catch (e) {
      debugPrint('[StartupUpdateController] Startup gate error: $e');
      // Fallback: Proceed to app so transient offline/failures never trap users
      state = state.copyWith(
        phase: GatePhase.ready,
        statusMessage: 'Ready',
      );
    }
  }

  /// Manually retry startup gate
  Future<void> retry() async {
    state = state.copyWith(phase: GatePhase.checking, errorMessage: null);
    await initStartupGate();
  }

  /// Bypasses the gate in testing/development environments
  void bypassGate() {
    state = state.copyWith(phase: GatePhase.ready);
  }
}
