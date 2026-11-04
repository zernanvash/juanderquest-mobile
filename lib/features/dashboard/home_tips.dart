import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/providers/auth_provider.dart';

/// Whether this traveler has seen the first-run tutorial on Home.
abstract interface class HomeTipsStore {
  Future<bool> seen();

  Future<void> markSeen();

  Future<void> reset();
}

/// This phone's own flag.
class SecureHomeTipsStore implements HomeTipsStore {
  const SecureHomeTipsStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'pixel_home_tips_seen_v1';

  @override
  Future<bool> seen() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      return;
    }
  }
}

/// Owner 2026-11-04: the tutorial shows once. "Seen" is kept on the account
/// (server, migration 079), so clearing app data or a new phone doesn't bring
/// it back, and on this phone, so a second account here doesn't get it either.
class AccountHomeTipsStore implements HomeTipsStore {
  AccountHomeTipsStore(this._local, this._dio);

  static const tutorialKey = 'home_first_run';

  final HomeTipsStore _local;
  final Dio _dio;

  @override
  Future<bool> seen() async {
    if (await _local.seen()) return true;
    try {
      final res = await _dio.get('/me/tutorials');
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final seen = data is Map ? data['seen'] : null;
      if (seen is Map && seen[tutorialKey] != null) {
        await _local.markSeen();
        return true;
      }
      return false;
    } catch (_) {
      // Offline or server trouble: don't show it now; ask again next time.
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    await _local.markSeen();
    try {
      await _dio.post('/me/tutorials/$tutorialKey/seen');
    } catch (_) {
      // The phone flag still holds; the account is marked on a later finish.
    }
  }

  /// Developer replay: clears only this phone's flag.
  @override
  Future<void> reset() => _local.reset();
}

final homeTipsStoreProvider = Provider<HomeTipsStore>(
  (ref) => AccountHomeTipsStore(
    const SecureHomeTipsStore(),
    ref.read(apiClientProvider).dio,
  ),
);

/// The Home widgets the tutorial points at.
class HomeTipsKeys {
  final GlobalKey hero = GlobalKey();
  final GlobalKey nextStop = GlobalKey();
  final GlobalKey hotbar = GlobalKey();
}

final homeTipsKeysProvider = Provider<HomeTipsKeys>((ref) => HomeTipsKeys());

class HomeTipsState {
  const HomeTipsState({this.showing = false});

  final bool showing;
}

class HomeTipsController extends StateNotifier<HomeTipsState> {
  HomeTipsController(this._store) : super(const HomeTipsState());

  final HomeTipsStore _store;
  bool _completed = false;
  bool _checking = false;

  Future<void> maybeStart() async {
    if (state.showing || _completed || _checking) return;
    _checking = true;
    final seen = await _store.seen();
    _checking = false;
    if (!mounted || seen) {
      if (seen) _completed = true;
      return;
    }
    state = const HomeTipsState(showing: true);
  }

  void skip() => finish();

  Future<void> finish() async {
    if (_completed) return;
    _completed = true;
    state = const HomeTipsState();
    await _store.markSeen();
  }

  Future<void> resetForReplay() async {
    _completed = false;
    await _store.reset();
    if (!mounted) return;
    state = const HomeTipsState(showing: true);
  }
}

final homeTipsControllerProvider =
    StateNotifierProvider<HomeTipsController, HomeTipsState>(
  (ref) => HomeTipsController(ref.watch(homeTipsStoreProvider)),
);
