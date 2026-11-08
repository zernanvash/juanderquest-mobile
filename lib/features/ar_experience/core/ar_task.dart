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

  /// Plan 77 `verification.game`: 'collect' (find the relic) or a mini-game.
  final String game;

  /// The `verification.object` value ('token', 'gem', 'beacon', 'box').
  final String object;

  const ArTaskSpec({
    required this.questId,
    required this.stepOrder,
    required this.title,
    this.description = '',
    required this.fence,
    required this.shape,
    this.objectLabel = 'Token',
    required this.color,
    this.game = 'collect',
    this.object = 'token',
  });

  /// The mini-games a task can use (Plan 77 §4.1).
  static const games = [
    'tumbang_preso',
    'shooting_hoop',
    'pana',
    'pabitin_palayok',
    'sipa'
  ];

  bool get isGame => games.contains(game);

  static const defaultRadiusMeters = 50.0;

  /// Builds the spec from the quest and its AR step. The fence falls back to
  /// the step's legacy GPS fields, then to the quest's own coordinates.
  factory ArTaskSpec.from(QuestModel quest, QuestStepModel step) {
    final cfg = step.verification ?? const <String, dynamic>{};
    final fenceMap = cfg['fence'];
    ArFence fence;
    if (fenceMap is Map && fenceMap['lat'] is num && fenceMap['lng'] is num) {
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
      game: games.contains(cfg['game']) ? cfg['game'] as String : 'collect',
      object: cfg['object'] is String ? cfg['object'] as String : 'token',
    );
  }

  static String labelForShape(ShapeType shape) => switch (shape) {
        ShapeType.gem => '3D Gem',
        ShapeType.beacon => '3D Beacon',
        ShapeType.crate => 'Relic Box',
        ShapeType.token => 'Quest Token',
        _ => 'AR Object',
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

  /// The last challenge came with a hidden relic spot: the collect says so.
  bool _hiddenSpot = false;

  /// Plan 77: a game task on a phone without ARCore hunts the relic instead,
  /// and tells the server so.
  bool noArcoreFallback = false;

  /// Plan 77: starts a mini-game session (inside the task's area).
  Future<ArServerResult<ArGameSession>> startGame(ArFix fix) async {
    try {
      final res = await dio.post(
        '/quests/${task.questId}/steps/${task.stepOrder}/ar-game',
        data: {
          'captured_lat': fix.lat,
          'captured_lng': fix.lng,
          'captured_accuracy': fix.accuracy
        },
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is Map && data['session_id'] is String && data['seed'] is num) {
        return ArServerResult.ok(ArGameSession(
            id: data['session_id'] as String,
            seed: (data['seed'] as num).toInt()));
      }
      return const ArServerResult.error(
          'BAD_RESPONSE', 'The server sent an unexpected reply.');
    } on DioException catch (e) {
      return _error(e);
    }
  }

  /// Plan 77: records the result; the reply has the best score and the top 5 here.
  Future<ArServerResult<ArGameResult>> finishGame(String sessionId,
      {required int score,
      required bool passed,
      required Map<String, Object> stats}) async {
    try {
      final res = await dio.post('/ar-games/sessions/$sessionId/finish',
          data: {'score': score, 'passed': passed, 'stats': stats});
      final data = res.data is Map ? res.data['data'] : null;
      if (data is Map) {
        return ArServerResult.ok(
            ArGameResult.fromJson(Map<String, dynamic>.from(data)));
      }
      return const ArServerResult.error(
          'BAD_RESPONSE', 'The server sent an unexpected reply.');
    } on DioException catch (e) {
      return _error(e);
    }
  }

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
        // Newer servers hide the relic at a random spot in the area.
        final r = data['relic'];
        final relic = r is Map && r['lat'] is num && r['lng'] is num
            ? ArFence(
                lat: (r['lat'] as num).toDouble(),
                lng: (r['lng'] as num).toDouble(),
                radiusMeters:
                    (data['relic_reach_meters'] as num?)?.toDouble() ?? 12)
            : null;
        _hiddenSpot = relic != null;
        return ArServerResult.ok(ArChallenge(
          token: data['challenge_token'] as String,
          expiresAt: DateTime.tryParse('${data['expires_at']}') ??
              DateTime.now().add(const Duration(minutes: 10)),
          relic: relic,
        ));
      }
      return const ArServerResult.error(
          'BAD_RESPONSE', 'The server sent an unexpected reply.');
    } on DioException catch (e) {
      return _error(e);
    }
  }

  Future<ArServerResult<void>> submitEvidence(ArFix fix, String challengeToken,
      {String? gameSessionId}) async {
    try {
      await dio.post(
        '/quests/${task.questId}/steps/${task.stepOrder}/evidence',
        data: {
          'idempotency_key': const Uuid().v4(),
          'captured_lat': fix.lat,
          'captured_lng': fix.lng,
          'captured_accuracy': fix.accuracy,
          'challenge_token': challengeToken,
          // A game is played at the player's own line, not at the relic spot.
          if (_hiddenSpot && gameSessionId == null) 'relic_mode': 'hidden_spot',
          if (gameSessionId != null) 'ar_game_session_id': gameSessionId,
          if (noArcoreFallback && gameSessionId == null)
            'fallback': 'no_arcore',
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
      case 'RELIC_NOT_HERE':
        return 'The relic is not here. Keep searching the area.';
      case 'GAME_NOT_PASSED':
        return 'Win the game first, then collect.';
      case 'SCORE_REJECTED':
        return 'That game could not be counted. Play again.';
      case 'RATE_LIMITED':
        return 'Too many games for now. Take a break and try again later.';
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

/// Plan 77: a mini-game session from the server.
class ArGameSession {
  final String id;
  final int seed;
  const ArGameSession({required this.id, required this.seed});
}

/// One row of a mini-game board.
class ArBoardEntry {
  final int rank;
  final String name;
  final int score;
  final bool isSelf;
  const ArBoardEntry(
      {required this.rank,
      required this.name,
      required this.score,
      required this.isSelf});

  factory ArBoardEntry.fromJson(Map<String, dynamic> j) => ArBoardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        name: j['handle'] is String
            ? '@${j['handle']}'
            : '${j['display_name'] ?? 'Explorer'}',
        score: (j['score'] as num?)?.toInt() ?? 0,
        isSelf: j['is_self'] == true,
      );
}

/// Plan 77: what the server says after a game.
class ArGameResult {
  final bool passed;
  final int score;
  final int? best;
  final int? rankPlace;
  final int? rankWeek;
  final List<ArBoardEntry> top;
  final bool lowerIsBetter;

  const ArGameResult({
    required this.passed,
    required this.score,
    this.best,
    this.rankPlace,
    this.rankWeek,
    this.top = const [],
    this.lowerIsBetter = false,
  });

  factory ArGameResult.fromJson(Map<String, dynamic> j) => ArGameResult(
        passed: j['passed'] == true,
        score: (j['score'] as num?)?.toInt() ?? 0,
        best: (j['best'] as num?)?.toInt(),
        rankPlace: (j['rank_place'] as num?)?.toInt(),
        rankWeek: (j['rank_week'] as num?)?.toInt(),
        top: [
          for (final e in (j['top'] as List? ?? const []))
            if (e is Map) ArBoardEntry.fromJson(Map<String, dynamic>.from(e)),
        ],
        lowerIsBetter: j['lower_is_better'] == true,
      );
}
