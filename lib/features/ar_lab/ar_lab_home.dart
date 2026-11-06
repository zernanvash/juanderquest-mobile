import 'package:flutter/material.dart';

import '../ar_experience/games/ar_minigame.dart';
import '../ar_experience/games/palayok.dart';
import '../ar_experience/games/pana.dart';
import '../ar_experience/games/ring_shoot.dart';
import '../ar_experience/games/sipa.dart';
import 'ar_lab_screen.dart';
import 'ar_minigame_screen.dart';
import 'tumbang_preso_screen.dart';

/// Start menu of the JDQ AR Lab test app. Each test opens its own ARCore view;
/// only one is alive at a time.
class ArLabHome extends StatelessWidget {
  const ArLabHome({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return Scaffold(
      appBar: AppBar(title: const Text('JDQ AR Lab')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            key: const ValueKey('lab_tumbang_preso'),
            title: const Text('Tumbang Preso (throwing game)'),
            subtitle: const Text('Knock the lata with a tsinelas.'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => open(const TumbangPresoScreen()),
          ),
        ),
        for (final (key, title, subtitle, create) in <(String, String, String, ArMiniGame Function())>[
          ('lab_ring_shoot', 'Ring Shoot (basketball)', 'Arc the ball through the barangay ring.', RingShootGame.new),
          ('lab_pana', 'Pana (archery)', 'Shoot arrows at the swaying bilao.', PanaGame.new),
          ('lab_palayok', 'Pukpok Palayok', 'Hit the swinging clay pot 3 times.', PalayokGame.new),
          ('lab_sipa', 'Sipa Rally', 'Keep the sipa up: 5 kicks in a row.', SipaGame.new),
        ])
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
