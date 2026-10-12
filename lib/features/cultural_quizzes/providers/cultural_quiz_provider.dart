import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
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
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _client.dio.put(
        '/quiz-attempts/$attemptId/submission',
        data: {
          'answers': answers.map((a) => {
            'question_id': a.questionId,
            'selected_option_id': a.selectedOptionId,
          }).toList(),
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
}

final culturalQuizControllerProvider = StateNotifierProvider<CulturalQuizController, AsyncValue<CulturalQuizGradedResultModel?>>((ref) {
  final client = ref.watch(culturalQuizApiClientProvider);
  return CulturalQuizController(client);
});
