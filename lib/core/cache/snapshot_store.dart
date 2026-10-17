import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SnapshotEntry {
  final DateTime savedAt;
  final int schemaVersion;
  final Object? data;

  const SnapshotEntry({required this.savedAt, required this.schemaVersion, required this.data});
}

/// Small JSON snapshot store (Plan 40 §A7): one file per key under
/// `<appSupport>/snapshots/`, holding `{savedAt, schemaVersion, data}`.
/// Deliberately minimal — the full relational cache stays in Plan 37.
class SnapshotStore {
  SnapshotStore({Future<Directory> Function()? directoryProvider, this.schemaVersion = 1})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;
  final int schemaVersion;
  static const int _maxBytes = 2 * 1024 * 1024;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/snapshots');
  }

  String _fileNameFor(String key) {
    final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'snapshot_$safe.json';
  }

  Future<void> save(String key, Object data) async {
    try {
      final directory = await _directoryProvider();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final payload = jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'schemaVersion': schemaVersion,
        'data': data,
      });
      if (payload.length > _maxBytes) return;
      final file = File('${directory.path}/${_fileNameFor(key)}');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // Snapshots are best-effort; failures must never break a fetch.
    }
  }

  Future<SnapshotEntry?> load(String key, {Duration? maxAge}) async {
    try {
      final directory = await _directoryProvider();
      final file = File('${directory.path}/${_fileNameFor(key)}');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      if (savedAt == null) return null;
      final version = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
      if (version != schemaVersion) return null;
      if (maxAge != null && DateTime.now().difference(savedAt) > maxAge) return null;
      return SnapshotEntry(savedAt: savedAt, schemaVersion: version, data: decoded['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String key) async {
    try {
      final directory = await _directoryProvider();
      final file = File('${directory.path}/${_fileNameFor(key)}');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore.
    }
  }
}

/// Human copy for "Saved 12 min ago" labels.
String relativeSnapshotAge(DateTime savedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(savedAt);
  if (difference.inSeconds < 60) return 'Saved just now';
  if (difference.inMinutes < 60) return 'Saved ${difference.inMinutes} min ago';
  if (difference.inHours < 24) return 'Saved ${difference.inHours} h ago';
  return 'Saved ${difference.inDays} d ago';
}
