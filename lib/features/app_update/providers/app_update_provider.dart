import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../data/release_manifest_client.dart';
import '../models/app_version_info.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  readyToInstall,
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
  final bool isCached;
  final String? cachedFilePath;
  final String? errorMessage;

  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.installedVersionName = '1.0.0',
    this.installedVersionCode = 1,
    this.latestVersion,
    this.downloadProgress = 0,
    this.isCached = false,
    this.cachedFilePath,
    this.errorMessage,
  });

  bool get hasUpdate =>
      latestVersion != null &&
      latestVersion!.versionCode > installedVersionCode;

  bool get isDownloading => status == UpdateStatus.downloading;
  bool get isReadyToInstall => status == UpdateStatus.readyToInstall || isCached;

  AppUpdateState copyWith({
    UpdateStatus? status,
    String? installedVersionName,
    int? installedVersionCode,
    AppVersionInfo? latestVersion,
    int? downloadProgress,
    bool? isCached,
    String? cachedFilePath,
    String? errorMessage,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      installedVersionName: installedVersionName ?? this.installedVersionName,
      installedVersionCode: installedVersionCode ?? this.installedVersionCode,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isCached: isCached ?? this.isCached,
      cachedFilePath: cachedFilePath ?? this.cachedFilePath,
      errorMessage: errorMessage,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final ReleaseManifestClient _manifestClient;
  CancelToken? _cancelToken;

  AppUpdateNotifier(this._manifestClient) : super(const AppUpdateState()) {
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

  Future<String> _getCachedFilePath(int versionCode) async {
    Directory? tempDir;
    if (Platform.isAndroid) {
      tempDir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    } else {
      tempDir = await getTemporaryDirectory();
    }
    return '${tempDir.path}/juanderquest-v$versionCode.apk';
  }

  Future<bool> _isVerifiedApk(File file, AppVersionInfo release) async {
    if (!await file.exists() || release.sizeBytes == null || release.sha256 == null) {
      return false;
    }
    if (await file.length() != release.sizeBytes) return false;
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString() == release.sha256;
  }

  /// Checks server for latest app version and verifies if APK is already cached
  Future<bool> checkForUpdates({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    }

    try {
      await _initCurrentVersion();

      final latest = await _manifestClient.fetch();
      if (latest != null) {

        final isUpdateAvailable = latest.versionCode > state.installedVersionCode;

        // Check if full completed APK is already cached on local storage
        bool isCached = false;
        String? cachedPath;
        if (isUpdateAvailable) {
          final filePath = await _getCachedFilePath(latest.versionCode);
          final file = File(filePath);
          if (await _isVerifiedApk(file, latest)) {
            isCached = true;
            cachedPath = filePath;
          }
        }

        state = state.copyWith(
          latestVersion: latest,
          isCached: isCached,
          cachedFilePath: cachedPath,
          downloadProgress: isCached ? 100 : 0,
          status: isUpdateAvailable
              ? (isCached ? UpdateStatus.readyToInstall : UpdateStatus.updateAvailable)
              : UpdateStatus.upToDate,
          errorMessage: null,
        );

        return isUpdateAvailable;
      } else {
        if (!silent) {
          state = state.copyWith(
            status: UpdateStatus.error,
            errorMessage: 'No valid release manifest is available.',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('[AppUpdate] Update check failed: $e');
      if (!silent) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Could not check GitHub Releases.',
        );
      }
      return false;
    }
  }

  /// Downloads APK into atomic temp file or uses cached package, then launches installer
  Future<void> startDownloadAndInstall({bool forceRedownload = false}) async {
    final latest = state.latestVersion;
    if (latest == null || latest.downloadUrl.isEmpty) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download URL is not available.',
      );
      return;
    }

    try {
      final completedFilePath = await _getCachedFilePath(latest.versionCode);
      final completedFile = File(completedFilePath);

      // 1. If APK is already fully cached and no forced re-download requested, launch immediately!
      if (!forceRedownload && await _isVerifiedApk(completedFile, latest)) {
        debugPrint('[AppUpdate] Using cached APK at $completedFilePath');
        state = state.copyWith(
          status: UpdateStatus.installing,
          downloadProgress: 100,
          isCached: true,
          cachedFilePath: completedFilePath,
        );

        if (Platform.isAndroid) {
          const platform = MethodChannel('com.juanderquest.app/installer');
          await platform.invokeMethod('installApk', {'filePath': completedFilePath});
        }
        return;
      }

      // 2. Otherwise, download to .tmp file to ensure atomic completion
      _cancelToken?.cancel();
      _cancelToken = CancelToken();

      state = state.copyWith(
        status: UpdateStatus.downloading,
        downloadProgress: 0,
        errorMessage: null,
      );

      final tempFilePath = '$completedFilePath.tmp';
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      await dio.download(
        latest.downloadUrl,
        tempFilePath,
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

      if (!await _isVerifiedApk(tempFile, latest)) {
        await tempFile.delete();
        throw const FormatException('Downloaded APK failed integrity verification');
      }

      // 3. Rename temp file to final APK (atomic cache completion)
      if (await tempFile.exists()) {
        if (await completedFile.exists()) {
          await completedFile.delete();
        }
        await tempFile.rename(completedFilePath);
      }

      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadProgress: 100,
        isCached: true,
        cachedFilePath: completedFilePath,
      );

      // 4. Trigger Android native package installer via MethodChannel
      if (Platform.isAndroid) {
        state = state.copyWith(status: UpdateStatus.installing);
        const platform = MethodChannel('com.juanderquest.app/installer');
        await platform.invokeMethod('installApk', {'filePath': completedFilePath});
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
  return AppUpdateNotifier(ReleaseManifestClient());
});
