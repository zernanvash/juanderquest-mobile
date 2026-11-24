import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';
import 'package:juanderquest_app/features/quests/builder/quest_wizard_logic.dart';
import 'package:juanderquest_app/features/quests/screens/quest_builder_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_edit_screen.dart';
import 'package:juanderquest_app/features/spots/theater/theater_about_section.dart';
import 'package:juanderquest_app/features/spots/utils/relocation_math.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'test-token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _FakeWizardRepo extends QuestBuilderRepository {
  _FakeWizardRepo(super.client);

  int createCalls = 0;
  int patchCalls = 0;
  Map<String, dynamic>? mockEditData;

  @override
  Future<String> createQuest({
    required String spotIdOrSlug,
    required Map<String, dynamic> payload,
  }) async {
    createCalls++;
    return 'draft-quest-118';
  }

  @override
  Future<int?> patchQuest({
    required String questId,
    required Map<String, dynamic> payload,
  }) async {
    patchCalls++;
    return patchCalls + 1;
  }

  @override
  Future<Map<String, dynamic>> getQuestForEdit(String questId) async {
    return mockEditData ??
        {
          'id': questId,
          'title': 'Bolinao Lighthouse Walk',
          'description': 'Walk up the scenic lighthouse trail and snap a view.',
          'category': 'eco',
          'reward_points': 75,
          'step_order_mode': 'sequential',
          'status': 'published',
          'version': 2,
          'tasks': [
            {
              'key': 'task_1',
              'step_order': 1,
              'title': 'Arrive at Lighthouse',
              'description': 'Check in near the gate.',
              'checkpoint_type': 'location',
              'required': true,
              'verification': {
                'type': 'location',
                'fence': {'lat': 16.32, 'lng': 119.785, 'radius_meters': 100},
              },
            },
          ],
        };
  }
}

