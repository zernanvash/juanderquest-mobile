import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages local storage of versioned content bundles (JSON configs, destination copy, remote media pointers).
class ContentBundleStore {
  static const String _activePointerFileName = 'active_version.txt';
  static const String _bundleDirName = 'mobile_content';

  Future<Directory> _getBaseDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final bundleDir = Directory('${appDocDir.path}/$_bundleDirName');
    if (!bundleDir.existsSync()) {
      bundleDir.createSync(recursive: true);
    }
    return bundleDir;
  }

  /// Gets the currently active content version string.
  Future<String?> getActiveVersion() async {
    try {
      final baseDir = await _getBaseDirectory();
      final pointerFile = File('${baseDir.path}/$_activePointerFileName');
      if (pointerFile.existsSync()) {
        return pointerFile.readAsStringSync().trim();
      }
    } catch (e) {
      debugPrint('[ContentBundleStore] Error reading active version: $e');
    }
    return null;
  }

  /// Atomically switches the active pointer to the newly verified version directory.
  Future<void> setActiveVersion(String version) async {
    try {
      final baseDir = await _getBaseDirectory();
      final pointerFile = File('${baseDir.path}/$_activePointerFileName');
      final tempFile = File('${baseDir.path}/$_activePointerFileName.tmp');
      await tempFile.writeAsString(version, flush: true);
      if (pointerFile.existsSync()) {
        await pointerFile.delete();
      }
      await tempFile.rename(pointerFile.path);
    } catch (e) {
      debugPrint('[ContentBundleStore] Error setting active version: $e');
    }
  }

  /// Gets the directory containing the active content files.
  Future<Directory?> getActiveContentDirectory() async {
    final version = await getActiveVersion();
    if (version == null) return null;
    final baseDir = await _getBaseDirectory();
    final versionDir = Directory('${baseDir.path}/$version');
    if (versionDir.existsSync()) {
      return versionDir;
    }
    return null;
  }
}
