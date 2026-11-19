class VoucherModel {
  final String id;
  final String merchantName;
  final String offerTitle;
  final int costPoints;
  final String category;
  final String location;
  final String description;
  final bool isActive;
  final String availability;
  final bool redeemable;
  final String? partnerLabel;
  final String? iconKey;

  /// v0.3.10: the shop behind the offer, for its public page.
  final String merchantId;

  /// Plan 110a/b: optional stock cap, validity days, and remaining inventory.
  final int? stockLimit;
  final int? validDays;
  final int redeemedCount;
  final int? remainingStock;

  bool get isOutOfStock => remainingStock != null && remainingStock! <= 0;

  VoucherModel({
    required this.id,
    required this.merchantName,
    required this.offerTitle,
    required this.costPoints,
    required this.category,
    required this.location,
    required this.description,
    required this.isActive,
    this.availability = 'live',
    this.redeemable = true,
    this.partnerLabel,
    this.iconKey,
    this.merchantId = '',
    this.stockLimit,
    this.validDays,
    this.redeemedCount = 0,
    this.remainingStock,
  });

  static int? _optInt(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] ?? '',
      merchantName: json['partnerLabel'] ?? json['partner_label'] ?? json['merchant_name'] ?? json['merchantName'] ?? 'Partner Merchant',
      offerTitle: json['title'] ?? json['offer_title'] ?? json['offerTitle'] ?? 'Voucher Offer',
      costPoints: ((json['cost_points'] ?? json['costPoints'] ?? 50) as num).toInt(),
      category: json['category'] ?? 'REWARDS',
      location: json['location'] ?? 'Location unavailable',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      availability: json['availability'] ?? 'live',
      redeemable: json['redeemable'] ?? (json['availability'] != 'preview'),
      partnerLabel: json['partnerLabel'] ?? json['partner_label'],
      iconKey: json['iconKey'] ?? json['icon_key'],
      merchantId: '${json['merchant_id'] ?? json['merchantId'] ?? ''}',
      stockLimit: _optInt(json['stock_limit'] ?? json['stockLimit']),
      validDays: _optInt(json['valid_days'] ?? json['validDays']),
      redeemedCount: _optInt(json['redeemed_count'] ?? json['redeemedCount']) ?? 0,
      remainingStock: _optInt(json['remaining_stock'] ?? json['remainingStock']),
    );
  }
}

class RedeemedVoucherModel {
  final String voucherId;
  final String merchantName;
  final String offerTitle;
  final String code;
  final DateTime redeemedAt;
  final DateTime? expiresAt;

  /// Plan 107: set once the shop's counter scanner confirmed the code.
  final DateTime? usedAt;
  final int costPoints;

  RedeemedVoucherModel({
    required this.voucherId,
    required this.merchantName,
    required this.offerTitle,
    required this.code,
    required this.redeemedAt,
    this.expiresAt,
    this.usedAt,
    required this.costPoints,
  });

  Map<String, dynamic> toJson() => {
    'voucherId': voucherId,
    'merchantName': merchantName,
    'offerTitle': offerTitle,
    'code': code,
    'redeemedAt': redeemedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'usedAt': usedAt?.toIso8601String(),
    'costPoints': costPoints,
  };

  factory RedeemedVoucherModel.fromJson(Map<String, dynamic> json) => RedeemedVoucherModel(
    voucherId: json['voucherId'] ?? '',
    merchantName: json['merchantName'] ?? 'Partner Merchant',
    offerTitle: json['offerTitle'] ?? 'Voucher Offer',
    code: json['code'] ?? '',
    redeemedAt: DateTime.tryParse(json['redeemedAt'] ?? '') ?? DateTime.now(),
    expiresAt: DateTime.tryParse(json['expiresAt'] ?? ''),
    usedAt: DateTime.tryParse(json['usedAt'] ?? ''),
    costPoints: (json['costPoints'] ?? 0) as int,
  );
}