void main() {
  final posterUser = UserModel(
    id: 'user-poster',
    seedId: 'maria_ph',
    displayName: 'Maria Explorer',
    email: 'maria@example.test',
    avatarUrl: '',
    role: 'user',
    demoPoints: 100,
  );

  final otherUser = UserModel(
    id: 'user-other',
    seedId: 'juan_ph',
    displayName: 'Juan Traveler',
    email: 'juan@example.test',
    avatarUrl: '',
    role: 'user',
    demoPoints: 50,
  );

  const authoredSpot = SpotModel(
    id: 'spot-118',
    slug: 'bolinao-sunset-cliff',
    name: 'Bolinao Sunset Cliff',
    description: 'A quiet limestone cliff overlooking the West Philippine Sea.',
    category: 'nature_outdoors',
    subcategory: 'viewpoint',
    municipality: 'Bolinao',
    address: 'Patar Rd, Bolinao',
    sourceName: 'Maria Explorer',
    trustLevel: 'community',
    gpsLat: 16.32,
    gpsLng: 119.785,
    tags: ['scenic'],
    reasons: [],
    createdBy: 'user-poster',
    author: SpotAuthor(
      id: 'user-poster',
      handle: 'maria_ph',
      displayName: 'Maria Explorer',
    ),
  );

  const officialSpot = SpotModel(
    id: 'spot-118-official',
    slug: 'dagupan-plaza',
    name: 'Dagupan Heritage Plaza',
    description: 'Official town square with historic civic buildings.',
    category: 'culture_heritage',
    subcategory: 'heritage_site',
    municipality: 'Dagupan City',
    address: 'AB Fernandez Ave, Dagupan City',
    sourceName: 'Dagupan LGU',
    trustLevel: 'lgu_verified',
    gpsLat: 16.0433,
    gpsLng: 120.3333,
    tags: ['heritage'],
    reasons: [],
    createdBy: null,
    author: null,
  );

  ApiClient inertClient() {
    final c = ApiClient(enableRetries: false);
    c.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ),
        ),
      ),
    );
    return c;
  }

  group('Plan 118 — Unit tests', () {
    test('haversine 200 m boundary distinguishes instant vs review moves', () {
      // ~150 m north
      final d150 = haversineMeters(16.32, 119.785, 16.32135, 119.785);
      expect(d150, inInclusiveRange(140, 160));
      expect(requiresRelocationReview(d150), isFalse);

      // Exact boundary
      expect(requiresRelocationReview(200.0), isFalse);
      expect(requiresRelocationReview(200.6), isTrue);

      // ~540 m north
      final d540 = haversineMeters(16.32, 119.785, 16.32486, 119.785);
      expect(d540, greaterThan(200));
      expect(requiresRelocationReview(d540), isTrue);
    });

    test('wizard page validation and resume-at-first-incomplete', () {
      expect(QuestWizardLogic.validateName('ab'), isNotNull);
      expect(QuestWizardLogic.validateName('Bolinao Walk'), isNull);
      expect(QuestWizardLogic.validateAbout('too short', 'eco'), isNotNull);
      expect(
        QuestWizardLogic.validateAbout(
            'Explore the coastal cliffs and snap photos.', 'eco'),
        isNull,
      );
      expect(QuestWizardLogic.validateReward(25), isNotNull);
      expect(QuestWizardLogic.validateReward(75), isNull);

      // Empty draft -> page 1
      expect(
        QuestWizardLogic.firstIncompletePage(const QuestBuilderState(
          title: '',
          description: '',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [],
          version: 1,
        )),
        1,
      );

      // Name done, description missing -> page 2
      expect(
        QuestWizardLogic.firstIncompletePage(const QuestBuilderState(
          title: 'Valid Name',
          description: 'short',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [],
          version: 1,
        )),
        2,
      );

      // Name + about done, tasks missing -> page 3
      expect(
        QuestWizardLogic.firstIncompletePage(const QuestBuilderState(
          title: 'Valid Name',
          description: 'Walk along the baywalk and discover local stops.',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [],
          version: 1,
        )),
        3,
      );

      // Everything complete -> page 7
      expect(
        QuestWizardLogic.firstIncompletePage(QuestBuilderState(
          title: 'Valid Name',
          description: 'Walk along the baywalk and discover local stops.',
          category: 'eco',
          rewardPoints: 75,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [
            QuestWizardLogic.buildDefaultTask(
              type: 'location',
              stepOrder: 1,
              lat: 16.32,
              lng: 119.785,
            ),
          ],
          version: 1,
        )),
        7,
      );
    });
  });

  group('Plan 118 — Author line, Edit button, 202 relocation, poster-only quests',
      () {
    testWidgets('author line visible when author present and hidden when null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: TheaterAboutSection(spot: authoredSpot),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('spot_author_line')), findsOneWidget);
      expect(find.text('Posted by @maria_ph'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: TheaterAboutSection(spot: officialSpot),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('spot_author_line')), findsNothing);
    });

    testWidgets('Edit button shown only for poster; Add quest hidden for non-poster',
        (tester) async {
      // As poster -> EDIT button visible
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(inertClient()),
            authProvider.overrideWith((ref) => _InertAuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  posterUser,
                )),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const SpotDetailScreen(spot: authoredSpot),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('theater_edit_btn')), findsOneWidget);

      // As non-poster -> EDIT button hidden
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(inertClient()),
            authProvider.overrideWith((ref) => _InertAuthNotifier(
                  ref.watch(apiClientProvider),
                  ref.watch(authRefreshProvider.notifier),
                  otherUser,
                )),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const SpotDetailScreen(spot: authoredSpot),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('theater_edit_btn')), findsNothing);
    });

    testWidgets('SpotEditScreen shows 202 relocation pending panel on big move',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(inertClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: SpotEditScreen(
              spot: authoredSpot,
              gpsFixFetcher: (onAcc) async {
                onAcc(8.0);
                return const GpsFixResult(
                  lat: 16.325,
                  lng: 119.785,
                  accuracyMeters: 8.0,
                );
              },
              patchOverride: (id, payload) async => {
                '_status': 202,
                'relocation': {'status': 'pending', 'distance_m': 540},
                'data': authoredSpot.toJson(),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1/5 -> 2/5 -> 3/5 (Location)
      expect(find.text('1 / 5'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spot_edit_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 5'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spot_edit_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('3 / 5'), findsOneWidget);

      // Use GPS fix -> shows live accuracy ±8 m
      final gpsBtn = find.byKey(const Key('spot_edit_use_gps_btn'));
      await tester.ensureVisible(gpsBtn);
      await tester.pumpAndSettle();
      await tester.tap(gpsBtn);
      await tester.pumpAndSettle();
      expect(find.text('±8 m'), findsOneWidget);

      // Step 4/5 -> 5/5 -> Save
      await tester.tap(find.byKey(const Key('spot_edit_next_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spot_edit_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('5 / 5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_edit_save_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('relocation_pending_panel')), findsOneWidget);
      expect(
        find.textContaining('Your move of 540 m is waiting for review.'),
        findsOneWidget,
      );
    });
  });

  group('Plan 118 — 7-Page Quest Wizard widget tests', () {
    testWidgets(
        'walks all 7 pages, disables NEXT until valid, adds a second task, and auto-saves draft',
        (tester) async {
      final repo = _FakeWizardRepo(inertClient());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questBuilderRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const QuestBuilderScreen(
              spotSlug: 'bolinao-sunset-cliff',
              initialSpot: authoredSpot,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 / 7: NEXT disabled while name is empty
      expect(find.text('1 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 7'), findsOneWidget); // stayed on page 1

      await tester.enterText(
          find.byKey(const Key('wizard_name_input')), 'Sunset Cliff Quest');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      expect(repo.createCalls, 1); // auto-saved draft on NEXT

      // Page 2 / 7: About
      expect(find.text('2 / 7'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('wizard_about_input')),
        'Walk to the cliff overlook and capture the sunset.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // Page 3 / 7: Task type -> Arrive (location) skips extra details
      expect(find.text('3 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_task_type_location')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // Page 4 / 7: Where
      expect(find.text('4 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // Page 5 / 7: Task list -> add a second task (Photo)
      expect(find.text('5 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_add_another_task_btn')));
      await tester.pumpAndSettle();
      expect(find.text('3 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_task_type_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('4 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      // Extra details page keeps "4 / 7"
      expect(find.text('4 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // Back on Page 5 / 7 with 2 tasks -> Page 6 / 7 -> Page 7 / 7
      expect(find.text('5 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      expect(find.text('6 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_reward_100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      expect(find.text('7 / 7'), findsOneWidget);
      expect(find.text('2 tasks'), findsWidgets);
      expect(find.text('Reward: 100 points'), findsOneWidget);
    });

    testWidgets('edit mode opens straight on page 7 and checklist jumps to page',
        (tester) async {
      final repo = _FakeWizardRepo(inertClient());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questBuilderRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const QuestBuilderScreen(questId: 'quest-edit-118'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7 / 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_check_name')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 7'), findsOneWidget);
    });
  });
}
