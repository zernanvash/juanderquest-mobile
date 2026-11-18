/// Plan 107 — what the customer's Suki scanner accepts.
/// (The merchant counter scanner has its own parser under features/merchant.)
library;

/// A printed Suki standee: `https://juanderquest.app/suki/<id>?v=<n>&s=<sig>`.
/// Returns the full URL (the server checks the signature), or null.
String? extractSukiStandee(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty || text.length > 400) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host != 'juanderquest.app') {
    return null;
  }
  if (uri.pathSegments.length != 2 ||
      uri.pathSegments.first != 'suki' ||
      uri.pathSegments[1].isEmpty) {
    return null;
  }
  final v = int.tryParse(uri.queryParameters['v'] ?? '');
  final s = uri.queryParameters['s'] ?? '';
  if (v == null || v < 1 || !RegExp(r'^[0-9a-f]{16}$').hasMatch(s)) {
    return null;
  }
  return text;
}

/// The program id inside a standee URL, for opening its card page.
String? sukiProgramIdFromStandee(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.pathSegments.length == 2
      ? uri.pathSegments[1]
      : null;
}
