class VoucherModel {
  final String id;
  final String merchantName;
  final String offerTitle;
  final int costPoints;
  final String category;
  final String location;
  final String description;
  final bool isActive;

  VoucherModel({
    required this.id,
    required this.merchantName,
    required this.offerTitle,
    required this.costPoints,
    required this.category,
    required this.location,
    required this.description,
    required this.isActive,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] ?? '',
      merchantName: json['merchant_name'] ?? json['merchantName'] ?? 'Partner Merchant',
      offerTitle: json['offer_title'] ?? json['offerTitle'] ?? 'Voucher Offer',
      costPoints: (json['cost_points'] ?? json['costPoints'] ?? 50) as int,
      category: json['category'] ?? 'REWARDS',
      location: json['location'] ?? 'Pangasinan',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }
}

class RedeemedVoucherModel {
  final String voucherId;
  final String merchantName;
  final String offerTitle;
  final String code;
  final DateTime redeemedAt;
  final DateTime expiresAt;
  final int costPoints;

  RedeemedVoucherModel({
    required this.voucherId,
    required this.merchantName,
    required this.offerTitle,
    required this.code,
    required this.redeemedAt,
    required this.expiresAt,
    required this.costPoints,
  });

  Map<String, dynamic> toJson() => {
    'voucherId': voucherId,
    'merchantName': merchantName,
    'offerTitle': offerTitle,
    'code': code,
    'redeemedAt': redeemedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'costPoints': costPoints,
  };

  factory RedeemedVoucherModel.fromJson(Map<String, dynamic> json) => RedeemedVoucherModel(
    voucherId: json['voucherId'] ?? '',
    merchantName: json['merchantName'] ?? 'Partner Merchant',
    offerTitle: json['offerTitle'] ?? 'Voucher Offer',
    code: json['code'] ?? 'JDQ-REDEEMED',
    redeemedAt: DateTime.tryParse(json['redeemedAt'] ?? '') ?? DateTime.now(),
    expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
    costPoints: (json['costPoints'] ?? 0) as int,
  );
}
