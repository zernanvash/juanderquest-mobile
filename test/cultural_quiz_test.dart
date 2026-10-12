import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/widgets/nearby_quiz_card.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/cultural_quiz_result_screen.dart';

void main() {
  testWidgets('NearbyQuizCard renders title, distance, and XP correctly', (tester) async {
    const invitation = NearbyQuizInvitationModel(
      quizId: 'quiz-1',
      destinationId: 'spot-1',
      destinationName: 'Patar Beach',
      municipality: 'Bolinao',
      title: 'Bolinao Coastal Heritage',
      description: 'Explore Cape Bolinao historical landmarks and culture.',
      radiusMeters: 200,
      distanceMeters: 45,
      xpReward: 25,
      timeLimitMinutes: 30,
      language: 'en',
      isCompleted: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NearbyQuizCard(invitation: invitation),
        ),
      ),
    );

    expect(find.text('Bolinao Coastal Heritage'), findsOneWidget);
    expect(find.text('Patar Beach'), findsOneWidget);
    expect(find.text('45m away'), findsOneWidget);
    expect(find.text('+25 XP'), findsOneWidget);
  });

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
      MaterialApp(
        home: CulturalQuizResultScreen(result: result),
      ),
    );

    expect(find.text('Quiz Passed!'), findsOneWidget);
    expect(find.text('+25 Explorer XP Awarded'), findsOneWidget);
    expect(find.text('1. When was Cape Bolinao Lighthouse built?'), findsOneWidget);
    expect(find.text('Constructed in 1905 by American, British, and Filipino engineers.'), findsOneWidget);
  });
}
