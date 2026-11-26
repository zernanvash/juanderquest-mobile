import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/vlog_manifest.dart';

/// Incremented whenever a local trail vlog clip or manifest mutates so screens
/// watching active or saved vlogs reload cleanly.
final trailVlogRevisionProvider = StateProvider<int>((ref) => 0);

/// Local-first, crash-safe storage manager for Trail Vlog clips and compiled MP4s.
class TrailVlogVault {
  final Future<Directory> Function() _baseDirProvider;

  TrailVlogVault({Future<Directory> Function()? baseDirProvider})
      : _baseDirProvider = baseDirProvider ?? getApplicationSupportDirectory;

  String _safeId(String trailId) {
    final cleaned = trailId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'trail' : cleaned;
  }

  Future<Directory> _rootDir() async {
    final base = await _baseDirProvider();
    final root = Directory('${base.path}${Platform.pathSeparator}trail_vlogs');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> trailDir(String trailId) async {
    final root = await _rootDir();
    final dir =
        Directory('${root.path}${Platform.pathSeparator}${_safeId(trailId)}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> compiledOutputPath(String trailId) async {
    final dir = await trailDir(trailId);
    return '${dir.path}${Platform.pathSeparator}compiled_${_safeId(trailId)}.mp4';
  }

  File _manifestFile(Directory dir) =>
      File('${dir.path}${Platform.pathSeparator}vlog_manifest.json');

  Future<void> _writeManifestAtomic(
    Directory dir,
    TrailVlogManifest manifest,
  ) async {
    final target = _manifestFile(dir);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(manifest.toEncodedJson(), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  Future<TrailVlogManifest?> loadManifest(String trailId) async {
    final root = await _rootDir();
    final dir =
        Directory('${root.path}${Platform.pathSeparator}${_safeId(trailId)}');
    if (!await dir.exists()) return null;
    final file = _manifestFile(dir);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return TrailVlogManifest.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<TrailVlogManifest> ensureManifest({
    required String trailId,
    required String trailTitle,
    required int totalStops,
    required double totalKm,
    int rewardPoints = 0,
  }) async {
    final existing = await loadManifest(trailId);
    final dir = await trailDir(trailId);
    if (existing != null) {
      if (existing.trailTitle != trailTitle ||
          existing.totalStops != totalStops ||
          existing.totalKm != totalKm ||
          (rewardPoints > 0 && existing.rewardPoints != rewardPoints)) {
        final updated = existing.copyWith(
          trailTitle: trailTitle,
          totalStops: totalStops,
          totalKm: totalKm,
          rewardPoints: rewardPoints > 0 ? rewardPoints : existing.rewardPoints,
          updatedAtIso: DateTime.now().toUtc().toIso8601String(),
        );
        await _writeManifestAtomic(dir, updated);
        return updated;
      }
      return existing;
    }
    final created = TrailVlogManifest(
      trailId: trailId,
      trailTitle: trailTitle,
      totalStops: totalStops,
      totalKm: totalKm,
      rewardPoints: rewardPoints,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeManifestAtomic(dir, created);
    return created;
  }

  /// Plan 124d: starts a custom video log (no trail). Its id starts with
  /// `custom_`, so it never collides with a trail id.
  Future<TrailVlogManifest> createCustomSession({String? title}) async {
    final now = DateTime.now();
    final id = 'custom_${now.millisecondsSinceEpoch}';
    final dir = await trailDir(id);
    final trimmed = title?.trim() ?? '';
    final created = TrailVlogManifest(
      trailId: id,
      trailTitle: trimmed.isNotEmpty ? trimmed : 'My JuanLog',
      totalStops: 0,
      totalKm: 0,
      isCustom: true,
      updatedAtIso: now.toUtc().toIso8601String(),
    );
    await _writeManifestAtomic(dir, created);
    return created;
  }

  /// Plan 124d: renames a saved vlog (used for custom logs).
  Future<TrailVlogManifest?> renameVlog(String trailId, String title) async {
    final existing = await loadManifest(trailId);
    final trimmed = title.trim();
    if (existing == null || trimmed.isEmpty) return existing;
    final dir = await trailDir(trailId);
    final updated = existing.copyWith(
      trailTitle: trimmed,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeManifestAtomic(dir, updated);
    return updated;
  }

  /// Copies [sourceFilePath] into the trail vault and updates `vlog_manifest.json`.
  Future<TrailVlogManifest> saveClip({
    required String trailId,
    required String trailTitle,
    required int totalStops,
    required double totalKm,
    int rewardPoints = 0,
    required VlogClipKind kind,
    required int stopPosition,
    String? spotId,
    required String spotName,
    required String municipality,
    required String sourceFilePath,
    int durationMs = 3000,
    String cameraFacing = 'back',
  }) async {
    final manifest = await ensureManifest(
      trailId: trailId,
      trailTitle: trailTitle,
      totalStops: totalStops,
      totalKm: totalKm,
      rewardPoints: rewardPoints,
    );
    final dir = await trailDir(trailId);
    final destName = switch (kind) {
      VlogClipKind.stop => 'stop_$stopPosition.mp4',
      VlogClipKind.road => 'leg_${stopPosition}_road.mp4',
      VlogClipKind.custom => 'custom_$stopPosition.mp4',
    };
    final destFile = File('${dir.path}${Platform.pathSeparator}$destName');
    final source = File(sourceFilePath);
    if (source.path != destFile.path) {
      if (await source.exists()) {
        await source.copy(destFile.path);
      } else {
        await destFile.writeAsBytes(const [], flush: true);
      }
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final entry = VlogClipEntry(
      id: '${kind.key}_$stopPosition',
      kind: kind,
      stopPosition: stopPosition,
      spotId: spotId,
      spotName: spotName,
      municipality: municipality,
      capturedAtIso: nowIso,
      filePath: destFile.path,
      durationMs: durationMs,
      cameraFacing: cameraFacing,
    );

    final nextClips = manifest.clips
        .where((c) => !(c.kind == kind && c.stopPosition == stopPosition))
        .toList()
      ..add(entry)
      ..sort((a, b) {
        final posCmp = a.stopPosition.compareTo(b.stopPosition);
        if (posCmp != 0) return posCmp;
        // Within a stop index: road clip captured en route comes before stop check-in.
        if (a.kind == b.kind) return 0;
        return a.kind == VlogClipKind.road ? -1 : 1;
      });

    final updated = manifest.copyWith(
      clips: nextClips,
      compiledPath: () => null,
      compiledAtIso: () => null,
      compiledSizeBytes: () => null,
      updatedAtIso: nowIso,
    );
    await _writeManifestAtomic(dir, updated);
    return updated;
  }

  Future<TrailVlogManifest?> deleteClip(
    String trailId, {
    required VlogClipKind kind,
    required int stopPosition,
  }) async {
    final existing = await loadManifest(trailId);
    if (existing == null) return null;
    final dir = await trailDir(trailId);
    final removed = existing.clips
        .where((c) => c.kind == kind && c.stopPosition == stopPosition)
        .toList();
    for (final clip in removed) {
      final f = File(clip.filePath);
      if (await f.exists()) {
        await f.delete();
      }
    }
    final nextClips = existing.clips
        .where((c) => !(c.kind == kind && c.stopPosition == stopPosition))
        .toList();
    final updated = existing.copyWith(
      clips: nextClips,
      compiledPath: () => null,
      compiledAtIso: () => null,
      compiledSizeBytes: () => null,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeManifestAtomic(dir, updated);
    return updated;
  }

  Future<TrailVlogManifest?> updatePreferences(
    String trailId, {
    VlogFrameStyle? frameStyle,
    VlogAudioMode? audioMode,
    int? rewardPoints,
  }) async {
    final existing = await loadManifest(trailId);
    if (existing == null) return null;
    final dir = await trailDir(trailId);
    final prefsChanged =
        (frameStyle != null && frameStyle != existing.frameStyle) ||
            (audioMode != null && audioMode != existing.audioMode);
    final updated = existing.copyWith(
      frameStyle: frameStyle ?? existing.frameStyle,
      audioMode: audioMode ?? existing.audioMode,
      rewardPoints: rewardPoints ?? existing.rewardPoints,
      compiledPath: prefsChanged ? () => null : null,
      compiledAtIso: prefsChanged ? () => null : null,
      compiledSizeBytes: prefsChanged ? () => null : null,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeManifestAtomic(dir, updated);
    return updated;
  }

  Future<TrailVlogManifest?> recordCompilation(
    String trailId,
    VlogCompileResult result,
  ) async {
    final existing = await loadManifest(trailId);
    if (existing == null) return null;
    final dir = await trailDir(trailId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updated = existing.copyWith(
      compiledPath: () => result.outputPath,
      compiledAtIso: () => nowIso,
      compiledSizeBytes: () => result.sizeBytes,
      updatedAtIso: nowIso,
    );
    await _writeManifestAtomic(dir, updated);
    return updated;
  }

  Future<List<TrailVlogManifest>> listAllVlogs() async {
    final root = await _rootDir();
    final entities = await root.list(followLinks: false).toList();
    final manifests = <TrailVlogManifest>[];
    for (final entity in entities) {
      if (entity is! Directory) continue;
      final file = _manifestFile(entity);
      if (!await file.exists()) continue;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final m =
              TrailVlogManifest.fromJson(Map<String, dynamic>.from(decoded));
          if (m.trailId.isNotEmpty) manifests.add(m);
        }
      } catch (_) {
        // Ignore corrupted directory entries gracefully.
      }
    }
    manifests.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
    return manifests;
  }

  Future<void> deleteTrailVlog(String trailId) async {
    final root = await _rootDir();
    final dir =
        Directory('${root.path}${Platform.pathSeparator}${_safeId(trailId)}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<int> totalStorageBytes() async {
    final root = await _rootDir();
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}

final trailVlogVaultProvider =
    Provider<TrailVlogVault>((ref) => TrailVlogVault());
