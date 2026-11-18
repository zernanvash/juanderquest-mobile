/// Plan 107 §6.5–6.7: the merchant side of Suki Cards (own models, so the
/// customer track's `features/suki` models can change independently).
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

/// The tag on the card's last slot: FREE / 10% OFF / ₱20 OFF / PROMO.
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

  bool get staffScan => mode == 'staff_scan';
  bool get isActive => status == 'active';
  bool get adminPaused => status == 'paused' && pausedBy == 'admin';
  String get rewardTag => sukiRewardTag(rewardKind, rewardValue);

  factory MerchantSukiProgram.fromJson(Map<String, dynamic> j) =>
      MerchantSukiProgram(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? 'Suki Card'}',
        rewardKind: '${j['reward_kind'] ?? 'free_item'}',
        rewardValue: _double(j['reward_value']),
        rewardText: '${j['reward_text'] ?? ''}',
        visitsRequired: _int(j['visits_required'], 10),
        mode: '${j['mode'] ?? 'standee'}',
        status: '${j['status'] ?? 'draft'}',
        radiusM: _int(j['radius_m'], 75),
        standeeVersion: _int(j['standee_version'], 1),
        pausedBy: _str(j['paused_by']),
        pauseReason: _str(j['pause_reason']),
      );
}

/// `GET /merchant/suki`: the shop's program (or none) plus the checklist.
class MerchantSukiView {
  const MerchantSukiView({
    required this.hasLocation,
    required this.isPublished,
    this.role = 'owner',
    this.program,
  });

  /// `role` is an additive field from the backend; when it is missing the
  /// owner controls show and the server still enforces owner-only routes.
  final String role;
  final MerchantSukiProgram? program;
  final bool hasLocation;
  final bool isPublished;

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
  });

  final String kind; // visit | reward | voucher
  final String customer; // pseudonym, e.g. "Suki #A3F"
  final String title;
  final String detail;

  factory MerchantSukiScanResult.fromJson(Map<String, dynamic> j) =>
      MerchantSukiScanResult(
        kind: '${j['kind'] ?? 'visit'}',
        customer: '${j['customer'] ?? ''}',
        title: '${j['title'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
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
        topRegulars: [
          for (final r in _rows(j['top_regulars']))
            (label: '${r['label'] ?? ''}', visits: _int(r['visits'])),
        ],
      );
}
