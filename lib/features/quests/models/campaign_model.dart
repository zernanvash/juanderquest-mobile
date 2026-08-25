class CampaignModel {
  final String id;
  final String hostId;
  final String hostName;
  final String title;
  final String category;
  final String locationName;
  final String municipality;
  final String bannerImageUrl;
  final String description;
  final String eventDate;
  final String startDate;
  final String endDate;
  final int totalBudgetMjdq;
  final int rewardPerParticipantMjdq;
  final int referralBountyMjdq;
  final int maxParticipants;
  final int reservedParticipants;
  final int completedParticipants;
  final List<String> preQuestRequirements;
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsRadiusMeters;
  final String status;
  final String createdAt;

  const CampaignModel({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.category,
    required this.locationName,
    required this.municipality,
    required this.bannerImageUrl,
    required this.description,
    required this.eventDate,
    required this.startDate,
    required this.endDate,
    required this.totalBudgetMjdq,
    required this.rewardPerParticipantMjdq,
    required this.referralBountyMjdq,
    required this.maxParticipants,
    required this.reservedParticipants,
    required this.completedParticipants,
    required this.preQuestRequirements,
    this.gpsLat,
    this.gpsLng,
    this.gpsRadiusMeters,
    required this.status,
    required this.createdAt,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> j) {
    final loc = j['location_name']?.toString() ?? '';
    final muni = j['municipality']?.toString() ??
        (loc.contains(',') ? loc.split(',')[0].trim() : loc);

    return CampaignModel(
      id: j['id'] ?? '',
      hostId: j['host_id'] ?? '',
      hostName: j['host_name'] ?? 'Pangasinan Tourism Office',
      title: j['title'] ?? '',
      category: j['category'] ?? 'eco',
      locationName: loc,
      municipality: muni,
      bannerImageUrl: j['banner_image_url'] ??
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
      description: j['description'] ?? '',
      eventDate: j['event_date'] ?? j['created_at'] ?? '',
      startDate: j['start_date'] ?? j['event_date'] ?? j['created_at'] ?? '',
      endDate: j['end_date'] ?? j['event_date'] ?? j['created_at'] ?? '',
      totalBudgetMjdq: (j['total_budget_mjdq'] as num?)?.toInt() ?? 0,
      rewardPerParticipantMjdq:
          (j['reward_per_participant_mjdq'] as num?)?.toInt() ?? 0,
      referralBountyMjdq: (j['referral_bounty_mjdq'] as num?)?.toInt() ?? 0,
      maxParticipants: (j['max_participants'] as num?)?.toInt() ?? 0,
      reservedParticipants: (j['reserved_participants'] as num?)?.toInt() ?? 0,
      completedParticipants: (j['completed_participants'] as num?)?.toInt() ?? 0,
      preQuestRequirements: List<String>.from(j['pre_quest_requirements'] ?? []),
      gpsLat: (j['gps_lat'] as num?)?.toDouble(),
      gpsLng: (j['gps_lng'] as num?)?.toDouble(),
      gpsRadiusMeters: (j['gps_radius_meters'] as num?)?.toDouble(),
      status: j['status'] ?? 'active',
      createdAt: j['created_at'] ?? '',
    );
  }
}
