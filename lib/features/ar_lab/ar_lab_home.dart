import 'package:flutter/material.dart';

import 'ar_lab_screen.dart';
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
            subtitle: const Text('Plan 77 prototype: knock the lata with a tsinelas.'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => open(const TumbangPresoScreen()),
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
