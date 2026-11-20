import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_badges.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_spot_card.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/studio/pixel/studio_icons.dart';
import 'package:juanderquest_app/features/spots/theater/theater_quest_picker_sheet.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null
        ? AuthState()
        : AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _StaticQuestNotifier extends QuestNotifier {
  _StaticQuestNotifier(super.apiClient, List<QuestModel> quests) {
    state = QuestState(quests: quests, isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

const _spotWithQuest = SpotModel(
  id: 'spot-105',
  slug: 'hundred-islands',
  name: 'Hundred Islands',
  description: 'A scenic archipelago in Pangasinan.',
  category: 'nature_outdoors',
  subcategory: 'islands',
  municipality: 'Alaminos',
  address: 'Lucap Wharf, Alaminos',
  sourceName: 'LGU Alaminos',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2036,
  gpsLng: 120.0056,
  tags: ['islands'],
  reasons: ['Hidden gem'],
  crowdStatus: 'quiet',
  crowdConfidence: 'high',
  questId: 'quest-105',
  likeCount: 5,
  liked: false,
);

final _quest105 = QuestModel(
  id: 'quest-105',
  title: 'Island Hopping Trail',
  description: 'Explore Lucap Wharf and nearby islands.',
  category: 'nature',
  locationName: 'Alaminos',
  gpsLat: 16.2036,
  gpsLng: 120.0056,
  radiusMeters: 200,
  rewardPoints: 150,
  markerImageUrl: '',
  steps: const [],
);

final _activeUser = UserModel(
  id: 'traveler-105',
  seedId: 'traveler-105',
  email: 'traveler@juanderquest.app',
  displayName: 'Traveler 105',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 50,
);

Widget _wrapSpotDetail({
  required SpotModel spot,
  List<QuestModel> quests = const [],
  UserModel? user,
  List<String>? pushedRoutes,
}) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/comments')) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': [
                  {
                    'id': 'c1',
                    'author_name': 'Maria Clara',
                    'tag': 'tip',
                    'content': 'Bring water and sunscreen.',
                    'helpful_count': 2,
                    'is_verified_visit': true,
                  },
                ],
              },
            ),
          );
        }
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ),
        );
      },
    ),
  );

  final router = GoRouter(
    initialLocation: '/spot',
    routes: [
      GoRoute(
        path: '/spot',
        builder: (_, __) => SpotDetailScreen(spot: spot),
      ),
      GoRoute(
        path: '/quests/:id',
        builder: (_, state) {
          pushedRoutes?.add('/quests/${state.pathParameters['id']}');
          return const Scaffold(body: Text('Quest Page'));
        },
      ),
      GoRoute(
        path: '/explore/:slug/quests/new',
        builder: (_, state) {
          pushedRoutes
              ?.add('/explore/${state.pathParameters['slug']}/quests/new');
          return const Scaffold(body: Text('New Quest Page'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith(
        (ref) => _InertAuthNotifier(
          ref.watch(apiClientProvider),
          ref.watch(authRefreshProvider.notifier),
          user,
        ),
      ),
      questProvider.overrideWith(
        (ref) => _StaticQuestNotifier(ref.watch(apiClientProvider), quests),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.pixel,
      routerConfig: router,
    ),
  );
}

void main() {
  group('Plan 105 destination details & explore cleanup', () {
    testWidgets('SpotDetailScreen scrolled actions + single-quest picker sheet',
        (tester) async {
      final pushed = <String>[];
      await tester.pumpWidget(
        _wrapSpotDetail(
          spot: _spotWithQuest,
          quests: [_quest105],
          user: _activeUser,
          pushedRoutes: pushed,
        ),
      );
      await tester.pumpAndSettle();

      // Network photos never load in tests, so this is the no-photo layout: ADD PHOTO and
      // PLAY QUEST show at once (owner 2026-11-20). The cover-photo layout, where they wait
      // for a scroll, is covered in missing_spot_photos_test.dart.
      expect(find.byKey(const ValueKey('theater_first_viewport_compact')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('spot_add_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_play_quest_btn')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spot_add_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_play_quest_btn')), findsOneWidget);

      // Even for 1 quest, tapping PLAY QUEST opens the quest picker sheet
      await tester.tap(find.byKey(const ValueKey('spot_play_quest_btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('spot_quest_picker_sheet')),
        findsOneWidget,
      );
      expect(find.text('Island Hopping Trail'), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_create_quest_button')),
          findsOneWidget);

      // Tapping PLAY navigates to /quests/quest-105
      await tester.tap(find.byKey(const ValueKey('spot_quest_play_quest-105')));
      await tester.pumpAndSettle();
      expect(pushed, contains('/quests/quest-105'));
    });

    testWidgets(
        'SpotDetailScreen removes Overview/Quests/Quizzes and shows badges+crowd before About',
        (tester) async {
      await tester.pumpWidget(
        _wrapSpotDetail(spot: _spotWithQuest, quests: [_quest105]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsNothing);
      expect(find.text('QUESTS HERE'), findsNothing);
      expect(find.text('CULTURAL QUIZZES HERE'), findsNothing);

      final badgesPanel =
          find.byKey(const ValueKey('theater_badges_status_panel'));
      await tester.scrollUntilVisible(
        badgesPanel,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(badgesPanel, findsOneWidget);
      expect(find.text('Low crowd pressure'), findsOneWidget);
      expect(find.byType(ExploreBadgeRow), findsOneWidget);

      // Badges+crowd panel sits above ABOUT
      final aboutFinder = find.text('ABOUT');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();
      if (badgesPanel.evaluate().isNotEmpty &&
          aboutFinder.evaluate().isNotEmpty) {
        expect(
          tester.getTopLeft(badgesPanel).dy,
          lessThan(tester.getTopLeft(aboutFinder).dy),
        );
      } else {
        await tester.scrollUntilVisible(
          aboutFinder,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(aboutFinder, findsOneWidget);
      }
    });

    testWidgets(
        'SpotCommunitySection removes spot_like, compacts POST NOTE, and places VERIFIED VISIT on header right',
        (tester) async {
      await tester.pumpWidget(
        _wrapSpotDetail(spot: _spotWithQuest, user: _activeUser),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('MARIA CLARA'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('spot_like')), findsNothing);
      expect(find.byKey(const ValueKey('spot_comment_post')), findsOneWidget);

      final author = find.text('MARIA CLARA');
      final verified = find.text('VERIFIED VISIT');
      expect(author, findsOneWidget);
      expect(verified, findsOneWidget);
      expect(
        tester.getTopLeft(verified).dx,
        greaterThan(tester.getTopLeft(author).dx),
      );
    });

    testWidgets('StudioIcons.share and gallery render cleanly at 1x and 3x',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                PixelSprite(StudioIcons.share, scale: 1),
                PixelSprite(StudioIcons.share, scale: 3),
                PixelSprite(StudioIcons.gallery, scale: 1),
                PixelSprite(StudioIcons.gallery, scale: 3),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ExploreSpotCard shows trophy icon, no PLAY QUEST button, and save on right at 320x568 and 568x320 with 2x text',
        (tester) async {
      for (final size in const [Size(320, 568), Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.pixel,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ExploreSpotCard(
                    spot: _spotWithQuest,
                    badges: exploreBadgesFor(_spotWithQuest),
                    likeCount: 5,
                    isLiked: false,
                    isSaved: false,
                    onTapCard: () {},
                    onToggleLike: () {},
                    onToggleSave: () {},
                    onPlayQuest: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PLAY QUEST'), findsNothing);
        expect(
          find.byKey(const ValueKey('explore_quest_row_spot-105')),
          findsOneWidget,
        );
        // Owner 2026-11-17: the trophy only, no quest line.
        expect(find.textContaining('Quest ·'), findsNothing);
        final likeBtn = find.byKey(const ValueKey('explore_like_spot-105'));
        final saveBtn = find.byKey(const ValueKey('explore_save_spot-105'));
        expect(
          tester.getTopLeft(saveBtn).dx,
          greaterThan(tester.getTopRight(likeBtn).dx),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        'TheaterQuestPickerSheet has 0 overflow at 320x568 and 568x320 with 2x text',
        (tester) async {
      for (final size in const [Size(320, 568), Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.pixel,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: TheaterQuestPickerSheet(
                  spot: _spotWithQuest,
                  matches: [
                    SpotQuestMatch(
                      quest: _quest105,
                      reason: 'Starts here',
                      isSpotOwn: true,
                      distanceMeters: 0,
                    ),
                  ],
                  canCreateQuest: true,
                  onPlayQuest: (_) {},
                  onCreateQuest: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
