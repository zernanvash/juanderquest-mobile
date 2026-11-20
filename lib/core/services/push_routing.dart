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
  // Web /funding?quest_id=<id>, /funding/<id>, or /economy/funding/<id>
  // -> app's /quests/<id>/funding.
  if (segments.first == 'funding') {
    final questId =
        uri.queryParameters['quest_id'] ?? (segments.length >= 2 ? segments[1] : null);
    if (questId != null && questId.isNotEmpty) {
      return '/quests/${Uri.encodeComponent(questId)}/funding';
    }
    return fallback;
  }
  if (segments.first == 'economy' &&
      segments.length >= 2 &&
      segments[1] == 'funding') {
    final questId =
        uri.queryParameters['quest_id'] ?? (segments.length >= 3 ? segments[2] : null);
    if (questId != null && questId.isNotEmpty) {
      return '/quests/${Uri.encodeComponent(questId)}/funding';
    }
    return fallback;
  }
  // Web /users/<@handle or id> is the app's /profile/<handle>.
  if (segments.first == 'users' && segments.length >= 2) {
    return '/profile/${Uri.encodeComponent(segments[1])}';
  }
  // Web /plaza/<activityId> -> app's /plaza?activity=<activityId>.
  if (segments.first == 'plaza' &&
      segments.length >= 2 &&
      segments[1] != 'people') {
    final params = Map<String, String>.from(uri.queryParameters)
      ..['activity'] = segments[1];
    return Uri(path: '/plaza', queryParameters: params).toString();
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
    'suki', // Plan 107: a Suki reward notification opens the card.
    'merchants',
    'recap',
    'leaderboard',
  };
  if (!appSections.contains(segments.first)) return fallback;
  return uri.replace(query: uri.query.isEmpty ? null : uri.query).toString();
}

/// Resolves the app route for a push notification or in-app notification item.
///
/// Uses [href] first, then falls back to [kind] + [data] identifiers.
/// Returns `'/notifications'` when no target can be determined (never Home).
String appRouteForNotification({
  String? href,
  String? kind,
  Map<String, dynamic>? data,
}) {
  const fallback = '/notifications';
  final fromHref = appRouteForPushHref(href);
  if (fromHref != fallback) return fromHref;

  final k = kind?.trim().toLowerCase();
  if (k == null || k.isEmpty) return fallback;

  String? pick(List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final v = data[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  final questId = pick(const ['quest_id', 'questId']);
  final spotSlug = pick(const ['spot_slug', 'spotSlug', 'slug']);
  final activityId = pick(const ['activity_id', 'activityId', 'post_id', 'postId']);
  final programId = pick(const ['program_id', 'programId', 'suki_id', 'sukiId']);
  final merchantId = pick(const ['merchant_id', 'merchantId']);
  final campaignId = pick(const ['campaign_id', 'campaignId']);
  final handle = pick(const [
    'handle',
    'username',
    'actor_handle',
    'actorHandle',
    'user_id',
    'userId',
  ]);

  switch (k) {
    case 'quest_funding':
    case 'sponsorship':
      if (questId != null) {
        return '/quests/${Uri.encodeComponent(questId)}/funding';
      }
      if (campaignId != null) {
        return '/quests/campaigns/${Uri.encodeComponent(campaignId)}';
      }
      if (merchantId != null) {
        return '/merchants/${Uri.encodeComponent(merchantId)}';
      }
      return '/quests';
    case 'quest_reward':
    case 'nearby_quest':
    case 'chain_alert':
      if (questId != null) {
        return '/quests/${Uri.encodeComponent(questId)}';
      }
      return '/quests';
    case 'nearby_quiz':
      if (spotSlug != null) {
        return '/explore/${Uri.encodeComponent(spotSlug)}';
      }
      if (questId != null) {
        return '/quests/${Uri.encodeComponent(questId)}';
      }
      return '/explore';
    case 'follow':
      if (handle != null) {
        return '/profile/${Uri.encodeComponent(handle)}';
      }
      return '/plaza/people';
    case 'cheer':
      if (activityId != null) {
        return '/plaza?activity=${Uri.encodeComponent(activityId)}';
      }
      return '/plaza';
    case 'comment':
      if (activityId != null) {
        return '/plaza?activity=${Uri.encodeComponent(activityId)}&comments=1';
      }
      return '/plaza';
    case 'overtaken':
      if (questId != null) {
        return '/quests/${Uri.encodeComponent(questId)}';
      }
      return '/leaderboard';
    case 'weekly_recap':
      return '/recap';
    case 'weekly_champion':
      return '/leaderboard';
    case 'spot_photo_approved':
    case 'spot_moderation':
      if (spotSlug != null) {
        return '/explore/${Uri.encodeComponent(spotSlug)}';
      }
      return '/explore';
    case 'suki_reward':
      if (programId != null) {
        return '/suki/${Uri.encodeComponent(programId)}';
      }
      return '/suki';
    default:
      return fallback;
  }
}
