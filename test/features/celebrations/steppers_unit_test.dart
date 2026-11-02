import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/celebrations/steppers.dart';

void main() {
  group('Steppers Unit Tests', () {
    test('the coin physics stepper is deterministic and only moves on 12 fps ticks', () {
      const unit = 2.0;

      // Determinism: two steppers with the same seed yield identical particle state
      final stepper1 = CoinPhysicsStepper(unit: unit, count: 22, seed: 7, originX: 100, originY: 200);
      final stepper2 = CoinPhysicsStepper(unit: unit, count: 22, seed: 7, originX: 100, originY: 200);

      expect(stepper1.coins.length, 22);
      expect(stepper2.coins.length, 22);

      for (var i = 0; i < 22; i++) {
        expect(stepper1.coins[i].x, stepper2.coins[i].x);
        expect(stepper1.coins[i].y, stepper2.coins[i].y);
        expect(stepper1.coins[i].vx, stepper2.coins[i].vx);
        expect(stepper1.coins[i].vy, stepper2.coins[i].vy);
      }

      // Step threshold: does NOT move if dt is below 1/12 second (~0.0833s)
      final initialX = stepper1.coins.first.x;
      final initialY = stepper1.coins.first.y;

      stepper1.update(0.04);
      expect(stepper1.tickCount, 0, reason: 'dt=0.04s should not trigger a 12 fps tick');
      expect(stepper1.coins.first.x, initialX);
      expect(stepper1.coins.first.y, initialY);

      // Accumulating up to >= 1/12s triggers exactly 1 tick
      stepper1.update(0.05); // 0.04 + 0.05 = 0.09s >= 0.0833s
      expect(stepper1.tickCount, 1, reason: '0.09s total should trigger exactly 1 tick');
      expect(stepper1.coins.first.x, isNot(equals(initialX)));
      expect(stepper1.coins.first.y, isNot(equals(initialY)));

      // Stepper 2 advances with a single 0.09s update and produces the exact same state
      stepper2.update(0.09);
      expect(stepper2.tickCount, 1);
      for (var i = 0; i < 22; i++) {
        expect(stepper1.coins[i].x, stepper2.coins[i].x);
        expect(stepper1.coins[i].y, stepper2.coins[i].y);
        expect(stepper1.coins[i].vx, stepper2.coins[i].vx);
        expect(stepper1.coins[i].vy, stepper2.coins[i].vy);
      }
    });

    test('the reward counter goes 0, 5, 10 … and ends exactly on the reward (also for rewards that aren\'t multiples of 5)', () {
      // 1. Multiple of 5: target = 75
      final stepper75 = RewardCounterStepper(targetReward: 75, stepSize: 5);
      final sequence75 = <int>[stepper75.current];

      while (!stepper75.isComplete) {
        stepper75.step();
        sequence75.add(stepper75.current);
      }

      expect(sequence75.first, 0);
      expect(sequence75[1], 5);
      expect(sequence75[2], 10);
      expect(sequence75.last, 75);
      expect(stepper75.current, 75);
      expect(stepper75.isComplete, isTrue);

      // Extra steps remain at target
      stepper75.step();
      expect(stepper75.current, 75);

      // 2. Non-multiple of 5: target = 73
      final stepper73 = RewardCounterStepper(targetReward: 73, stepSize: 5);
      final sequence73 = <int>[stepper73.current];

      while (!stepper73.isComplete) {
        stepper73.step();
        sequence73.add(stepper73.current);
      }

      expect(sequence73.first, 0);
      expect(sequence73[1], 5);
      expect(sequence73[14], 70);
      expect(sequence73.last, 73, reason: 'Must end exactly on 73, not 75');
      expect(stepper73.current, 73);
      expect(stepper73.isComplete, isTrue);

      // 3. Small target below stepSize: target = 3
      final stepper3 = RewardCounterStepper(targetReward: 3, stepSize: 5);
      expect(stepper3.current, 0);
      stepper3.step();
      expect(stepper3.current, 3);
      expect(stepper3.isComplete, isTrue);

      // 4. Zero target
      final stepper0 = RewardCounterStepper(targetReward: 0, stepSize: 5);
      expect(stepper0.isComplete, isTrue);
      expect(stepper0.current, 0);
    });

    test('the typewriter reveals one letter per step', () {
      const text = 'QUEST COMPLETE!';
      final stepper = TypewriterStepper(text);

      expect(stepper.text, '');
      expect(stepper.revealedLength, 0);
      expect(stepper.isComplete, isFalse);

      for (var i = 0; i < text.length; i++) {
        stepper.step();
        expect(stepper.revealedLength, i + 1);
        expect(stepper.text, text.substring(0, i + 1));
      }

      expect(stepper.isComplete, isTrue);
      expect(stepper.text, text);

      // Subsequent steps do nothing
      stepper.step();
      expect(stepper.text, text);
    });

    test('ray rotation has exactly 8 steps', () {
      final stepper = RayRotationStepper();
      final seenSteps = <int>{};
      final seenAngles = <double>{};

      for (var i = 0; i < 8; i++) {
        seenSteps.add(stepper.currentStep);
        seenAngles.add(stepper.angle);
        stepper.step();
      }

      // Exactly 8 distinct step indices (0 to 7) and 8 distinct angles
      expect(seenSteps.length, 8);
      expect(seenSteps, {0, 1, 2, 3, 4, 5, 6, 7});
      expect(seenAngles.length, 8);

      // The 9th step wraps exactly to step 0
      expect(stepper.currentStep, 0);
      expect(stepper.angle, 0.0);
    });
  });
}
