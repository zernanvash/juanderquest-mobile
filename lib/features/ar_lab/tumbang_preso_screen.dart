import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../ar_experience/core/geo_anchor.dart';
import '../ar_experience/core/world_ar.dart';
import '../ar_experience/games/ar_sprites.dart';
import '../ar_experience/games/tumbang_preso.dart';
import '../ar_experience/games/tumbang_preso_hud.dart';
import '../ar_experience/widgets/world_ar_view.dart';

/// AR Lab prototype of the throwing game (Plan 77, owner 2026-11-06: "lets try
/// do the throwing game first"). ARCore draws the sprites in its own frame
/// (`ArSpriteRenderer.kt`); this screen runs the game and the HUD.
class TumbangPresoScreen extends StatefulWidget {
  const TumbangPresoScreen({super.key});

  @override
  State<TumbangPresoScreen> createState() => _TumbangPresoScreenState();
}

class _TumbangPresoScreenState extends State<TumbangPresoScreen> with SingleTickerProviderStateMixin {
  final TumbangPresoGame _game = TumbangPresoGame();
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_tick);
  WorldArSession? _world;
  bool _ready = false;
  bool _placing = false;
  String? _error;
  String? _callout;
  Timer? _calloutTimer;
  ({double from, double to})? _sweet;
  double _lastSweet = -1;
  V3? _cam;
  V3? _forward;

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

  /// Camera position (relative to the can's anchor) and view direction, or null.
  void _readPose() {
    final f = _world?.frame.value;
    final a = f?.anchor;
    if (f == null || !f.tracking || a == null) {
      _cam = null;
      return;
    }
    final c = GeoAnchor.cameraPosition(f.view!);
    final fw = GeoAnchor.cameraForward(f.view!);
    _cam = V3(c.x - a[12], c.y - a[13], c.z - a[14]);
    _forward = V3(fw.x, fw.y, fw.z);
  }

  void _tick(Duration _) {
    if (!mounted) return;
    _readPose();
    final now = _now;
    final cam = _cam;
    if (cam != null && (_game.phase == TumbangPhase.ready || _game.phase == TumbangPhase.charging) &&
        now - _lastSweet > 0.25) {
      _lastSweet = now;
      _sweet = TumbangPresoGame.sweetSpot(cam);
    }
    switch (_game.update(now)) {
      case TumbangEvent.hit:
        HapticFeedback.heavyImpact();
        _say('BAGSAK!');
      case TumbangEvent.miss:
        _say('MINTIS!');
      case TumbangEvent.reset:
        _world?.setSprites(TumbangPresoScene.ready());
      case TumbangEvent.won:
        HapticFeedback.heavyImpact();
      case TumbangEvent.none:
        break;
    }
    setState(() {});
  }

  void _say(String text) {
    _calloutTimer?.cancel();
    _callout = text;
    _calloutTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _callout = null);
    });
  }

  Future<void> _place() async {
    setState(() => _placing = true);
    final ok = await _world?.placeAnchor() ?? false;
    if (!mounted) return;
    setState(() => _placing = false);
    if (!ok) {
      _say('NO FLOOR YET');
      return;
    }
    _game.placed();
    await _world?.setSprites(TumbangPresoScene.ready());
  }

  Future<void> _move() async {
    _game.unplaced();
    await _world?.setSprites(const []);
    await _world?.clearAnchor();
    setState(() {});
  }

  Future<void> _restart() async {
    _game.restart();
    await _world?.setSprites(TumbangPresoScene.ready());
    setState(() {});
  }

  void _holdStart() => _game.startCharge(_now);

  void _holdEnd() {
    final cam = _cam, fw = _forward;
    if (cam == null || fw == null) {
      _game.cancelCharge();
      return;
    }
    final shot = _game.release(_now, camera: cam, forward: fw);
    if (shot == null) return;
    HapticFeedback.lightImpact();
    _world?.setSprites(TumbangPresoScene.throwing(shot));
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
                    Positioned.fill(child: _hud()),
                  ]),
      ),
    );
  }

  Widget _hud() {
    final cam = _cam, fw = _forward;
    return TumbangPresoHud(
      phase: _game.phase,
      hits: _game.hits,
      targetHits: _game.targetHits,
      power: _game.power(_now),
      sweetSpot: _sweet,
      distanceM: cam == null ? null : math.sqrt(cam.x * cam.x + cam.z * cam.z),
      offAimDeg: cam == null || fw == null ? null : TumbangPresoGame.offAimDegrees(cam, fw),
      canInView: cam != null,
      callout: _callout,
      placing: _placing,
      onPlace: _place,
      onMove: _move,
      onRestart: _restart,
      onHoldStart: _holdStart,
      onHoldEnd: _holdEnd,
    );
  }
}
