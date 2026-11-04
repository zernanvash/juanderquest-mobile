import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/cosmetic_avatar.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/profile_banner.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/pixel/saved_quests.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_spot_card.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/core/pixel/pixel_background.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _QuestFixture extends QuestNotifier {
  _QuestFixture(super.apiClient, List<QuestModel> quests) {
    state = QuestState(quests: quests, isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _SpotFixture extends SpotDiscoveryNotifier {
  _SpotFixture(super.ref, List<SpotModel> spots) {
    state = SpotDiscoveryState(
      spots: spots,
      categories: const ['nature'],
      isInitialLoading: false,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {}
}

class _MemorySavedStorage implements SavedQuestsStorage {
  @override
  Future<List<String>> read() async => const [];

  @override
  Future<void> write(List<String> ids) async {}
}

final _user = UserModel(
  id: 'u1111111-2222',
  seedId: 'test_scout',
  displayName: 'Juan Dela Cruz',
  email: 'juan@juanderquest.ph',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 500,
);

final _quest = QuestModel(
  id: 'q1',
  title: 'Patar Beach Cleanup',
  description: 'Clean the beach and learn the local story.',
  category: 'eco',
  locationName: 'Patar, Bolinao',
  gpsLat: 16.2,
  gpsLng: 119.9,
  radiusMeters: 100,
  rewardPoints: 50,
  markerImageUrl: '',
  steps: const [
    QuestStepModel(
      order: 1,
      title: 'Arrive at the beach',
      description: 'Check in on site.',
      checkpointType: 'location',
      required: true,
    ),
    QuestStepModel(
      order: 2,
      title: 'Collect a bag of litter',
      description: 'Take a photo of the collected litter.',
      checkpointType: 'photo',
      required: true,
    ),
  ],
);

const _spot = SpotModel(
  id: 's1',
  slug: 'patar-beach',
  name: 'Patar Beach',
  description: 'A long white beach in Bolinao.',
  category: 'nature_outdoors',
  subcategory: 'beaches',
  municipality: 'Bolinao',
  address: 'Patar, Bolinao',
  sourceName: 'Bolinao Tourism',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2,
  gpsLng: 119.9,
  tags: ['beach'],
  reasons: [],
  crowdStatus: 'quiet',
);

ApiClient _questApi() {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/q1/progress') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'has_completed': false, 'active_attempt': null},
            },
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': <String, dynamic>{}},
        ));
      },
    ),
  );
  return api;
}

void main() {
  testWidgets(
      'map has no REAL/PIXEL switch, keeps LIST, and the selected card '
      'does not repeat the OSM credit', (tester) async {
    final fakeMap = FakeJdqMap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_questApi()),
          jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
          mapStyleProvider.overrideWith((ref) async => '{}'),
          questProvider.overrideWith(
              (ref) => _QuestFixture(ref.read(apiClientProvider), [_quest])),
          spotDiscoveryProvider
              .overrideWith((ref) => _SpotFixture(ref, [_spot])),
          choiceSpotlightProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: MapViewScreen(initialQuestId: 'q1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('REAL'), findsNothing);
    expect(find.text('PIXEL'), findsNothing);
    expect(find.text('LIST'), findsOneWidget);

    final card = find
        .ancestor(
          of: find.text('VIEW DETAILS'),
          matching: find.byType(PixelPanel),
        )
        .first;
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('OpenStreetMap'),
      ),
      findsNothing,
    );
  });

  testWidgets('quest detail keeps the status-bar inset and one task count',
      (tester) async {
    final api = _questApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => _Auth(
                api,
                ref.watch(authRefreshProvider.notifier),
                _user,
              )),
          savedQuestsStorageProvider.overrideWithValue(_MemorySavedStorage()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 24, bottom: 16),
            ),
            child: QuestDetailScreen(quest: _quest),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('0 / 2 tasks done'), findsOneWidget);
    final listTop = tester.getTopLeft(find.byType(ListView).first).dy;
    expect(listTop, greaterThanOrEqualTo(24));
  });

  testWidgets('Explore photo-less card clips its category strip',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExploreSpotCard(
              spot: _spot,
              likeCount: 3,
              isLiked: false,
              isSaved: false,
              onTapCard: () {},
              onToggleLike: () {},
              onToggleSave: () {},
              onReport: () {},
              onPlayQuest: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ClipRect), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile avatar is square and the banner is dithered',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth(ref.read(apiClientProvider),
              ref.watch(authRefreshProvider.notifier), _user)),
          profileStatsProvider.overrideWithValue(
            ProfileStatsModel(
              completedQuestsCount: 0,
              pendingSubmissionsCount: 0,
              totalPointsEarned: 0,
              ecoPioneerState: BadgeState.locked,
              heritageKeeperState: BadgeState.locked,
              foodExplorerState: BadgeState.locked,
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CosmeticAvatar), findsNothing);
    expect(find.byType(ProfileBanner), findsNothing);
    expect(find.byType(DitherBackground), findsWidgets);
  });
}
