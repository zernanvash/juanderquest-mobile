class GeoFence {
  final double lat;
  final double lng;
  final int radiusMeters;

  const GeoFence({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  GeoFence copyWith({
    double? lat,
    double? lng,
    int? radiusMeters,
  }) =>
      GeoFence(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radiusMeters: radiusMeters ?? this.radiusMeters,
      );

  factory GeoFence.fromJson(Map<String, dynamic> json) => GeoFence(
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
        radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 100,
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'radius_meters': radiusMeters,
      };
}

abstract class TaskVerification {
  String get type;
  Map<String, dynamic> toJson();

  static TaskVerification fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'location';
    switch (type) {
      case 'qr':
        return QrVerification.fromJson(json);
      case 'photo':
        return PhotoVerification.fromJson(json);
      case 'ar':
        return ArVerification.fromJson(json);
      case 'action':
        return ActionVerification.fromJson(json);
      case 'location':
      default:
        return LocationVerification.fromJson(json);
    }
  }
}

class LocationVerification implements TaskVerification {
  @override
  String get type => 'location';
  final GeoFence fence;

  const LocationVerification({required this.fence});

  factory LocationVerification.fromJson(Map<String, dynamic> json) =>
      LocationVerification(
        fence: json['fence'] is Map<String, dynamic>
            ? GeoFence.fromJson(json['fence'] as Map<String, dynamic>)
            : const GeoFence(lat: 0, lng: 0, radiusMeters: 100),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'fence': fence.toJson(),
      };
}

class QrVerification implements TaskVerification {
  @override
  String get type => 'qr';
  final GeoFence fence;
  final String? markerCode;
  final String scanMode; // 'traveler_scans' | 'host_scans_traveler'

  const QrVerification({
    required this.fence,
    this.markerCode,
    this.scanMode = 'traveler_scans',
  });

  factory QrVerification.fromJson(Map<String, dynamic> json) => QrVerification(
        fence: json['fence'] is Map<String, dynamic>
            ? GeoFence.fromJson(json['fence'] as Map<String, dynamic>)
            : const GeoFence(lat: 0, lng: 0, radiusMeters: 80),
        markerCode: json['marker_code'] as String?,
        scanMode: json['scan_mode'] as String? ?? 'traveler_scans',
      );

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'fence': fence.toJson(),
      'scan_mode': scanMode,
    };
    if (markerCode != null && markerCode!.isNotEmpty) {
      map['marker_code'] = markerCode;
    }
    return map;
  }
}

class PhotoVerification implements TaskVerification {
  @override
  String get type => 'photo';
  final String prompt;
  final GeoFence? fence;
  final bool requireGps;

  const PhotoVerification({
    required this.prompt,
    this.fence,
    this.requireGps = false,
  });

  factory PhotoVerification.fromJson(Map<String, dynamic> json) =>
      PhotoVerification(
        prompt: json['prompt'] as String? ?? '',
        fence: json['fence'] is Map<String, dynamic>
            ? GeoFence.fromJson(json['fence'] as Map<String, dynamic>)
            : null,
        requireGps: json['require_gps'] == true,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'fence': fence?.toJson(),
        'require_gps': requireGps,
      };
}

class ArVerification implements TaskVerification {
  @override
  String get type => 'ar';
  final GeoFence fence;
  final String object; // 'token' | 'gem' | 'beacon' | 'box'
  final String color; // '#FFB703' | '#2D6A4F' | '#3B82F6' | '#E11D48'

  /// Plan 76: true when the creator placed the object with the AR camera, so
  /// [fence] centres on the object's own point. False = a map pin (approximate).
  final bool placedLive;

  /// GPS accuracy (m) when the object was placed live.
  final double? placementAccuracyM;

  const ArVerification({
    required this.fence,
    this.object = 'token',
    this.color = '#FFB703',
    this.placedLive = false,
    this.placementAccuracyM,
  });

  factory ArVerification.fromJson(Map<String, dynamic> json) {
    final placement = json['placement'];
    final live = placement is Map && placement['mode'] == 'ar_live';
    return ArVerification(
      fence: json['fence'] is Map<String, dynamic>
          ? GeoFence.fromJson(json['fence'] as Map<String, dynamic>)
          : const GeoFence(lat: 0, lng: 0, radiusMeters: 50),
      object: json['object'] as String? ?? 'token',
      color: json['color'] as String? ?? '#FFB703',
      placedLive: live,
      placementAccuracyM: live && placement['gps_accuracy_m'] is num
          ? (placement['gps_accuracy_m'] as num).toDouble()
          : null,
    );
  }

  /// Copies with changes. A new [fence] alone (a map pin) makes the placement
  /// approximate again unless [placedLive] says otherwise.
  ArVerification copyWith({
    GeoFence? fence,
    String? object,
    String? color,
    bool? placedLive,
    double? placementAccuracyM,
  }) {
    final live = placedLive ?? (fence == null && this.placedLive);
    return ArVerification(
      fence: fence ?? this.fence,
      object: object ?? this.object,
      color: color ?? this.color,
      placedLive: live,
      placementAccuracyM:
          live ? (placementAccuracyM ?? this.placementAccuracyM) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'fence': fence.toJson(),
        'object': object,
        'color': color,
        'placement': {
          'mode': placedLive ? 'ar_live' : 'map',
          if (placedLive && placementAccuracyM != null)
            'gps_accuracy_m':
                double.parse(placementAccuracyM!.toStringAsFixed(1)),
        },
      };
}

class ActionVerification implements TaskVerification {
  @override
  String get type => 'action';
  final Map<String, dynamic> task;

