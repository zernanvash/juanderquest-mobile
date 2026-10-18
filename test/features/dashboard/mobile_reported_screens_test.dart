// Regression tests for reported screens: submission history, recent activity, cultural quiz.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/widgets/nearby_quiz_card.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/submissions/screens/submission_history_screen.dart';
import '../../overflow_test.dart' as fixture;

const longTitle = 'Mangatarem Community Forest and River Cleanup';
final submissions = [
  SubmissionModel(
    id: 'audit-1',
    questTitle: longTitle,
    category: 'eco',
    status: 'pending',
    rewardPoints: 25,
    createdAt: '2026-10-17T01:00:00Z',
  ),
];

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.api, SubmissionState initial) {
    state = initial;
  }
  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

Future<void> render(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(320, 568),
  double scale = 2,
  SubmissionState? submissionState,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final api = ApiClient();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => fixture.InertAuthNotifier(
          api,
          AuthRefreshNotifier(),
          UserModel(
            id: 'audit-traveler',
            seedId: 'audit',
            displayName: 'Audit Traveler',
            email: '',
            avatarUrl: '',
            role: 'user',
            demoPoints: 0,
          ))),
      submissionProvider.overrideWith((ref) => _SubmissionFixture(
          api, submissionState ?? SubmissionState(submissions: submissions))),
      questProvider.overrideWith((ref) => fixture.InertQuestNotifier(api, [])),
      spotDiscoveryProvider
          .overrideWith((ref) => fixture.InertSpotDiscoveryNotifier(ref, [])),
      hiddenGemProvider.overrideWith((ref) async => []),
      choiceOverviewProvider.overrideWith((ref) async => const ChoiceOverview(
            current: null,
            nextOpensAt: null,
            nextClosesAt: null,
            nextTheme: null,
            previous: null,
            notice: null,
            votingEnabled: false,
          )),
      choiceEngagementProvider.overrideWith((ref) async =>
          const ChoiceEngagementSummary(
            currentStreak: 0,
            longestStreak: 0,
            nextMilestone: 1,
            verifiedVisits: 0,
            uniqueDestinations: 0,
            municipalities: 0,
            participations: 0,
            challenges: [],
          )),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('submission history populated at 320px, ${scale}x text',
        (tester) async {
      await render(tester, const SubmissionHistoryScreen(), scale: scale);
      final exc = tester.takeException();
      if (exc is FlutterError) {
        for (final d in exc.diagnostics) {
          debugPrint('DIAG: ${d.value}');
        }
      }
      expect(exc, isNull);
    });
  }
  testWidgets('submission history empty in landscape, 2x text', (tester) async {
    await render(tester, const SubmissionHistoryScreen(),
        size: const Size(568, 320), submissionState: SubmissionState());
    expect(tester.takeException(), isNull);
  });
  testWidgets('submission history distinguishes API failure from empty',
      (tester) async {
    await render(tester, const SubmissionHistoryScreen(),
        scale: 1,
        submissionState: SubmissionState(error: 'Failed to fetch submissions.'));
    expect(find.text('Connection Issue'), findsOneWidget);
    expect(find.text('No Submissions Yet'), findsNothing);
  });
  testWidgets('recent activity title is readable at 320px, 2x text',
      (tester) async {
    await render(tester, const DashboardScreen());
    await tester.scrollUntilVisible(find.text(longTitle), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.renderObject<RenderParagraph>(find.text(longTitle));
    expect(title.didExceedMaxLines, isFalse,
        reason: 'Populated recent activity title is clipped to one line.');
  });
  testWidgets('cultural quiz CTA title is readable at 320px, 2x text',
      (tester) async {
    await render(tester, const DashboardScreen());
    await tester.scrollUntilVisible(find.text('Cultural quizzes'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title =
        tester.renderObject<RenderParagraph>(find.text('Cultural quizzes'));
    expect(title.didExceedMaxLines, isFalse,
        reason: 'Primary cultural quiz CTA is clipped to one line.');
  });
  testWidgets('nearby cultural quiz invitation at 320px, 2x text',
      (tester) async {
    await render(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: NearbyQuizCard(
                invitation: NearbyQuizInvitationModel(
                    quizId: 'audit-quiz',
                    destinationId: 'audit-spot',
                    destinationName: 'Community Heritage Museum',
                    municipality: 'Dagupan',
                    title: 'Local food and history',
                    description: 'Learn about local heritage.',
                    radiusMeters: 200,
                    distanceMeters: 125,
                    xpReward: 25,
                    timeLimitMinutes: 10,
                    language: 'en',
                    isCompleted: false)),
          ),
        ));
    expect(tester.takeException(), isNull);
  });
}
