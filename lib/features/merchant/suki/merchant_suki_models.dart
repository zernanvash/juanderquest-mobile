/// Plan 107 / Plan 111 §6: merchant side of Suki Cards (tiers, points & stats).
library;

// Postgres BIGINT/NUMERIC can arrive as strings; accept both.
int _int(Object? v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? _str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) => [
      for (final row in (v is List ? v : const []))
        if (row is Map) Map<String, dynamic>.from(row),
    ];

const sukiRewardKinds = ['free_item', 'percent_off', 'amount_off', 'promo'];
const merchantSukiIconKeys = [
  'gift',
  'coffee',
  'meal',
  'snack',
  'dessert',
  'drink',
  'discount',
  'promo',
];

/// The tag on a reward slot: FREE / 10% OFF / ₱20 OFF / PROMO.
String sukiRewardTag(String kind, num? value) {
  final v = value == null
      ? 'N'
      : (value == value.roundToDouble() ? '${value.round()}' : '$value');
  return switch (kind) {
    'percent_off' => '$v% OFF',
    'amount_off' => '₱$v OFF',
    'promo' => 'PROMO',
    _ => 'FREE',
  };
}

class MerchantSukiTier {
  const MerchantSukiTier({
    required this.visitNumber,
    required this.rewardKind,
    required this.rewardText,
    required this.rewardTag,
    this.rewardValue,
    this.iconKey = 'gift',
  });

  final int visitNumber;
  final String rewardKind;
  final double? rewardValue;
  final String rewardText;
  final String rewardTag;
  final String iconKey;

  factory MerchantSukiTier.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    final value = _double(j['reward_value']);
    return MerchantSukiTier(
      visitNumber: _int(j['visit_number'], 10),
      rewardKind: kind,
      rewardValue: value,
      rewardText: '${j['reward_text'] ?? ''}',
      rewardTag: _str(j['reward_tag']) ?? sukiRewardTag(kind, value),
      iconKey: '${j['icon_key'] ?? 'gift'}',
    );
  }
}

class MerchantSukiPointsConfig {
  const MerchantSukiPointsConfig({
    this.enabled = false,
    this.programEnabled = false,
    this.perVisit = 10,
    this.pesosPerPoint,
    this.maxPerVisit = 200,
    this.expireDays,
  });

  final bool enabled;
  final bool programEnabled;
  final int perVisit;
  final double? pesosPerPoint;
  final int maxPerVisit;
  final int? expireDays;

  factory MerchantSukiPointsConfig.fromJson(Map<String, dynamic> j) =>
      MerchantSukiPointsConfig(
        enabled: j['enabled'] == true,
        programEnabled: j['program_enabled'] == true || j['enabled'] == true,
        perVisit: _int(j['per_visit'], 10),
        pesosPerPoint: _double(j['pesos_per_point']),
        maxPerVisit: _int(j['max_per_visit'], 200),
        expireDays:
            j['expire_days'] == null ? null : _int(j['expire_days']),
      );
}

