class ChoiceCampaign {
  const ChoiceCampaign({required this.id, required this.theme, required this.region,
    required this.status, required this.opensAt, required this.closesAt});
  final String id, theme, region, status;
  final DateTime opensAt, closesAt;

  factory ChoiceCampaign.fromJson(Map<String, dynamic> json) => ChoiceCampaign(
    id: json['id'] as String, theme: json['theme'] as String,
    region: json['region'] as String, status: json['status'] as String,
    opensAt: DateTime.parse(json['opens_at'] as String),
    closesAt: DateTime.parse(json['closes_at'] as String));

  bool get isOpen => (status == 'voting' || status == 'scheduled') && DateTime.now().isBefore(closesAt) &&
      !DateTime.now().isBefore(opensAt);
}

class ChoiceOverview {
  const ChoiceOverview({required this.current, required this.nextOpensAt,
    required this.nextClosesAt, required this.nextTheme, required this.previous,
    required this.notice, required this.votingEnabled, this.serverTime, this.receivedAt,
    this.monotonicClock});
  final ChoiceCampaign? current;
  final DateTime? nextOpensAt, nextClosesAt;
  final String? nextTheme, notice;
  final ChoicePreviousResult? previous;
  final bool votingEnabled;
  final DateTime? serverTime, receivedAt;
  final Stopwatch? monotonicClock;

  // Server time is the display gate. The API still enforces the deadline on write.
  bool isCampaignOpen(ChoiceCampaign campaign) {
    if (!votingEnabled || serverTime == null || receivedAt == null) return false;
    final serverNow = serverTime!.add(monotonicClock?.elapsed ?? DateTime.now().difference(receivedAt!));
    return (campaign.status == 'voting' || campaign.status == 'scheduled') &&
        !serverNow.isBefore(campaign.opensAt) && serverNow.isBefore(campaign.closesAt);
  }

  factory ChoiceOverview.fromJson(Map<String, dynamic> json) {
    final next = (json['next'] as Map?)?.cast<String, dynamic>();
    final availability = (json['availability'] as Map?)?.cast<String, dynamic>() ?? const {};
    final notice = (json['notice'] as Map?)?.cast<String, dynamic>();
    final current = (json['current'] as Map?)?.cast<String, dynamic>();
    final previous = (json['previous'] as Map?)?.cast<String, dynamic>();
    return ChoiceOverview(
      current: current == null ? null : ChoiceCampaign.fromJson(current),
      nextOpensAt: next?['opens_at'] == null ? null : DateTime.parse(next!['opens_at'] as String),
      nextClosesAt: next?['closes_at'] == null ? null : DateTime.parse(next!['closes_at'] as String),
      nextTheme: next?['theme'] as String?,
      previous: previous == null ? null : ChoicePreviousResult.fromJson(previous),
      notice: notice?['message'] as String?,
      votingEnabled: availability['voting_enabled'] == true,
      serverTime: json['server_time'] == null ? null : DateTime.parse(json['server_time'] as String),
      receivedAt: DateTime.now(),
      monotonicClock: Stopwatch()..start(),
    );
  }
}

class ChoicePreviousResult {
  const ChoicePreviousResult({required this.periodLabel, required this.validBallots,
    required this.coWinnerIds, required this.standings});
  final String periodLabel;
  final int validBallots;
  final Set<String> coWinnerIds;
  final List<ChoiceStanding> standings;
  factory ChoicePreviousResult.fromJson(Map<String, dynamic> json) => ChoicePreviousResult(
    periodLabel: json['period_label'] as String,
    validBallots: (json['valid_ballots'] as num).toInt(),
    coWinnerIds: (json['co_winner_ids'] as List<dynamic>).cast<String>().toSet(),
    standings: (json['standings'] as List<dynamic>)
        .map((item) => ChoiceStanding.fromJson((item as Map).cast<String, dynamic>())).toList(),
  );
}

class ChoiceStanding {
  const ChoiceStanding({required this.candidateId, required this.spotName, required this.votes});
  final String candidateId, spotName;
  final int votes;
  factory ChoiceStanding.fromJson(Map<String, dynamic> json) => ChoiceStanding(
    candidateId: json['candidate_id'] as String,
    spotName: (json['spot_name'] as String?) ?? 'Destination',
    votes: (json['votes'] as num).toInt());
}

class ChoiceBallot {
  const ChoiceBallot({required this.candidateId, required this.version});
  final String candidateId;
  final int version;
  factory ChoiceBallot.fromJson(Map<String, dynamic> json) => ChoiceBallot(
    candidateId: json['candidate_id'] as String,
    version: (json['version'] as num).toInt());
}

class ChoiceEligibility {
  const ChoiceEligibility({required this.eligible, required this.reason,
    required this.eligibleAt, required this.canVoteNow});
  final bool eligible, canVoteNow;
  final String? reason;
  final DateTime? eligibleAt;

