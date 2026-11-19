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
