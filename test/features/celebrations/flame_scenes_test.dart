import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/features/celebrations/scenes/level_up_scene.dart';
import 'package:juanderquest_app/features/celebrations/scenes/quest_complete_scene.dart';
import 'package:juanderquest_app/features/celebrations/scenes/stamp_earned_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flame celebration scene tests (flame_test)', () {
    testWithGame<QuestCompleteGame>(
      'QuestCompleteGame loads and reaches final state after updates (chest opens, reward counts up)',
      () => QuestCompleteGame(
        unit: 2.0,
        font: 'Silkscreen',
        questTitle: 'Hundred Islands Eco Run',
        reward: 75,
        fontScale: 1.0,
      ),
      (game) async {
        expect(game.isChestOpen, isFalse);
        expect(game.displayedReward, 0);

        // Chest opens at t >= 0.8s
        game.update(0.85);
        expect(game.isChestOpen, isTrue);

        // Further updates complete the reward counter to exactly 75
        for (var i = 0; i < 30; i++) {
          game.update(0.1);
        }
        expect(game.displayedReward, 75);
      },
    );

    testWithGame<LevelUpGame>(
      'LevelUpGame loads and flips level to toLevel after updates',
      () => LevelUpGame(
        unit: 2.0,
        font: 'Silkscreen',
        fromLevel: 7,
        toLevel: 8,
        fontScale: 1.0,
      ),
      (game) async {
        expect(game.displayedLevel, 7);

        // Advance 1.0s to execute squash beat and flip to level 8
        game.update(1.0);
        expect(game.displayedLevel, 8);
      },
    );

    testWithGame<StampEarnedGame>(
      'StampEarnedGame loads and lands stamp after updates',
      () => StampEarnedGame(
        unit: 2.0,
        font: 'Silkscreen',
        stampName: 'JuanChoice Voter',
        stamp: DesignerArt.juanChoice,
        fontScale: 1.0,
      ),
      (game) async {
        expect(game.hasLanded, isFalse);

        // Advance time so stamp drops down and lands
        game.update(1.0);
        expect(game.hasLanded, isTrue);
      },
    );
  });
}
