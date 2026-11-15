import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../spots/utils/spot_location_handoff.dart';
import '../models/cultural_quiz_model.dart';

final culturalQuizApiClientProvider = Provider<ApiClient>((ref) {
  return ref.watch(apiClientProvider);
});

// Nearby quiz invitations query based on current position
final nearbyQuizzesProvider = FutureProvider.family<List<NearbyQuizInvitationModel>, ({double lat, double lng})>((ref, coords) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final client = ref.watch(culturalQuizApiClientProvider);

  try {
    final response = await client.dio.post(
      '/quizzes/nearby',
      data: {
        'lat': coords.lat,
        'lng': coords.lng,
      },
    );

    final data = response.data;
    if (data is! Map || data['data'] is! List) return const [];
    return (data['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map((item) => NearbyQuizInvitationModel.fromJson(item))
        .toList();
  } catch (e) {
    return const [];
  }
});

// Detail provider for a specific quiz
final culturalQuizDetailProvider = FutureProvider.family<CulturalQuizModel?, String>((ref, quizId) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final client = ref.watch(culturalQuizApiClientProvider);

  try {
    final response = await client.dio.get('/quizzes/$quizId');
    final data = response.data;
    if (data is! Map || data['data'] is! Map) return null;
    return CulturalQuizModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  } catch (e) {
    return null;
  }
});

// Cultural Quiz attempt controller
class CulturalQuizController extends StateNotifier<AsyncValue<CulturalQuizGradedResultModel?>> {
  final ApiClient _client;

  CulturalQuizController(this._client) : super(const AsyncValue.data(null));

