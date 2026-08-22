import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

import '../../../core/network/api_client.dart';
import '../models/app_version_info.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  installing,
  error,
}

class AppUpdateState {
  final UpdateStatus status;
  final String installedVersionName;
  final int installedVersionCode;
  final AppVersionInfo? latestVersion;
  final int downloadProgress; // 0 - 100
  final String? errorMessage;

  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.installedVersionName = '1.0.0',
    this.installedVersionCode = 1,
    this.latestVersion,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  bool get hasUpdate =>
      latestVersion != null &&
      latestVersion!.versionCode > installedVersionCode;

  bool get isDownloading => status == UpdateStatus.downloading;

  AppUpdateState copyWith({
    UpdateStatus? status,
    String? installedVersionName,
    int? installedVersionCode,
    AppVersionInfo? latestVersion,
    int? downloadProgress,
    String? errorMessage,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      installedVersionName: installedVersionName ?? this.installedVersionName,
      installedVersionCode: installedVersionCode ?? this.installedVersionCode,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final ApiClient _apiClient;
  StreamSubscription<OtaEvent>? _otaSubscription;

  AppUpdateNotifier(this._apiClient) : super(const AppUpdateState()) {
    _initCurrentVersion();
  }

  Future<void> _initCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      state = state.copyWith(
        installedVersionName: packageInfo.version,
        installedVersionCode: buildNumber,
      );
    } catch (e) {
      debugPrint('[AppUpdate] Failed to get PackageInfo: $e');
    }
  }

  /// Checks server for latest app version
  Future<bool> checkForUpdates({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    }

    try {
      await _initCurrentVersion();

      final response = await _apiClient.dio.get('/app/version');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        final latest = AppVersionInfo.fromJson(data);

        final isUpdateAvailable = latest.versionCode > state.installedVersionCode;

        state = state.copyWith(
          latestVersion: latest,
          status: isUpdateAvailable
              ? UpdateStatus.updateAvailable
              : UpdateStatus.upToDate,
          errorMessage: null,
        );

        return isUpdateAvailable;
      } else {
        if (!silent) {
          state = state.copyWith(
            status: UpdateStatus.error,
            errorMessage: 'Server returned invalid response',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('[AppUpdate] Update check failed: $e');
      if (!silent) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Could not connect to update server.',
        );
      }
      return false;
    }
  }

  /// Downloads APK and invokes Android package installer
  Future<void> startDownloadAndInstall() async {
    final latest = state.latestVersion;
    if (latest == null || latest.downloadUrl.isEmpty) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download URL is not available.',
      );
      return;
    }

    // Cancel any previous stream
    await _otaSubscription?.cancel();

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
      errorMessage: null,
    );

    try {
      _otaSubscription = OtaUpdate()
          .execute(
            latest.downloadUrl,
            destinationFilename: 'juanderquest-v${latest.versionCode}.apk',
          )
          .listen(
            (OtaEvent event) {
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  final progress = int.tryParse(event.value ?? '0') ?? 0;
                  state = state.copyWith(
                    status: UpdateStatus.downloading,
                    downloadProgress: progress.clamp(0, 100),
                  );
                  break;
                case OtaStatus.INSTALLING:
                  state = state.copyWith(
                    status: UpdateStatus.installing,
                    downloadProgress: 100,
                  );
                  break;
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  state = state.copyWith(
                    status: UpdateStatus.error,
                    errorMessage: 'An update is already downloading in background.',
                  );
                  break;
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  state = state.copyWith(
                    status: UpdateStatus.error,
                    errorMessage: 'Storage / install permission not granted.',
                  );
                  break;
                case OtaStatus.CANCELED:
                  state = state.copyWith(
                    status: UpdateStatus.idle,
                    errorMessage: 'Update was canceled.',
                  );
                  break;
                case OtaStatus.INTERNAL_ERROR:
                case OtaStatus.DOWNLOAD_ERROR:
                case OtaStatus.CHECKSUM_ERROR:
                  state = state.copyWith(
                    status: UpdateStatus.error,
                    errorMessage: 'Download failed (${event.status.name}). Check internet connection.',
                  );
                  break;
              }
            },
            onError: (error) {
              state = state.copyWith(
                status: UpdateStatus.error,
                errorMessage: 'Download error: $error',
              );
            },
          );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Failed to start installer: $e',
      );
    }
  }

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AppUpdateNotifier(apiClient);
});
