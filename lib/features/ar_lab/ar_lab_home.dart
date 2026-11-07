import 'package:flutter/material.dart';

import '../ar_experience/games/ar_minigame.dart';
import '../ar_experience/games/palayok.dart';
import '../ar_experience/games/pana.dart';
import '../ar_experience/games/ring_shoot.dart';
import '../ar_experience/games/sipa.dart';
import '../ar_experience/games/tumbang_preso.dart';
import 'ar_collect_lab_screen.dart';
import 'ar_lab_screen.dart';
import 'ar_minigame_screen.dart';

/// Start menu of the JDQ AR Lab test app. Each test opens its own ARCore view;
/// only one is alive at a time.
class ArLabHome extends StatefulWidget {
  const ArLabHome({super.key});

  @override
  State<ArLabHome> createState() => _ArLabHomeState();
}

class _ArLabHomeState extends State<ArLabHome> {
  /// Half distances, for trying the games indoors.
  bool _short = false;

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final scale = _short ? 0.5 : 1.0;
    final games = <(String, String, String, ArMiniGame Function())>[
      ('lab_tumbang_preso', 'Tumbang Preso', '10 tsinelas, knock the lata 4 times. Watch out for the taya.',
          () => TumbangGame(rangeScale: scale)),
      ('lab_ring_shoot', 'Ring Shoot (basketball)', '10 balls, 4 baskets. The ring starts moving.',
          () => RingShootGame(rangeScale: scale)),
      ('lab_pana', 'Pana (archery)', '9 arrows, 40 points. Sway, wind and a golden bangus.',
          () => PanaGame(rangeScale: scale)),
      ('lab_palayok', 'Pukpok Palayok', 'Break the swinging pot. Blindfolded after the first hit.',
          () => PalayokGame(rangeScale: scale)),
      ('lab_sipa', 'Sipa Rally', 'Keep the sipa up: 5 kicks in a row.', () => SipaGame(rangeScale: scale)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('JDQ AR Lab')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          key: const ValueKey('lab_short_range'),
          title: const Text('Short range (indoors)'),
          subtitle: const Text('Half the distances, for testing in a small room.'),
          value: _short,
          onChanged: (v) => setState(() => _short = v),
        ),
        for (final (key, title, subtitle, create) in games)
          Card(
            child: ListTile(
              key: ValueKey(key),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => open(ArMiniGameScreen(create: create)),
            ),
          ),
        Card(
          child: ListTile(
            key: const ValueKey('lab_collect'),
            title: const Text('Collect objects (AR task)'),
            subtitle: const Text('The quest AR models: token, gem, crate, beacon, orb, pyramid. Tap to collect.'),
            trailing: const Icon(Icons.diamond_outlined),
            onTap: () => open(const ArCollectLabScreen()),
          ),
        ),
        Card(
          child: ListTile(
            key: const ValueKey('lab_world_spawn'),
            title: const Text('World-location spawn'),
            subtitle: const Text('Spawn the gem at a real latitude/longitude.'),
            trailing: const Icon(Icons.place),
            onTap: () => open(const ArLabScreen()),
          ),
        ),
      ]),
    );
  }
}
