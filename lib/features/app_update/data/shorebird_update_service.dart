import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adapter for Shorebird Code Push / Dart live updates.
/// Wraps native invocation and provides graceful fallback when Shorebird is not active.
class ShorebirdUpdateService {
  static const MethodChannel _channel = MethodChannel('dev.zernanvash.juanderquest/shorebird');

  bool _isAvailable = false;
  int? _currentPatchNumber;

  ShorebirdUpdateService() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Check if Shorebird updater is bundled in binary
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await _channel.invokeMethod<bool>('isAvailable');
        _isAvailable = result ?? false;
        if (_isAvailable) {
          _currentPatchNumber = await _channel.invokeMethod<int>('currentPatch');
        }
      }
    } catch (_) {
      // Shorebird not linked or running in standard debug/test runner
      _isAvailable = false;
    }
  }

  bool get isAvailable => _isAvailable;
  int? get currentPatchNumber => _currentPatchNumber;

  /// Checks if a compatible Dart patch is available on Shorebird servers.
  Future<bool> checkForPatchUpdate() async {
    if (!_isAvailable) return false;
    try {
      final hasUpdate = await _channel.invokeMethod<bool>('checkForUpdate');
      return hasUpdate ?? false;
    } catch (e) {
      debugPrint('[ShorebirdUpdateService] Check failed: $e');
      return false;
    }
  }

  /// Downloads and verifies the latest Shorebird Dart patch.
  Future<bool> downloadPatch({void Function(double progress)? onProgress}) async {
    if (!_isAvailable) return false;
    try {
      onProgress?.call(0.1);
      final success = await _channel.invokeMethod<bool>('downloadUpdate');
      onProgress?.call(1.0);
      return success ?? false;
    } catch (e) {
      debugPrint('[ShorebirdUpdateService] Download failed: $e');
      return false;
    }
  }

  /// Relaunches the process to activate the downloaded Dart patch without invoking Package Installer.
  Future<void> restartApp() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('restartApp');
      }
    } catch (e) {
      debugPrint('[ShorebirdUpdateService] Restart failed: $e');
    }
  }
}
