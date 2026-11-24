/// Plan 107 / Plan 111 — Suki Card models (customer side of merchant loyalty cards).
library;

/// Postgres BIGINT/NUMERIC can arrive as strings: accept num or a parsable string.
num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
int _int(Object? v, [int fallback = 0]) => _num(v)?.toInt() ?? fallback;
double? _double(Object? v) => _num(v)?.toDouble();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');
String? _str(Object? v) => v == null ? null : '$v';
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
List<Map<String, dynamic>> _rows(Object? v) => [
      for (final r in (v is List ? v : const []))
        if (r is Map) Map<String, dynamic>.from(r),
    ];

const sukiIconKeys = [
  'gift',
  'coffee',
  'meal',
  'snack',
  'dessert',
  'drink',
  'discount',
  'promo',
];

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

class SukiHolder {
  const SukiHolder({
    required this.displayName,
    this.handle,
    this.memberSince,
  });

  final String displayName;
  final String? handle;
  final DateTime? memberSince;

  factory SukiHolder.fromJson(Map<String, dynamic> j) => SukiHolder(
        displayName: '${j['display_name'] ?? 'Traveler'}',
        handle: _str(j['handle']),
        memberSince: _date(j['member_since']),
      );
}

class SukiTier {
  const SukiTier({
    required this.visitNumber,
    required this.rewardKind,
    required this.rewardText,
    required this.rewardTag,
    this.rewardValue,
    this.iconKey = 'gift',
    this.state = 'locked',
  });

  final int visitNumber;
  final String rewardKind;
  final double? rewardValue;
  final String rewardText;
  final String rewardTag;
  final String iconKey;
  final String state; // locked | issued | claimed

  bool get unlocked => state == 'issued' || state == 'claimed';
  bool get claimed => state == 'claimed';

  factory SukiTier.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    final value = _double(j['reward_value']);
    return SukiTier(
      visitNumber: _int(j['visit_number'], 10),
      rewardKind: kind,
      rewardValue: value,
      rewardText: '${j['reward_text'] ?? ''}',
      rewardTag: _str(j['reward_tag']) ?? sukiRewardTag(kind, value),
      iconKey: '${j['icon_key'] ?? 'gift'}',
      state: '${j['state'] ?? 'locked'}',
    );
  }
}

class SukiPointsState {
  const SukiPointsState({
    this.enabled = false,
    this.balance = 0,
    this.lifetime = 0,
    this.perVisit = 0,
    this.pesosPerPoint,
    this.maxPerVisit = 200,
  });

  final bool enabled;
  final int balance;
  final int lifetime;
  final int perVisit;
  final double? pesosPerPoint;
  final int maxPerVisit;

  factory SukiPointsState.fromJson(Map<String, dynamic> j) => SukiPointsState(
        enabled: j['enabled'] == true,
        balance: _int(j['balance']),
        lifetime: _int(j['lifetime']),
        perVisit: _int(j['per_visit']),
        pesosPerPoint: _double(j['pesos_per_point']),
        maxPerVisit: _int(j['max_per_visit'], 200),
      );
}

class SukiPointsMenuItem {
  const SukiPointsMenuItem({
    required this.id,
    required this.programId,
    required this.title,
    required this.pointsCost,
    this.iconKey = 'gift',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String programId;
  final String title;
  final int pointsCost;
  final String iconKey;
  final bool isActive;
  final int sortOrder;

  factory SukiPointsMenuItem.fromJson(Map<String, dynamic> j) =>
      SukiPointsMenuItem(
        id: '${j['id'] ?? ''}',
        programId: '${j['program_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        pointsCost: _int(j['points_cost']),
        iconKey: '${j['icon_key'] ?? 'gift'}',
        isActive: j['is_active'] != false,
        sortOrder: _int(j['sort_order']),
      );
}

class SukiPointsLedgerEntry {
  const SukiPointsLedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.createdAt,
    this.visitId,
    this.rewardId,
    this.amountSpent,
  });

  final String id;
  final int delta;
  final String reason; // visit | spend | redeem | expire | admin_adjust
  final DateTime? createdAt;
  final String? visitId;
  final String? rewardId;
  final double? amountSpent;

  factory SukiPointsLedgerEntry.fromJson(Map<String, dynamic> j) =>
      SukiPointsLedgerEntry(
        id: '${j['id'] ?? ''}',
        delta: _int(j['delta']),
        reason: '${j['reason'] ?? 'visit'}',
        createdAt: _date(j['created_at']),
        visitId: _str(j['visit_id']),
        rewardId: _str(j['reward_id']),
        amountSpent: _double(j['amount_spent']),
      );
}

class SukiPointsLedgerPage {
  const SukiPointsLedgerPage({
    required this.cardId,
    required this.balance,
    required this.lifetime,
    this.items = const [],
    this.nextCursor,
  });

