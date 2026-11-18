/// Plan 107 — Suki Card models (customer side of merchant loyalty cards).
library;

/// Postgres BIGINT/NUMERIC can arrive as strings: accept num or a parsable string.
num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
int _int(Object? v, [int fallback = 0]) => _num(v)?.toInt() ?? fallback;
double? _double(Object? v) => _num(v)?.toDouble();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');
String? _str(Object? v) => v == null ? null : '$v';
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

/// The tag on the reward slot: FREE / 10% OFF / ₱20 OFF / PROMO.
String sukiRewardTag(String kind, double? value) {
  final amount = value == null
      ? ''
      : (value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString());
  return switch (kind) {
    'percent_off' => '$amount% OFF',
    'amount_off' => '₱$amount OFF',
    'promo' => 'PROMO',
    _ => 'FREE',
  };
}

class SukiMerchant {
  const SukiMerchant({
    required this.id,
    required this.name,
    this.municipality,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? municipality;
  final String? logoUrl;

  factory SukiMerchant.fromJson(Map<String, dynamic> j) => SukiMerchant(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'Shop'}',
        municipality: _str(j['municipality']),
        logoUrl: _str(j['logo_url']),
      );
}

class SukiProgram {
  const SukiProgram({
    required this.id,
    required this.title,
    required this.rewardKind,
    required this.rewardText,
    required this.rewardTag,
    required this.visitsRequired,
    required this.mode,
    required this.status,
    required this.merchant,
    this.rewardValue,
    this.distanceM,
  });

  final String id;
  final String title;
  final String rewardKind; // free_item | percent_off | amount_off | promo
  final double? rewardValue;
  final String rewardText;
  final String rewardTag;
  final int visitsRequired;
  final String mode; // standee | staff_scan
  final String status;
  final SukiMerchant merchant;
  final int? distanceM;

  bool get staffScan => mode == 'staff_scan';

  factory SukiProgram.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    final value = _double(j['reward_value']);
    return SukiProgram(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Suki Card'}',
      rewardKind: kind,
      rewardValue: value,
      rewardText: '${j['reward_text'] ?? ''}',
      rewardTag: _str(j['reward_tag']) ?? sukiRewardTag(kind, value),
      visitsRequired: _int(j['visits_required'], 10),
      mode: '${j['mode'] ?? 'standee'}',
      status: '${j['status'] ?? 'active'}',
      merchant: SukiMerchant.fromJson(_map(j['merchant'])),
      distanceM: _num(j['distance_m'])?.round(),
    );
  }
}

class SukiReward {
  const SukiReward({
    required this.id,
    required this.code,
    required this.rewardText,
    required this.rewardTag,
    required this.status,
    required this.expiresAt,
    required this.expired,
  });

  final String id;
  final String code;
  final String rewardText;
  final String rewardTag;
  final String status; // issued | claimed
  final DateTime? expiresAt;
  final bool expired;

  bool get claimable => status == 'issued' && !expired && code.isNotEmpty;

  factory SukiReward.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    return SukiReward(
      id: '${j['id'] ?? ''}',
      code: '${j['code'] ?? ''}',
      rewardText: '${j['reward_text'] ?? ''}',
      rewardTag: _str(j['reward_tag']) ??
          sukiRewardTag(kind, _double(j['reward_value'])),
      status: '${j['status'] ?? 'issued'}',
      expiresAt: _date(j['expires_at']),
      expired: j['expired'] == true,
    );
  }
}

/// Progress on one card. [visits] counts toward [required] in this cycle.
class SukiCardProgress {
  const SukiCardProgress({
    required this.cardId,
    required this.cycle,
    required this.visits,
    required this.required,
    required this.totalVisits,
    required this.visitedToday,
  });

  final String cardId;
  final int cycle;
  final int visits;
  final int required;
  final int totalVisits;
  final bool visitedToday;

  int get remaining => (required - visits).clamp(0, required);

  factory SukiCardProgress.fromJson(Map<String, dynamic> j) => SukiCardProgress(
        cardId: '${j['card_id'] ?? ''}',
        cycle: _int(j['cycle'], 1),
        visits: _int(j['visits']),
        required: _int(j['required'], 10),
        totalVisits: _int(j['total_visits']),
        visitedToday: j['visited_today'] == true,
      );
}

