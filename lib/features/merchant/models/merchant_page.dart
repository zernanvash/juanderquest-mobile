/// v0.3.10: the public merchant page (`GET /merchants/:id`).
library;

num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
String? _text(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) => [
      for (final row in (v is List ? v : const []))
        if (row is Map) Map<String, dynamic>.from(row),
    ];

class MerchantPageProduct {
  const MerchantPageProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.isSpecialty,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final double? price;
  final String currency;
  final bool isSpecialty;
  final String? imageUrl;

  String? get priceLabel =>
      price == null ? null : '$currency ${price!.toStringAsFixed(2)}';

  factory MerchantPageProduct.fromJson(Map<String, dynamic> j) =>
      MerchantPageProduct(
        id: '${j['id'] ?? ''}',
        name: _text(j['name']) ?? 'Item',
        description: _text(j['description']) ?? '',
        price: _num(j['price'])?.toDouble(),
        currency: _text(j['currency']) ?? 'PHP',
        isSpecialty: j['is_specialty'] == true,
        imageUrl: _text(j['image_url']),
      );
}

class MerchantPageVoucher {
  const MerchantPageVoucher({
    required this.id,
    required this.title,
    required this.description,
    required this.costPoints,
  });

  final String id;
  final String title;
  final String description;
  final int costPoints;

  factory MerchantPageVoucher.fromJson(Map<String, dynamic> j) =>
      MerchantPageVoucher(
        id: '${j['id'] ?? ''}',
        title: _text(j['title']) ?? 'Voucher',
        description: _text(j['description']) ?? '',
        costPoints: _num(j['cost_points'])?.toInt() ?? 0,
      );
}

/// The viewer's Suki status at this shop.
class MerchantPageSuki {
  const MerchantPageSuki({
    required this.enabled,
    this.programId,
    this.title,
    this.rewardText,
    this.rewardTag,
    this.visitsRequired = 0,
    this.visits,
    this.required,
  });

  final bool enabled;
  final String? programId;
  final String? title;
  final String? rewardText;
  final String? rewardTag;
  final int visitsRequired;

  /// The viewer's card; null when they have none here yet.
  final int? visits;
  final int? required;

  bool get hasProgram => enabled && programId != null;
  bool get hasCard => visits != null;

  factory MerchantPageSuki.fromJson(Map<String, dynamic> j) {
    final p = j['program'] is Map ? _map(j['program']) : null;
    final card = j['my_card'] is Map ? _map(j['my_card']) : null;
    return MerchantPageSuki(
      enabled: j['enabled'] == true,
      programId: p == null ? null : _text(p['id']),
      title: p == null ? null : _text(p['title']),
      rewardText: p == null ? null : _text(p['reward_text']),
      rewardTag: p == null ? null : _text(p['reward_tag']),
      visitsRequired: _num(p?['visits_required'])?.toInt() ?? 0,
      visits: card == null ? null : _num(card['visits'])?.toInt() ?? 0,
      required: card == null ? null : _num(card['required'])?.toInt() ?? 0,
    );
  }
}

class MerchantPageLinkedSpot {
  const MerchantPageLinkedSpot({
    required this.id,
    required this.slug,
    required this.name,
    required this.municipality,
    required this.gpsLat,
    required this.gpsLng,
    this.imageUrl,
  });

  final String id;
  final String slug;
  final String name;
  final String municipality;
  final double gpsLat;
  final double gpsLng;
  final String? imageUrl;

  factory MerchantPageLinkedSpot.fromJson(Map<String, dynamic> j) =>
      MerchantPageLinkedSpot(
        id: '${j['id'] ?? ''}',
        slug: _text(j['slug']) ?? '${j['id'] ?? ''}',
        name: _text(j['name']) ?? 'Destination',
        municipality: _text(j['municipality']) ?? '',
        gpsLat: _num(j['gps_lat'])?.toDouble() ?? 0.0,
        gpsLng: _num(j['gps_lng'])?.toDouble() ?? 0.0,
        imageUrl: _text(j['image_url']),
      );
}

class MerchantPageData {
  const MerchantPageData({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublished,
    required this.specialties,
    required this.products,
    required this.vouchers,
    required this.suki,
    required this.isMember,
    this.category,
    this.municipality,
    this.location,
    this.logoUrl,
    this.bannerUrl,
    this.contactEmail,
    this.contactPhone,
    this.lat,
    this.lng,
    this.spotId,
    this.linkedSpot,
  });

  final String id;
  final String name;
  final String description;
  final bool isPublished;
  final String? category;
  final String? municipality;
  final String? location;
  final String? logoUrl;
  final String? bannerUrl;
  final String? contactEmail;
  final String? contactPhone;
  final double? lat;
  final double? lng;
  final String? spotId;
  final MerchantPageLinkedSpot? linkedSpot;
  final List<MerchantPageProduct> specialties;
  final List<MerchantPageProduct> products;
  final List<MerchantPageVoucher> vouchers;
  final MerchantPageSuki suki;
  final bool isMember;

  bool get hasLocation => lat != null && lng != null;

  factory MerchantPageData.fromJson(Map<String, dynamic> j) {
    final m = _map(j['merchant']);
    final rawLinked = m['linked_spot'];
    return MerchantPageData(
      id: '${m['id'] ?? ''}',
      name: _text(m['name']) ?? 'Shop',
      description: _text(m['description']) ?? '',
      isPublished: m['is_published'] != false,
      category: _text(m['category']),
      municipality: _text(m['municipality']),
      location: _text(m['location']),
      logoUrl: _text(m['logo_url']),
      bannerUrl: _text(m['banner_url']),
      contactEmail: _text(m['contact_email']),
      contactPhone: _text(m['contact_phone']),
      lat: _num(m['gps_lat'])?.toDouble(),
      lng: _num(m['gps_lng'])?.toDouble(),
      spotId: _text(m['spot_id']),
      linkedSpot: rawLinked is Map
          ? MerchantPageLinkedSpot.fromJson(
              Map<String, dynamic>.from(rawLinked),
            )
          : null,
      specialties: _rows(
        j['specialties'],
      ).map(MerchantPageProduct.fromJson).toList(),
      products: _rows(j['products']).map(MerchantPageProduct.fromJson).toList(),
      vouchers: _rows(j['vouchers']).map(MerchantPageVoucher.fromJson).toList(),
      suki: MerchantPageSuki.fromJson(_map(j['suki'])),
      isMember: _map(j['viewer'])['is_member'] == true,
    );
  }
}
