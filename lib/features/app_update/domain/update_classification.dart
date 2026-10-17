import '../models/app_version_info.dart';

/// Classification of the type of update discovered.
enum UpdateChannel {
  none,
  dartPatch,
  contentBundle,
  baseRelease,
}

/// UX class for an available update (Plan 40 §B6).
enum UpdateClass {
  none,
  optional,
  recommended,
  required,
  reinstallRequired,
}

/// Signing-key generation baked into this build at compile time.
const int installedSigningGeneration =
    int.fromEnvironment('SIGNING_KEY_GENERATION', defaultValue: 1);

/// Single source of truth for how an update should present itself.
/// Pure function so every combination is unit-testable.
UpdateClass classifyUpdate({
  required int installedBuild,
  AppVersionInfo? manifest,
  int installedGeneration = installedSigningGeneration,
}) {
  if (manifest == null) return UpdateClass.none;

  final manifestGeneration = manifest.signingKeyGeneration;
  if (manifestGeneration != null && manifestGeneration > installedGeneration) {
    return UpdateClass.reinstallRequired;
  }

  final latestBuild = manifest.buildNumber ?? manifest.versionCode;
  if (latestBuild <= installedBuild) return UpdateClass.none;

  final minSupported = manifest.minSupportedBuildNumber ?? manifest.minSupportedVersionCode;
  if (manifest.forceUpdate || manifest.updatePolicy == UpdatePolicy.mandatory || installedBuild < minSupported) {
    return UpdateClass.required;
  }

  if (manifest.baseReleaseRequired) return UpdateClass.recommended;

  return UpdateClass.optional;
}

/// Operational phase of the startup update gate.
enum GatePhase {
  checking,
  downloading,
  verifying,
  restartRequired,
  ready,
  compatibleOffline,
  baseRequired,
  error,
}

/// Immutable state describing the startup update gate progress.
class StartupGateState {
  final GatePhase phase;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String installedVersionName;
  final int installedVersionCode;
  final AppVersionInfo? latestVersion;
  final String? patchVersion;
  final String? contentVersion;
  final String? errorMessage;
  final bool isMandatory;

  const StartupGateState({
    this.phase = GatePhase.checking,
    this.progress = 0.0,
    this.statusMessage = 'Initializing JuanDerQuest...',
    this.installedVersionName = '1.0.0',
    this.installedVersionCode = 1,
    this.latestVersion,
    this.patchVersion,
    this.contentVersion,
    this.errorMessage,
    this.isMandatory = false,
  });

  bool get isReady => phase == GatePhase.ready;
  bool get isBlocking => phase == GatePhase.baseRequired || (phase == GatePhase.error && isMandatory);

  StartupGateState copyWith({
    GatePhase? phase,
    double? progress,
    String? statusMessage,
    String? installedVersionName,
    int? installedVersionCode,
    AppVersionInfo? latestVersion,
    String? patchVersion,
    String? contentVersion,
    String? errorMessage,
    bool? isMandatory,
  }) {
    return StartupGateState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      installedVersionName: installedVersionName ?? this.installedVersionName,
      installedVersionCode: installedVersionCode ?? this.installedVersionCode,
      latestVersion: latestVersion ?? this.latestVersion,
      patchVersion: patchVersion ?? this.patchVersion,
      contentVersion: contentVersion ?? this.contentVersion,
      errorMessage: errorMessage,
      isMandatory: isMandatory ?? this.isMandatory,
    );
  }
}
