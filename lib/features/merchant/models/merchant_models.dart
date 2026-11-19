/// Plan 95: typed views of the merchant workspace API.
library;

import '../../quests/widgets/sponsorship_conditions_widgets.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

String _str(Object? value) => value?.toString() ?? '';

/// Where the signed-in traveler is in the merchant journey.
enum MerchantHubState {
  none,
  pendingReview,
  needsChanges,
  rejected,
  approvedMerchant,
}

class MerchantHubStatus {
  const MerchantHubStatus({
    required this.state,
    this.application,
    this.merchantName,
  });

  static const none = MerchantHubStatus(state: MerchantHubState.none);

  final MerchantHubState state;
  final Map<String, dynamic>? application;
  final String? merchantName;

  /// Reads `GET /affiliate/applications/me` (`data` = application,
  /// top-level `merchant` = workspace summary).
  factory MerchantHubStatus.fromResponse(Object? body) {
    final root = _map(body);
    final app = root['data'] is Map ? _map(root['data']) : null;
    final merchant = root['merchant'] is Map ? _map(root['merchant']) : null;
    if (merchant != null) {
      return MerchantHubStatus(
        state: MerchantHubState.approvedMerchant,
        application: app,
        merchantName: _str(merchant['name']),
      );
    }
    final state = switch (app?['status']) {
      'received' ||
      'in_review' ||
      'appealed' ||
      'approved' =>
        MerchantHubState.pendingReview,
      'needs_changes' => MerchantHubState.needsChanges,
      'rejected' => MerchantHubState.rejected,
      _ => MerchantHubState.none,
    };
    return MerchantHubStatus(state: state, application: app);
  }

  /// Owner 2026-11-18: a rejected application can be re-opened (edit and
  /// resubmit, or appeal) this many times in total; the backend enforces it.
  static const maxReapplications = 3;

  int get reapplicationsUsed => _int(application?['resubmission_count']);

  bool get canReapply =>
      state == MerchantHubState.rejected &&
      reapplicationsUsed < maxReapplications;

  /// The screen this state opens.
  String get route => switch (state) {
        MerchantHubState.approvedMerchant => '/merchant',
        MerchantHubState.pendingReview ||
        MerchantHubState.needsChanges ||
        MerchantHubState.rejected =>
          '/affiliate/pending',
        _ => '/affiliate',
      };

  String get label => switch (state) {
        MerchantHubState.approvedMerchant => 'Merchant dashboard',
        MerchantHubState.pendingReview => 'Application pending',
        MerchantHubState.needsChanges => 'Changes requested',
        MerchantHubState.rejected => 'Application not approved',
        _ => 'Merchant affiliate',
      };

  String get subtitle => switch (state) {
        MerchantHubState.approvedMerchant =>
          'Manage your storefront, catalog and sponsorships',
        MerchantHubState.pendingReview =>
          'The tourism team is reviewing your application',
        MerchantHubState.needsChanges =>
          'The reviewer asked for changes to your application',
        MerchantHubState.rejected =>
          'Edit and resubmit, or appeal the decision',
        _ => 'Apply to take part in tourism promotions',
      };
}

class MerchantChecklistItem {
  const MerchantChecklistItem({
    required this.id,
    required this.title,
    required this.completed,
  });

  final String id;
  final String title;
  final bool completed;
}

class MerchantDashboardData {
  const MerchantDashboardData({
    this.id = '',
    required this.name,
    required this.category,
    required this.municipality,
    required this.isPublished,
    required this.activeProducts,
    required this.checklist,
    required this.notice,
  });

  final String id;
  final String name;
  final String category;
  final String municipality;
  final bool isPublished;
  final int activeProducts;
  final List<MerchantChecklistItem> checklist;
  final String notice;

  int get completedCount => checklist.where((c) => c.completed).length;

  factory MerchantDashboardData.fromJson(Map<String, dynamic> json) {
    final merchant = _map(json['merchant']);
    final checklist = _map(json['checklist']);
    return MerchantDashboardData(
      id: _str(merchant['id']),
      name: _str(merchant['name']),
      category: _str(merchant['category']),
      municipality: _str(merchant['municipality']),
      isPublished: merchant['is_published'] == true,
      activeProducts: _int(_map(json['counts'])['active_products']),
      checklist: [
        for (final item in (checklist['items'] as List? ?? const []))
          if (item is Map)
            MerchantChecklistItem(
              id: _str(item['id']),
              title: _str(item['title']),
              completed: item['completed'] == true,
            ),
      ],
      notice: _str(_map(json['truthful_notice'])['statement']),
    );
  }
}

