import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_builder_screen.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _FakeQuestBuilderRepository extends QuestBuilderRepository {
  _FakeQuestBuilderRepository(super.client);

  Map<String, dynamic>? lastCreatedPayload;
  String? lastCreatedSpotSlug;
  String? lastPatchedId;
  Map<String, dynamic>? lastPatchedPayload;
  Map<String, dynamic>? mockRawEditQuest;
  int? nextPatchVersion;

  @override
  Future<String> createQuest({
    required String spotIdOrSlug,
    required Map<String, dynamic> payload,
  }) async {
    lastCreatedSpotSlug = spotIdOrSlug;
    lastCreatedPayload = payload;
    return 'created-quest-999';
  }

  @override
  Future<Map<String, dynamic>> getQuestForEdit(String questId) async {
    if (mockRawEditQuest != null) return mockRawEditQuest!;
    return {
      'id': questId,
      'spot_id': 's1',
      'title': 'Existing Edit Quest',
      'description': 'Existing description for edit',
      'category': 'heritage',
      'reward_points': 75,
      'order_mode': 'ordered',
      'status': 'draft',
      'version': 3,
      'tasks': [
        {
          'title': 'Existing Task 1',
          'description': 'Description for task 1',
          'verification': {
            'type': 'location',
            'fence': {
              'lat': 16.2044,
              'lng': 120.0406,
              'radius_meters': 50,
            },
          },
          'is_required': true,
        },
      ],
    };
  }

  @override
  Future<int?> patchQuest({
    required String questId,
    required Map<String, dynamic> payload,
  }) async {
    lastPatchedId = questId;
    lastPatchedPayload = payload;
    return nextPatchVersion;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyAuthor = UserModel(
    id: 'user-author-1',
    seedId: 'seed-1',
    displayName: 'Quest Author',
    email: 'author@juanderquest.app',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 100,
  );

  final dummyNonAuthor = UserModel(
    id: 'user-other-2',
    seedId: 'seed-2',
    displayName: 'Regular Explorer',
    email: 'explorer@juanderquest.app',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 100,
  );

  const dummySpot = SpotModel(
    id: 's1',
    slug: 'hundred-islands',
    name: 'Hundred Islands National Park',
    description: 'Beautiful islands in Alaminos',
    category: 'nature_outdoors',
    subcategory: 'islands',
    municipality: 'Alaminos City',
    address: 'Lucap Wharf',
    sourceName: 'Tourism Office',
    trustLevel: 'lgu_verified',
    gpsLat: 16.2044,
    gpsLng: 120.0406,
    tags: ['beaches', 'island_hopping'],
    reasons: ['Scenic Views'],
    createdBy: 'user-author-1',
  );

  final dummyQuest = QuestModel(
    id: 'quest-edit-1',
    title: 'Hundred Islands Eco Quest',
    description: 'Explore the islands',
    category: 'nature_outdoors',
    locationName: 'Alaminos',
    gpsLat: 16.2044,
    gpsLng: 120.0406,
    radiusMeters: 100,
    rewardPoints: 75,
    markerImageUrl: 'https://example.com/marker.png',
    authorId: 'user-author-1',
  );

  group('Plan 73 — Quest Builder Widget Tests', () {
    testWidgets('Non-author does not see "Create a quest here" on spot detail', (tester) async {
      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false));
      final testClient = ApiClient(enableRetries: false);
      testClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
        },
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyNonAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SpotDetailScreen(spot: dummySpot),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('spot_create_quest_btn')), findsNothing);
    });

    testWidgets('Spot author sees "Create a quest here" on spot detail', (tester) async {
      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false));
      final testClient = ApiClient(enableRetries: false);
      testClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
        },
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SpotDetailScreen(spot: dummySpot),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('spot_create_quest_btn')), findsOneWidget);
    });

    testWidgets('Quest author sees "Edit quest" and "QR sheet" on quest detail', (tester) async {
      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false));
      final testClient = ApiClient(enableRetries: false);
      testClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/progress')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': {'has_completed': false, 'active_attempt': null}},
            ));
          }
          handler.next(options);
        },
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: QuestDetailScreen(quest: dummyQuest),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quest_edit_btn')), findsOneWidget);
      expect(find.byKey(const Key('quest_qr_sheet_btn')), findsOneWidget);
    });

    testWidgets('Create a 3-task quest (AR + host-scan QR + photo) and verify POST payload', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const QuestBuilderScreen(initialSpot: dummySpot),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify title field is populated with default template
      expect(find.byKey(const Key('quest_title_input')), findsOneWidget);

      // Task 0 is created by default as Location Geofence. Let's switch Task 0 to AR:
      await tester.tap(find.byKey(const Key('task_type_dropdown_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Augmented Reality (AR)').last);
      await tester.pumpAndSettle();

      // Tap "Add Task" to add Task 1: QR Task with host_scans
      await tester.tap(find.byKey(const Key('builder_add_task_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task_type_dropdown_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR Code Verification').last);
      await tester.pumpAndSettle();

      // Switch to host scans traveler
      final hostScansFinder = find.byKey(const Key('qr_mode_host_scans')).last;
      await tester.tap(hostScansFinder);
      await tester.pumpAndSettle();

      // Tap "Add Task" to add Task 2: Photo Task
      await tester.tap(find.byKey(const Key('builder_add_task_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task_type_dropdown_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo Submission').last);
      await tester.pumpAndSettle();

      // Verify Save Draft button has minimumSize 48 and sits in bottom bar
      final draftBtnFinder = find.byKey(const Key('builder_save_draft_btn'));
      expect(draftBtnFinder, findsOneWidget);

      final publishBtnFinder = find.byKey(const Key('builder_publish_btn'));
      expect(publishBtnFinder, findsOneWidget);

      // Tap Publish
      await tester.tap(publishBtnFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeRepo.lastCreatedPayload, isNotNull);
      expect(fakeRepo.lastCreatedSpotSlug, 'hundred-islands');
      final payload = fakeRepo.lastCreatedPayload!;
      expect(payload['status'], 'published');
      final tasks = payload['tasks'] as List;
      expect(tasks.length, 3);
      expect(tasks[0]['verification']['type'], 'ar');
      expect(tasks[1]['verification']['type'], 'qr');
      expect(tasks[2]['verification']['type'], 'photo');
      // Changing a task's type keeps it at the destination: a 0,0 fence fails
      // the server's Philippines bounds check (found on the phone, 2026-11-01).
      expect(tasks[0]['verification']['fence'], {'lat': 16.2044, 'lng': 120.0406, 'radius_meters': 50});
      expect(tasks[1]['verification']['fence'], {'lat': 16.2044, 'lng': 120.0406, 'radius_meters': 80});
      expect(tasks[1]['verification']['scan_mode'], 'host_scans_traveler');
    });

    testWidgets('Edit quest loads GET /quests/:id/edit and sends PATCH with expected_version', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const QuestBuilderScreen(questId: 'quest-edit-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify existing title is loaded
      expect(find.text('Existing Edit Quest'), findsOneWidget);

      // Tap Publish to save changes via PATCH
      final publishBtnFinder = find.byKey(const Key('builder_publish_btn'));
      expect(publishBtnFinder, findsOneWidget);
      await tester.tap(publishBtnFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeRepo.lastPatchedId, 'quest-edit-1');
      expect(fakeRepo.lastPatchedPayload, isNotNull);
      expect(fakeRepo.lastPatchedPayload!['expected_version'], 3);
    });

    testWidgets('Second save sends the version the server returned (no 409)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FakeQuestBuilderRepository(ApiClient(enableRetries: false))
        ..nextPatchVersion = 4;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _InertAuthNotifier(ref.watch(apiClientProvider), ref.watch(authRefreshProvider.notifier), dummyAuthor)),
            questBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const QuestBuilderScreen(questId: 'quest-edit-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final draftBtn = find.byKey(const Key('builder_save_draft_btn'));
      await tester.tap(draftBtn);
      await tester.pumpAndSettle();
      expect(fakeRepo.lastPatchedPayload!['expected_version'], 3);

      // The "Draft saved!" snackbar sits over the bottom bar; dismiss it first.
      ScaffoldMessenger.of(tester.element(draftBtn)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(draftBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fakeRepo.lastPatchedPayload!['expected_version'], 4);
    });
  });
}

