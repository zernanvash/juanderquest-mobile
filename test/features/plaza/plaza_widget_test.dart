import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_like_heart.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/plaza/plaza_art.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';
import 'package:juanderquest_app/features/plaza/plaza_provider.dart';
import 'package:juanderquest_app/features/plaza/plaza_screen.dart';
import 'package:juanderquest_app/features/settings/home_town.dart';

class _FakePlazaFeedNotifier extends PlazaFeedNotifier {
  _FakePlazaFeedNotifier(
    super.api,
    AsyncValue<List<ActivityItemModel>> initial,
  ) : _currentScope = 'mixed' {
    state = initial;
  }

  String _currentScope;
  String? lastScope;
  int cheerToggles = 0;

  @override
  String get scope => _currentScope;

  @override
  Future<void> loadFeed({bool reset = false, bool quiet = false}) async {}

  @override
  void setScope(String newScope) {
    lastScope = newScope;
    _currentScope = newScope;
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
              },
            ],
            'me': {'rank': 1, 'points': 2000, 'quests': 5},
          },
        ),
        pushServiceProvider.overrideWithValue(_FakePushService()),
      ],
      child: MaterialApp(theme: AppTheme.pixel, home: const PlazaScreen()),
    );
  }

  group('PlazaScreen (Plan 79a)', () {
    testWidgets('Renders wrapping 2-row toolbar without duplicate feed switch',
        (
      tester,
    ) async {
      final feedNotifier = _FakePlazaFeedNotifier(
        ApiClient(),
        AsyncValue.data([testActivity]),
      );

      await tester.pumpWidget(createPlazaApp(feedNotifier));
      await tester.pumpAndSettle();

      // Verify toolbar chips are all present and duplicate feed scope switch is removed
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('My Town'), findsOneWidget);
      // Owner 2026-11-18: Friends is first and selected by default.
      expect(
        tester.getTopLeft(find.text('Friends')).dx,
        lessThan(tester.getTopLeft(find.text('Everyone')).dx),
      );
      expect(
        tester
            .widget<PixelChip>(find.ancestor(
                of: find.text('Friends'), matching: find.byType(PixelChip)))
            .style,
        PixelBoxStyle.gold,
      );
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.byKey(const ValueKey('plaza_feed_scope')), findsNothing);

      // Verify tapping 'My Town' selects it and updates feed scope to 'town'
      final myTownFinder = find.ancestor(
        of: find.text('My Town'),
        matching: find.byType(PixelChip),
      );
      expect(
        tester.widget<PixelChip>(myTownFinder).style,
        PixelBoxStyle.parchment,
      );
      await tester.tap(find.text('Everyone'));
      await tester.pump();
      expect(feedNotifier.lastScope, 'mixed');
      await tester.tap(find.text('Friends'));
      await tester.pump();
      expect(feedNotifier.lastScope, 'following');

      // Verify tapping 'My Town' selects it and updates feed scope to 'town'
      await tester.tap(find.text('My Town'));
      await tester.pump();
      expect(tester.widget<PixelChip>(myTownFinder).style, PixelBoxStyle.gold);
      expect(feedNotifier.lastScope, 'town');
    });

    testWidgets('Renders PlazaRanker v2 activity reason chips', (tester) async {
      final rivalActivity = ActivityItemModel(
        id: 'act-rival-1',
        verb: 'quest_completed',
        actorName: 'Scout Marco',
        subjectType: 'quest',
        subjectTitle: 'Bolinao Lighthouse Quest',
        municipality: 'Bolinao',
        payload: const {},
        reason: 'rival',
        reasonLabel: 'Rival · #3 This Week',
        cheerCount: 3,
        cheeredByMe: false,
        commentCount: 1,
        createdAt: DateTime(2026, 11, 8),
      );

      final feedNotifier = _FakePlazaFeedNotifier(
        ApiClient(),
        AsyncValue.data([rivalActivity]),
      );

      await tester.pumpWidget(createPlazaApp(feedNotifier));
      await tester.pumpAndSettle();

      expect(find.text('Rival · #3 This Week'), findsOneWidget);
    });

    // v0.3.1: a small Explore-style heart. v0.3.8: comments are back.
    testWidgets('Cheer is a small heart like Explore, with a comments chip', (
      tester,
    ) async {
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

      final cheer = find.byKey(const ValueKey('plaza_cheer_act-test-1'));
      expect(cheer, findsOneWidget);
      expect(
        find.descendant(of: cheer, matching: find.byType(SpotLikeHeartIcon)),
        findsOneWidget,
      );
      expect(find.descendant(of: cheer, matching: find.byType(PixelButton)),
          findsNothing);
      expect(tester.getSize(cheer).height, lessThanOrEqualTo(40));
      expect(find.byKey(const ValueKey('plaza_comments_act-test-1')),
          findsOneWidget);
      expect(find.text('2 comments'), findsOneWidget);
    });
  });

  // Owner 2026-11-08: My Town follows the town you say you are from.
  testWidgets('My Town without a home town asks for one and opens the picker', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plazaFeedProvider.overrideWith((ref) => feedNotifier),
          plazaStandingsProvider.overrideWith(
            (ref, arg) async => arg.startsWith('town:')
                ? {'entries': [], 'reason': 'NO_HOME_TOWN'}
                : {'entries': []},
          ),
          homeTownProvider.overrideWith(
            (ref) async => const HomeTownInfo(
              town: null,
              gpsEnabled: false,
              options: ['Bolinao', 'Dagupan City'],
            ),
          ),
          pushServiceProvider.overrideWithValue(_FakePushService()),
        ],
        child: MaterialApp(theme: AppTheme.pixel, home: const PlazaScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plaza_no_home_town')), findsNothing);

    await tester.tap(find.text('My Town'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plaza_no_home_town')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plaza_set_home_town')));
    await tester.pumpAndSettle();
    // Team review v0.3.10: a province -> town combobox, not 49 buttons.
    expect(find.byKey(const ValueKey('home_town_picker')), findsOneWidget);
    expect(find.text('Outside Pangasinan / visiting'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('town_picker_province')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pangasinan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('town_picker_town')));
    await tester.pumpAndSettle();
    expect(find.text('Dagupan City'), findsWidgets);
    expect(find.text('Bolinao'), findsWidgets);
  });

  testWidgets('the Plaza refresh button uses the two-arrow icon', (
    tester,
  ) async {
    final feedNotifier = _FakePlazaFeedNotifier(
      ApiClient(),
      AsyncValue.data([testActivity]),
    );
    await tester.pumpWidget(createPlazaApp(feedNotifier));
    await tester.pumpAndSettle();
    final button = tester
        .widget<PixelIconButton>(find.byKey(const ValueKey('plaza_refresh')));
    expect(button.icon, PlazaArt.refresh);
    expect(button.semanticLabel, 'Refresh Plaza');
  });
}
