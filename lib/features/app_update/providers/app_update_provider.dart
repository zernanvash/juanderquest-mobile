import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

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
  CancelToken? _cancelToken;

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

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
      errorMessage: null,
    );

    try {
      // Get device download / cache directory
      Directory? tempDir;
      if (Platform.isAndroid) {
        tempDir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      } else {
        tempDir = await getTemporaryDirectory();
      }

      final filePath = '${tempDir.path}/juanderquest-v${latest.versionCode}.apk';
      final file = File(filePath);

      // Clean up previous file if exists
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      final downloadTarget = latest.downloadUrl;
      try {
        await dio.download(
          downloadTarget,
          filePath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = ((received / total) * 100).toInt().clamp(0, 100);
              state = state.copyWith(
                status: UpdateStatus.downloading,
                downloadProgress: progress,
              );
            }
          },
        );
      } on DioException catch (dioErr) {
        // If static URL 404s, attempt fallback to direct API stream endpoint
        if (dioErr.response?.statusCode == 404 && !downloadTarget.contains('/app/download')) {
          final fallbackUrl = '${_apiClient.dio.options.baseUrl}/app/download';
          debugPrint('[AppUpdate] Static URL 404, attempting fallback to $fallbackUrl');
          await dio.download(
            fallbackUrl,
            filePath,
            cancelToken: _cancelToken,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final progress = ((received / total) * 100).toInt().clamp(0, 100);
                state = state.copyWith(
                  status: UpdateStatus.downloading,
                  downloadProgress: progress,
                );
              }
            },
          );
        } else {
          rethrow;
        }
      }

      state = state.copyWith(
        status: UpdateStatus.installing,
        downloadProgress: 100,
      );

      // Trigger Android native package installer via MethodChannel
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.juanderquest.app/installer');
        await platform.invokeMethod('installApk', {'filePath': filePath});
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = state.copyWith(
          status: UpdateStatus.idle,
          errorMessage: 'Download was canceled.',
        );
      } else {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Download failed: ${e.message}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Update error: $e',
      );
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
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
