import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../quests/models/quest_model.dart';
import '../engine/shapes_factory.dart';
import 'ar_hunt.dart';

/// Everything the AR screen needs about one Plan 43 AR task.
class ArTaskSpec {
  final String questId;
  final int stepOrder;
  final String title;
  final String description;
  final ArFence fence;
  final ShapeType shape;
  final String objectLabel;
  final Color color;

  const ArTaskSpec({
    required this.questId,
    required this.stepOrder,
    required this.title,
    this.description = '',
    required this.fence,
    required this.shape,
    this.objectLabel = 'Token',
    required this.color,
  });

  static const defaultRadiusMeters = 50.0;

  /// Builds the spec from the quest and its AR step. The fence falls back to
  /// the step's legacy GPS fields, then to the quest's own coordinates.
  factory ArTaskSpec.from(QuestModel quest, QuestStepModel step) {
    final cfg = step.verification ?? const <String, dynamic>{};
    final fenceMap = cfg['fence'];
    ArFence fence;
    if (fenceMap is Map &&
        fenceMap['lat'] is num &&
        fenceMap['lng'] is num) {
      fence = ArFence(
        lat: (fenceMap['lat'] as num).toDouble(),
        lng: (fenceMap['lng'] as num).toDouble(),
        radiusMeters: (fenceMap['radius_meters'] as num?)?.toDouble() ??
            defaultRadiusMeters,
      );
    } else if (step.gpsLat != null && step.gpsLng != null) {
      fence = ArFence(
        lat: step.gpsLat!,
        lng: step.gpsLng!,
        radiusMeters: step.radiusMeters?.toDouble() ?? defaultRadiusMeters,
      );
    } else {
      fence = ArFence(
        lat: quest.gpsLat,
        lng: quest.gpsLng,
        radiusMeters: defaultRadiusMeters,
      );
    }
    final shape = shapeFor(cfg['object']);
    return ArTaskSpec(
      questId: quest.id,
      stepOrder: step.order,
      title: step.title.isNotEmpty ? step.title : quest.title,
      description: step.description,
      fence: fence,
      shape: shape,
      objectLabel: labelForShape(shape),
      color: colorFor(cfg['color']),
    );
  }

  static String labelForShape(ShapeType shape) => switch (shape) {
        ShapeType.gem => '3D Gem',
        ShapeType.beacon => '3D Beacon',
        ShapeType.crate => 'Relic Box',
        ShapeType.token => 'Quest Token',
      };

  /// Plan 43 `ArCfg.object`: token | gem | beacon | box.
  static ShapeType shapeFor(Object? object) => switch (object) {
        'gem' => ShapeType.gem,
        'beacon' => ShapeType.beacon,
        'box' => ShapeType.crate,
        _ => ShapeType.token,
      };

  /// Plan 43 `ArCfg.color`: one of four brand colours, as `#RRGGBB`.
  static Color colorFor(Object? hex) {
    if (hex is String) {
      final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
      if (m != null) return Color(int.parse('FF${m.group(1)}', radix: 16));
    }
    return const Color(0xFFFFB703);
  }
}

/// Plan 43 endpoints used by the AR task.
class ArQuestApi {
  final Dio dio;
  final ArTaskSpec task;

  ArQuestApi(this.dio, this.task);

  Future<ArServerResult<ArChallenge>> requestChallenge(ArFix fix) async {
    try {
      final res = await dio.post(
        '/quests/${task.questId}/steps/${task.stepOrder}/ar-challenge',
        data: {
          'captured_lat': fix.lat,
          'captured_lng': fix.lng,
          'captured_accuracy': fix.accuracy,
        },
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is Map && data['challenge_token'] is String) {
        return ArServerResult.ok(ArChallenge(
          token: data['challenge_token'] as String,
          expiresAt: DateTime.tryParse('${data['expires_at']}') ??
              DateTime.now().add(const Duration(minutes: 10)),
        ));
      }
      return const ArServerResult.error(
          'BAD_RESPONSE', 'The server sent an unexpected reply.');
    } on DioException catch (e) {
      return _error(e);
    }
  }

  Future<ArServerResult<void>> submitEvidence(
      ArFix fix, String challengeToken) async {
    try {
      await dio.post(
        '/quests/${task.questId}/steps/${task.stepOrder}/evidence',
        data: {
          'idempotency_key': const Uuid().v4(),
          'captured_lat': fix.lat,
          'captured_lng': fix.lng,
          'captured_accuracy': fix.accuracy,
          'challenge_token': challengeToken,
        },
      );
      return const ArServerResult.ok(null);
    } on DioException catch (e) {
      return _error(e);
    }
  }

  static ArServerResult<T> _error<T>(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      final code = '${err['code'] ?? 'SERVER_ERROR'}';
      return ArServerResult.error(code, messageFor(code, err['message']));
    }
    return const ArServerResult.error('NETWORK',
        'No connection to JuanDerQuest. Check your internet and try again.');
  }

  /// Traveler-facing copy for each Plan 43 error code.
  static String messageFor(String code, Object? serverMessage) {
    switch (code) {
      case 'NO_ACTIVE_ATTEMPT':
        return 'Start this quest first, then come back to the AR task.';
      case 'STEP_NOT_READY':
        return 'Finish the earlier tasks first. This one unlocks after them.';
      case 'STEP_ALREADY_VERIFIED':
        return 'You already completed this AR task.';
      case 'NOT_AR_TASK':
        return 'This task is not an AR task.';
      case 'CHALLENGE_TOKEN_EXPIRED':
      case 'CHALLENGE_NONCE_REUSED':
      case 'INVALID_CHALLENGE_TOKEN':
        return 'The AR session expired. Close AR and open it again.';
    }
    if (serverMessage is String && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    return 'Something went wrong. Please try again.';
  }
}
