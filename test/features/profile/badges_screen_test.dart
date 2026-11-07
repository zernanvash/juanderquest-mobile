import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/screens/badges_screen.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';

class _FakeSpotDiscoveryNotifier extends SpotDiscoveryNotifier {
  _FakeSpotDiscoveryNotifier(super.ref) {
    state = const SpotDiscoveryState(spots: []);
  }
}

Widget _createBadgesApp({
  required int stamps,
  required int streak,
  double textScale = 1.0,
}) {
  final dailyState = HomeDailyState(
    stamps: stamps,
    missions: const [],
    streak: streak,
    calendar: const [],
  );

  return ProviderScope(
    overrides: [
      homeDailyProvider.overrideWith((ref) async => dailyState),
      profileStatsProvider.overrideWithValue(ProfileStatsModel(
        completedQuestsCount: 0,
        pendingSubmissionsCount: 0,
        totalPointsEarned: 0,
        ecoPioneerState: BadgeState.earned,
        heritageKeeperState: BadgeState.locked,
        foodExplorerState: BadgeState.locked,
      )),
      spotDiscoveryProvider.overrideWith((ref) => _FakeSpotDiscoveryNotifier(ref)),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
        ),
        child: const BadgesScreen(),
      ),
    ),
  );
}

void main() {
  group('BadgesScreen Tests (Plan 79a)', () {
    testWidgets('Singular 1 Day and 1 Stamp labels render correctly',
        (tester) async {
      await tester.pumpWidget(_createBadgesApp(stamps: 1, streak: 1));
      await tester.pumpAndSettle();

      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('Stamp'), findsOneWidget);
      expect(find.text('1 Days'), findsNothing);
      expect(find.text('Stamps'), findsNothing);
    });

    testWidgets('Plural Days and Stamps labels render correctly',
        (tester) async {
      await tester.pumpWidget(_createBadgesApp(stamps: 5, streak: 3));
      await tester.pumpAndSettle();

      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('Stamps'), findsOneWidget);
      expect(find.text('Badges'), findsOneWidget);
    });

    testWidgets(
        'Header does not overflow at 320px width with 2.0x text scaling',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      final List<FlutterErrorDetails> overflowErrors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflowErrors.add(details);
        }
        originalOnError?.call(details);
      };

      addTearDown(() {
        FlutterError.onError = originalOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(_createBadgesApp(
        stamps: 1,
        streak: 1,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pangasinan Badge Case'), findsOneWidget);
      expect(overflowErrors, isEmpty,
          reason: 'Expected 0 RenderFlex overflow errors in header');
    });
  });
}