class MerchantSukiPointsMenuItem {
  const MerchantSukiPointsMenuItem({
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

  factory MerchantSukiPointsMenuItem.fromJson(Map<String, dynamic> j) =>
      MerchantSukiPointsMenuItem(
        id: '${j['id'] ?? ''}',
        programId: '${j['program_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        pointsCost: _int(j['points_cost']),
        iconKey: '${j['icon_key'] ?? 'gift'}',
        isActive: j['is_active'] != false,
        sortOrder: _int(j['sort_order']),
      );
}

class MerchantSukiProgram {
  const MerchantSukiProgram({
    required this.id,
    required this.title,
    required this.rewardKind,
    required this.rewardText,
    required this.visitsRequired,
    required this.mode,
    required this.status,
    this.rewardValue,
    this.radiusM = 75,
    this.standeeVersion = 1,
    this.pausedBy,
    this.pauseReason,
    this.skinKey = 'jdq_classic',
    this.tiers = const [],
    this.points = const MerchantSukiPointsConfig(),
  });

  final String id;
  final String title;
  final String rewardKind; // free_item | percent_off | amount_off | promo
  final double? rewardValue;
  final String rewardText;
  final int visitsRequired;
  final String mode; // standee | staff_scan
  final String status; // draft | active | paused
  final int radiusM;
  final int standeeVersion;
  final String? pausedBy; // merchant | admin
  final String? pauseReason;
  final String skinKey;
  final List<MerchantSukiTier> tiers;
  final MerchantSukiPointsConfig points;

  bool get staffScan => mode == 'staff_scan';
  bool get isActive => status == 'active';
  bool get adminPaused => status == 'paused' && pausedBy == 'admin';
  String get rewardTag => sukiRewardTag(rewardKind, rewardValue);

  List<MerchantSukiTier> get effectiveTiers => tiers.isNotEmpty
      ? tiers
      : [
          MerchantSukiTier(
            visitNumber: visitsRequired,
            rewardKind: rewardKind,
            rewardValue: rewardValue,
            rewardText: rewardText,
            rewardTag: rewardTag,
          ),
        ];

  factory MerchantSukiProgram.fromJson(Map<String, dynamic> j) {
    final kind = '${j['reward_kind'] ?? 'free_item'}';
    final value = _double(j['reward_value']);
    final visits = _int(j['visits_required'], 10);
    final rewardText = '${j['reward_text'] ?? ''}';
    final rawTiers = _rows(j['tiers']).map(MerchantSukiTier.fromJson).toList();
    return MerchantSukiProgram(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Suki Card'}',
      rewardKind: kind,
      rewardValue: value,
      rewardText: rewardText,
      visitsRequired: visits,
      mode: '${j['mode'] ?? 'standee'}',
      status: '${j['status'] ?? 'draft'}',
      radiusM: _int(j['radius_m'], 75),
      standeeVersion: _int(j['standee_version'], 1),
      pausedBy: _str(j['paused_by']),
      pauseReason: _str(j['pause_reason']),
      skinKey: '${j['skin_key'] ?? 'jdq_classic'}',
      tiers: rawTiers.isNotEmpty
          ? rawTiers
          : [
              MerchantSukiTier(
                visitNumber: visits,
                rewardKind: kind,
                rewardValue: value,
                rewardText: rewardText,
                rewardTag: sukiRewardTag(kind, value),
              ),
            ],
      points: j['points'] is Map
          ? MerchantSukiPointsConfig.fromJson(_map(j['points']))
          : const MerchantSukiPointsConfig(),
    );
  }
}

/// `GET /merchant/suki`: the shop's program (or none), points menu & checklist.
class MerchantSukiView {
  const MerchantSukiView({
    required this.hasLocation,
    required this.isPublished,
    this.role = 'owner',
    this.program,
    this.globalPointsEnabled = false,
    this.pointsMenu = const [],
  });

  final String role;
  final MerchantSukiProgram? program;
  final bool hasLocation;
  final bool isPublished;
  final bool globalPointsEnabled;
  final List<MerchantSukiPointsMenuItem> pointsMenu;

  bool get isOwner => role == 'owner';

  factory MerchantSukiView.fromJson(Map<String, dynamic> j) {
    final checklist = _map(j['checklist']);
    final p = j['program'];
    return MerchantSukiView(
      role: '${j['role'] ?? 'owner'}',
      program: p is Map ? MerchantSukiProgram.fromJson(_map(p)) : null,
      hasLocation:
          checklist['has_location'] == true || j['shop_location'] is Map,
      isPublished: checklist['is_published'] == true,
      globalPointsEnabled: j['global_points_enabled'] == true,
      pointsMenu: _rows(j['points_menu'])
          .map(MerchantSukiPointsMenuItem.fromJson)
          .toList(),
    );
  }
}

/// `GET /merchant/suki/standee`: what the printed standee shows.
class MerchantSukiStandee {
  const MerchantSukiStandee({
    required this.url,
    required this.title,
    required this.rewardText,
    required this.shopName,
    required this.version,
    this.rewardTag,
    this.visitsRequired,
  });

  final String url;
  final String title;
  final String rewardText;
  final String shopName;
  final int version;
  final String? rewardTag;
  final int? visitsRequired;

  factory MerchantSukiStandee.fromJson(Map<String, dynamic> j) =>
      MerchantSukiStandee(
        url: '${j['url'] ?? ''}',
        title: '${j['title'] ?? 'Suki Card'}',
        rewardText: '${j['reward_text'] ?? ''}',
        shopName: '${j['shop_name'] ?? ''}',
        version: _int(j['version'], 1),
        rewardTag: _str(j['reward_tag']),
        visitsRequired:
            j['visits_required'] == null ? null : _int(j['visits_required']),
      );
}

/// `POST /merchant/suki/scan`: one counter scan's result.
class MerchantSukiScanResult {
  const MerchantSukiScanResult({
    required this.kind,
    required this.customer,
    required this.title,
    required this.detail,
    this.pointsAwarded = 0,
  });

  final String kind; // visit | reward | voucher
  final String customer; // pseudonym, e.g. "Suki #A3F"
  final String title;
  final String detail;
  final int pointsAwarded;

  factory MerchantSukiScanResult.fromJson(Map<String, dynamic> j) =>
      MerchantSukiScanResult(
        kind: '${j['kind'] ?? 'visit'}',
        customer: '${j['customer'] ?? ''}',
        title: '${j['title'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
        pointsAwarded: _int(j['points_awarded']),
      );
}

/// `GET /merchant/suki/stats`: aggregates over the last [days] Manila days.
class MerchantSukiStats {
  const MerchantSukiStats({
    required this.days,
    required this.visitsByDay,
    required this.uniqueCustomers,
    required this.repeatCustomers,
    required this.newToApp,
    required this.rewardsIssued,
    required this.rewardsClaimed,
    required this.vouchersConfirmed,
    required this.topRegulars,
    this.pointsIssued = 0,
    this.pointsRedeemed = 0,
    this.rewardsByTier = const [],
  });

  final int days;
  final Map<String, int> visitsByDay; // 'YYYY-MM-DD' -> visits
  final int uniqueCustomers;
  final int repeatCustomers;
  final int newToApp;
  final int rewardsIssued;
  final int rewardsClaimed;
  final int vouchersConfirmed;
  final List<({String label, int visits})> topRegulars;
  final int pointsIssued;
  final int pointsRedeemed;
  final List<({int? tierVisit, String source, int issued, int claimed})>
      rewardsByTier;

  int get totalVisits => visitsByDay.values.fold(0, (sum, v) => sum + v);

  double get claimRate =>
      rewardsIssued == 0 ? 0 : (rewardsClaimed / rewardsIssued).clamp(0, 1);

  factory MerchantSukiStats.fromJson(Map<String, dynamic> j) =>
      MerchantSukiStats(
        days: _int(j['days'], 30),
        visitsByDay: {
          for (final d in _rows(j['visits_by_day']))
            '${d['date']}'.split('T').first: _int(d['visits']),
        },
        uniqueCustomers: _int(j['unique_customers']),
        repeatCustomers: _int(j['repeat_customers']),
        newToApp: _int(j['new_to_app']),
        rewardsIssued: _int(j['rewards_issued']),
        rewardsClaimed: _int(j['rewards_claimed']),
        vouchersConfirmed: _int(j['vouchers_confirmed']),
        pointsIssued: _int(j['points_issued']),
        pointsRedeemed: _int(j['points_redeemed']),
        rewardsByTier: [
          for (final t in _rows(j['rewards_by_tier']))
            (
              tierVisit:
                  t['tier_visit'] == null ? null : _int(t['tier_visit']),
              source: '${t['source'] ?? 'visits'}',
              issued: _int(t['issued']),
              claimed: _int(t['claimed']),
            ),
        ],
        topRegulars: [
          for (final r in _rows(j['top_regulars']))
            (label: '${r['label'] ?? ''}', visits: _int(r['visits'])),
        ],
      );
}
