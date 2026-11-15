import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/providers/cultural_quiz_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_play_screen.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';

class _RecordingQuizController extends CulturalQuizController {
  _RecordingQuizController(this._result) : super(ApiClient());

  final CulturalQuizGradedResultModel _result;
  List<({String questionId, String? selectedOptionId, List<String>? orderedOptionIds})>?
      lastSubmittedAnswers;

  @override
  Future<CulturalQuizGradedResultModel> submitAttemptAnswers({
    required String attemptId,
    required List<({String questionId, String? selectedOptionId, List<String>? orderedOptionIds})>
        answers,
  }) async {
    lastSubmittedAnswers = answers;
    return _result;
  }
}

void main() {
  test('models parse questionType, mediaUrl, nullable ordinal, and correctOrder', () {
    final q = CulturalQuizQuestionModel.fromJson({
      'id': 'q-seq',
      'version_id': 'v-1',
      'ordinal': 4,
      'question_type': 'sequence_order',
      'media_url': null,
      'question_text': 'Order the events',
      'explanation': 'Chronological order',
      'options': [
        {'id': 'o-1', 'question_id': 'q-seq', 'option_text': 'First'},
        {'id': 'o-2', 'question_id': 'q-seq', 'option_text': 'Second'},
      ],
    });
    expect(q.questionType, 'sequence_order');
    expect(q.options.first.ordinal, isNull);

    final item = CulturalQuizGradeBreakdownItem.fromJson({
      'question_id': 'q-seq',
      'question_type': 'sequence_order',
      'question_text': 'Order the events',
      'selected_option_id': '',
      'correct_option_id': '',
      'correct_order': ['First', 'Second', 'Third'],
      'is_correct': true,
      'explanation': 'Chronological order',
    });
    expect(item.questionType, 'sequence_order');
    expect(item.correctOrder, ['First', 'Second', 'Third']);
  });

  testWidgets('play screen renders 4 question types, clickable pips, hides 50/50 on TF/seq, and submits sequence',
      (tester) async {
    final fakeResult = CulturalQuizGradedResultModel(
      attempt: CulturalQuizAttemptModel(
        id: 'att-1',
        quizId: 'quiz-1',
        versionId: 'v-1',
        rewardScopeId: 'scope-1',
        userId: 'u-1',
        status: 'passed',
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        completedAt: DateTime.now(),
        score: 4,
        totalQuestions: 4,
        xpAwarded: 50,
      ),
      passed: true,
      score: 4,
      totalQuestions: 4,
      xpAwarded: 50,
      alreadyCompletedPrior: false,
      breakdown: const [],
    );
    final controller = _RecordingQuizController(fakeResult);

    final session = (
      attempt: CulturalQuizAttemptModel(
        id: 'att-1',
        quizId: 'quiz-1',
        versionId: 'v-1',
        rewardScopeId: 'scope-1',
        userId: 'u-1',
        status: 'in_progress',
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        totalQuestions: 4,
        xpAwarded: 0,
      ),
      questions: const [
        CulturalQuizQuestionModel(
          id: 'q1',
          versionId: 'v-1',
          ordinal: 1,
          questionType: 'multiple_choice',
          questionText: 'MC Question',
          explanation: 'MC expl',
          options: [
            CulturalQuizOptionModel(id: 'mc1', questionId: 'q1', ordinal: 1, optionText: 'A'),
            CulturalQuizOptionModel(id: 'mc2', questionId: 'q1', ordinal: 2, optionText: 'B'),
            CulturalQuizOptionModel(id: 'mc3', questionId: 'q1', ordinal: 3, optionText: 'C'),
            CulturalQuizOptionModel(id: 'mc4', questionId: 'q1', ordinal: 4, optionText: 'D'),
          ],
        ),
        CulturalQuizQuestionModel(
          id: 'q2',
          versionId: 'v-1',
          ordinal: 2,
          questionType: 'true_false',
          questionText: 'TF Question',
          explanation: 'TF expl',
          options: [
            CulturalQuizOptionModel(id: 'tf1', questionId: 'q2', ordinal: 1, optionText: 'Fact'),
            CulturalQuizOptionModel(id: 'tf2', questionId: 'q2', ordinal: 2, optionText: 'Myth'),
          ],
        ),
        CulturalQuizQuestionModel(
          id: 'q3',
          versionId: 'v-1',
          ordinal: 3,
          questionType: 'photo_clue',
          mediaUrl: 'https://juanderquest.app/media/spot.jpg',
          questionText: 'Photo Question',
          explanation: 'Photo expl',
          options: [
            CulturalQuizOptionModel(id: 'ph1', questionId: 'q3', ordinal: 1, optionText: 'P1'),
            CulturalQuizOptionModel(id: 'ph2', questionId: 'q3', ordinal: 2, optionText: 'P2'),
            CulturalQuizOptionModel(id: 'ph3', questionId: 'q3', ordinal: 3, optionText: 'P3'),
            CulturalQuizOptionModel(id: 'ph4', questionId: 'q3', ordinal: 4, optionText: 'P4'),
          ],
        ),
        CulturalQuizQuestionModel(
          id: 'q4',
          versionId: 'v-1',
          ordinal: 4,
          questionType: 'sequence_order',
          questionText: 'Seq Question',
          explanation: 'Seq expl',
          options: [
            CulturalQuizOptionModel(id: 'sq1', questionId: 'q4', optionText: 'Step One'),
            CulturalQuizOptionModel(id: 'sq2', questionId: 'q4', optionText: 'Step Two'),
            CulturalQuizOptionModel(id: 'sq3', questionId: 'q4', optionText: 'Step Three'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          culturalQuizControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: CulturalQuizPlayScreen(quizId: 'quiz-1', session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Q1: MC shows MULTIPLE CHOICE pill and 50/50 button
    expect(find.text('MULTIPLE CHOICE'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_lifeline_fifty_fifty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz_option_mc1')));
    await tester.pumpAndSettle();

    // Jump directly to Q2 via pip
    await tester.tap(find.byKey(const ValueKey('quiz_pip_1')));
    await tester.pumpAndSettle();
    expect(find.text('MYTH VS FACT'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_lifeline_fifty_fifty')), findsNothing);
    expect(find.text('FACT'), findsOneWidget);
    expect(find.text('MYTH'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz_option_tf1')));
    await tester.pumpAndSettle();

    // Jump to Q3 (photo_clue)
    await tester.tap(find.byKey(const ValueKey('quiz_pip_2')));
    await tester.pumpAndSettle();
    expect(find.text('PHOTO CLUE'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_photo_clue_frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_lifeline_fifty_fifty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz_option_ph2')));
    await tester.pumpAndSettle();

    // Jump to Q4 (sequence_order)
    await tester.tap(find.byKey(const ValueKey('quiz_pip_3')));
    await tester.pumpAndSettle();
    expect(find.text('SEQUENCE ORDER'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_lifeline_fifty_fifty')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quiz_sequence_option_sq2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz_sequence_reset')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz_sequence_reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz_sequence_reset')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quiz_sequence_option_sq1')));
    await tester.tap(find.byKey(const ValueKey('quiz_sequence_option_sq2')));
    await tester.tap(find.byKey(const ValueKey('quiz_sequence_option_sq3')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quiz_submit')));
    await tester.pump();

    expect(controller.lastSubmittedAnswers, isNotNull);
    expect(controller.lastSubmittedAnswers![0].selectedOptionId, 'mc1');
    expect(controller.lastSubmittedAnswers![3].orderedOptionIds, ['sq1', 'sq2', 'sq3']);
  });

  testWidgets('result screen renders rank chip, rolling score, and sequence Correct order',
      (tester) async {
    final result = CulturalQuizGradedResultModel(
      attempt: CulturalQuizAttemptModel(
        id: 'att-5',
        quizId: 'quiz-5',
        versionId: 'v-1',
        rewardScopeId: 'scope-1',
        userId: 'u-1',
        status: 'passed',
        startedAt: DateTime.now(),
        expiresAt: DateTime.now(),
        completedAt: DateTime.now(),
        score: 5,
        totalQuestions: 5,
        xpAwarded: 75,
      ),
      passed: true,
      score: 5,
      totalQuestions: 5,
      xpAwarded: 75,
      alreadyCompletedPrior: false,
      breakdown: const [
        CulturalQuizGradeBreakdownItem(
          questionId: 'q-seq',
          questionType: 'sequence_order',
          questionText: 'Order the route stops',
          selectedOptionId: '',
          correctOptionId: '',
          correctOrder: ['Lingayen', 'Alaminos', 'Bolinao'],
          isCorrect: false,
          explanation: 'Travel west along the coast.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CulturalQuizResultScreen(result: result),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiz Passed!'), findsOneWidget);
    expect(find.text('CULTURAL MASTER'), findsOneWidget);
    expect(find.text('+75 Explorer XP Awarded'), findsOneWidget);
    expect(find.text('Correct order: 1. Lingayen 2. Alaminos 3. Bolinao'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_result_explore')), findsOneWidget);
  });
}
