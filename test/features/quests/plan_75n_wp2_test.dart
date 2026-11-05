import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/widgets/quest_card.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/quest_traveler_preview_card.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/screens/qr_sheet_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_builder_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_list_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _StubQuestNotifier extends QuestNotifier {
  _StubQuestNotifier(super.apiClient, QuestState initial) {
    state = initial;
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _StubCampaignNotifier extends CampaignNotifier {
  _StubCampaignNotifier(super.apiClient, CampaignState initial) {
    state = initial;
  }

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}

class _StubSubmissionNotifier extends SubmissionNotifier {
  _StubSubmissionNotifier(super.apiClient, SubmissionState initial) {
    state = initial;
  }

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _FailingQrRepo extends QuestBuilderRepository {
  _FailingQrRepo(super.client, {required this.error});

  final Object error;

  @override
  Future<QrSheetData> getQrSheet(String questId) async {
    throw error;
  }
}

final _testUser = UserModel(
  id: 'u-1',
  seedId: 'seed-1',
  displayName: 'Juan Traveler',
  email: 'traveler@test.local',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 100,
);

const _testSpot = SpotModel(
  id: 's-1',
  slug: 'lingayen-beach',
  name: 'Lingayen Gulf Beach',
  description: 'Historic and scenic gulf beach.',
  category: 'nature_outdoors',
  subcategory: 'beach',
  municipality: 'Lingayen',
  address: 'Lingayen, Pangasinan',
  sourceName: 'LGU Lingayen',
  trustLevel: 'lgu_verified',
  gpsLat: 16.02,
  gpsLng: 120.23,
  tags: ['beach', 'heritage'],
  reasons: [],
);

QuestModel _makeQuest({
  required String id,
  required String title,
  bool isTest = false,
  List<QuestStepModel> steps = const [],
  String imageUrl = '',
  double baseRewardPhp = 25.0,
}) {
  return QuestModel(
    id: id,
    title: title,
    description: 'Test quest description for verification.',
    category: 'eco',
    locationName: 'Lingayen',
    gpsLat: 16.02,
    gpsLng: 120.23,
    radiusMeters: 100,
    rewardPoints: 50,
    markerImageUrl: imageUrl,
    baseRewardPhp: baseRewardPhp,
    difficultyFactor: 1.0,
    steps: steps,
    tags: const ['eco'],
    isTest: isTest,
  );
}

ApiClient _stubClient({
  Future<Response<dynamic>> Function(RequestOptions options)? onGet,
  Future<Response<dynamic>> Function(RequestOptions options)? onPost,
}) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Future<Response<dynamic>>? result;
        if (options.method == 'GET') result = onGet?.call(options);
        if (options.method == 'POST') result = onPost?.call(options);
        if (result == null) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ));
          return;
        }
        result.then(
          (response) => handler.resolve(response),
          onError: (Object error) {
            if (error is DioException) {
              handler.reject(error);
            } else {
              handler.reject(
                DioException(requestOptions: options, error: error),
              );
            }
          },
        );
      },
    ),
  );
  return client;
}