class MerchantProductItem {
  const MerchantProductItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    this.isSpecialty = false,
  });

  final String id;
  final String name;
  final String description;
  final double? price;
  final String currency;

  /// v0.3.10: pinned by the owner as the shop's specialty (max 3).
  final bool isSpecialty;

  String get priceLabel => price == null
      ? 'Informational'
      : '$currency ${price!.toStringAsFixed(2)}';

  factory MerchantProductItem.fromJson(Map<String, dynamic> json) =>
      MerchantProductItem(
        id: _str(json['id']),
        name: _str(json['name']),
        description: _str(json['description']),
        price: json['price'] is num
            ? (json['price'] as num).toDouble()
            : double.tryParse('${json['price'] ?? ''}'),
        currency:
            _str(json['currency']).isEmpty ? 'PHP' : _str(json['currency']),
        isSpecialty:
            json['is_specialty'] == true || json['specialty_at'] != null,
      );
}

class MerchantPointCredit {
  const MerchantPointCredit({
    required this.source,
    required this.reference,
    required this.points,
  });

  final String source;
  final String reference;
  final int points;
}

class MerchantPointSummary {
  const MerchantPointSummary({required this.balance, required this.history});

  final int balance;
  final List<MerchantPointCredit> history;

  factory MerchantPointSummary.fromJson(Map<String, dynamic> json) =>
      MerchantPointSummary(
        balance: _int(json['balance_points']),
        history: [
          for (final row in (json['history'] as List? ?? const []))
            if (row is Map)
              MerchantPointCredit(
                source: _str(row['source']),
                reference: _str(row['reference']),
                points: _int(row['points']),
              ),
        ],
      );
}

class MerchantSponsorshipItem {
  const MerchantSponsorshipItem({
    required this.id,
    required this.status,
    required this.questTitle,
    required this.spotName,
    required this.points,
    required this.voucherQty,
    required this.promo,
    required this.termsVersion,
    required this.planId,
    required this.planStatus,
    this.conditions = const [],
    this.acceptedWithUnmet = const [],
  });

  final String id;
  final String status;
  final String questTitle;
  final String spotName;
  final int points;
  final int voucherQty;
  final bool promo;
  final int termsVersion;
  final String planId;
  final String planStatus;
  final List<SponsorshipConditionData> conditions;
  final List<SponsorshipConditionData> acceptedWithUnmet;

  factory MerchantSponsorshipItem.fromJson(Map<String, dynamic> json) =>
      MerchantSponsorshipItem(
        id: _str(json['id']),
        status: _str(json['status']),
        questTitle: _str(json['quest_title']),
        spotName: _str(json['spot_name']),
        points: _int(json['points']),
        voucherQty: _int(json['voucher_qty']),
        promo: json['promo'] == true,
        termsVersion:
            _int(json['terms_version']) < 1 ? 1 : _int(json['terms_version']),
        planId: _str(json['plan_id']),
        planStatus: _str(json['plan_status']),
        conditions: _parseConditions(json['conditions']),
        acceptedWithUnmet: _parseConditions(json['accepted_with_unmet']),
      );

  static List<SponsorshipConditionData> _parseConditions(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map)
          SponsorshipConditionData.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}

class MerchantVoucherOption {
  const MerchantVoucherOption({required this.id, required this.title});

  final String id;
  final String title;
}

int? _optInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _optDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _optDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

