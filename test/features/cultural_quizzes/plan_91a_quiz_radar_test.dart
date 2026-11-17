import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/cultural_quizzes/models/cultural_quiz_model.dart';
import 'package:juanderquest_app/features/cultural_quizzes/providers/cultural_quiz_provider.dart';
import 'package:juanderquest_app/features/cultural_quizzes/screens/nearby_quizzes_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';

class _FakeQuizApiClient extends ApiClient {
  _FakeQuizApiClient(this.handler);

  final Future<Response<dynamic>> Function(RequestOptions options) handler;

  @override
  Dio get dio {
    final d = Dio();
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, h) async {
          try {
            h.resolve(await handler(options));
          } catch (e) {
            h.reject(DioException(requestOptions: options, error: e));
          }
        },
      ),
    );
    return d;
  }
}

class _FixedRadarNotifier extends QuizRadarNotifier {
  _FixedRadarNotifier(super.ref, QuizRadarState initial) {
    state = initial;
  }

  @override
  Future<void> refreshFromHome({bool force = false}) async {}
}

NearbyQuizInvitationModel _inv({
  required String id,
  required String title,
  required int distance,
  required int radius,
  required int xp,
  bool? inRange,
  bool isCompleted = false,
}) {
  return NearbyQuizInvitationModel(
    quizId: id,
    destinationId: 'spot-1',
    destinationName: 'Lingayen Capitol',
    municipality: 'Lingayen',
    title: title,
    description: 'Quiz description',
    radiusMeters: radius,
    distanceMeters: distance,
    inRange: inRange,
    xpReward: xp,
    timeLimitMinutes: 10,
    language: 'en',
    isCompleted: isCompleted,
  );
}

