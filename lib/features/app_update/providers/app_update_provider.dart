import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../data/update_repository_impl.dart';
import '../domain/update_repository.dart';
import '../models/app_version_info.dart';
import 'startup_update_controller.dart';

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

/// A higher build code is an update, except for local debug/test builds
/// (build code below 100, e.g. `0.3.10+1`) of the same version name: those
/// would otherwise prompt "v0.3.10 -> v0.3.10" (phone QA 2026-11-19).
/// Server floor (Plan 109 WP-5). Local debug builds (code < 100) are never forced.
bool _belowMinSupported(AppVersionInfo latest, int installedCode) =>
    installedCode >= 100 && latest.effectiveMinSupportedBuild > installedCode;

bool isNewerRelease({
  required int latestCode,
  required String latestName,
  required int installedCode,
  required String installedName,
}) {
  if (latestCode <= installedCode) return false;
  // Local debug builds (code < 100): only a strictly newer version name counts,
  // so a v0.3.10 dev build is never offered v0.3.9.
  if (installedCode < 100) {
    return _compareVersionNames(latestName, installedName) > 0;
  }
  return true;
}

int _compareVersionNames(String a, String b) {
  List<int> parts(String v) => v
      .trim()
      .split(RegExp(r'[^0-9]+'))
      .where((p) => p.isNotEmpty)
      .map(int.parse)
      .toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
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

  final DateTime? lastCheckedAt;

  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.installedVersionName = '1.0.0',
    this.installedVersionCode = 1,
    this.latestVersion,
    this.downloadProgress = 0,
    this.isCached = false,
    this.cachedFilePath,
    this.errorMessage,
    this.lastCheckedAt,
  });

  bool get hasUpdate =>
      latestVersion != null &&
      (isNewerRelease(
            latestCode: latestVersion!.buildNumber ?? latestVersion!.versionCode,
            latestName: latestVersion!.versionName,
            installedCode: installedVersionCode,
            installedName: installedVersionName,
          ) ||
          _belowMinSupported(latestVersion!, installedVersionCode));

  bool get isUpdateRequired =>
      latestVersion != null &&
      (latestVersion!.forceUpdate ||
          latestVersion!.updatePolicy == UpdatePolicy.mandatory ||
          _belowMinSupported(latestVersion!, installedVersionCode));

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
    DateTime? lastCheckedAt,
    bool clearErrorMessage = false,
    bool clearCachedFilePath = false,
    bool clearLatestVersion = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      installedVersionName: installedVersionName ?? this.installedVersionName,
      installedVersionCode: installedVersionCode ?? this.installedVersionCode,
      latestVersion: clearLatestVersion ? null : (latestVersion ?? this.latestVersion),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isCached: isCached ?? this.isCached,
      cachedFilePath: clearCachedFilePath ? null : (cachedFilePath ?? this.cachedFilePath),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final IUpdateRepository _repository;
  CancelToken? _cancelToken;
  Completer<bool>? _checkFlight;

  AppUpdateNotifier({
    IUpdateRepository? repository,
  })  : _repository = repository ?? UpdateRepositoryImpl(),
        super(const AppUpdateState()) {
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

  /// Checks server for latest app version and verifies if APK is already cached.
  /// Deduplicates concurrent checks using a single-flight completer.
  Future<bool> checkForUpdates({bool silent = false}) async {
    if (_checkFlight != null) {
      return _checkFlight!.future;
    }

    final completer = Completer<bool>();
    _checkFlight = completer;

    if (!silent) {
      state = state.copyWith(
        status: UpdateStatus.checking,
        clearErrorMessage: true,
      );
    }

    try {
      await _initCurrentVersion();

      final latest = await _repository.fetchBackendVersionMetadata();
      final now = DateTime.now();

      if (latest != null) {
        final isUpdateAvailable = isNewerRelease(
              latestCode: latest.buildNumber ?? latest.versionCode,
              latestName: latest.versionName,
              installedCode: state.installedVersionCode,
              installedName: state.installedVersionName,
            ) ||
            _belowMinSupported(latest, state.installedVersionCode);

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
          clearErrorMessage: true,
          lastCheckedAt: now,
        );

        completer.complete(isUpdateAvailable);
        return isUpdateAvailable;
      } else {
        if (!silent) {
          state = state.copyWith(
            status: UpdateStatus.error,
            errorMessage: 'Unable to reach the release server. Check your connection and try again.',
            lastCheckedAt: now,
          );
        }
        completer.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('[AppUpdate] Update check failed: $e');
      if (!silent) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Could not connect to update service ($e).',
          lastCheckedAt: DateTime.now(),
        );
      }
      completer.complete(false);
      return false;
    } finally {
      _checkFlight = null;
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
  final repository = ref.watch(updateRepositoryProvider);
  return AppUpdateNotifier(repository: repository);
});

class DismissedAnnouncementNotifier extends StateNotifier<Set<String>> {
  static const _storageKey = 'jdq_dismissed_announcements_v1';
  static const _maxStored = 20;

  final FlutterSecureStorage? _storage;

  DismissedAnnouncementNotifier([FlutterSecureStorage? storage])
      : _storage = storage,
        super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = decoded.whereType<String>().toSet();
      }
    } catch (_) {
      // Ignore storage errors (e.g. missing plugin in widget tests).
    }
  }

  Future<void> dismiss(String key) async {
    if (key.isEmpty || state.contains(key)) return;
    final next = <String>[...state, key];
    if (next.length > _maxStored) {
      next.removeRange(0, next.length - _maxStored);
    }
    state = next.toSet();
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.write(key: _storageKey, value: jsonEncode(next));
    } catch (_) {
      // Ignore storage errors.
    }
  }
}

final dismissedAnnouncementProvider =
    StateNotifierProvider<DismissedAnnouncementNotifier, Set<String>>((ref) {
  return DismissedAnnouncementNotifier(const FlutterSecureStorage());
});

final activeAnnouncementProvider = Provider<AppAnnouncement?>((ref) {
  final updateLatest = ref.watch(appUpdateProvider).latestVersion;
  final startupLatest = ref.watch(startupUpdateControllerProvider).latestVersion;
  final announcement = updateLatest?.announcement ?? startupLatest?.announcement;
  if (announcement == null) return null;
  if (announcement.isExpiredAt(DateTime.now())) return null;
  final dismissed = ref.watch(dismissedAnnouncementProvider);
  if (dismissed.contains(announcement.dismissalKey)) return null;
  return announcement;
});
