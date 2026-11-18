import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owner 2026-11-18 (v0.3.3): Explore search shows "previous searched texts".
/// The last [max] searches, newest first, kept on the phone only.
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier({bool load = true}) : super(const []) {
    if (load) _load();
  }

  static const max = 8;
  static const _storage = FlutterSecureStorage();
  static const _key = 'jdq_recent_searches_v1';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || !mounted) return;
      final list = (jsonDecode(raw) as List).whereType<String>().toList();
      // Keep anything added while loading on top.
      state = [...state, ...list.where((q) => !state.contains(q))]
          .take(max)
          .toList();
    } catch (_) {
      // No history on storage failures.
    }
  }

  Future<void> _save() async {
    try {
      await _storage.write(key: _key, value: jsonEncode(state));
    } catch (_) {
      // The list still works for this session.
    }
  }

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [
      q,
      ...state.where((s) => s.toLowerCase() != q.toLowerCase()),
    ].take(max).toList();
    _save();
  }

  void remove(String query) {
    state = state.where((s) => s != query).toList();
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
        (ref) => RecentSearchesNotifier());
