class QuestStepModel {
  final int order;
  final String title;
  final String description;
  final String checkpointType;
  final bool required;
  final String status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final String? hint;
  final double? gpsLat;
  final double? gpsLng;
  final int? radiusMeters;
  final String? key;
  final Map<String, dynamic>? verification;

  const QuestStepModel({
    required this.order,
    required this.title,
    required this.description,
    required this.checkpointType,
    required this.required,
    this.status = 'not_started',
    this.rejectionReason,
    this.verifiedAt,
    this.hint,
    this.gpsLat,
    this.gpsLng,
    this.radiusMeters,
    this.key,
    this.verification,
  });

  bool get isVerified => status == 'verified';
  bool get isPendingReview => status == 'pending_review';
  bool get isReady => status == 'ready';
  bool get isNeedsChanges => status == 'needs_changes';
  bool get isLocked => status == 'not_started';

  QuestStepModel copyWith({
    int? order,
    String? title,
    String? description,
    String? checkpointType,
    bool? required,
    String? status,
    String? rejectionReason,
    DateTime? verifiedAt,
    String? hint,
    double? gpsLat,
    double? gpsLng,
    int? radiusMeters,
    String? key,
    Map<String, dynamic>? verification,
  }) {
    return QuestStepModel(
      order: order ?? this.order,
      title: title ?? this.title,
      description: description ?? this.description,
      checkpointType: checkpointType ?? this.checkpointType,
      required: required ?? this.required,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      hint: hint ?? this.hint,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      key: key ?? this.key,
      verification: verification ?? this.verification,
    );
  }

  factory QuestStepModel.fromJson(Map<String, dynamic> json) => QuestStepModel(
        order: (json['step_order'] as num?)?.toInt() ?? (json['order'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        checkpointType: json['checkpoint_type'] as String? ?? json['checkpointType'] as String? ?? 'action',
        required: json['required'] as bool? ?? true,
        status: json['status'] as String? ?? 'not_started',
        rejectionReason: json['rejection_reason'] as String?,
        verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
        hint: json['hint'] as String?,
        gpsLat: (json['gps_lat'] as num?)?.toDouble(),
        gpsLng: (json['gps_lng'] as num?)?.toDouble(),
        radiusMeters: (json['radius_meters'] as num?)?.toInt(),
        key: json['key'] as String?,
        verification: json['verification'] is Map<String, dynamic>
            ? json['verification'] as Map<String, dynamic>
            : null,
      );
}

class QuestAttemptModel {
  final String id;
  final String questId;
  final String userId;
  final int version;
  final int currentStep;
  final int totalSteps;
  final int verifiedSteps;
  final int requiredSteps;
  final String status;
  final String stepOrderMode;
  final List<QuestStepModel> steps;
  final String? reviewNotes;

  const QuestAttemptModel({
    required this.id,
    required this.questId,
    required this.userId,
    this.version = 1,
    this.currentStep = 1,
    this.totalSteps = 1,
    this.verifiedSteps = 0,
    this.requiredSteps = 1,
    this.status = 'in_progress',
    this.stepOrderMode = 'sequential',
    this.steps = const [],
    this.reviewNotes,
  });

  bool get isCompleted => status == 'completed';
  bool get isSubmitted => status == 'submitted';
  bool get isInProgress => status == 'in_progress';

  factory QuestAttemptModel.fromJson(Map<String, dynamic> json) {
    return QuestAttemptModel(
      id: json['id'] as String? ?? '',
      questId: json['quest_id'] as String? ?? json['questId'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      currentStep: (json['current_step'] as num?)?.toInt() ?? 1,
      totalSteps: (json['total_steps'] as num?)?.toInt() ?? 1,
      verifiedSteps: (json['verified_steps'] as num?)?.toInt() ?? 0,
      requiredSteps: (json['required_steps'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'in_progress',
      stepOrderMode: json['step_order_mode'] as String? ?? 'sequential',
      steps: (json['steps'] is List ? json['steps'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(QuestStepModel.fromJson)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      reviewNotes: json['review_notes'] as String?,
    );
  }
}

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
  final String markerImageUrl;
  final String crowdStatus;
  final String? campaignId;
  final int? remainingSlots;
  final List<QuestStepModel> steps;
  final String? authorId;
  final String stepOrderMode;
  final QuestFundingSummary? funding;

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
    required this.markerImageUrl,
    this.crowdStatus = 'unknown',
    this.campaignId,
    this.remainingSlots,
    this.steps = const [],
    this.authorId,
    this.stepOrderMode = 'sequential',
    this.funding,
  });

  int get allowedRadiusMeters => radiusMeters;
  String? get imageUrl => markerImageUrl.isNotEmpty ? markerImageUrl : null;

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'eco',
      locationName: json['location_name'] ?? 'Location unavailable',
      gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: json['radius_meters'] ?? 200,
      rewardPoints: json['reward_points'] ?? 50,
      markerImageUrl: json['marker_image_url'] ?? json['image_url'] ?? '',
      crowdStatus: json['crowd_status'] ?? json['crowdStatus'] ?? 'unknown',
      campaignId: json['campaign_id'] ?? json['campaignId'],
      remainingSlots: json['remaining_slots'] ?? json['remainingSlots'],
      steps: (json['steps'] is List ? json['steps'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(QuestStepModel.fromJson)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      authorId: json['author_id'] as String? ?? json['authorId'] as String?,
      stepOrderMode: json['step_order_mode'] as String? ?? 'sequential',
      funding: json['funding'] is Map<String,dynamic>
          ? QuestFundingSummary.fromJson(json['funding'] as Map<String,dynamic>)
          : null,
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

class QuestFundingSummary {
  final String status;
  final String mode;
  final DateTime? endsAt;
  final int rewardPoints;
  final int completionsLeftEstimate;
  final List<Map<String,dynamic>> sponsors;
  final Map<String,dynamic>? perk;
  const QuestFundingSummary({required this.status,required this.mode,this.endsAt,required this.rewardPoints,required this.completionsLeftEstimate,this.sponsors=const [],this.perk});
  factory QuestFundingSummary.fromJson(Map<String,dynamic> json)=>QuestFundingSummary(
    status:json['status']?.toString()??'unknown',mode:json['mode']?.toString()??'budget',
    endsAt:DateTime.tryParse(json['ends_at']?.toString()??''),rewardPoints:(json['reward_points'] as num?)?.toInt()??0,
    completionsLeftEstimate:(json['completions_left_estimate'] as num?)?.toInt()??0,
    sponsors:(json['sponsors'] is List ? (json['sponsors'] as List).whereType<Map<String,dynamic>>().toList() : const []),
    perk:json['perk'] is Map<String,dynamic>?json['perk'] as Map<String,dynamic>:null,
  );
}
