import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/app/router.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/core/widgets/in_app_banner.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/providers/cultural_quiz_provider.dart';

// Owner 2026-11-17: "remove the quiz unlocked prompt in map, just put any
// updates in notif, create an in-app banner if theres updates".
class _FixedRadar extends QuizRadarNotifier {
  _FixedRadar(super.ref, QuizRadarState initial) {
    state = initial;
  }

  @override
  Future<void> refreshFromHome({bool force = false}) async {}
}

NearbyQuizInvitationModel _quiz({bool done = false, int distance = 40}) =>
    NearbyQuizInvitationModel(
      quizId: 'q1',
      destinationId: 'spot-1',
      destinationName: 'Lingayen Capitol',
      municipality: 'Lingayen',
      title: 'Capitol Quiz',
      description: 'Quiz description',
      radiusMeters: 100,
      distanceMeters: distance,
      xpReward: 30,
      timeLimitMinutes: 10,
      language: 'en',
      isCompleted: done,
    );

Future<void> _pump(WidgetTester tester, QuizRadarState radar) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Text('home page')),
    GoRoute(
      path: '/cultural-quizzes/:id',
      builder: (_, s) => Text('quiz ${s.pathParameters['id']}'),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      quizRadarProvider.overrideWith((ref) => _FixedRadar(ref, radar)),
      routerProvider.overrideWithValue(router),
    ],
    child: MaterialApp.router(
      theme: AppTheme.pixel,
      routerConfig: router,
      builder: (context, child) => InAppBannerHost(child: child!),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a quiz you reach shows a banner; a tap opens it',
      (tester) async {
    await _pump(tester, QuizRadarState(items: [_quiz()]));
    expect(find.byKey(const ValueKey('in_app_banner')), findsOneWidget);
    expect(find.text('Quiz unlocked: Capitol Quiz'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('in_app_banner')));
    await tester.pumpAndSettle();
    expect(find.text('quiz q1'), findsOneWidget);
    expect(find.byKey(const ValueKey('in_app_banner')), findsNothing);
  });

  testWidgets('the banner hides itself after a few seconds', (tester) async {
    await _pump(tester, QuizRadarState(items: [_quiz()]));
    expect(find.byKey(const ValueKey('in_app_banner')), findsOneWidget);
    await tester.pump(InAppBannerController.showFor);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('in_app_banner')), findsNothing);
  });

  testWidgets('done or far quizzes raise no banner', (tester) async {
    await _pump(
      tester,
      QuizRadarState(items: [_quiz(done: true), _quiz(distance: 500)]),
    );
    expect(find.byKey(const ValueKey('in_app_banner')), findsNothing);
  });
}
