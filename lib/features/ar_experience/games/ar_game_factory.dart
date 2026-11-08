import 'dart:math' as math;

import 'ar_minigame.dart';
import 'palayok.dart';
import 'pana.dart';
import 'ring_shoot.dart';
import 'sipa.dart';
import 'tumbang_preso.dart';

/// The game for a task's `verification.game` (Plan 77), seeded by the server
/// session so the taya's route, the wind and the bangus are reproducible.
ArMiniGame? createArGame(String game, int seed) {
  final r = math.Random(seed);
  return switch (game) {
    'tumbang_preso' => TumbangGame(random: r),
    'shooting_hoop' => RingShootGame(),
    'pana' => PanaGame(random: r),
    'pabitin_palayok' => PalayokGame(random: r),
    'sipa' => SipaGame(random: r),
    _ => null,
  };
}

/// Builder and help copy for each game (Plan 77 WP-3).
const arGameInfo = <String, ({String name, String rule, double metres})>{
  'collect': (name: 'Collect relic', rule: 'Find the hidden relic in the area.', metres: 0),
  'tumbang_preso': (name: 'Tumbang Preso', rule: '10 tsinelas; knock the can 4 times.', metres: 5),
  'shooting_hoop': (name: 'Ring Shoot', rule: '10 balls; sink 4 baskets.', metres: 4.2),
  'pana': (name: 'Pana', rule: '6 arrows; score 28 points.', metres: 8),
  'pabitin_palayok': (name: 'Pukpok Palayok', rule: 'Break the palayok, blindfolded.', metres: 1.5),
  'sipa': (name: 'Sipa Rally', rule: '3 lives; keep it up 5 kicks in a row.', metres: 2),
};
