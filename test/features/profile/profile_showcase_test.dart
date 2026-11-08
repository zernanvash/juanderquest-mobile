import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/profile/showcase.dart';

// Owner 2026-11-08: bio, 3 equipped badges, home town, Pasaporte, stats,
// favourite spot and latest journey on the profile.
void main() {
  final full = ProfileShowcase.fromJson({
    'bio':
        'Bangus lover from Dagupan. Chasing every sunset in Bolinao and every pista in between, with a very long bio.',
    'home_municipality': 'San Carlos City',
    'featured_badges': [
      {'id': 'pangasinan_pioneer', 'title': 'Pangasinan Pioneer'},
      {'id': 'first_footstep', 'title': 'First Footstep'},
    ],
    'favorite_spot': {'id': 's1', 'slug': 'tondaligan', 'name': 'Tondaligan Beach', 'municipality': 'Dagupan City'},
    'stats': {
      'quests_completed': 12,
      'spots_posted': 3,
      'trails_completed': 1,
      'best_weekly_rank': 4,
      'badges_earned': 5
    },
    'pasaporte': {
      'visited': ['Alaminos City', 'Bolinao', 'Dagupan City', 'San Fabian', 'Lingayen'],
      'total': 48
    },
    'latest_journey': [
      {'title': 'Hundred Islands island-hop', 'municipality': 'Alaminos City', 'at': DateTime.now().toIso8601String()},
      {'title': 'Cape Bolinao lighthouse climb', 'municipality': 'Bolinao', 'at': '2026-11-01T08:00:00Z'},
    ],
  });

  test('parses the server showcase', () {
    expect(full.badges.map((b) => b.title), ['Pangasinan Pioneer', 'First Footstep']);
    expect((full.quests, full.bestWeeklyRank, full.townsVisited.length, full.townsTotal), (12, 4, 5, 48));
    expect(full.favorite!.slug, 'tondaligan');
    expect(ProfileShowcase.fromJson({'bio': '  '}).bio, isNull);
  });

  Widget host(ProfileShowcase s, {required bool mine, Size size = const Size(400, 900)}) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
            child: Scaffold(body: SingleChildScrollView(child: ProfileShowcaseSection(showcase: s, isMine: mine))),
          ),
        ),
      );

  testWidgets('your own profile has edit buttons and an empty slot to equip', (tester) async {
    await tester.pumpWidget(host(full, mine: true));
    expect(find.text('Taga-San Carlos City'), findsOneWidget);
    expect(find.text('Pangasinan Pioneer'), findsOneWidget);
    expect(find.text('+ Equip'), findsOneWidget);
    expect(find.text('5 / 48'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_edit_bio')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_edit_badges')), findsOneWidget);
    expect(find.text('Hundred Islands island-hop'), findsOneWidget);
  });

  testWidgets("someone else's profile has no edit buttons, and no favourite card when unset", (tester) async {
    await tester.pumpWidget(host(const ProfileShowcase(bio: 'Hi'), mine: false));
    expect(find.byKey(const ValueKey('profile_edit_bio')), findsNothing);
    expect(find.byKey(const ValueKey('profile_favorite')), findsNothing);
    expect(find.byKey(const ValueKey('profile_journey')), findsNothing);
    expect(find.text('—'), findsNWidgets(4)); // three empty badge slots + no best week
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('fits at ${size.width.toInt()}x${size.height.toInt()} with 2x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(full, mine: true, size: size));
      expect(tester.takeException(), isNull);
    });
  }
}
