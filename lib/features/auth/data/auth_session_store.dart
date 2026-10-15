import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredAuthSession {
  final String token;
  final Map<String, dynamic> user;

  const StoredAuthSession({required this.token, required this.user});
}

abstract interface class AuthSessionStore {
  Future<StoredAuthSession?> read();
  Future<void> write(StoredAuthSession session);
  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  static const _sessionKey = 'jdq.auth.session.v1';

  final FlutterSecureStorage _storage;

  SecureAuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<StoredAuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await clear();
      return null;
    }
    if (decoded is! Map ||
        decoded['token'] is! String ||
        decoded['user'] is! Map) {
      await clear();
      return null;
    }

    final token = (decoded['token'] as String).trim();
    if (token.isEmpty) {
      await clear();
      return null;
    }
    return StoredAuthSession(
      token: token,
      user: Map<String, dynamic>.from(decoded['user'] as Map),
    );
  }

  @override
  Future<void> write(StoredAuthSession session) => _storage.write(
        key: _sessionKey,
        value: jsonEncode({'token': session.token, 'user': session.user}),
      );

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
