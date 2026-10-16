import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Debug/profile-only API server override (Settings → Developer).
/// Release builds never read or honor a stored override.
abstract final class ServerOverrideStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'jdq_debug_api_server_override_v1';

  static bool get isAvailable => !kReleaseMode;

  static Future<String?> read() async {
    if (kReleaseMode) return null;
    try {
      final value = await _storage.read(key: _key);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String url) async {
    if (kReleaseMode) return;
    await _storage.write(key: _key, value: url.trim());
  }

  static Future<void> clear() async {
    if (kReleaseMode) return;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Ignore storage failures; the override simply stays off.
    }
  }
}
