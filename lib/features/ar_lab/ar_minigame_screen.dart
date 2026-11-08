import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../ar_experience/core/geo_anchor.dart';
import '../ar_experience/core/world_ar.dart';
import '../ar_experience/games/ar_minigame.dart';
import '../ar_experience/games/ar_minigame_hud.dart';
import '../ar_experience/games/ar_sprites.dart';
import '../ar_experience/games/tumbang_preso.dart';
import '../ar_experience/widgets/world_ar_view.dart';

/// AR Lab host for one [ArMiniGame] (Plan 77; owner 2026-11-06: "build the mini
/// games altogether then we check it all at the same time"). ARCore draws the
/// sprites natively (`ArSpriteRenderer.kt`); this screen feeds the game the time
/// and the pose, sends its scenes and shows the HUD.
class ArMiniGameScreen extends StatefulWidget {
  const ArMiniGameScreen({super.key, required this.create});

  final ArMiniGame Function() create;

  @override
  State<ArMiniGameScreen> createState() => _ArMiniGameScreenState();
}

class _ArMiniGameScreenState extends State<ArMiniGameScreen> with SingleTickerProviderStateMixin {
  late final ArMiniGame _game = widget.create();
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_tick);
  WorldArSession? _world;
  bool _ready = false;
  bool _placing = false;

  /// The anchor is down; start the game on the first frame that has a pose
  /// (Pana faces its sway across the player).
  bool _placePending = false;
  bool _pressed = false;
  String? _error;
  String? _callout;
  Timer? _calloutTimer;
  GamePose? _pose;

  double get _now => _clock.elapsedMicroseconds / 1e6;

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
    _ticker.start();
  }

  Future<void> _onViewCreated(int id) async {
    final s = WorldArSession(id);
    _world = s;
    final bundle = DefaultAssetBundle.of(context);
    await s.setNativeObject(false);
    final sheets = await ArSpriteSheet.loadManifest(bundle);
    for (final sheet in sheets.values) {
      await s.loadSpriteSheet(sheet, await sheet.loadPng(bundle));
    }
  }

  /// Camera position (relative to the anchor) and view direction, or null.
  void _readPose() {
    final f = _world?.frame.value;
    final a = f?.anchor;
    if (f == null || !f.tracking || a == null) {
      _pose = null;
      return;
    }
    final c = GeoAnchor.cameraPosition(f.view!);
    final fw = GeoAnchor.cameraForward(f.view!);
    _pose = GamePose(V3(c.x - a[12], c.y - a[13], c.z - a[14]), V3(fw.x, fw.y, fw.z));
  }

  /// Sends what the game asked for: scene, callout, haptics.
  void _flush() {
    final scene = _game.takeScene();
    if (scene != null) _world?.setSprites(scene);
    final text = _game.takeCallout();
    if (text != null) {
      _calloutTimer?.cancel();
      _callout = text;
      _calloutTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _callout = null);
      });
    }
    switch (_game.takeHaptic()) {
      case ArHaptic.heavy:
        HapticFeedback.heavyImpact();
      case ArHaptic.light:
        HapticFeedback.lightImpact();
      case ArHaptic.none:
        break;
    }
  }

  void _tick(Duration _) {
    if (!mounted) return;
    _readPose();
    if (_placePending && _pose != null) {
      _placePending = false;
      _placing = false;
      _game.place(_now, _pose);
    }
    _game.update(_now, _pose);
    _flush();
    setState(() {});
  }

  /// Owner 2026-11-07: "spawn point is where the player should be against the
  /// target". The player stands where they will play; the target is anchored
  /// [ArMiniGame.standDistance] metres straight ahead on the floor, and the chalk
  /// line goes at their feet.
  Future<void> _place() async {
    final f = _world?.frame.value;
    if (f == null || !f.tracking || f.view == null) {
      _game.say('MOVE YOUR PHONE A LITTLE');
      _flush();
      return;
    }
    final c = GeoAnchor.cameraPosition(f.view!);
    final fw = GeoAnchor.cameraForward(f.view!);
    final flat = V3(fw.x, 0, fw.z);
    if (flat.horizontalLength < 0.2) {
      _game.say('FACE AHEAD, NOT DOWN');
      _flush();
      return;
    }
    final ahead = flat.unit * _game.standDistance;
    setState(() => _placing = true);
    final at = await _world?.placeAnchorAt(c.x + ahead.x, c.z + ahead.z);
    if (!mounted) return;
    if (at == null) {
      setState(() => _placing = false);
      _game.say('NO FLOOR YET');
      _flush();
      return;
    }
    _game.stand = V3(c.x - at.x, 0, c.z - at.z);
    _placePending = true;
  }

  Future<void> _move() async {
    _pressed = false;
    _placePending = false;
    _placing = false;
    _game.unplace();
    _flush();
    await _world?.clearAnchor();
    setState(() {});
  }

  void _restart() {
    _game.restart(_now, _pose);
    _flush();
    setState(() {});
  }

  void _press() {
    _pressed = _game.buttonMode == ArButtonMode.hold;
    _game.press(_now, _pose);
    _flush();
  }

  void _release() {
    _pressed = false;
    _game.release(_now, _pose);
    _flush();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _ticker.dispose();
    _calloutTimer?.cancel();
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
                    Positioned.fill(child: WorldArView(onCreated: _onViewCreated)),
                    Positioned.fill(
                      child: ArMiniGameHud(
                        game: _game,
                        now: _now,
                        pose: _pose,
                        callout: _callout,
                        placing: _placing,
                        pressed: _pressed,
                        onPlace: _place,
                        onMove: _move,
                        onRestart: _restart,
                        onPress: _press,
                        onRelease: _release,
                        onSwipe: (deg) {
                          _game.swipe(_now, _pose, deg);
                          _flush();
                        },
                        onPull: (v) => _game.pull(_now, v),
                      ),
                    ),
                  ]),
      ),
    );
  }
}