  final String cardId;
  final int balance;
  final int lifetime;
  final List<SukiPointsLedgerEntry> items;
  final String? nextCursor;

  factory SukiPointsLedgerPage.fromJson(Map<String, dynamic> j) =>
      SukiPointsLedgerPage(
        cardId: '${j['card_id'] ?? ''}',
        balance: _int(j['balance']),
        lifetime: _int(j['lifetime']),
        items: _rows(j['items']).map(SukiPointsLedgerEntry.fromJson).toList(),
        nextCursor: _str(j['next_cursor']),
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
    this.skinKey = 'jdq_classic',
    this.tiers = const [],
    this.points = const SukiPointsState(),
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
  final String skinKey;
  final List<SukiTier> tiers;
  final SukiPointsState points;

  bool get staffScan => mode == 'staff_scan';

  List<SukiTier> get effectiveTiers => tiers.isNotEmpty
      ? tiers
      : [
          SukiTier(
            visitNumber: visitsRequired,
            rewardKind: rewardKind,
            rewardValue: rewardValue,
            rewardText: rewardText,
            rewardTag: rewardTag,
          ),
        ];

  factory SukiProgram.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    final value = _double(j['reward_value']);
    final visits = _int(j['visits_required'], 10);
    final rewardText = '${j['reward_text'] ?? ''}';
    final rewardTag = _str(j['reward_tag']) ?? sukiRewardTag(kind, value);
    final rawTiers = _rows(j['tiers']).map(SukiTier.fromJson).toList();
    return SukiProgram(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Suki Card'}',
      rewardKind: kind,
      rewardValue: value,
      rewardText: rewardText,
      rewardTag: rewardTag,
      visitsRequired: visits,
      mode: '${j['mode'] ?? 'standee'}',
      status: '${j['status'] ?? 'active'}',
      merchant: SukiMerchant.fromJson(_map(j['merchant'])),
      distanceM: _num(j['distance_m'])?.round(),
      skinKey: '${j['skin_key'] ?? 'jdq_classic'}',
      tiers: rawTiers.isNotEmpty
          ? rawTiers
          : [
              SukiTier(
                visitNumber: visits,
                rewardKind: kind,
                rewardValue: value,
                rewardText: rewardText,
                rewardTag: rewardTag,
              ),
            ],
      points: j['points'] is Map
          ? SukiPointsState.fromJson(_map(j['points']))
          : const SukiPointsState(),
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
    this.tierVisit,
    this.source = 'visits',
    this.pointsCost,
  });

  final String id;
  final String code;
  final String rewardText;
  final String rewardTag;
  final String status; // issued | claimed
  final DateTime? expiresAt;
  final bool expired;
  final int? tierVisit;
  final String source; // visits | points
  final int? pointsCost;

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
      tierVisit: j['tier_visit'] == null ? null : _int(j['tier_visit']),
      source: '${j['source'] ?? 'visits'}',
      pointsCost: j['points_cost'] == null ? null : _int(j['points_cost']),
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
    this.cardNo = '',
    this.points = const SukiPointsState(),
    this.tiers = const [],
  });

  final String cardId;
  final int cycle;
  final int visits;
  final int required;
  final int totalVisits;
  final bool visitedToday;
  final String cardNo;
  final SukiPointsState points;
  final List<SukiTier> tiers;

  int get remaining => (required - visits).clamp(0, required);

  factory SukiCardProgress.fromJson(Map<String, dynamic> j) =>
      SukiCardProgress(
        cardId: '${j['card_id'] ?? ''}',
        cycle: _int(j['cycle'], 1),
        visits: _int(j['visits']),
        required: _int(j['required'], 10),
        totalVisits: _int(j['total_visits']),
        visitedToday: j['visited_today'] == true,
        cardNo: '${j['card_no'] ?? ''}',
        points: j['points'] is Map
            ? SukiPointsState.fromJson(_map(j['points']))
            : const SukiPointsState(),
        tiers: _rows(j['tiers']).map(SukiTier.fromJson).toList(),
      );
}

List<SukiReward> _rewards(Map<String, dynamic> j) => [
      for (final r in (j['rewards'] is List ? j['rewards'] as List : const []))
        if (r is Map) SukiReward.fromJson(_map(r)),
      // §6.4 also allows a single `reward`.
      if (j['rewards'] is! List && j['reward'] is Map)
        SukiReward.fromJson(_map(j['reward'])),
    ];

/// A card in "my cards": progress, its program, tier ladder, points and open rewards.
class SukiCard {
  const SukiCard({
    required this.progress,
    required this.program,
    this.rewards = const [],
    this.holder,
    this.skinKey = 'jdq_classic',
    this.tiers = const [],
    this.points = const SukiPointsState(),
    this.pointsMenu = const [],
  });