List<SukiReward> _rewards(Map<String, dynamic> j) => [
      for (final r in (j['rewards'] is List ? j['rewards'] as List : const []))
        if (r is Map) SukiReward.fromJson(_map(r)),
      // §6.4 also allows a single `reward`.
      if (j['rewards'] is! List && j['reward'] is Map)
        SukiReward.fromJson(_map(j['reward'])),
    ];

/// A card in "my cards": progress, its program and open rewards.
class SukiCard {
  const SukiCard({
    required this.progress,
    required this.program,
    this.rewards = const [],
  });

  final SukiCardProgress progress;
  final SukiProgram program;
  final List<SukiReward> rewards;

  factory SukiCard.fromJson(Map<String, dynamic> j) => SukiCard(
        progress: SukiCardProgress.fromJson(j),
        program: SukiProgram.fromJson(_map(j['program'])),
        rewards: _rewards(j),
      );
}

/// One program page (`GET /suki/programs/:id`): the program, my card, rewards.
class SukiProgramDetail {
  const SukiProgramDetail({
    required this.program,
    this.card,
    this.rewards = const [],
  });

  final SukiProgram program;
  final SukiCardProgress? card;
  final List<SukiReward> rewards;

  factory SukiProgramDetail.fromJson(Map<String, dynamic> j) =>
      SukiProgramDetail(
        program: SukiProgram.fromJson(_map(j['program'])),
        card: j['my_card'] is Map
            ? SukiCardProgress.fromJson(_map(j['my_card']))
            : null,
        rewards: _rewards(j),
      );
}

class SukiVisitResult {
  const SukiVisitResult({
    required this.program,
    required this.card,
    required this.replayed,
    required this.xpAwarded,
    required this.badges,
    required this.missionCompleted,
    this.rewardIssued,
  });

  final SukiProgram program;
  final SukiCardProgress card;
  final bool replayed;
  final int xpAwarded;
  final List<String> badges;
  final bool missionCompleted;
  final SukiReward? rewardIssued;

  /// The visit number just recorded: a completed card resets to 0.
  int get visitNumber => rewardIssued != null ? card.required : card.visits;

  factory SukiVisitResult.fromJson(Map<String, dynamic> j) => SukiVisitResult(
        program: SukiProgram.fromJson(_map(j['program'])),
        card: SukiCardProgress.fromJson(_map(j['card'])),
        replayed: j['replayed'] == true,
        xpAwarded: _int(j['xp_awarded']),
        badges: [
          for (final b in (j['badges'] is List ? j['badges'] as List : const []))
            '$b'
        ],
        missionCompleted: j['mission_completed'] == true,
        rewardIssued: j['reward_issued'] is Map
            ? SukiReward.fromJson(_map(j['reward_issued']))
            : null,
      );
}

/// A Shop voucher or sponsor perk the traveler holds (`GET /me/redemptions`).
class SukiRedemption {
  const SukiRedemption({
    required this.id,
    required this.voucherId,
    required this.code,
    required this.title,
    required this.merchantName,
    required this.createdAt,
    this.usedAt,
    this.costPoints = 0,
  });

  final String id;
  final String voucherId;
  final String code;
  final String title;
  final String merchantName;
  final DateTime? createdAt;
  final DateTime? usedAt;
  final int costPoints;

  bool get used => usedAt != null;

  factory SukiRedemption.fromJson(Map<String, dynamic> j) {
    final voucher = _map(j['voucher']);
    final merchant = _map(j['merchant']);
    return SukiRedemption(
      id: '${j['id'] ?? ''}',
      voucherId: '${voucher['id'] ?? j['voucher_id'] ?? ''}',
      code: '${j['code'] ?? ''}',
      title: '${voucher['title'] ?? j['voucher_title'] ?? 'Voucher'}',
      merchantName:
          '${merchant['name'] ?? j['merchant_name'] ?? 'Partner Merchant'}',
      createdAt: _date(j['created_at']),
      usedAt: _date(j['used_at']),
      costPoints: _int(j['cost_points']),
    );
  }
}
