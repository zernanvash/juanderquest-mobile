import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/celebrations/celebration.dart';
import 'package:juanderquest_app/features/celebrations/scenes/quest_complete_scene.dart';

class _MemoryPixelSettingsStore implements PixelSettingsStore {
  PixelSettings? value;

  @override
  Future<PixelSettings?> read() async => value;

  @override
  Future<void> write(PixelSettings settings) async {
    value = settings;
  }
}

Widget _buildTestApp({
  required Widget home,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      pixelSettingsStoreProvider.overrideWithValue(_MemoryPixelSettingsStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 720),
          disableAnimations: disableAnimations,
        ),
        child: home,
      ),
    ),
  );
}

void main() {
  group('Celebration Widget Tests', () {
    testWidgets('showCelebration pushes the page and overlay button pops it', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCelebration(
                  context,
                  const QuestComplete(
                    questTitle: 'Hundred Islands Eco Run',
                    reward: 75,
                  ),
                ),
                child: const Text('TRIGGER'),
              ),
            ),
          ),
        ),
      );

      // Verify home is showing
      expect(find.text('TRIGGER'), findsOneWidget);
      expect(find.byType(CelebrationPage), findsNothing);

      // Tap trigger to show celebration
      await tester.tap(find.text('TRIGGER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Celebration page is now showing
      expect(find.byType(CelebrationPage), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
      expect(find.text('CLAIM REWARD'), findsOneWidget);

      // Tap action button to pop
      await tester.tap(find.text('CLAIM REWARD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Celebration page has been dismissed
      expect(find.byType(CelebrationPage), findsNothing);
      expect(find.text('TRIGGER'), findsOneWidget);
    });

    testWidgets('Back pops the celebration page', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCelebration(
                  context,
                  const LevelUp(fromLevel: 7, toLevel: 8),
                ),
                child: const Text('TRIGGER_LEVEL'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TRIGGER_LEVEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CelebrationPage), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);

      // Simulate back press via WidgetsBinding
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CelebrationPage), findsNothing);
      expect(find.text('TRIGGER_LEVEL'), findsOneWidget);
    });

    testWidgets('Stamp earned scene shows ADD TO PASSPORT button and pops', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCelebration(
                  context,
                  const StampEarned(
                    stampName: 'JuanChoice Voter',
                    stamp: DesignerArt.juanChoice,
                  ),
                ),
                child: const Text('TRIGGER_STAMP'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TRIGGER_STAMP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CelebrationPage), findsOneWidget);
      expect(find.text('ADD TO PASSPORT'), findsOneWidget);

      await tester.tap(find.text('ADD TO PASSPORT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CelebrationPage), findsNothing);
    });

    testWidgets('reduced motion shows the final state at once', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          disableAnimations: true,
          home: const CelebrationPage(
            celebration: QuestComplete(
              questTitle: 'Eco Run',
              reward: 75,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Find GameWidget and verify its game instance
      final gameWidget = tester.widget(find.byWidgetPredicate((w) => w is GameWidget)) as GameWidget;
      final game = gameWidget.game as QuestCompleteGame;

      // Under reduced motion, chest is immediately open and reward is at target
      expect(game.reducedMotion, isTrue);
      expect(game.isChestOpen, isTrue);
      expect(game.displayedReward, 75);
    });
  });
}