void main() {
  test(
      'sortNearbyQuizInvitations orders incomplete, inRange, distance asc, xp desc',
      () {
    final sorted = sortNearbyQuizInvitations([
      _inv(
          id: 'done',
          title: 'Done',
          distance: 10,
          radius: 100,
          xp: 90,
          isCompleted: true),
      _inv(
          id: 'far',
          title: 'Far',
          distance: 250,
          radius: 100,
          xp: 80,
          inRange: false),
      _inv(
          id: 'low',
          title: 'LowXP',
          distance: 20,
          radius: 100,
          xp: 15,
          inRange: true),
      _inv(
          id: 'high',
          title: 'HighXP',
          distance: 20,
          radius: 100,
          xp: 60,
          inRange: true),
    ]);

    expect(
      sorted.map((q) => q.quizId).toList(),
      ['high', 'low', 'far', 'done'],
    );
  });

  test(
      'NearbyQuizInvitationModel.inRange falls back to distance <= radius when missing',
      () {
    final inside = NearbyQuizInvitationModel.fromJson({
      'quiz_id': 'q1',
      'radius_meters': 100,
      'distance_meters': 100,
    });
    final outside = NearbyQuizInvitationModel.fromJson({
      'quiz_id': 'q2',
      'radius_meters': 100,
      'distance_meters': 101,
    });
    expect(inside.inRange, isTrue);
    expect(outside.inRange, isFalse);
  });

  test(
      'radar throttle skips calls under 50m or under 30s and Home never requests permission',
      () async {
    var apiCalls = 0;
    var now = DateTime(2026, 11, 15, 10, 0, 0);
    final fakeClient = _FakeQuizApiClient((options) async {
      apiCalls++;
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'data': [
            {
              'quiz_id': 'q1',
              'destination_id': 's1',
              'destination_name': 'Capitol',
              'municipality': 'Lingayen',
              'title': 'Capitol Quiz',
              'description': 'Desc',
              'radius_meters': 100,
              'distance_meters': 30,
              'in_range': true,
              'xp_reward': 35,
              'time_limit_minutes': 10,
              'language': 'en',
              'is_completed': false,
            }
          ],
        },
      );
    });

    final container = ProviderContainer(
      overrides: [
        culturalQuizApiClientProvider.overrideWithValue(fakeClient),
      ],
    );
    addTearDown(container.dispose);

    // Direct QuizRadarNotifier with injected clock & no-permission reader
    final testNotifier = QuizRadarNotifier(
      container.read(Provider((ref) => ref)),
      clock: () => now,
      lastKnownPositionReader: () async => null,
    );
    addTearDown(testNotifier.dispose);

    // Home refresh uses Lingayen fallback without requesting permission
    await testNotifier.refreshFromHome();
    expect(apiCalls, 1);
    expect(testNotifier.state.origin, 'default');
    expect(testNotifier.state.originLabel, 'Around Lingayen');

    // Move ~100m, only 10s elapsed -> throttled
    now = now.add(const Duration(seconds: 10));
    await testNotifier.checkWithLocation(
        lat: 16.025, lng: 120.23, origin: 'gps');
    expect(apiCalls, 1);

    // 40s elapsed total, but 0m moved from last query -> throttled
    now = now.add(const Duration(seconds: 30));
    await testNotifier.checkWithLocation(
      lat: testNotifier.state.lastQueryLat!,
      lng: testNotifier.state.lastQueryLng!,
      origin: 'gps',
    );
    expect(apiCalls, 1);

    // >= 50m moved AND >= 30s elapsed -> fires!
    await testNotifier.checkWithLocation(
        lat: 16.030, lng: 120.23, origin: 'gps');
    expect(apiCalls, 2);
  });

  test('markCompleted moves a passed quiz to completed and drops the banner',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = _FixedRadarNotifier(
      container.read(Provider((ref) => ref)),
      QuizRadarState(items: [
        _inv(
            id: 'q1', title: 'Capitol Quiz', distance: 30, radius: 100, xp: 35),
      ]),
    );
    addTearDown(notifier.dispose);
    expect(notifier.state.showBanner, isTrue);

    notifier.markCompleted('q1');

    expect(notifier.state.showBanner, isFalse);
    expect(notifier.state.inRangeIncomplete, isEmpty);
    expect(notifier.state.completed.single.quizId, 'q1');
  });

  testWidgets(
      'NearbyQuizzesScreen renders Ready to play, Walk closer, and Completed sections',
      (tester) async {
    final hubState = QuizRadarState(
      origin: 'gps',
      items: [
        _inv(
            id: 'q1',
            title: 'Ready Quiz',
            distance: 25,
            radius: 100,
            xp: 45,
            inRange: true),
        _inv(
            id: 'q2',
            title: 'Walk Quiz',
            distance: 220,
            radius: 100,
            xp: 30,
            inRange: false),
        _inv(
            id: 'q3',
            title: 'Done Quiz',
            distance: 15,
            radius: 100,
            xp: 50,
            inRange: true,
            isCompleted: true),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizRadarProvider
              .overrideWith((ref) => _FixedRadarNotifier(ref, hubState)),
        ],
        child: const MaterialApp(home: NearbyQuizzesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 IN RANGE · 1 DONE'), findsOneWidget);
    expect(find.text('Near you'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('quiz_radar_section_ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_radar_section_approaching')),
        findsOneWidget);
    expect(find.text('PLAY NOW'), findsOneWidget);
    expect(find.text('ROUTE'), findsOneWidget);
    // The completed section can sit below the fold.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('quiz_radar_section_completed')), 200);
    expect(find.byKey(const ValueKey('quiz_radar_section_completed')),
        findsOneWidget);
    expect(find.text('REPLAY · 0 XP'), findsOneWidget);
  });

  testWidgets('SpotDetailScreen never shows a cultural quiz section',
      (tester) async {
    const spot = SpotModel(
      id: 'spot-91a',
      slug: 'spot-91a',
      name: 'Lingayen Capitol',
      description: 'Heritage building',
      category: 'culture_heritage',
      subcategory: 'heritage_site',
      municipality: 'Lingayen',
      address: 'Lingayen, Pangasinan',
      sourceName: 'LGU',
      trustLevel: 'lgu_verified',
      gpsLat: 16.02,
      gpsLng: 120.23,
      tags: ['heritage'],
      reasons: ['landmark'],
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          spotQuizzesProvider('spot-91a').overrideWith(
            (ref) async => const [
              SpotQuizSummaryModel(
                quizId: 'q1',
                title: 'Capitol Trivia',
                xpReward: 55,
                radiusMeters: 150,
                language: 'en',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: SpotDetailScreen(spot: spot)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spot_cultural_quizzes_section')),
        findsNothing);
    expect(find.text('CULTURAL QUIZZES HERE'), findsNothing);
    expect(find.text('Capitol Trivia'), findsNothing);
  });
}
