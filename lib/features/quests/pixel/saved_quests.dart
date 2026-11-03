import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SavedQuestsStorage {
  Future<List<String>> read();

  Future<void> write(List<String> ids);
}

class SecureSavedQuestsStorage implements SavedQuestsStorage {
  const SecureSavedQuestsStorage();

  static const _storage = FlutterSecureStorage();
  static const _key = 'saved_quests_v1';

  @override
  Future<List<String>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<String> ids) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(ids));
    } catch (_) {
      return;
    }
  }
}

final savedQuestsStorageProvider = Provider<SavedQuestsStorage>(
  (ref) => const SecureSavedQuestsStorage(),
);

class SavedQuestsNotifier extends StateNotifier<Set<String>> {
  SavedQuestsNotifier(this._storage) : super(<String>{}) {
    unawaited(_restore());
  }

  final SavedQuestsStorage _storage;

  Future<void> _restore() async {
    try {
      final ids = await _storage.read();
      if (mounted) state = ids.toSet();
    } catch (_) {
      return;
    }
  }

  bool toggle(String id) {
    final next = {...state};
    final saved = !next.remove(id);
    if (saved) next.add(id);
    state = next;
    unawaited(_storage.write(next.toList()));
    return saved;
  }
}

final savedQuestsProvider =
    StateNotifierProvider<SavedQuestsNotifier, Set<String>>(
  (ref) => SavedQuestsNotifier(ref.watch(savedQuestsStorageProvider)),
);