String? _optStr(Object? value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Allowed icon keys in `POST/PATCH /merchant/vouchers`.
const merchantVoucherIconKeys = [
  'meal',
  'coffee',
  'souvenir',
  'ticket',
  'discount',
  'gift',
];

class MerchantManagedVoucher {
  const MerchantManagedVoucher({
    required this.id,
    required this.title,
    required this.description,
    required this.costPoints,
    this.availability = 'preview',
    this.isActive = true,
    this.stockLimit,
    this.validDays,
    this.iconKey,
    this.partnerLabel,
    this.redeemedCount = 0,
    this.usedCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final int costPoints;
  final String availability;
  final bool isActive;
  final int? stockLimit;
  final int? validDays;
  final String? iconKey;
  final String? partnerLabel;
  final int redeemedCount;
  final int usedCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int? get remainingStock => stockLimit == null
      ? null
      : (stockLimit! - redeemedCount).clamp(0, stockLimit!);

  factory MerchantManagedVoucher.fromJson(Map<String, dynamic> json) =>
      MerchantManagedVoucher(
        id: _str(json['id']),
        title: _str(json['title']),
        description: _str(json['description']),
        costPoints: _int(json['cost_points']),
        availability: _optStr(json['availability']) ?? 'preview',
        isActive: json['is_active'] != false,
        stockLimit: _optInt(json['stock_limit']),
        validDays: _optInt(json['valid_days']),
        iconKey: _optStr(json['icon_key']),
        partnerLabel: _optStr(json['partner_label']),
        redeemedCount: _int(json['redeemed_count']),
        usedCount: _int(json['used_count']),
        createdAt: _optDate(json['created_at']),
        updatedAt: _optDate(json['updated_at']),
      );
}

class MerchantManagedVoucherList {
  const MerchantManagedVoucherList({
    required this.merchantId,
    required this.role,
    required this.items,
  });

  final String merchantId;
  final String role;
  final List<MerchantManagedVoucher> items;

  bool get isOwner => role == 'owner';
  int get activeCount => items.where((v) => v.isActive).length;

  factory MerchantManagedVoucherList.fromJson(Map<String, dynamic> json) =>
      MerchantManagedVoucherList(
        merchantId: _str(json['merchant_id']),
        role: _optStr(json['role']) ?? 'staff',
        items: [
          for (final row in (json['items'] as List? ?? const []))
            if (row is Map)
              MerchantManagedVoucher.fromJson(Map<String, dynamic>.from(row)),
        ],
      );
}

class MerchantStaffMember {
  const MerchantStaffMember({
    required this.id,
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String? email;
  final String role;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOwner => role == 'owner';
  bool get isActive => status == 'active';

  factory MerchantStaffMember.fromJson(Map<String, dynamic> json) =>
      MerchantStaffMember(
        id: _str(json['id']),
        userId: _str(json['user_id']),
        displayName: _optStr(json['display_name']) ?? 'Member',
        email: _optStr(json['email']),
        role: _optStr(json['role']) ?? 'staff',
        status: _optStr(json['status']) ?? 'active',
        createdAt: _optDate(json['created_at']),
        updatedAt: _optDate(json['updated_at']),
      );
}

class MerchantStaffList {
  const MerchantStaffList({
    required this.merchantId,
    required this.items,
  });

  final String merchantId;
  final List<MerchantStaffMember> items;

  int get activeStaffCount =>
      items.where((m) => !m.isOwner && m.isActive).length;

  factory MerchantStaffList.fromJson(Map<String, dynamic> json) =>
      MerchantStaffList(
        merchantId: _str(json['merchant_id']),
        items: [
          for (final row in (json['items'] as List? ?? const []))
            if (row is Map)
              MerchantStaffMember.fromJson(Map<String, dynamic>.from(row)),
        ],
      );
}

class MerchantCounterEvent {
  const MerchantCounterEvent({
    required this.kind,
    required this.customer,
    this.code,
    this.method,
    required this.detail,
    this.staffName,
    this.at,
  });

  final String kind;
  final String customer;
  final String? code;
  final String? method;
  final String detail;
  final String? staffName;
  final DateTime? at;

  factory MerchantCounterEvent.fromJson(Map<String, dynamic> json) =>
      MerchantCounterEvent(
        kind: _optStr(json['kind']) ?? 'voucher',
        customer: _optStr(json['customer']) ?? 'Customer',
        code: _optStr(json['code']),
        method: _optStr(json['method']),
        detail: _str(json['detail']),
        staffName: _optStr(json['staff_name']),
        at: _optDate(json['at']),
      );
}

class MerchantFundingAnalytics {
  const MerchantFundingAnalytics({
    required this.activeSponsorships,
    required this.totalPointsCommitted,
    required this.totalPointsPaid,
    required this.fundedCompletions,
  });

  final int activeSponsorships;
  final int totalPointsCommitted;
  final int totalPointsPaid;
  final int fundedCompletions;

  factory MerchantFundingAnalytics.fromJson(Map<String, dynamic> json) =>
      MerchantFundingAnalytics(
        activeSponsorships: _int(json['active_sponsorships']),
        totalPointsCommitted: _int(json['total_points_committed']),
        totalPointsPaid: _int(json['total_points_paid']),
        fundedCompletions: _int(json['funded_completions']),
      );
}

class MerchantVoucherAnalytics {
  const MerchantVoucherAnalytics({
    required this.activeCatalogCount,
    required this.shopRedeemedInWindow,
    required this.perksGrantedInWindow,
    required this.confirmedAtCounterInWindow,
  });

  final int activeCatalogCount;
  final int shopRedeemedInWindow;
  final int perksGrantedInWindow;
  final int confirmedAtCounterInWindow;

  factory MerchantVoucherAnalytics.fromJson(Map<String, dynamic> json) =>
      MerchantVoucherAnalytics(
        activeCatalogCount: _int(json['active_catalog_count']),
        shopRedeemedInWindow: _int(json['shop_redeemed_in_window']),
        perksGrantedInWindow: _int(json['perks_granted_in_window']),
        confirmedAtCounterInWindow: _int(json['confirmed_at_counter_in_window']),
      );
}

class MerchantSukiAnalytics {
  const MerchantSukiAnalytics({
    required this.visitsInWindow,
    required this.uniqueCustomers,
    required this.repeatCustomers,
    required this.rewardsIssued,
    required this.rewardsClaimed,
  });

  final int visitsInWindow;
  final int uniqueCustomers;
  final int repeatCustomers;
  final int rewardsIssued;
  final int rewardsClaimed;

  factory MerchantSukiAnalytics.fromJson(Map<String, dynamic> json) =>
      MerchantSukiAnalytics(
        visitsInWindow: _int(json['visits_in_window']),
        uniqueCustomers: _int(json['unique_customers']),
        repeatCustomers: _int(json['repeat_customers']),
        rewardsIssued: _int(json['rewards_issued']),
        rewardsClaimed: _int(json['rewards_claimed']),
      );
}

class MerchantAnalyticsData {
  const MerchantAnalyticsData({
    required this.merchantId,
    required this.days,
    required this.funding,
    required this.vouchers,
    required this.suki,
  });

  final String merchantId;
  final int days;
  final MerchantFundingAnalytics funding;
  final MerchantVoucherAnalytics vouchers;
  final MerchantSukiAnalytics suki;

  factory MerchantAnalyticsData.fromJson(Map<String, dynamic> json) =>
      MerchantAnalyticsData(
        merchantId: _str(json['merchant_id']),
        days: _int(json['days']) > 0 ? _int(json['days']) : 30,
        funding: MerchantFundingAnalytics.fromJson(_map(json['funding'])),
        vouchers: MerchantVoucherAnalytics.fromJson(_map(json['vouchers'])),
        suki: MerchantSukiAnalytics.fromJson(_map(json['suki'])),
      );
}

class PublicMerchantItem {
  const PublicMerchantItem({
    required this.id,
    required this.name,
    this.category,
    this.municipality,
    this.location,
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    this.spotId,
    this.gpsLat,
    this.gpsLng,
    this.distanceM,
    this.activeVoucherCount = 0,
    this.hasActiveSuki = false,
  });

  final String id;
  final String name;
  final String? category;
  final String? municipality;
  final String? location;
  final String description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? spotId;
  final double? gpsLat;
  final double? gpsLng;
  final int? distanceM;
  final int activeVoucherCount;
  final bool hasActiveSuki;

  String? get distanceLabel {
    final m = distanceM;
    if (m == null) return null;
    if (m < 1000) return '$m m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  factory PublicMerchantItem.fromJson(Map<String, dynamic> json) =>
      PublicMerchantItem(
        id: _str(json['id']),
        name: _optStr(json['name']) ?? 'Shop',
        category: _optStr(json['category']),
        municipality: _optStr(json['municipality']),
        location: _optStr(json['location']),
        description: _str(json['description']),
        logoUrl: _optStr(json['logo_url']),
        bannerUrl: _optStr(json['banner_url']),
        spotId: _optStr(json['spot_id']),
        gpsLat: _optDouble(json['gps_lat']),
        gpsLng: _optDouble(json['gps_lng']),
        distanceM: _optInt(json['distance_m']),
        activeVoucherCount: _int(json['active_voucher_count']),
        hasActiveSuki: json['has_active_suki'] == true,
      );
}

class PublicMerchantPage {
  const PublicMerchantPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<PublicMerchantItem> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  factory PublicMerchantPage.fromJson(Map<String, dynamic> json) =>
      PublicMerchantPage(
        items: [
          for (final row in (json['items'] as List? ?? const []))
            if (row is Map)
              PublicMerchantItem.fromJson(Map<String, dynamic>.from(row)),
        ],
        page: _int(json['page']) > 0 ? _int(json['page']) : 1,
        limit: _int(json['limit']) > 0 ? _int(json['limit']) : 20,
        total: _int(json['total']),
      );
}
