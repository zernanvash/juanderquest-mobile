import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';
import 'package:juanderquest_app/features/plaza/plaza_provider.dart';
import 'package:juanderquest_app/features/plaza/plaza_screen.dart';
import 'package:juanderquest_app/features/spots/studio/pixel/studio_icons.dart';

class _FakePlazaFeedNotifier extends PlazaFeedNotifier {
  _FakePlazaFeedNotifier(super.api, AsyncValue<List<ActivityItemModel>> initial) {
    state = initial;
  }

  String? lastScope;
  int cheerToggles = 0;

  @override
  Future<void> loadFeed({bool reset = false}) async {}

  @override
  void setScope(String newScope) {
    lastScope = newScope;
  }

  @override
  Future<void> toggleCheer(String activityId) async {
    cheerToggles++;
  }
}

class _FakePushService extends PushService {
  _FakePushService() : super(ApiClient());

  @override
  Future<bool> hasAskedPermission() async => true;
}

void main() {
  final testActivity = ActivityItemModel(
    id: 'act-test-1',
    verb: 'quest_completed',
    actorName: 'Scout Clara',
    subjectType: 'quest',
    subjectTitle: 'Lingayen Gulf Trail',
    municipality: 'Lingayen',
    payload: const {},
    reason: 'everyone',
    cheerCount: 5,
    cheeredByMe: false,
    commentCount: 2,
    createdAt: DateTime(2026, 11, 8),
  );

  Widget createPlazaApp(_FakePlazaFeedNotifier feedNotifier) {
    return ProviderScope(
      overrides: [
        plazaFeedProvider.overrideWith((ref) => feedNotifier),
        plazaStandingsProvider.overrideWith(
          (ref, arg) async => {
            'entries': [
              {
                'rank': 1,
                'user_id': 'u1',
                'display_name': 'Scout Clara',
                'points': 2000,
                'quests': 5,
              }
            ],
            'me': {
              'rank': 1,
              'points': 2000,
              'quests': 5,
            }
          },
        ),
        pushServiceProvider.overrideWithValue(_FakePushService()),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: const PlazaScreen(),
      ),
    );
  }

  group('PlazaScreen (Plan 79a)', () {
    testWidgets('Renders compact 1-row toolbar with scope and period chips',
        (tester) async {
      final feedNotifier = _FakePlazaFeedNotifier(
        ApiClient(),
        AsyncValue.data([testActivity]),
      );

      await tester.pumpWidget(createPlazaApp(feedNotifier));
      await tester.pumpAndSettle();

      // Verify toolbar chips are all present in the compact row
      expect(find.text('Everyone'), findsWidgets);
      expect(find.text('Following'), findsWidgets);
      expect(find.text('My Town'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);

      // Verify tapping 'My Town' selects it
      final myTownFinder = find.ancestor(
        of: find.text('My Town'),
        matching: find.byType(PixelChip),
      );
      expect(tester.widget<PixelChip>(myTownFinder).style, PixelBoxStyle.parchment);
      await tester.tap(find.text('My Town'));
      await tester.pump();
      expect(tester.widget<PixelChip>(myTownFinder).style, PixelBoxStyle.gold);
    });

    testWidgets('Cheer button and Comments chip use existing pixel icons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final feedNotifier = _FakePlazaFeedNotifier(
        ApiClient(),
        AsyncValue.data([testActivity]),
      );

      await tester.pumpWidget(createPlazaApp(feedNotifier));
      await tester.pumpAndSettle();

      // Verify CHEER button uses DesignerArt.heartLiked
      final cheerButton = find.byKey(const ValueKey('plaza_cheer_act-test-1'));
      expect(cheerButton, findsOneWidget);
      final pixelSpriteFinder = find.descendant(
        of: cheerButton,
        matching: find.byType(PixelSprite),
      );
      expect(pixelSpriteFinder, findsOneWidget);
      final spriteWidget = tester.widget<PixelSprite>(pixelSpriteFinder);
      expect(spriteWidget.art, equals(DesignerArt.heartLiked));

      // Verify COMMENTS chip uses StudioIcons.edit
      final commentsChip = find.text('2 comments');
      expect(commentsChip, findsOneWidget);
      final commentsPixelChip = find.ancestor(
        of: commentsChip,
        matching: find.byType(PixelChip),
      );
      expect(commentsPixelChip, findsOneWidget);
      final chipWidget = tester.widget<PixelChip>(commentsPixelChip);
      expect(chipWidget.icon, equals(StudioIcons.edit));
    });
  });
}
