import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/geo_anchor.dart';
import '../core/world_ar.dart';
import 'ar_minigame.dart';
import 'ar_minigame_hud.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// Plays one [ArMiniGame] over an ARCore view the parent owns (Plan 77): the
/// AR Lab screen and the quest AR task both use it. ARCore draws the sprites
/// natively (`ArSpriteRenderer.kt`); this widget feeds the game the time and
/// the pose, sends its scenes and shows the HUD.
class ArMiniGameHost extends StatefulWidget {
  const ArMiniGameHost({
    super.key,
    required this.game,
    required this.session,
    this.onOver,
    this.onRestart,
    this.endExtra,
    this.endActions,
  });

  final ArMiniGame game;

  /// The parent's ARCore session; null until its view exists.
  final WorldArSession? session;

  /// Called once when the game ends (won, or out of throws).
  final ValueChanged<ArMiniGame>? onOver;

  /// PLAY AGAIN: when set, the parent restarts (e.g. with a new server
  /// session and a new game); otherwise the game restarts in place.
  final VoidCallback? onRestart;

  /// Shown on the end panel under the result, and buttons that replace PLAY AGAIN.
  final Widget? endExtra;
  final List<Widget>? endActions;

  @override
  State<ArMiniGameHost> createState() => _ArMiniGameHostState();
}

/// Sprite sheets already uploaded to a session (once per ARCore view).
final Expando<bool> _sheetsLoaded = Expando('arSpriteSheets');

/// Uploads every sprite sheet in the bundled manifest to [session], once, and
/// hides the native 3D gem. False if a sheet could not be loaded.
Future<bool> loadArSpriteSheets(WorldArSession session, AssetBundle bundle) async {
  if (_sheetsLoaded[session] == true) return true;
  _sheetsLoaded[session] = true;
  await session.setNativeObject(false);
  try {
    final sheets = await ArSpriteSheet.loadManifest(bundle);
    var ok = true;
    for (final sheet in sheets.values) {
      ok = await session.loadSpriteSheet(sheet, await sheet.loadPng(bundle)) && ok;
    }
    return ok;
  } catch (_) {
    return false;
  }
}

/// The relic of a collect task in the games' pixel style (owner 2026-11-07:
/// "the object collection should now be the same style from the games"),
/// spinning and bobbing over its shadow at the anchor, where the gem was.
List<ArSprite> relicSprites(String object, {required double height}) {
  final item = object == 'box' ? 'crate' : object;
  return [
    const ArSprite('shadow', x: 0, y: 0, z: 0, scale: 2, floor: true),
    ArSprite('item_$item', x: 0, y: height, z: 0, scale: 1.6, fps: 10, loop: true, oscPeriod: 2.0, oy: 0.06),
  ];
}

class _ArMiniGameHostState extends State<ArMiniGameHost> with SingleTickerProviderStateMixin {
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_tick);
  bool _placing = false;

  /// The anchor is down; start the game on the first frame that has a pose
  /// (Pana faces its sway across the player).
  bool _placePending = false;
  bool _pressed = false;
  bool _wasOver = false;
  String? _callout;
  Timer? _calloutTimer;
  GamePose? _pose;

  ArMiniGame get _game => widget.game;
  WorldArSession? get _world => widget.session;
  double get _now => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _loadSheets();
  }

  @override
  void didUpdateWidget(ArMiniGameHost old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) _loadSheets();
  }

  void _loadSheets() {
    final s = _world;
    if (s != null) loadArSpriteSheets(s, DefaultAssetBundle.of(context));
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
    if (_game.over && !_wasOver) widget.onOver?.call(_game);
    _wasOver = _game.over;
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
    if (widget.onRestart != null) {
      widget.onRestart!();
      return;
    }
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
    _ticker.dispose();
    _calloutTimer?.cancel();
    // Leave the view clean for whatever comes next (a new game, or the relic).
    _world?.setSprites(const []);
    _world?.clearAnchor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArMiniGameHud(
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
      endExtra: widget.endExtra,
      endActions: widget.endActions,
    );
  }
}
