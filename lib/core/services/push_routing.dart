/// Turns a notification's `href` (written for the web app) into an app route.
///
/// Only internal paths are followed. Web-only pages (merchant tools, admin)
/// and anything unexpected open the in-app notification inbox instead.
String appRouteForPushHref(String? href) {
  const fallback = '/notifications';
  final raw = href?.trim();
  if (raw == null ||
      raw.isEmpty ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      raw.contains('\\') ||
      raw.length > 500) {
    return fallback;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return fallback;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return '/dashboard';

  // The web shows a destination at /spots/<slug>; the app at /explore/<slug>.
  if (segments.first == 'spots' && segments.length >= 2) {
    return '/explore/${Uri.encodeComponent(segments[1])}';
  }
  // QA 2026-11-17: funding and follower notifications opened the inbox.
  // Web /funding?quest_id=<id> is the app's /quests/<id>/funding.
  if (segments.first == 'funding') {
    final questId = uri.queryParameters['quest_id'];
    if (questId != null && questId.isNotEmpty) {
      return '/quests/${Uri.encodeComponent(questId)}/funding';
    }
    return fallback;
  }
  // Web /users/<@handle or id> is the app's /profile/<handle>.
  if (segments.first == 'users' && segments.length >= 2) {
    return '/profile/${Uri.encodeComponent(segments[1])}';
  }
  const appSections = {
    'dashboard',
    'explore',
    'map',
    'quests',
    'choice',
    'plaza',
    'profile',
    'notifications',
    'saved',
    'history',
    'shop',
    'vote',
    'trail',
    'settings',
  };
  if (!appSections.contains(segments.first)) return fallback;
  return uri.replace(query: uri.query.isEmpty ? null : uri.query).toString();
}
