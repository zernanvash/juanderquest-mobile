class ActivityItemModel {
  final String id;
  final String verb;
  final String actorName;
  final String? actorHandle;
  final String? actorAvatar;
  final bool isFollowing;
  final String subjectType;
  final String subjectTitle;
  final String? subjectHref;
  final String? municipality;
  final Map<String, dynamic> payload;
  final String reason;
  final int cheerCount;
  final bool cheeredByMe;
  final int commentCount;
  final bool canHide;
  final DateTime createdAt;

  const ActivityItemModel({
    required this.id,
    required this.verb,
    required this.actorName,
    this.actorHandle,
    this.actorAvatar,
    this.isFollowing = false,
    required this.subjectType,
    required this.subjectTitle,
    this.subjectHref,
    this.municipality,
    this.payload = const {},
    required this.reason,
    required this.cheerCount,
    required this.cheeredByMe,
    required this.commentCount,
    this.canHide = false,
    required this.createdAt,
  });

  factory ActivityItemModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>? ?? {};
    final subject = json['subject'] as Map<String, dynamic>? ?? {};

    return ActivityItemModel(
      id: json['id'] as String? ?? '',
      verb: json['verb'] as String? ?? 'quest_completed',
      actorName: actor['display_name'] as String? ?? 'An explorer',
      actorHandle: actor['handle'] as String?,
      actorAvatar: actor['avatar_url'] as String?,
      isFollowing: actor['is_following'] as bool? ?? false,
      subjectType: subject['type'] as String? ?? 'quest',
      subjectTitle: subject['title'] as String? ?? '',
      subjectHref: subject['href'] as String?,
      municipality: json['municipality'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      reason: json['reason'] as String? ?? 'nearby',
      cheerCount: json['cheer_count'] as int? ?? 0,
      cheeredByMe: json['cheered_by_me'] as bool? ?? false,
      commentCount: json['comment_count'] as int? ?? 0,
      canHide: json['can_hide'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ActivityItemModel copyWith({
    bool? cheeredByMe,
    int? cheerCount,
    int? commentCount,
  }) {
    return ActivityItemModel(
      id: id,
      verb: verb,
      actorName: actorName,
      actorHandle: actorHandle,
      actorAvatar: actorAvatar,
      isFollowing: isFollowing,
      subjectType: subjectType,
      subjectTitle: subjectTitle,
      subjectHref: subjectHref,
      municipality: municipality,
      payload: payload,
      reason: reason,
      cheerCount: cheerCount ?? this.cheerCount,
      cheeredByMe: cheeredByMe ?? this.cheeredByMe,
      commentCount: commentCount ?? this.commentCount,
      canHide: canHide,
      createdAt: createdAt,
    );
  }
}

class StandingEntryModel {
  final int rank;
  final String? userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final int score;
  final int quests;
  final String? homeTown;
  final int? delta;
  final bool isSelf;
  final bool isFollowing;

  const StandingEntryModel({
    required this.rank,
    this.userId,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    required this.score,
    required this.quests,
    this.homeTown,
    this.delta,
    this.isSelf = false,
    this.isFollowing = false,
  });

  factory StandingEntryModel.fromJson(Map<String, dynamic> json) {
    return StandingEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String? ?? 'Explorer',
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      score: json['score'] as int? ?? 0,
      quests: json['quests'] as int? ?? 0,
      homeTown: json['home_town'] as String?,
      delta: json['delta'] as int?,
      isSelf: json['is_self'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }
}
