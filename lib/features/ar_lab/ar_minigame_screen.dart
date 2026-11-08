import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../ar_experience/core/world_ar.dart';
import '../ar_experience/games/ar_minigame.dart';
import '../ar_experience/games/ar_minigame_host.dart';
import '../ar_experience/widgets/world_ar_view.dart';

/// AR Lab screen for one [ArMiniGame] (Plan 77; owner 2026-11-06: "build the
/// mini games altogether then we check it all at the same time"): the camera
/// view plus [ArMiniGameHost], with no server session.
class ArMiniGameScreen extends StatefulWidget {
  const ArMiniGameScreen({super.key, required this.create});

  final ArMiniGame Function() create;

  @override
  State<ArMiniGameScreen> createState() => _ArMiniGameScreenState();
}

class _ArMiniGameScreenState extends State<ArMiniGameScreen> {
  late final ArMiniGame _game = widget.create();
  WorldArSession? _world;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _start();
  }

  Future<void> _start() async {
    if (!(await Permission.camera.request()).isGranted) {
      setState(() => _error = 'Camera permission is needed.');
      return;
    }
    final ar = await WorldArSupport.check();
    if (ar != WorldArAvailability.installed) {
      setState(() => _error = 'ARCore is not available on this phone ($ar).');
      return;
    }
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _world?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : Stack(children: [
                    Positioned.fill(child: WorldArView(onCreated: (id) => setState(() => _world = WorldArSession(id)))),
                    Positioned.fill(child: ArMiniGameHost(game: _game, session: _world)),
                  ]),
      ),
    );
  }
}