  final SukiCardProgress progress;
  final SukiProgram program;
  final List<SukiReward> rewards;
  final SukiHolder? holder;
  final String skinKey;
  final List<SukiTier> tiers;
  final SukiPointsState points;
  final List<SukiPointsMenuItem> pointsMenu;

  List<SukiTier> get effectiveTiers =>
      tiers.isNotEmpty ? tiers : program.effectiveTiers;

  factory SukiCard.fromJson(Map<String, dynamic> j) {
    final program = SukiProgram.fromJson(_map(j['program']));
    final progress = SukiCardProgress.fromJson(j);
    final rawTiers = _rows(j['tiers']).map(SukiTier.fromJson).toList();
    return SukiCard(
      progress: progress,
      program: program,
      rewards: _rewards(j),
      holder: j['holder'] is Map ? SukiHolder.fromJson(_map(j['holder'])) : null,
      skinKey: '${j['skin_key'] ?? program.skinKey}',
      tiers: rawTiers.isNotEmpty ? rawTiers : program.effectiveTiers,
      points: j['points'] is Map
          ? SukiPointsState.fromJson(_map(j['points']))
          : progress.points,
      pointsMenu: _rows(j['points_menu'])
          .map(SukiPointsMenuItem.fromJson)
          .toList(),
    );
  }
}

/// One program page (`GET /suki/programs/:id`): the program, my card, points menu, rewards.
class SukiProgramDetail {
  const SukiProgramDetail({
    required this.program,
    this.card,
    this.rewards = const [],
    this.pointsMenu = const [],
  });

  final SukiProgram program;
  final SukiCardProgress? card;
  final List<SukiReward> rewards;
  final List<SukiPointsMenuItem> pointsMenu;

  List<SukiTier> get effectiveTiers =>
      card != null && card!.tiers.isNotEmpty
          ? card!.tiers
          : program.effectiveTiers;

  factory SukiProgramDetail.fromJson(Map<String, dynamic> j) =>
      SukiProgramDetail(
        program: SukiProgram.fromJson(_map(j['program'])),
        card: j['my_card'] is Map
            ? SukiCardProgress.fromJson(_map(j['my_card']))
            : null,
        rewards: _rewards(j),
        pointsMenu: _rows(j['points_menu'])
            .map(SukiPointsMenuItem.fromJson)
            .toList(),
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
    this.rewardsIssued = const [],
    this.pointsAwarded = 0,
  });

  final SukiProgram program;
  final SukiCardProgress card;
  final bool replayed;
  final int xpAwarded;
  final List<String> badges;
  final bool missionCompleted;
  final SukiReward? rewardIssued;
  final List<SukiReward> rewardsIssued;
  final int pointsAwarded;

  /// The visit number just recorded: a completed cycle resets to 0.
  int get visitNumber =>
      card.visits == 0 && rewardIssued != null ? card.required : card.visits;

  factory SukiVisitResult.fromJson(Map<String, dynamic> j) {
    final single = j['reward_issued'] is Map
        ? SukiReward.fromJson(_map(j['reward_issued']))
        : null;
    final list = _rows(j['rewards_issued']).map(SukiReward.fromJson).toList();
    return SukiVisitResult(
      program: SukiProgram.fromJson(_map(j['program'])),
      card: SukiCardProgress.fromJson(_map(j['card'])),
      replayed: j['replayed'] == true,
      xpAwarded: _int(j['xp_awarded']),
      badges: [
        for (final b in (j['badges'] is List ? j['badges'] as List : const []))
          '$b'
      ],
      missionCompleted: j['mission_completed'] == true,
      rewardIssued: single ?? (list.isNotEmpty ? list.first : null),
      rewardsIssued: list.isNotEmpty ? list : (single != null ? [single] : const []),
      pointsAwarded: _int(j['points_awarded']),
    );
  }
}

class SukiPointsRedeemResult {
  const SukiPointsRedeemResult({
    required this.replayed,
    required this.reward,
    required this.card,
  });

  final bool replayed;
  final SukiReward reward;
  final SukiCardProgress card;

  factory SukiPointsRedeemResult.fromJson(Map<String, dynamic> j) =>
      SukiPointsRedeemResult(
        replayed: j['replayed'] == true,
        reward: SukiReward.fromJson(_map(j['reward'])),
        card: SukiCardProgress.fromJson(_map(j['card'])),
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
    this.expiresAt,
    this.usedAt,
    this.costPoints = 0,
  });

  final String id;
  final String voucherId;
  final String code;
  final String title;
  final String merchantName;
  final DateTime? createdAt;
  final DateTime? expiresAt;
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
      expiresAt: _date(j['expires_at']),
      usedAt: _date(j['used_at']),
      costPoints: _int(j['cost_points']),
    );
  }
}
