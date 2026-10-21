import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

const mapSiteOrigin = 'https://juanderquest.app';

String validateMapOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException(
        'Enter a site origin, e.g. http://127.0.0.1:3120');
  }
  return value.trim().replaceFirst(RegExp(r'/$'), '');
}

/// URI resolution encodes MapLibre template braces. Keep these strings literal.
Map<String, dynamic> absolutizeStyle(
    Map<String, dynamic> input, String origin) {
  origin = validateMapOrigin(origin);
  final style = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  String absolute(String value) => value.startsWith('//')
      ? '${Uri.parse(origin).scheme}:$value'
      : value.startsWith('/')
          ? '$origin$value'
          : value;
  for (final source in (style['sources'] as Map).values) {
    if (source is! Map) continue;
    if (source['tiles'] is List) {
      source['tiles'] = [
        for (final tile in source['tiles']) absolute(tile as String)
      ];
    }
    if (source['url'] is String) source['url'] = absolute(source['url']);
  }
  for (final key in ['glyphs', 'sprite']) {
    if (style[key] is String) style[key] = absolute(style[key]);
  }
  if (style['version'] != 8 || style['layers'] is! List) {
    throw const FormatException('Invalid vector style');
  }
  return style;
}

abstract final class MapOriginStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'jdq_debug_map_site_origin_v1';
  static Future<String> read() async {
    if (!kDebugMode) return mapSiteOrigin;
    try {
      final value = await _storage.read(key: _key);
      return value == null ? mapSiteOrigin : validateMapOrigin(value);
    } catch (_) {
      return mapSiteOrigin;
    }
  }

  static Future<void> write(String value) async {
    if (kDebugMode)
      await _storage.write(key: _key, value: validateMapOrigin(value));
  }

  static Future<void> clear() async {
    if (kDebugMode) await _storage.delete(key: _key);
  }
}

/// Separate unauthenticated client: never send the API session to a map host.
class StyleLoader {
  StyleLoader({Dio? client, Future<Directory> Function()? directory})
      : _client = client ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4))),
        _directory = directory ?? getApplicationSupportDirectory;
  final Dio _client;
  final Future<Directory> Function() _directory;
  Future<String> load(String origin) async {
    origin = validateMapOrigin(origin);
    final name = sha256.convert(utf8.encode(origin));
    File? cache;
    try {
      cache = File('${(await _directory()).path}/map-style-$name.json');
    } catch (_) {/* Storage unavailable: network still works. */}
    try {
      final response = await _client.get<Object>('$origin/map/style.json');
      final raw = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final result = jsonEncode(
          absolutizeStyle(Map<String, dynamic>.from(raw as Map), origin));
      if (cache != null) {
        try {
          await cache.parent.create(recursive: true);
          // A complete write + rename prevents a killed write corrupting last-good.
          final temp = File('${cache.path}.tmp');
          await temp.writeAsString(result, flush: true);
          await temp.rename(cache.path);
        } catch (_) {/* Cache failure must not hide a valid network style. */}
      }
      return result;
    } catch (_) {
      if (cache != null && await cache.exists()) {
        final raw =
            jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
        return jsonEncode(absolutizeStyle(raw, origin));
      }
      rethrow;
    }
  }
}