  const ActionVerification({required this.task});

  factory ActionVerification.fromJson(Map<String, dynamic> json) =>
      ActionVerification(
        task: json['task'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['task'] as Map)
            : <String, dynamic>{},
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'task': task,
      };
}

class BuilderTask {
  final String key;
  final int stepOrder;
  final String title;
  final String description;
  final bool required;
  final String checkpointType; // 'location' | 'qr' | 'photo' | 'ar' | 'action'
  final TaskVerification verification;

  const BuilderTask({
    required this.key,
    required this.stepOrder,
    required this.title,
    required this.description,
    required this.required,
    required this.checkpointType,
    required this.verification,
  });

  BuilderTask copyWith({
    String? key,
    int? stepOrder,
    String? title,
    String? description,
    bool? required,
    String? checkpointType,
    TaskVerification? verification,
  }) =>
      BuilderTask(
        key: key ?? this.key,
        stepOrder: stepOrder ?? this.stepOrder,
        title: title ?? this.title,
        description: description ?? this.description,
        required: required ?? this.required,
        checkpointType: checkpointType ?? this.checkpointType,
        verification: verification ?? this.verification,
      );

  factory BuilderTask.fromJson(Map<String, dynamic> json) {
    final cpType = json['checkpoint_type'] as String? ?? 'location';
    TaskVerification ver;
    if (json['verification'] is Map<String, dynamic>) {
      ver = TaskVerification.fromJson(json['verification'] as Map<String, dynamic>);
    } else {
      ver = LocationVerification(
        fence: GeoFence(
          lat: (json['gps_lat'] as num?)?.toDouble() ?? 0,
          lng: (json['gps_lng'] as num?)?.toDouble() ?? 0,
          radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 100,
        ),
      );
    }
    return BuilderTask(
      key: json['key'] as String? ?? 'task_${json['step_order'] ?? 1}',
      stepOrder: (json['step_order'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      required: json['required'] != false,
      checkpointType: cpType,
      verification: ver,
    );
  }

  Map<String, dynamic> toJson({bool isNew = false}) {
    final map = <String, dynamic>{
      'step_order': stepOrder,
      'title': title.trim(),
      'description': description.trim(),
      'required': required,
      'checkpoint_type': checkpointType,
      'verification': verification.toJson(),
    };
    if (!isNew && !key.startsWith('task_new_')) {
      map['key'] = key;
    }
    return map;
  }
}

class QuestCategoryOption {
  final String value;
  final String label;
  const QuestCategoryOption({required this.value, required this.label});
}

const List<QuestCategoryOption> questCategories = [
  QuestCategoryOption(value: 'eco', label: 'Eco-Tourism & Nature'),
  QuestCategoryOption(value: 'cultural', label: 'Cultural Heritage'),
  QuestCategoryOption(value: 'food_trade', label: 'Food & Local Trade'),
];

String questCategoryOrDefault(String? category) {
  if (category == null) return 'eco';
  return questCategories.any((c) => c.value == category) ? category : 'eco';
}

class QuestBuilderState {
  final String title;
  final String description;
  final String category;
  final int rewardPoints; // 50, 75, 100
  final String stepOrderMode; // 'sequential' | 'any'
  final String status; // 'draft' | 'published'
  final List<BuilderTask> tasks;
  final int version;

  const QuestBuilderState({
    required this.title,
    required this.description,
    required this.category,
    required this.rewardPoints,
    required this.stepOrderMode,
    required this.status,
    required this.tasks,
    required this.version,
  });

  QuestBuilderState copyWith({
    String? title,
    String? description,
    String? category,
    int? rewardPoints,
    String? stepOrderMode,
    String? status,
    List<BuilderTask>? tasks,
    int? version,
  }) =>
      QuestBuilderState(
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        rewardPoints: rewardPoints ?? this.rewardPoints,
        stepOrderMode: stepOrderMode ?? this.stepOrderMode,
        status: status ?? this.status,
        tasks: tasks ?? this.tasks,
        version: version ?? this.version,
      );

  Map<String, dynamic> toCreatePayload({required String targetStatus}) => {
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'reward_points': rewardPoints,
        'step_order_mode': stepOrderMode,
        'status': targetStatus,
        'tasks': tasks.map((t) => t.toJson(isNew: true)).toList(),
      };

  Map<String, dynamic> toPatchPayload({
    required String targetStatus,
    required int expectedVersion,
  }) =>
      {
        'expected_version': expectedVersion,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'reward_points': rewardPoints,
        'step_order_mode': stepOrderMode,
        'status': targetStatus,
        'tasks': tasks.map((t) => t.toJson(isNew: false)).toList(),
      };
}
