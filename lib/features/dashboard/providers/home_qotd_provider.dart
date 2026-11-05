import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'home_daily_provider.dart';

class HomeQotdOption {
  const HomeQotdOption({
    required this.id,
    required this.ordinal,
    required this.text,
  });

  final String id;
  final int ordinal;
  final String text;

  factory HomeQotdOption.fromJson(Map<String, dynamic> json) => HomeQotdOption(
        id: json['id']?.toString() ?? '',
        ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
        text: json['text']?.toString() ?? '',
      );
}

class HomeQotdState {
  const HomeQotdState({
    required this.date,
    required this.questionId,
    required this.questionText,
    required this.quizTitle,
    required this.options,
    this.answered = false,
    this.selectedOptionId,
    this.correct = false,
    this.correctOptionId,
    this.explanation,
    this.sourceUrl,
    this.submitting = false,
    this.answerError,
  });

  final String date;
  final String questionId;
  final String questionText;
  final String quizTitle;
  final List<HomeQotdOption> options;
  final bool answered;
  final String? selectedOptionId;
  final bool correct;
  final String? correctOptionId;
  final String? explanation;
  final String? sourceUrl;
  final bool submitting;
  final String? answerError;

  bool get hasQuestion => questionText.isNotEmpty;

  HomeQotdState copyWith({
    bool? answered,
    String? selectedOptionId,
    bool? correct,
    String? correctOptionId,
    String? explanation,
    String? sourceUrl,
    bool? submitting,
    String? answerError,
    bool clearAnswerError = false,
  }) =>
      HomeQotdState(
        date: date,
        questionId: questionId,
        questionText: questionText,
        quizTitle: quizTitle,
        options: options,
        answered: answered ?? this.answered,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        correct: correct ?? this.correct,
        correctOptionId: correctOptionId ?? this.correctOptionId,
        explanation: explanation ?? this.explanation,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        submitting: submitting ?? this.submitting,
        answerError:
            clearAnswerError ? null : (answerError ?? this.answerError),
      );

  factory HomeQotdState.fromJson(Map<String, dynamic> data) {
    final question =
        (data['question'] as Map?)?.cast<String, dynamic>() ?? const {};
    final answer =
        (data['answer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final optionsRaw = question['options'];
    return HomeQotdState(
      date: data['date']?.toString() ?? '',
      questionId: question['id']?.toString() ?? '',
      questionText: question['text']?.toString() ?? '',
      quizTitle: question['quiz_title']?.toString() ?? '',
      options: (optionsRaw is List ? optionsRaw : const [])
          .whereType<Map>()
          .map((row) => HomeQotdOption.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      answered: data['answered'] == true,
      selectedOptionId: answer['option_id']?.toString(),
      correct: answer['correct'] == true,
      correctOptionId: null,
      explanation: answer['explanation']?.toString(),
      sourceUrl: answer['source_url']?.toString(),
    );
  }
}

class HomeQotdNotifier extends StateNotifier<AsyncValue<HomeQotdState>> {
  HomeQotdNotifier(this._ref, {bool autoLoad = true})
      : super(const AsyncValue.loading()) {
    if (autoLoad) load();
  }

  final Ref _ref;
  bool _busy = false;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _ref.read(apiClientProvider).dio.get('/qotd');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) {
        throw StateError('Question of the Day response was not understood.');
      }
      state = AsyncValue.data(
        HomeQotdState.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> answer(String optionId) async {
    if (_busy) return;
    final current = state.asData?.value;
    if (current == null || current.answered || !current.hasQuestion) return;
    _busy = true;
    state = AsyncValue.data(
      current.copyWith(submitting: true, clearAnswerError: true),
    );
    try {
      final response = await _ref
          .read(apiClientProvider)
          .dio
          .post('/qotd/answer', data: {'option_id': optionId});
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) {
        throw StateError('Question of the Day answer was not understood.');
      }
      final correctOption = data['correct_option_id']?.toString();
      state = AsyncValue.data(
        current.copyWith(
          answered: true,
          selectedOptionId: optionId,
          correct: data['correct'] == true,
          correctOptionId: correctOption,
          explanation: data['explanation']?.toString(),
          sourceUrl: data['source_url']?.toString(),
          submitting: false,
          clearAnswerError: true,
        ),
      );
      _ref.invalidate(homeDailyProvider);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        await load();
      } else {
        state = AsyncValue.data(
          current.copyWith(
            submitting: false,
            answerError: 'Could not submit your answer. Try again.',
          ),
        );
      }
    } catch (_) {
      state = AsyncValue.data(
        current.copyWith(
          submitting: false,
          answerError: 'Could not submit your answer. Try again.',
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() => load();
}

final homeQotdProvider =
    StateNotifierProvider<HomeQotdNotifier, AsyncValue<HomeQotdState>>(
  (ref) => HomeQotdNotifier(ref),
);
