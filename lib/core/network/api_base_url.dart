import 'package:flutter/foundation.dart';

/// Normalizes an API base URL so both `https://api.juanderquest.app` and
/// `https://juanderquest.app` resolve to a canonical `/api/v1` endpoint.
String normalizeApiBaseUrl(String url) {
  var trimmed = url.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (!trimmed.endsWith('/api/v1')) {
    trimmed = '$trimmed/api/v1';
  }
  return trimmed;
}

const String productionApiBaseUrl = 'https://api.juanderquest.app/api/v1';

/// Debug and profile builds talk to a local preview API (reach it over USB
/// with `adb reverse tcp:<port> tcp:<port>`), never to production by accident.
const String localApiBaseUrl = 'http://127.0.0.1:4100/api/v1';

const String _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// `--dart-define=API_BASE_URL=...` wins; otherwise release builds use
/// production and every other build uses the local preview API.
String defaultApiBaseUrl({String defined = _definedApiBaseUrl, bool release = kReleaseMode}) {
  if (defined.trim().isNotEmpty) return defined.trim();
  return release ? productionApiBaseUrl : localApiBaseUrl;
}
