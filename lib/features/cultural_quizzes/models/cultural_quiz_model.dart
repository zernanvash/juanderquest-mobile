class CulturalQuizModel {
  final String id;
  final String destinationId;
  final String destinationName;
  final String municipality;
  final double gpsLat;
  final double gpsLng;
  final String title;
  final String description;
  final String language;
  final int radiusMeters;
  final int xpReward;
  final int timeLimitMinutes;
  final int cooldownHours;
  final String status;
  final int version;
  final bool isCompleted;
  final String? activeAttemptId;
  final String? cooldownUntil;

  const CulturalQuizModel({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.municipality,
    required this.gpsLat,
    required this.gpsLng,
    required this.title,
    required this.description,
    required this.language,
    required this.radiusMeters,
    required this.xpReward,
    required this.timeLimitMinutes,
    required this.cooldownHours,
    required this.status,
    required this.version,
    required this.isCompleted,
    this.activeAttemptId,
    this.cooldownUntil,
  });

  factory CulturalQuizModel.fromJson(Map<String, dynamic> json) {
    return CulturalQuizModel(
      id: json['id'] as String? ?? '',
      destinationId: json['destination_id'] as String? ?? '',
      destinationName: json['destination_name'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 200,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 25,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 30,
      cooldownHours: (json['cooldown_hours'] as num?)?.toInt() ?? 24,
      status: json['status'] as String? ?? 'published',
      version: (json['version'] as num?)?.toInt() ?? 1,
      isCompleted: json['is_completed'] as bool? ?? false,
      activeAttemptId: json['active_attempt_id'] as String?,
      cooldownUntil: json['cooldown_until'] as String?,
    );
  }
}

class CulturalQuizOptionModel {
  final String id;
  final String questionId;
  final int ordinal;
  final String optionText;
  final bool? isCorrect;

  const CulturalQuizOptionModel({
    required this.id,
    required this.questionId,
    required this.ordinal,
    required this.optionText,
    this.isCorrect,
  });

  factory CulturalQuizOptionModel.fromJson(Map<String, dynamic> json) {
    return CulturalQuizOptionModel(
      id: json['id'] as String? ?? '',
      questionId: json['question_id'] as String? ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
      optionText: json['option_text'] as String? ?? '',
      isCorrect: json['is_correct'] as bool?,
    );
  }
}

class CulturalQuizQuestionModel {
  final String id;
  final String versionId;
  final int ordinal;
  final String questionText;
  final String explanation;
  final String? sourceUrl;
  final List<CulturalQuizOptionModel> options;

  const CulturalQuizQuestionModel({
    required this.id,
    required this.versionId,
    required this.ordinal,
    required this.questionText,
    required this.explanation,
    this.sourceUrl,
    required this.options,
  });

  factory CulturalQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return CulturalQuizQuestionModel(
      id: json['id'] as String? ?? '',
      versionId: json['version_id'] as String? ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
      questionText: json['question_text'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
      options: (json['options'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((o) => CulturalQuizOptionModel.fromJson(o))
          .toList(),
    );
  }
}

class CulturalQuizAttemptModel {
  final String id;
  final String quizId;
  final String versionId;
  final String rewardScopeId;
  final String userId;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final int? score;
  final int totalQuestions;
  final int xpAwarded;

  const CulturalQuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.versionId,
    required this.rewardScopeId,
    required this.userId,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    this.completedAt,
    this.score,
    required this.totalQuestions,
    required this.xpAwarded,
  });

  factory CulturalQuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return CulturalQuizAttemptModel(
      id: json['id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      versionId: json['version_id'] as String? ?? '',
      rewardScopeId: json['reward_scope_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'in_progress',
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      score: (json['score'] as num?)?.toInt(),
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 5,
      xpAwarded: (json['xp_awarded'] as num?)?.toInt() ?? 0,
    );
  }
}

class CulturalQuizGradeBreakdownItem {
  final String questionId;
  final String questionText;
  final String selectedOptionId;
  final String correctOptionId;
  final bool isCorrect;
  final String explanation;
  final String? sourceUrl;

  const CulturalQuizGradeBreakdownItem({
    required this.questionId,
    required this.questionText,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    required this.explanation,
    this.sourceUrl,
  });

  factory CulturalQuizGradeBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CulturalQuizGradeBreakdownItem(
      questionId: json['question_id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      selectedOptionId: json['selected_option_id'] as String? ?? '',
      correctOptionId: json['correct_option_id'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
    );
  }
}

class CulturalQuizGradedResultModel {
  final CulturalQuizAttemptModel attempt;
  final bool passed;
  final int score;
  final int totalQuestions;
  final int xpAwarded;
  final bool alreadyCompletedPrior;
  final String? cooldownUntil;
  final List<CulturalQuizGradeBreakdownItem> breakdown;

  const CulturalQuizGradedResultModel({
    required this.attempt,
    required this.passed,
    required this.score,
    required this.totalQuestions,
    required this.xpAwarded,
    required this.alreadyCompletedPrior,
    this.cooldownUntil,
    required this.breakdown,
  });

  factory CulturalQuizGradedResultModel.fromJson(Map<String, dynamic> json) {
    return CulturalQuizGradedResultModel(
      attempt: CulturalQuizAttemptModel.fromJson(Map<String, dynamic>.from(json['attempt'] as Map)),
      passed: json['passed'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 5,
      xpAwarded: (json['xp_awarded'] as num?)?.toInt() ?? 0,
      alreadyCompletedPrior: json['already_completed_prior'] as bool? ?? false,
      cooldownUntil: json['cooldown_until'] as String?,
      breakdown: (json['breakdown'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((b) => CulturalQuizGradeBreakdownItem.fromJson(b))
          .toList(),
    );
  }
}

class NearbyQuizInvitationModel {
  final String quizId;
  final String destinationId;
  final String destinationName;
  final String municipality;
  final String title;
  final String description;
  final int radiusMeters;
  final int distanceMeters;
  final int xpReward;
  final int timeLimitMinutes;
  final String language;
  final bool isCompleted;

  const NearbyQuizInvitationModel({
    required this.quizId,
    required this.destinationId,
    required this.destinationName,
    required this.municipality,
    required this.title,
    required this.description,
    required this.radiusMeters,
    required this.distanceMeters,
    required this.xpReward,
    required this.timeLimitMinutes,
    required this.language,
    required this.isCompleted,
  });

  factory NearbyQuizInvitationModel.fromJson(Map<String, dynamic> json) {
    return NearbyQuizInvitationModel(
      quizId: json['quiz_id'] as String? ?? '',
      destinationId: json['destination_id'] as String? ?? '',
      destinationName: json['destination_name'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 200,
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 25,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 30,
      language: json['language'] as String? ?? 'en',
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}
