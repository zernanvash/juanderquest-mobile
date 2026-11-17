import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_spot_card.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

const _testSpot = SpotModel(
  id: 'spot-like-anim',
  slug: 'like-anim-spot',
  name: 'Hundred Islands',
  description: 'A scenic archipelago.',
  category: 'nature_outdoors',
  subcategory: 'islands',
  municipality: 'Alaminos',
  address: 'Lucap Wharf',
  sourceName: 'LGU Alaminos',
  sourceUrl: 'https://alaminoscity.gov.ph',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2036,
  gpsLng: 120.0056,
  tags: ['islands'],
  reasons: [],
  crowdStatus: 'estimated_quiet',
  crowdConfidence: 'high',
  likeCount: 3,
  liked: false,
);

Widget _wrapSpotDetail(SpotModel spot) {
  final testClient = ApiClient(enableRetries: false);
  testClient.dio.interceptors.insert(
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
  final user = UserModel(
    id: 'traveler-1',
    seedId: 'traveler-1',
    email: 'traveler@juanderquest.app',
    displayName: 'Traveler One',
    avatarUrl: '',
    role: 'explorer',
    demoPoints: 50,
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testClient),
      authProvider.overrideWith(
        (ref) => _InertAuthNotifier(
          ref.watch(apiClientProvider),
          ref.watch(authRefreshProvider.notifier),
          user,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: SpotDetailScreen(spot: spot),
    ),
  );
}

void main() {
  group('Like heart animation', () {
    testWidgets('ExploreSpotCard plays heartLikeAnim when like is tapped',
        (tester) async {
      var liked = false;
      var count = 3;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => ExploreSpotCard(
                  spot: _testSpot,
                  likeCount: count,
                  isLiked: liked,
                  isSaved: false,
                  onTapCard: () {},
                  onToggleLike: () => setState(() {
                    liked = !liked;
                    count += liked ? 1 : -1;
                  }),
                  onToggleSave: () {},
                  onPlayQuest: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final likeBtn = find.byKey(const ValueKey('explore_like_spot-like-anim'));
      expect(likeBtn, findsOneWidget);

      await tester.tap(likeBtn);
      await tester.pump(const Duration(milliseconds: 16));

      final animFinder = find.descendant(
        of: likeBtn,
        matching: find.byType(PixelAnimation),
      );
      expect(animFinder, findsOneWidget);
      final anim = tester.widget<PixelAnimation>(animFinder);
      expect(anim.frames, same(DesignerArt.heartLikeAnim));
      expect(anim.playing, isTrue);

      await tester.pumpAndSettle();
      expect(animFinder, findsNothing);
    });

    testWidgets('SpotDetailScreen plays heartLikeAnim on theater_like_btn tap',
        (tester) async {
      await tester.pumpWidget(_wrapSpotDetail(_testSpot));
      await tester.pumpAndSettle();

      final likeBtn = find.byKey(const Key('theater_like_btn'));
      expect(likeBtn, findsOneWidget);

      await tester.tap(likeBtn);
      await tester.pump(const Duration(milliseconds: 16));

      final animFinder = find.descendant(
        of: likeBtn,
        matching: find.byType(PixelAnimation),
      );
      expect(animFinder, findsOneWidget);
      final anim = tester.widget<PixelAnimation>(animFinder);
      expect(anim.frames, same(DesignerArt.heartLikeAnim));
      expect(anim.playing, isTrue);

      await tester.pumpAndSettle();
      expect(animFinder, findsNothing);
    });
  });
}