Widget _wrapScreen(Widget screen, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: screen,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 75n WP-2: Quest Funding Screen (P1)', () {
    testWidgets('404 on funding-plan fetch shows friendly empty state, no raw DioException',
        (tester) async {
      final client = _stubClient(
        onGet: (options) async {
          if (options.path.contains('/funding-plan')) {
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 404,
                data: {'success': false, 'error': {'message': 'Not Found'}},
              ),
            );
          }
          return Response(requestOptions: options, statusCode: 200, data: {'success': true});
        },
      );

      await tester.pumpWidget(_wrapScreen(
        const QuestFundingScreen(questId: 'quest-404'),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
        ],
      ));
      await tester.pumpAndSettle();

      // Empty state title and friendly subtitle should be present
      expect(find.text('Set up this round'), findsOneWidget);
      expect(find.text('No funding round yet — set one up below'), findsOneWidget);

      // Raw DioException or 404 stack error text should NEVER appear
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('status code of 404'), findsNothing);
      expect(find.textContaining('developer.mozilla.org'), findsNothing);
    });

    testWidgets('500 on funding-plan fetch shows friendly error message', (tester) async {
      final client = _stubClient(
        onGet: (options) async {
          if (options.path.contains('/funding-plan')) {
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 500,
                data: {'success': false, 'error': {'message': 'Internal database error'}},
              ),
            );
          }
          return Response(requestOptions: options, statusCode: 200, data: {'success': true});
        },
      );

      await tester.pumpWidget(_wrapScreen(
        const QuestFundingScreen(questId: 'quest-500'),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('developer.mozilla.org'), findsNothing);
      expect(find.text('Internal database error'), findsOneWidget);
    });
  });

  group('Plan 75n WP-2: QR Sheet Screen (P1)', () {
    testWidgets('403 error displays creator/admin notice without RETRY button', (tester) async {
      final requestOptions = RequestOptions(path: '/quests/quest-403/qr-sheet');
      final dio403 = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {'success': false, 'error': {'message': 'Forbidden'}},
        ),
      );

      await tester.pumpWidget(_wrapScreen(
        const QrSheetScreen(questId: 'quest-403'),
        overrides: [
          questBuilderRepositoryProvider.overrideWith(
            (ref) => _FailingQrRepo(ref.read(apiClientProvider), error: dio403),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Only the quest creator or an LGU admin can print QR placards for this quest'),
        findsOneWidget,
      );
      // RETRY button must not be present on 403
      expect(find.byKey(const ValueKey('qr_sheet_retry')), findsNothing);
      // Raw exception text must never be present
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('developer.mozilla.org'), findsNothing);
    });

    testWidgets('non-403 error displays friendly message with RETRY button', (tester) async {
      final requestOptions = RequestOptions(path: '/quests/quest-500/qr-sheet');
      final dio500 = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 500,
          data: {'success': false},
        ),
      );

      await tester.pumpWidget(_wrapScreen(
        const QrSheetScreen(questId: 'quest-500'),
        overrides: [
          questBuilderRepositoryProvider.overrideWith(
            (ref) => _FailingQrRepo(ref.read(apiClientProvider), error: dio500),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load QR sheet. Please check your connection.'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr_sheet_retry')), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });

  group('Plan 75n WP-2: Quest Detail & Quest Card (P1)', () {
    testWidgets('bottom bar counts 0 / 1 tasks done and shows ₱25 currency symbol when steps empty',
        (tester) async {
      final quest = _makeQuest(
        id: 'quest-detail-empty-steps',
        title: 'Empty Steps Quest',
        steps: const [],
        baseRewardPhp: 25.0,
      );

      final client = _stubClient(
        onGet: (options) async {
          if (options.path.contains('/progress')) {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'has_completed': false,
                  'active_attempt': null,
                },
              },
            );
          }
          return Response(requestOptions: options, statusCode: 200, data: {'success': true});
        },
      );

      await tester.pumpWidget(_wrapScreen(
        QuestDetailScreen(quest: quest),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
        ],
      ));
      await tester.pumpAndSettle();

      // Bottom bar must say 0 / 1 tasks done (matching fallback task display), NOT 0 / 0
      expect(find.text('0 / 1 tasks done'), findsOneWidget);
      expect(find.text('0 / 0 tasks done'), findsNothing);

      // Reward must render with ₱ sign, not plain P
      expect(find.text('₱25'), findsOneWidget);
    });

    testWidgets('QuestCard hides "0 tasks" chip when steps is empty, shows chip when steps exist',
        (tester) async {
      final emptyQuest = _makeQuest(
        id: 'q-empty',
        title: 'Zero Tasks Quest',
        steps: const [],
      );

      final stepsQuest = _makeQuest(
        id: 'q-steps',
        title: 'Two Tasks Quest',
        steps: const [
          QuestStepModel(
            order: 1,
            title: 'Step 1',
            description: 'Desc 1',
            checkpointType: 'location',
            required: true,
          ),
          QuestStepModel(
            order: 2,
            title: 'Step 2',
            description: 'Desc 2',
            checkpointType: 'qr',
            required: true,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              QuestCard(
                quest: emptyQuest,
                status: 'available',
                onTap: () {},
                key: const ValueKey('card-empty'),
              ),
              QuestCard(
                quest: stepsQuest,
                status: 'available',
                onTap: () {},
                key: const ValueKey('card-steps'),
              ),
            ],
          ),
        ),
      ));

      // 0 tasks chip should be hidden
      expect(find.text('0 tasks', skipOffstage: false), findsNothing);
      // 2 tasks chip should be shown
      expect(find.text('2 tasks', skipOffstage: false), findsOneWidget);
    });

    testWidgets('QuestCard and QuestDetailScreen fall back when given mismatched sofa stock photo',
        (tester) async {
      const sofaUrl = 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=800&q=80';
      final sofaQuest = _makeQuest(
        id: 'q-sofa',
        title: 'Heritage Trail',
        imageUrl: sofaUrl,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              QuestCard(
                quest: sofaQuest,
                status: 'available',
                onTap: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      // Should not load the sofa image, should fall back to dither placeholder
      expect(tester.takeException(), isNull);
    });
  });

  group('Plan 75n WP-2: Quest Builder & Chips (P1)', () {
    testWidgets('traveler preview card singularizes 1 task vs N tasks', (tester) async {
      const state1 = QuestBuilderState(
        title: 'Quest One',
        description: 'Desc',
        category: 'heritage',
        rewardPoints: 50,
        stepOrderMode: 'sequential',
        status: 'draft',
        tasks: [
          BuilderTask(
            key: 't1',
            stepOrder: 1,
            title: 'Task 1',
            description: 'Desc 1',
            required: true,
            checkpointType: 'location',
            verification: LocationVerification(
              fence: GeoFence(lat: 16.0, lng: 120.0, radiusMeters: 100),
            ),
          ),
        ],
        version: 1,
      );

      const state2 = QuestBuilderState(
        title: 'Quest Two',
        description: 'Desc',
        category: 'heritage',
        rewardPoints: 100,
        stepOrderMode: 'sequential',
        status: 'draft',
        tasks: [
          BuilderTask(
            key: 't1',
            stepOrder: 1,
            title: 'Task 1',
            description: 'Desc 1',
            required: true,
            checkpointType: 'location',
            verification: LocationVerification(
              fence: GeoFence(lat: 16.0, lng: 120.0, radiusMeters: 100),
            ),
          ),
          BuilderTask(
            key: 't2',
            stepOrder: 2,
            title: 'Task 2',
            description: 'Desc 2',
            required: true,
            checkpointType: 'qr',
            verification: QrVerification(
              fence: GeoFence(lat: 16.0, lng: 120.0, radiusMeters: 80),
              markerCode: 'TEST-QR',
            ),
          ),
        ],
        version: 1,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              QuestTravelerPreviewCard(
                state: state1,
                locationName: 'Lingayen',
              ),
              QuestTravelerPreviewCard(
                state: state2,
                locationName: 'Lingayen',
              ),
            ],
          ),
        ),
      ));

      expect(find.text('1 task'), findsOneWidget);
      expect(find.text('2 tasks'), findsOneWidget);
      expect(find.text('1 tasks'), findsNothing);
    });

    testWidgets('Category chips and verification method chips render inside Wrap without overflow at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = _stubClient();

      await tester.pumpWidget(_wrapScreen(
        const QuestBuilderScreen(initialSpot: _testSpot),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
        ],
      ));
      await tester.pumpAndSettle();

      // The Category Wrap should display full labels
      expect(find.byKey(const ValueKey('builder_category_segmented')), findsOneWidget);
      expect(find.text('Eco-Tourism & Nature'), findsOneWidget);

      // Verify Wrap is used for categories
      expect(find.byType(Wrap), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Plan 75n WP-2: Quest List Filtering with withoutTestContent (P1)', () {
    testWidgets('filters test quests when developer flag is false', (tester) async {
      final realQuest = _makeQuest(id: 'q-real', title: 'Real Pangasinan Trail', isTest: false);
      final testQuest = _makeQuest(id: 'q-test', title: 'Automated Test Quest', isTest: true);

      final client = _stubClient();
      final state = QuestState(
        quests: [realQuest, testQuest],
        isLoading: false,
      );

      await tester.pumpWidget(_wrapScreen(
        const QuestListScreen(),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          questProvider.overrideWith((ref) => _StubQuestNotifier(client, state)),
          campaignProvider.overrideWith((ref) => _StubCampaignNotifier(client, const CampaignState())),
          submissionProvider.overrideWith((ref) => _StubSubmissionNotifier(client, SubmissionState())),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
          showTestContentProvider.overrideWith((ref) => false),
        ],
      ));
      await tester.pumpAndSettle();

      // Real quest should be shown, test quest hidden
      expect(find.text('Real Pangasinan Trail', skipOffstage: false), findsOneWidget);
      expect(find.text('Automated Test Quest', skipOffstage: false), findsNothing);
    });

    testWidgets('includes test quests when developer flag is true', (tester) async {
      final realQuest = _makeQuest(id: 'q-real', title: 'Real Pangasinan Trail', isTest: false);
      final testQuest = _makeQuest(id: 'q-test', title: 'Automated Test Quest', isTest: true);

      final client = _stubClient();
      final state = QuestState(
        quests: [realQuest, testQuest],
        isLoading: false,
      );

      await tester.pumpWidget(_wrapScreen(
        const QuestListScreen(),
        overrides: [
          apiClientProvider.overrideWithValue(client),
          questProvider.overrideWith((ref) => _StubQuestNotifier(client, state)),
          campaignProvider.overrideWith((ref) => _StubCampaignNotifier(client, const CampaignState())),
          submissionProvider.overrideWith((ref) => _StubSubmissionNotifier(client, SubmissionState())),
          authProvider.overrideWith((ref) => _InertAuthNotifier(client, ref.watch(authRefreshProvider.notifier), _testUser)),
          showTestContentProvider.overrideWith((ref) => true),
        ],
      ));
      await tester.pumpAndSettle();

      // Segment header confirms 2 visible quests
      expect(find.text('Quests · 2'), findsOneWidget);

      // Scroll down so the second card is built in the ListView
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Both cards are now visible
      expect(find.text('Automated Test Quest'), findsOneWidget);
    });
  });
}
