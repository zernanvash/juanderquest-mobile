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
