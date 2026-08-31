import '../models/app_version_info.dart';

/// Classification of the type of update discovered.
enum UpdateChannel {
  none,
  dartPatch,
  contentBundle,
  baseRelease,
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