  Future<({CulturalQuizAttemptModel attempt, List<CulturalQuizQuestionModel> questions})> startAttempt({
    required String quizId,
    required double lat,
    required double lng,
  }) async {
    final response = await _client.dio.post(
      '/quizzes/$quizId/attempts',
      data: {
        'lat': lat,
        'lng': lng,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final attempt = CulturalQuizAttemptModel.fromJson(Map<String, dynamic>.from(data['attempt'] as Map));
    final questions = (data['questions'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((q) => CulturalQuizQuestionModel.fromJson(q))
        .toList();

    return (attempt: attempt, questions: questions);
  }

  Future<CulturalQuizGradedResultModel> submitAttempt({
    required String attemptId,
    required List<({String questionId, String selectedOptionId})> answers,
  }) {
    return submitAttemptAnswers(
      attemptId: attemptId,
      answers: answers
          .map((a) => (
                questionId: a.questionId,
                selectedOptionId: a.selectedOptionId,
                orderedOptionIds: null,
              ))
          .toList(),
    );
  }

  Future<CulturalQuizGradedResultModel> submitAttemptAnswers({
    required String attemptId,
    required List<({String questionId, String? selectedOptionId, List<String>? orderedOptionIds})> answers,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _client.dio.put(
        '/quiz-attempts/$attemptId/submission',
        data: {
          'answers': answers
              .map((a) => {
                    'question_id': a.questionId,
                    if (a.selectedOptionId != null)
                      'selected_option_id': a.selectedOptionId,
                    if (a.orderedOptionIds != null)
                      'ordered_option_ids': a.orderedOptionIds,
                  })
              .toList(),
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final result = CulturalQuizGradedResultModel.fromJson(data);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<List<String>> useFiftyFifty({
    required String quizId,
    required String attemptId,
    required String questionId,
  }) async {
    final response = await _client.dio.post(
      '/quizzes/$quizId/attempts/$attemptId/lifeline',
      data: {
        'lifeline': 'fifty_fifty',
        'question_id': questionId,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    final eliminated = data?['eliminated_option_ids'] as List<dynamic>? ?? const [];
    return eliminated.map((e) => e.toString()).toList();
  }
}

final culturalQuizControllerProvider = StateNotifierProvider<CulturalQuizController, AsyncValue<CulturalQuizGradedResultModel?>>((ref) {
  final client = ref.watch(culturalQuizApiClientProvider);
  return CulturalQuizController(client);
});

final spotQuizzesProvider =
    FutureProvider.family<List<SpotQuizSummaryModel>, String>((ref, spotId) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final client = ref.watch(culturalQuizApiClientProvider);

  try {
    final response = await client.dio.get('/spots/$spotId/quizzes');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => SpotQuizSummaryModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((q) => q.quizId.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
});

List<NearbyQuizInvitationModel> sortNearbyQuizInvitations(
  List<NearbyQuizInvitationModel> items,
) {
  final copy = List<NearbyQuizInvitationModel>.of(items);
  copy.sort((a, b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    if (a.inRange != b.inRange) return a.inRange ? -1 : 1;
    if (a.distanceMeters != b.distanceMeters) {
      return a.distanceMeters.compareTo(b.distanceMeters);
    }
    return b.xpReward.compareTo(a.xpReward);
  });
  return copy;
}

class QuizRadarState {
  const QuizRadarState({
    this.items = const [],
    this.origin = 'default',
    this.loading = false,
    this.error,
    this.announcedIds = const {},
    this.dismissedIds = const {},
    this.lastQueryLat,
    this.lastQueryLng,
    this.lastQueryAt,
  });

  final List<NearbyQuizInvitationModel> items;
  final String origin;
  final bool loading;
  final String? error;
  final Set<String> announcedIds;
  final Set<String> dismissedIds;
  final double? lastQueryLat;
  final double? lastQueryLng;
  final DateTime? lastQueryAt;

  String get originLabel => switch (origin) {
        'gps' => 'Near you',
        'map' => 'Around your last map view',
        _ => 'Around Lingayen',
      };

  List<NearbyQuizInvitationModel> get inRangeIncomplete =>
      items.where((q) => q.inRange && !q.isCompleted).toList();

  List<NearbyQuizInvitationModel> get approachingIncomplete =>
      items.where((q) => !q.inRange && !q.isCompleted).toList();

  List<NearbyQuizInvitationModel> get completed =>
      items.where((q) => q.isCompleted).toList();

  bool get showBanner =>
      inRangeIncomplete.any((q) => !dismissedIds.contains(q.quizId));

  QuizRadarState copyWith({
    List<NearbyQuizInvitationModel>? items,
    String? origin,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<String>? announcedIds,
    Set<String>? dismissedIds,
    double? lastQueryLat,
    double? lastQueryLng,
    DateTime? lastQueryAt,
  }) {
    return QuizRadarState(
      items: items ?? this.items,
      origin: origin ?? this.origin,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      announcedIds: announcedIds ?? this.announcedIds,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      lastQueryLat: lastQueryLat ?? this.lastQueryLat,
      lastQueryLng: lastQueryLng ?? this.lastQueryLng,
      lastQueryAt: lastQueryAt ?? this.lastQueryAt,
    );
  }
}

typedef LastKnownPositionReader = Future<({double lat, double lng})?> Function();

Future<({double lat, double lng})?> defaultLastKnownPositionReader() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return null;
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null;
  }
}

class QuizRadarNotifier extends StateNotifier<QuizRadarState> {
  QuizRadarNotifier(
    this._ref, {
    DateTime Function()? clock,
    LastKnownPositionReader? lastKnownPositionReader,
    void Function()? onUnlockSfx,
  })  : _clock = clock ?? DateTime.now,
        _lastKnownPositionReader =
            lastKnownPositionReader ?? defaultLastKnownPositionReader,
        _onUnlockSfx = onUnlockSfx,
        super(const QuizRadarState());

  final Ref _ref;
  final DateTime Function() _clock;
  final LastKnownPositionReader _lastKnownPositionReader;
  final void Function()? _onUnlockSfx;

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Refreshes radar from Home using last-known position only (never prompts
  /// for location permission) or map/Lingayen fallback.
  Future<void> refreshFromHome({bool force = false}) async {
    var lat = lingayenAnchor.lat;
    var lng = lingayenAnchor.lng;
    var origin = 'default';

    final lastCenter = _ref.read(lastMapCenterProvider);
    if (lastCenter != null) {
      lat = lastCenter.lat;
      lng = lastCenter.lng;
      origin = 'map';
    }

    final lastKnown = await _lastKnownPositionReader();
    if (lastKnown != null) {
      lat = lastKnown.lat;
      lng = lastKnown.lng;
      origin = 'gps';
    }

    await checkWithLocation(lat: lat, lng: lng, origin: origin, force: force);
  }

  /// Queries `/quizzes/nearby` with `include_approaching: true`, throttled to
  /// >= 50 m moved AND >= 30 s elapsed since the last call unless [force].
  Future<void> checkWithLocation({
    required double lat,
    required double lng,
    required String origin,
    bool force = false,
  }) async {
    final now = _clock();
    if (!force &&
        state.lastQueryAt != null &&
        state.lastQueryLat != null &&
        state.lastQueryLng != null) {
      final elapsed = now.difference(state.lastQueryAt!);
      final movedMeters = _haversineMeters(
        state.lastQueryLat!,
        state.lastQueryLng!,
        lat,
        lng,
      );
      if (movedMeters < 50.0 || elapsed < const Duration(seconds: 30)) {
        return;
      }
    }

    state = state.copyWith(loading: true, clearError: true, origin: origin);

    try {
      final client = _ref.read(culturalQuizApiClientProvider);
      final response = await client.dio.post(
        '/quizzes/nearby',
        data: {
          'lat': lat,
          'lng': lng,
          'include_approaching': true,
        },
      );
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is! List) {
        state = state.copyWith(
          loading: false,
          lastQueryLat: lat,
          lastQueryLng: lng,
          lastQueryAt: now,
        );
        return;
      }

      final parsed = raw
          .whereType<Map>()
          .map(
            (item) => NearbyQuizInvitationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((q) => q.quizId.isNotEmpty)
          .toList();
      final sorted = sortNearbyQuizInvitations(parsed);

      final newlyInRange = sorted
          .where(
            (q) =>
                q.inRange &&
                !q.isCompleted &&
                !state.announcedIds.contains(q.quizId),
          )
          .map((q) => q.quizId)
          .toSet();

      if (newlyInRange.isNotEmpty && GameAudio.instance.buttonSounds.value) {
        if (_onUnlockSfx != null) {
          _onUnlockSfx!();
        } else {
          GameAudio.instance.playSfx('unlock');
        }
      }

      state = state.copyWith(
        items: sorted,
        origin: origin,
        loading: false,
        announcedIds: {...state.announcedIds, ...newlyInRange},
        lastQueryLat: lat,
        lastQueryLng: lng,
        lastQueryAt: now,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not check nearby quizzes.',
      );
    }
  }

  /// Marks a quiz done after a passing submit, so the unlock banner stops
  /// offering it before the next (throttled) radar check.
  void markCompleted(String quizId) {
    if (!state.items.any((q) => q.quizId == quizId && !q.isCompleted)) return;
    state = state.copyWith(
      items: sortNearbyQuizInvitations([
        for (final q in state.items) q.quizId == quizId ? q.asCompleted() : q,
      ]),
    );
  }

  void dismissBanner() {
    final activeIds = state.inRangeIncomplete.map((q) => q.quizId).toSet();
    if (activeIds.isEmpty) return;
    state = state.copyWith(
      dismissedIds: {...state.dismissedIds, ...activeIds},
    );
  }
}

final quizRadarProvider =
    StateNotifierProvider<QuizRadarNotifier, QuizRadarState>((ref) {
  ref.watch(authProvider.select((state) => state.user?.id));
  return QuizRadarNotifier(ref);
});
