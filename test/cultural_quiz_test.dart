import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';

void main() {
  testWidgets('CulturalQuizResultScreen displays score and explanations', (tester) async {
    final result = CulturalQuizGradedResultModel(
      attempt: CulturalQuizAttemptModel(
        id: 'att-1',
        quizId: 'quiz-1',
        versionId: 'v-1',
        rewardScopeId: 'scope-1',
        userId: 'user-1',
        status: 'passed',
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().add(const Duration(minutes: 25)),
        completedAt: DateTime.now(),
        score: 5,
        totalQuestions: 5,
        xpAwarded: 25,
      ),
      passed: true,
      score: 5,
      totalQuestions: 5,
      xpAwarded: 25,
      alreadyCompletedPrior: false,
      breakdown: [
        const CulturalQuizGradeBreakdownItem(
          questionId: 'q-1',
          questionText: 'When was Cape Bolinao Lighthouse built?',
          selectedOptionId: 'opt-1',
          correctOptionId: 'opt-1',
          isCorrect: true,
          explanation: 'Constructed in 1905 by American, British, and Filipino engineers.',
          sourceUrl: 'https://en.wikipedia.org/wiki/Cape_Bolinao_Lighthouse',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CulturalQuizResultScreen(result: result),
        ),
      ),
    );

    expect(find.text('Quiz Passed!'), findsOneWidget);
    expect(find.text('+25 Explorer XP Awarded'), findsOneWidget);
    expect(find.text('1. When was Cape Bolinao Lighthouse built?'), findsOneWidget);
    expect(find.text('Constructed in 1905 by American, British, and Filipino engineers.'), findsOneWidget);
  });
}
