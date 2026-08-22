class QuestModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String locationName;
  final double gpsLat;
  final double gpsLng;
  final int radiusMeters;
  final int rewardPoints;
  final String markerCode;
  final String markerImageUrl;
  final String crowdStatus;
  final String? campaignId;
  final int? remainingSlots;

  QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.locationName,
    required this.gpsLat,
    required this.gpsLng,
    required this.radiusMeters,
    required this.rewardPoints,
    required this.markerCode,
    required this.markerImageUrl,
    this.crowdStatus = 'unknown',
    this.campaignId,
    this.remainingSlots,
  });

  int get allowedRadiusMeters => radiusMeters;
  String? get imageUrl => markerImageUrl.isNotEmpty ? markerImageUrl : null;

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'eco',
      locationName: json['location_name'] ?? 'Pangasinan',
      gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: json['radius_meters'] ?? 200,
      rewardPoints: json['reward_points'] ?? 50,
      markerCode: json['marker_code'] ?? '',
      markerImageUrl: json['marker_image_url'] ?? json['image_url'] ?? '',
      crowdStatus: json['crowd_status'] ?? json['crowdStatus'] ?? 'unknown',
      campaignId: json['campaign_id'] ?? json['campaignId'],
      remainingSlots: json['remaining_slots'] ?? json['remainingSlots'],
    );
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'eco':
        return 'Eco-Tourism';
      case 'cultural':
      case 'heritage':
        return 'Cultural Heritage';
      case 'food_trade':
      case 'food':
        return 'Food & Culinary';
      default:
        return category.toUpperCase();
    }
  }
}
