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
