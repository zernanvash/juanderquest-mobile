import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/spot_model.dart';

final spotsCacheRepositoryProvider = Provider<SpotsCacheRepository>((ref) {
  return SpotsCacheRepository();
});

class SpotsCacheResult {
  final List<SpotModel> spots;
  final DateTime cachedAt;
  final bool isStale;
  final String partition;

  const SpotsCacheResult({
    required this.spots,
    required this.cachedAt,
    required this.isStale,
    required this.partition,
  });
}

class TaxonomyCacheResult {
  final List<String> categories;
  final List<String> tags;
  final DateTime cachedAt;

  const TaxonomyCacheResult({
    required this.categories,
    required this.tags,
    required this.cachedAt,
  });
}

/// Durable local cache repository for read-only spots and taxonomy.
///
/// Implements account partitioning, schema versioning, stale-while-revalidate,
/// and low-storage/offline resilience.
class SpotsCacheRepository {
  static const int currentSchemaVersion = 1;
  static const String publicPartition = 'public_spots';
  static const String cacheFileName = 'spots_cache_v1.json';

  final Directory? _overrideDirectory;
  final Map<String, String>? _memoryFallback;

  SpotsCacheRepository({
    Directory? overrideDirectory,
    Map<String, String>? memoryFallback,
  })  : _overrideDirectory = overrideDirectory,
        _memoryFallback = memoryFallback;

  Future<File?> _getCacheFile() async {
    if (_memoryFallback != null) return null;
    try {
      if (_overrideDirectory != null) {
        return File('${_overrideDirectory!.path}/$cacheFileName');
      }
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$cacheFileName');
    } catch (e) {
      debugPrint('[SpotsCache] Could not resolve documents directory: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _readRootJson() async {
    try {
      if (_memoryFallback != null) {
        final content = _memoryFallback![cacheFileName];
        if (content == null || content.isEmpty) return {};
        return jsonDecode(content) as Map<String, dynamic>;
      }

      final file = await _getCacheFile();
      if (file == null || !await file.exists()) {
        return {};
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      debugPrint('[SpotsCache] Read error or corrupt cache, returning empty: $e');
      return {};
    }
  }

  Future<void> _writeRootJson(Map<String, dynamic> data) async {
    try {
      final encoded = jsonEncode(data);
      if (_memoryFallback != null) {
        _memoryFallback![cacheFileName] = encoded;
        return;
      }

      final file = await _getCacheFile();
      if (file == null) return;
      await file.writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('[SpotsCache] Write error: $e');
    }
  }

  /// Saves a list of spots under a specific partition (defaulting to [publicPartition]).
  Future<void> saveSpots(
    List<SpotModel> spots, {
    String partition = publicPartition,
  }) async {
    final root = await _readRootJson();
    final now = DateTime.now().toUtc().toIso8601String();

    final partitions = (root['partitions'] as Map<String, dynamic>?) ?? {};
    partitions[partition] = {
      'cached_at': now,
      'spots': spots.map((s) => s.toJson()).toList(),
    };

    root['version'] = currentSchemaVersion;
    root['partitions'] = partitions;

    await _writeRootJson(root);
  }

  /// Loads spots for a partition. Marks [isStale] if older than [staleThreshold].
  Future<SpotsCacheResult?> loadSpots({
    String partition = publicPartition,
    Duration staleThreshold = const Duration(hours: 1),
  }) async {
    final root = await _readRootJson();
    final partitions = root['partitions'] as Map<String, dynamic>?;
    if (partitions == null || !partitions.containsKey(partition)) {
      return null;
    }

    final entry = partitions[partition] as Map<String, dynamic>?;
    if (entry == null) return null;

    final cachedAtStr = entry['cached_at'] as String?;
    final rawSpots = entry['spots'] as List?;
    if (cachedAtStr == null || rawSpots == null) return null;

    final cachedAt = DateTime.tryParse(cachedAtStr)?.toLocal() ?? DateTime.now();
    final isStale = DateTime.now().difference(cachedAt) >= staleThreshold;

    final spots = rawSpots
        .whereType<Map<String, dynamic>>()
        .map((j) => SpotModel.fromJson(j))
        .toList();

    return SpotsCacheResult(
      spots: spots,
      cachedAt: cachedAt,
      isStale: isStale,
      partition: partition,
    );
  }

  /// Persists taxonomy categories and tags.
  Future<void> saveTaxonomy(List<String> categories, List<String> tags) async {
    final root = await _readRootJson();
    root['taxonomy'] = {
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'categories': categories,
      'tags': tags,
    };
    root['version'] = currentSchemaVersion;
    await _writeRootJson(root);
  }

  /// Loads cached taxonomy categories and tags.
  Future<TaxonomyCacheResult?> loadTaxonomy() async {
    final root = await _readRootJson();
    final taxonomy = root['taxonomy'] as Map<String, dynamic>?;
    if (taxonomy == null) return null;

    final cachedAtStr = taxonomy['cached_at'] as String?;
    final categories = (taxonomy['categories'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final tags = (taxonomy['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return TaxonomyCacheResult(
      categories: categories,
      tags: tags,
      cachedAt: DateTime.tryParse(cachedAtStr ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  /// Purges private user-partitioned data upon account logout.
  Future<void> purgeUserPartition(String userId) async {
    final root = await _readRootJson();
    final partitions = root['partitions'] as Map<String, dynamic>?;
    if (partitions != null) {
      partitions.remove('user_$userId');
      root['partitions'] = partitions;
      await _writeRootJson(root);
    }
  }

  /// Completely clears cache.
  Future<void> purgeAll() async {
    if (_memoryFallback != null) {
      _memoryFallback!.remove(cacheFileName);
      return;
    }
    final file = await _getCacheFile();
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}