  static ChoiceEligibility? fromOwnerJson(Map<String, dynamic> json) {
    final raw = json['eligibility'];
    final serverTime = DateTime.tryParse(json['server_time']?.toString() ?? '');
    if (raw is! Map || raw['eligible'] is! bool || json['can_vote_now'] is! bool || serverTime == null) {
      return null; // Older or incomplete API responses cannot authorize voting.
    }
    final eligibleAt = DateTime.tryParse(raw['eligible_at']?.toString() ?? '');
    return ChoiceEligibility(
      eligible: raw['eligible'] as bool,
      reason: raw['reason'] as String?,
      eligibleAt: eligibleAt,
      canVoteNow: raw['eligible'] == true && json['can_vote_now'] == true,
    );
  }
}

class ChoiceDetail {
  const ChoiceDetail({required this.campaign, required this.standings, required this.ballot,
    this.eligibility});
  final ChoiceCampaign campaign;
  final List<ChoiceStanding> standings;
  final ChoiceBallot? ballot;
  final ChoiceEligibility? eligibility;
}

class ChoiceSpotlight {
  const ChoiceSpotlight({required this.campaignId, required this.theme,
    required this.expiresAt, required this.winnerSpotIds});
  final String campaignId, theme;
  final DateTime expiresAt;
  final Set<String> winnerSpotIds;
  bool get isActive => DateTime.now().isBefore(expiresAt) && winnerSpotIds.isNotEmpty;

  factory ChoiceSpotlight.fromJson(Map<String, dynamic> json) => ChoiceSpotlight(
    campaignId: json['campaign_id'] as String,
    theme: json['theme'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    winnerSpotIds: (json['winners'] as List<dynamic>)
        .map((winner) => (winner as Map<String, dynamic>)['spot_id'] as String).toSet());
}

({List<T> ordinary, List<T> winners}) planChoiceSpotlight<T>(
    List<T> items, String Function(T) idOf, ChoiceSpotlight? spotlight) {
  if (spotlight == null || !spotlight.isActive) {
    return (ordinary: List<T>.of(items), winners: <T>[]);
  }
  return (
    ordinary: items.where((item) => !spotlight.winnerSpotIds.contains(idOf(item))).toList(),
    winners: items.where((item) => spotlight.winnerSpotIds.contains(idOf(item))).toList(),
  );
}

class ChoiceSupporterQuest {
  const ChoiceSupporterQuest({required this.campaignId,required this.questId,
    required this.spotName,required this.questTitle,required this.questDescription,
    required this.expiresAt,required this.explorerXp,required this.claimed});
  final String campaignId,questId,spotName,questTitle,questDescription;
  final DateTime expiresAt;
  final int explorerXp;
  final bool claimed;
  factory ChoiceSupporterQuest.fromJson(Map<String,dynamic> json)=>ChoiceSupporterQuest(
    campaignId:json['campaign_id'] as String,questId:json['quest_id'] as String,
    spotName:json['spot_name'] as String,questTitle:json['quest_title'] as String,
    questDescription:json['quest_description'] as String,
    expiresAt:DateTime.parse(json['expires_at'] as String),
    explorerXp:(json['explorer_xp'] as num).toInt(),claimed:json['claimed']==true);
}

class ChoiceEngagementSummary {
  const ChoiceEngagementSummary({required this.currentStreak, required this.longestStreak,
    required this.nextMilestone, required this.verifiedVisits, required this.uniqueDestinations,
    required this.municipalities, required this.participations, required this.challenges});
  final int currentStreak, longestStreak, verifiedVisits, uniqueDestinations, municipalities, participations;
  final int? nextMilestone;
  final List<ChoiceChallenge> challenges;

  factory ChoiceEngagementSummary.fromJson(Map<String, dynamic> json) {
    final streak = (json['streak'] as Map?)?.cast<String, dynamic>() ?? const {};
    final impact = (json['impact'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rows = (json['challenges'] as List?) ?? const [];
    return ChoiceEngagementSummary(
      currentStreak: (streak['current'] as num?)?.toInt() ?? 0,
      longestStreak: (streak['longest'] as num?)?.toInt() ?? 0,
      nextMilestone: (streak['next_milestone'] as num?)?.toInt(),
      verifiedVisits: (impact['verified_visits'] as num?)?.toInt() ?? 0,
      uniqueDestinations: (impact['unique_destinations'] as num?)?.toInt() ?? 0,
      municipalities: (impact['municipalities'] as num?)?.toInt() ?? 0,
      participations: (impact['finalized_participations'] as num?)?.toInt() ?? 0,
      challenges: rows.whereType<Map>().map((row) => ChoiceChallenge.fromJson(row.cast<String, dynamic>())).toList(),
    );
  }
}

class ChoiceChallenge {
  const ChoiceChallenge({required this.title, required this.progress, required this.target, required this.complete});
  final String title;
  final int progress, target;
  final bool complete;
  factory ChoiceChallenge.fromJson(Map<String, dynamic> json) => ChoiceChallenge(
    title: json['title'] as String? ?? 'Community challenge',
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    target: (json['target'] as num?)?.toInt() ?? 1,
    complete: json['complete'] == true,
  );
}
