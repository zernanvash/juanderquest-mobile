import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/providers/auth_provider.dart';
import '../../quests/models/quest_model.dart';
import '../core/ar_calibration.dart';
import '../core/ar_device.dart';
import '../core/ar_hunt.dart';
import '../core/ar_task.dart';
import '../core/camera_optics.dart';
import '../core/heading_fusion.dart';
import '../core/world_ar.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_calibration_panel.dart';
import '../widgets/ar_camera_layer.dart';
import '../widgets/ar_overlay.dart';
import '../widgets/world_ar_view.dart';
import '../core/ar_math.dart';
import '../core/geo_anchor.dart';
import '../games/ar_game_factory.dart';
import '../games/ar_minigame.dart';
import '../games/ar_minigame_host.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../map/pixel/map_marker_art.dart';

/// Which AR tier is running (Plan 47 §2).
enum ArTier {
  /// ARCore world tracking: the object sits on the real ground.
  world,

  /// Rotation-vector compass AR: works on every phone.
  compass,
}

/// Plays one Plan 43 AR task.
///
/// Route: `/quests/:id/ar?step=<order>`; `extra` may carry the [QuestModel].
class ArQuestScreen extends ConsumerStatefulWidget {
  final String questId;
  final int? stepOrder;
  final QuestModel? quest;

  const ArQuestScreen({
    super.key,
    required this.questId,
    this.stepOrder,
    this.quest,
  });

  /// Give up on World AR after tracking has been lost this long with nothing
  /// placed. Never for a game task (Plan 77): tracking drops on the walk there
  /// (phone lowered or in a pocket), and the relic hunt would replace the game.
  @visibleForTesting
  static bool fallBackOnTrackingLoss({
    required Duration lost,
    required Duration grace,
    required bool hasAnchor,
    required bool isGame,
  }) =>
      !isGame && !hasAnchor && lost > grace;

  @override
  ConsumerState<ArQuestScreen> createState() => _ArQuestScreenState();
}

class _ArQuestScreenState extends ConsumerState<ArQuestScreen> {
  /// Fall back to Compass AR if World AR can't track for this long.
  static const worldTrackingGrace = Duration(seconds: 8);
  static const setupTrackingGrace = Duration(seconds: 30);

  /// If the gem can't land on seen floor in its real direction this long, place
  /// it where the camera aims instead (still on seen floor).
  static const placeGrace = Duration(seconds: 8);

  /// Spawn distances tried in turn: the gem only lands on floor the camera has
  /// seen, so a wall or a bed in the way makes it try closer.
  static const spawnDistances = [ArHuntRules.spawnDistanceM, 2.5, 1.5];

  final ArDevice _device = ArDevice();
  ArTaskSpec? _task;
  ArHuntController? _hunt;
  StreamSubscription<Position>? _gps;
  CameraOptics _optics = CameraOptics.fallback;
  double _previewAspect = 4 / 3;
  String? _setupError;
  bool _permissionsDenied = false;

  ArTier? _tier;
  WorldArSession? _world;
  DateTime? _worldNotTrackingSince;
  bool _placing = false;

  /// Links compass bearings to ARCore's yaw so the object spawns in a real
  /// direction (AR Lab, owner 2026-11-02: "IT WORKED").
  final HeadingCalibration _heading = HeadingCalibration();
  DateTime _lastHeadingSample = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _placeTryingSince;
  int _spawnTry = 0;

  /// Guided set-up before the hunt; Juan's tutorial runs once per device first.
  final ArCalibration _calibration = ArCalibration();
  bool? _showTutorial;
  final ValueNotifier<ArScreenObject?> _worldObject = ValueNotifier(null);
  CompassObjectProjector? _compassObject;

  // Plan 77: a game task plays its mini-game once the player is in the area.
  ArQuestApi? _api;
  ArGameSession? _gameSession;
  ArMiniGame? _game;
  ArGameResult? _gameResult;
  bool _gameBusy = false;
  bool _gameDone = false;
  String? _gameError;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _setup();
  }

  Future<void> _setup() async {
    try {
      final quest = widget.quest ?? await _fetchQuest();
      final step = _pickStep(quest);
      if (step == null) {
        setState(() => _setupError = 'This quest has no AR task.');
        return;
      }
      final task = ArTaskSpec.from(quest, step);
      final api = ArQuestApi(ref.read(apiClientProvider).dio, task);
      final hunt = ArHuntController(
        fence: task.fence,
        requestChallenge: api.requestChallenge,
        submitEvidence: api.submitEvidence,
      )..addListener(_onHunt);
      if (!mounted) {
        hunt.dispose();
        return;
      }
      setState(() {
        _task = task;
        _hunt = hunt;
        _api = api;
      });
      _device.pose.addListener(_onPose);
      await _startSensors();
    } catch (_) {
      if (mounted) {
        setState(() => _setupError =
            'The quest could not be loaded. Check your connection and try again.');
      }
    }
  }

  Future<QuestModel> _fetchQuest() async {
    final res =
        await ref.read(apiClientProvider).dio.get('/quests/${widget.questId}');
    return QuestModel.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map));
  }

  QuestStepModel? _pickStep(QuestModel quest) {
    final ar = quest.steps.where((s) => s.checkpointType == 'ar');
    if (widget.stepOrder != null) {
      for (final s in ar) {
        if (s.order == widget.stepOrder) return s;
      }
      return null;
    }
    return ar.isEmpty ? null : ar.first;
  }

  Future<void> _startSensors() async {
    bool granted;
    try {
      final statuses =
          await [Permission.camera, Permission.locationWhenInUse].request();
      granted = statuses.values.every((s) => s.isGranted);
    } catch (_) {
      granted = false;
    }
    if (!granted) {
      if (mounted) setState(() => _permissionsDenied = true);
      return;
    }
    if (mounted) setState(() => _permissionsDenied = false);
    _optics = await ArDevice.cameraOptics();
    _device.start();
    await _chooseTier();
    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      _onPosition(first);
    } catch (_) {
      // The stream below keeps trying.
    }
    await _gps?.cancel();
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen(_onPosition, onError: (_) {});
    if (mounted) setState(() {});
  }

  /// World AR when it is enabled and ARCore is installed; otherwise Compass AR.
  Future<void> _chooseTier() async {
    var tier = ArTier.compass;
    if (await WorldArPrefs.enabled()) {
      var a = await WorldArSupport.check();
      if (a == WorldArAvailability.installable &&
          await WorldArPrefs.explicitlyEnabled() &&
          await WorldArSupport.requestInstall()) {
        a = WorldArAvailability.installed;
      }
      if (a == WorldArAvailability.installed) tier = ArTier.world;
    }
    // Plan 77: a phone without ARCore hunts the relic for a game task instead.
    _api?.noArcoreFallback = tier == ArTier.compass;
    final showTutorial = tier == ArTier.world &&
        _task?.isGame != true &&
        !await ArTutorialPrefs.seen();
    if (mounted) {
      setState(() {
        _tier = tier;
        _showTutorial = showTutorial;
      });
    }
    if (tier == ArTier.compass) _noGameNotice();
  }

  void _fallBackToCompass() {
    final world = _world;
    _world = null;
    world?.frame.removeListener(_onWorldFrame);
    world?.dispose();
    _worldObject.value = null;
    _api?.noArcoreFallback = true;
    if (mounted) setState(() => _tier = ArTier.compass);
    _noGameNotice();
  }

  void _onWorldViewCreated(int id) {
    final session = WorldArSession(id);
    session.frame.addListener(_onWorldFrame);
    _world = session;
    // Drawn natively in the camera frame, so it never lags behind the picture.
    session.setNativeObject(true, color: _task?.color);
    final task = _task;
    if (task != null && !task.isGame) _showPixelRelic(session, task);
  }

  /// Plan 77c: the relic as a pixel sprite; the 3D gem stays if the sheets fail.
  Future<void> _showPixelRelic(WorldArSession session, ArTaskSpec task) async {
    final ok =
        await loadArSpriteSheets(session, DefaultAssetBundle.of(context));
    if (!ok) {
      await session.setNativeObject(true, color: task.color);
      return;
    }
    await session
        .setSprites(relicSprites(task.object, height: WorldProjection.liftM));
  }

  void _onWorldFrame() {
    final frame = _world?.frame.value;
    final hunt = _hunt;
    if (frame == null || hunt == null || !mounted) return;
    // A game runs its own anchor and tracking (ArMiniGameHost).
    if (_game != null || _gameBusy || _gameError != null) return;
    if (frame.error != null) {
      _fallBackToCompass();
      return;
    }
    final now = DateTime.now();
    if (!frame.tracking) {
      // Reading Juan's tips is not a tracking failure; the set-up coaches the
      // traveler, so it gets longer before we give up on World AR.
      if (_showTutorial != false) _worldNotTrackingSince = null;
      _worldNotTrackingSince ??= now;
      final grace = _calibration.done ? worldTrackingGrace : setupTrackingGrace;
      if (ArQuestScreen.fallBackOnTrackingLoss(
          lost: now.difference(_worldNotTrackingSince!),
          grace: grace,
          hasAnchor: frame.anchor != null,
          isGame: _task?.isGame == true)) {
        _fallBackToCompass();
        return;
      }
    } else {
      _worldNotTrackingSince = null;
      // Heading link: compass bearing of the camera vs its yaw in ARCore space.
      final yaw = GeoAnchor.cameraYaw(frame.view!);
      final pose = _device.pose.value;
      if (yaw != null &&
          pose.hasData &&
          !pose.compassUnreliable &&
          pose.camera.elevation.abs() < 40 &&
          now.difference(_lastHeadingSample).inMilliseconds >= 150) {
        _heading.add(compassBearing: pose.camera.bearing, arYaw: yaw);
        _lastHeadingSample = now;
      }
    }

    // Guided set-up first (after Juan's tutorial); the gem waits for it.
    if (_showTutorial == false && !_calibration.done) {
      _calibration.update(
        tracking: frame.tracking,
        planes: frame.planes,
        compassUnreliable: _device.pose.value.compassUnreliable,
        headingSamples: _heading.count,
        headingReady: _heading.ready,
      );
    }

    final screen = MediaQuery.sizeOf(context);
    final p = WorldProjection.project(frame, screen);
    if (p == null) {
      _worldObject.value = null;
      // Off screen or tracking lost: not "locked on" any more.
      hunt.onCentred(false);
    } else {
      final o = ArScreenObject.from(
        p,
        WorldProjection.focalPx(frame, screen) *
            ArObjectLayer.objectSizeM /
            (p.depth <= 0 ? 1 : p.depth),
        WorldProjection.relativeDegrees(frame),
      );
      _worldObject.value = o;
      // Close enough to reach out and grab it.
      hunt.onCentred(o.centredOn(screen) && p.depth <= 4.5);
    }

    // Once the object is unlocked, put it on the ground in its real direction:
    // the hunt picked the bearing (towards the AR point, or off to one side when
    // you are standing on it); the calibrated heading turns that bearing into
    // ARCore space, and ARCore's tracking then holds it still while you walk.
    // It only lands on floor the camera has seen (never behind a wall), trying
    // closer if the way is blocked.
    final searching = hunt.phase == ArHuntPhase.searching ||
        hunt.phase == ArHuntPhase.aligned;
    if (frame.anchor != null) _placeTryingSince = null;
    if (searching &&
        _calibration.done &&
        frame.tracking &&
        frame.anchor == null &&
        frame.planes > 0 &&
        !_placing) {
      _placeTryingSince ??= now;
      final offset = _calibration.headingFallback ? null : _heading.offset;
      final position = hunt.objectPosition;
      final giveUp = now.difference(_placeTryingSince!) > placeGrace;
      if (offset != null && position != null && !giveUp) {
        final cam = GeoAnchor.cameraPosition(frame.view!);
        final p = GeoAnchor.localPoint(
          camX: cam.x,
          camZ: cam.z,
          bearing: ArGeo.bearingOf(position),
          distance: spawnDistances[_spawnTry++ % spawnDistances.length],
          headingOffset: offset,
        );
        _placing = true;
        _world!
            .placeAnchorAt(p.x, p.z, strict: true)
            .whenComplete(() => _placing = false);
      } else {
        // No reliable direction, or nowhere seen that way: drop it on the floor
        // where the camera aims.
        _placing = true;
        _world!.placeAnchor().whenComplete(() => _placing = false);
      }
    }
    setState(() {}); // refresh the status hint (the overlay is separate)
  }

  void _onPosition(Position p) {
    _hunt?.onFix(
      ArFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: p.accuracy,
        at: DateTime.now(),
      ),
      cameraBearing: _device.pose.value.camera.bearing,
    );
  }

  void _onPose() {
    if (_tier == ArTier.compass) {
      _hunt?.onCamera(_device.pose.value.camera);
    }
  }

  void _onHunt() {
    if (!mounted) return;
    final p = _hunt?.phase;
    if (_task?.isGame == true &&
        _tier == ArTier.world &&
        _gameSession == null &&
        !_gameBusy &&
        _gameError == null &&
        (p == ArHuntPhase.seeking ||
            p == ArHuntPhase.searching ||
            p == ArHuntPhase.aligned)) {
      // Inside the area with a challenge: play the game instead of the hunt.
      _startGame();
    }
    // While the object exists, only the gyro moves the scene, so it stays put.
    switch (_hunt?.phase) {
      case ArHuntPhase.searching:
      case ArHuntPhase.aligned:
      case ArHuntPhase.submitting:
      case ArHuntPhase.verified:
        _device.lockHeading();
      default:
        _device.unlockHeading();
    }
    setState(() {});
    if (_hunt?.phase == ArHuntPhase.aligned) {
      HapticFeedback.selectionClick();
    }
    if (_hunt?.phase == ArHuntPhase.verified) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _gps?.cancel();
    _device.pose.removeListener(_onPose);
    _compassObject?.dispose();
    _device.dispose();
    _world?.frame.removeListener(_onWorldFrame);
    _world?.dispose();
    _worldObject.dispose();
    _hunt?.removeListener(_onHunt);
    _hunt?.dispose();
    super.dispose();
  }

  /// Plan 77: a game task on a phone that cannot run ARCore games.
  void _noGameNotice() {
    if (mounted && _task?.isGame == true && _game == null) {
      showPixelToast(
          context, "This phone can't run the game; collect the relic instead.");
    }
  }

  /// Plan 77: a new server session (and a newly seeded game).
  Future<void> _startGame() async {
    final api = _api, fix = _hunt?.fix, task = _task;
    if (api == null || fix == null || task == null) return;
    setState(() {
      _gameBusy = true;
      _gameError = null;
    });
    final r = await api.startGame(fix);
    if (!mounted) return;
    setState(() {
      _gameBusy = false;
      if (r.ok) {
        _gameSession = r.data;
        _game = createArGame(task.game, r.data!.seed);
        _gameResult = null;
      } else {
        _gameError = r.message;
      }
    });
  }

  Future<void> _onGameOver(ArMiniGame game) async {
    final api = _api, session = _gameSession;
    if (api == null || session == null) return;
    setState(() => _gameBusy = true);
    final r = await api.finishGame(session.id,
        score: game.boardScore, passed: game.passed, stats: game.stats);
    if (!mounted) return;
    setState(() {
      _gameBusy = false;
      if (r.ok) {
        _gameResult = r.data;
      } else {
        _gameError = r.message;
      }
    });
  }

  /// Passed: a fresh challenge (games can outlast one), then the evidence.
  Future<void> _collectGame() async {
    final api = _api, fix = _hunt?.fix, session = _gameSession;
    if (api == null || fix == null || session == null) return;
    setState(() {
      _gameBusy = true;
      _gameError = null;
    });
    final ch = await api.requestChallenge(fix);
    final ArServerResult<void> r = ch.ok
        ? await api.submitEvidence(fix, ch.data!.token,
            gameSessionId: session.id)
        : ArServerResult.error(ch.code!, ch.message!);
    if (!mounted) return;
    setState(() {
      _gameBusy = false;
      if (r.ok) {
        _gameDone = true;
        HapticFeedback.mediumImpact();
      } else {
        _gameError = r.message;
      }
    });
  }

  void _replayGame() {
    setState(() {
      _gameSession = null;
      _game = null;
      _gameResult = null;
      _gameError = null;
    });
    _startGame();
  }

  void _finishTutorial() {
    ArTutorialPrefs.markSeen();
    setState(() => _showTutorial = false);
  }

  void _close({bool completed = false}) {
    if (context.canPop()) {
      context.pop(completed);
    } else {
      context.go('/quests/${widget.questId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final hunt = _hunt;
    final ready = task != null && !_permissionsDenied && _tier != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready && _tier == ArTier.world)
            WorldArView(onCreated: _onWorldViewCreated)
          else if (ready)
            ArCameraLayer(
              onPreviewAspect: (a) => setState(() => _previewAspect = a),
            ),
          if (ready && hunt != null) ..._buildScene(task, hunt),
          SafeArea(child: _buildTopBar(task)),
          if (_setupError != null)
            _MessagePanel(
              icon: Icons.error_outline_rounded,
              message: _setupError!,
              actionLabel: 'Back',
              onAction: _close,
            )
          else if (_permissionsDenied)
            _MessagePanel(
              icon: Icons.no_photography_rounded,
              message:
                  'AR needs the camera and your location. Allow both to play.',
              actionLabel: 'Open Settings',
              onAction: () async {
                await openAppSettings();
                await _startSensors();
              },
            )
          else if (!ready)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB703))),
        ],
      ),
    );
  }

  ValueListenable<ArScreenObject?> _objectSource(ArHuntController hunt) {
    if (_tier == ArTier.world) return _worldObject;
    final size = MediaQuery.sizeOf(context);
    final focal =
        _optics.focalPixels(screen: size, previewAspect: _previewAspect);
    final c = _compassObject ??= CompassObjectProjector(
      pose: _device.pose,
      focalPx: focal,
      screen: size,
    );
    c
      ..focalPx = focal
      ..screen = size
      ..position = hunt.objectPosition;
    return c;
  }

  /// Plan 77: the game over the camera, below the top bar.
  Widget _gameLayer(ArTaskSpec task) {
    final game = _game;
    if (game == null) {
      final err = _gameError;
      return _MessagePanel(
        icon: err == null
            ? Icons.sports_esports_rounded
            : Icons.error_outline_rounded,
        message: err ?? 'Getting the game ready...',
        actionLabel: err == null ? 'Back' : 'Try again',
        onAction: err == null ? _close : _startGame,
      );
    }
    final result = _gameResult;
    final busy = _gameBusy;
    return Theme(
      data: AppTheme.pixel,
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: ArMiniGameHost(
          key: ValueKey(_gameSession?.id),
          game: game,
          session: _world,
          onOver: _onGameOver,
          onRestart: _replayGame,
          endExtra: ArGameEndExtra(
              result: result, error: _gameError, done: _gameDone, busy: busy),
          endActions: [
            if (_gameDone)
              PixelButton(
                  key: const ValueKey('ar_game_done'),
                  label: 'DONE',
                  onPressed: () => _close(completed: true))
            else if (game.passed && result != null && result.passed)
              PixelButton(
                  key: const ValueKey('ar_game_collect'),
                  label: 'COLLECT',
                  onPressed: busy ? null : _collectGame)
            else
              PixelButton(
                  key: const ValueKey('play_again'),
                  label: 'PLAY AGAIN',
                  onPressed: busy ? null : _replayGame),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScene(ArTaskSpec task, ArHuntController hunt) {
    if (task.isGame &&
        _tier == ArTier.world &&
        (_game != null || _gameBusy || _gameError != null)) {
      return [_gameLayer(task)];
    }
    final phase = hunt.phase;
    final unlocked = phase == ArHuntPhase.searching ||
        phase == ArHuntPhase.aligned ||
        phase == ArHuntPhase.submitting;
    final world = _tier == ArTier.world;
    if (world && _showTutorial == true) {
      return [ArTutorial(onDone: _finishTutorial)];
    }
    if (world && !_calibration.done && !task.isGame) {
      return [
        ArCalibrationPanel(
          calibration: _calibration,
          trackingHint: _world?.frame.value?.trackingHint,
        ),
      ];
    }
    final frame = _world?.frame.value;
    final waitingForGround = world && unlocked && frame?.anchor == null;
    // Owner 2026-11-08: "too much text ... simplify the AR UI": while finding,
    // one small banner keeps the camera clear; the (i) button has the details,
    // and the card shows only when there is something to do.
    String bannerText = switch (phase) {
      ArHuntPhase.locating => 'Finding your location…',
      ArHuntPhase.outside => 'Follow the arrow to the area',
      ArHuntPhase.unlocking => 'Unlocking…',
      _ => 'Look around for the ${task.objectLabel}',
    };
    if (waitingForGround) {
      final tracking = frame?.tracking ?? false;
      bannerText =
          tracking ? 'Scan the ground slowly' : 'Move your phone slowly';
    }
    final showCard = phase == ArHuntPhase.aligned ||
        phase == ArHuntPhase.submitting ||
        phase == ArHuntPhase.verified ||
        phase == ArHuntPhase.failed;
    return [
      if (unlocked) ...[
        ArReticle(
          active: phase == ArHuntPhase.aligned,
          progress: () => hunt.alignmentProgress,
        ),
        ArObjectLayer(
          object: _objectSource(hunt),
          mesh: ShapesFactory.createShape(task.shape, themeColor: task.color),
          color: task.color,
          collectable: phase == ArHuntPhase.aligned,
          onTap: hunt.collect,
          drawObject: !world,
        ),
      ],
      if (phase == ArHuntPhase.outside &&
          hunt.distanceToCentre != null &&
          hunt.bearingToCentre != null)
        Center(
          child: ArFinder(
            pose: _device.pose,
            bearingToTarget: hunt.bearingToCentre!,
            distanceMeters: hunt.distanceToCentre!,
            radiusMeters: task.fence.radiusMeters,
          ),
        ),
      if (!world) _CompassHint(pose: _device.pose, phase: phase),
      if (!showCard)
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 64, left: 16, right: 16),
              child: phase == ArHuntPhase.seeking
                  ? HuntHeatBanner(
                      heat: hunt.heat ?? 'COLD',
                      trend: hunt.trend,
                      distance: hunt.relicDistance,
                    )
                  : _HuntBanner(text: bannerText),
            ),
          ),
        ),
      if (showCard)
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ArStatusCard(
              phase: phase,
              error: hunt.error,
              objectLabel: task.objectLabel,
              onCollect: hunt.collect,
              onDone: () => _close(completed: true),
              onRetry: () =>
                  hunt.retry(cameraBearing: _device.pose.value.camera.bearing),
            ),
          ),
        ),
    ];
  }

  Widget _buildTopBar(ArTaskSpec? task) {
    final mode = switch (_tier) {
      ArTier.world => 'World AR',
      ArTier.compass => 'Compass AR',
      null => null,
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelIconButton(
            key: const ValueKey('ar_close'),
            onPressed: _close,
            icon: MapMarkerArt.iconClose,
            semanticLabel: 'Close AR',
            style: PixelBoxStyle.parchment,
          ),
          const SizedBox(width: 10),
          if (task != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: task.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (task != null) ...[
            const SizedBox(width: 10),
            PixelIconButton(
              key: const ValueKey('ar_info'),
              onPressed: () => _showHelp(task, mode),
              icon: MapMarkerArt.iconInfo,
              semanticLabel: 'How AR finding works',
              style: PixelBoxStyle.parchment,
            ),
          ],
        ],
      ),
    );
  }

  /// The (i) sheet: how finding works, the safety notes and the AR mode.
  void _showHelp(ArTaskSpec task, String? mode) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          ArHelpSheet(objectLabel: task.objectLabel, mode: mode),
    );
  }
}

/// Native ARCore camera view (Hybrid Composition, needed for a SurfaceView).
/// Bottom card: a four-stage progress strip (locate, reach, find, collect),
/// what to do now, and the one relevant action.
class ArStatusCard extends StatelessWidget {
  final ArHuntPhase phase;
  final String? error;

  /// Replaces the default "look around" text while searching (World AR uses
  /// it to guide ground scanning).
  final String? searchingHint;

  /// What the traveler is looking for, e.g. "3D Gem".
  final String objectLabel;
  final VoidCallback onCollect;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  const ArStatusCard({
    super.key,
    required this.phase,
    required this.error,
    this.searchingHint,
    this.objectLabel = 'AR object',
    required this.onCollect,
    required this.onDone,
    required this.onRetry,
  });

  static const _green = Color(0xFF2D6A4F);
  static const _gold = Color(0xFFFFB703);
  static const stages = ['Locate', 'Reach', 'Find', 'Collect'];

  /// Index into [stages] for [phase]; `stages.length` when done, -1 on failure.
  static int stageOf(ArHuntPhase phase) => switch (phase) {
        ArHuntPhase.locating => 0,
        ArHuntPhase.outside || ArHuntPhase.unlocking => 1,
        ArHuntPhase.seeking || ArHuntPhase.searching => 2,
        ArHuntPhase.aligned || ArHuntPhase.submitting => 3,
        ArHuntPhase.verified => 4,
        ArHuntPhase.failed => -1,
      };

  @override
  Widget build(BuildContext context) {
    final String title;
    final String detail;
    final IconData icon;
    Color accent = _gold;
    Widget? action;
    switch (phase) {
      case ArHuntPhase.locating:
        title = 'Finding your location';
        detail = 'Hold still for a moment while GPS locks on.';
        icon = Icons.gps_not_fixed_rounded;
        break;
      case ArHuntPhase.outside:
        title = 'Walk to the AR area';
        detail =
            'Follow the arrow. Watch your step: stay off roads and away from crowds.';
        icon = Icons.directions_walk_rounded;
        break;
      case ArHuntPhase.unlocking:
        title = 'You have arrived';
        detail = 'Unlocking the $objectLabel…';
        icon = Icons.lock_open_rounded;
        break;
      case ArHuntPhase.seeking:
        title = 'Search for the $objectLabel';
        detail =
            '${searchingHint ?? 'Walk around the area.'}\nLook up while you walk: mind traffic, people, steps and trees.';
        icon = Icons.explore_rounded;
        break;
      case ArHuntPhase.searching:
        title = 'Find the $objectLabel';
        detail = searchingHint ?? 'Look around and hold it inside the frame.';
        icon = Icons.travel_explore_rounded;
        break;
      case ArHuntPhase.aligned:
        title = 'Locked on';
        detail = 'Tap Collect to claim the $objectLabel.';
        icon = Icons.center_focus_strong_rounded;
        accent = const Color(0xFF52B788);
        action = FilledButton.icon(
          key: const ValueKey('ar_collect'),
          onPressed: onCollect,
          icon: const Icon(Icons.back_hand_rounded),
          label: const Text('Collect'),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        break;
      case ArHuntPhase.submitting:
        title = 'Verifying';
        detail = 'Checking your collection with the server…';
        icon = Icons.cloud_sync_rounded;
        break;
      case ArHuntPhase.verified:
        title = 'AR task complete!';
        detail = 'The $objectLabel is yours. Head back to continue your quest.';
        icon = Icons.verified_rounded;
        accent = const Color(0xFF52B788);
        action = FilledButton(
          key: const ValueKey('ar_done'),
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Back to quest'),
        );
        break;
      case ArHuntPhase.failed:
        title = 'Not verified';
        detail = error ?? 'Something went wrong.';
        icon = Icons.error_outline_rounded;
        accent = const Color(0xFFE76F51);
        action = OutlinedButton(
          key: const ValueKey('ar_retry'),
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Try again'),
        );
        break;
    }
    final stage = stageOf(phase);
    // Never cover more than half the screen, even at large text sizes.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      key: const ValueKey('ar_status_card'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F1F17).withValues(alpha: 0.86),
            Colors.black.withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 6))
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stage >= 0) _StageStrip(current: stage, accent: accent),
            if (stage >= 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(phase),
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}

/// Locate · Reach · Find · Collect, with the current stage highlighted.
class _StageStrip extends StatelessWidget {
  final int current;
  final Color accent;

  const _StageStrip({required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: current >= ArStatusCard.stages.length
          ? 'All AR stages done'
          : 'AR stage ${current + 1} of ${ArStatusCard.stages.length}: ${ArStatusCard.stages[current]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < ArStatusCard.stages.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < current
                            ? const Color(0xFF52B788)
                            : i == current
                                ? accent
                                : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ArStatusCard.stages[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: i <= current ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight:
                            i == current ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Move your phone in a figure-8" — only while the compass is unreliable
/// and the traveler is navigating by it.
class _CompassHint extends StatelessWidget {
  final ValueListenable<ArPose> pose;
  final ArHuntPhase phase;

  const _CompassHint({required this.pose, required this.phase});

  @override
  Widget build(BuildContext context) {
    if (phase != ArHuntPhase.outside && phase != ArHuntPhase.searching) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<ArPose>(
      valueListenable: pose,
      builder: (context, p, _) {
        if (!p.hasData || !p.compassUnreliable) return const SizedBox.shrink();
        return SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.72),
            child: Container(
              key: const ValueKey('ar_compass_hint'),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7D5800).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Compass is unsure. Move your phone in a figure-8.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessagePanel({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: PixelPalette.woodDeep),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PixelType.body(context),
              ),
              const SizedBox(height: 16),
              PixelButton(
                label: actionLabel,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One short line under the top bar while there is nothing to tap.
class _HuntBanner extends StatelessWidget {
  const _HuntBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        key: const ValueKey('ar_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ));
}

/// While seeking the hidden relic: the heat (HOT/WARM/COOL/COLD), about how
/// far, and whether you are getting WARMER or COLDER. Nothing else.
class HuntHeatBanner extends StatelessWidget {
  const HuntHeatBanner(
      {super.key, required this.heat, required this.trend, this.distance});
  final String heat;
  final String trend;
  final double? distance;

  static Color colourFor(String heat) => switch (heat) {
        'HOT' => const Color(0xFFE5452B),
        'WARM' => const Color(0xFFFFB703),
        'COOL' => const Color(0xFF7CC4F2),
        _ => const Color(0xFF3B82F6),
      };

  @override
  Widget build(BuildContext context) {
    final c = colourFor(heat);
    final d = distance;
    // Shrinks to fit on narrow screens with big text; never wraps or overflows.
    return FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          key: const ValueKey('ar_heat_banner'),
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            border: Border.all(color: c, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: c,
              child: Text(heat,
                  style: const TextStyle(
                      color: Color(0xFF0D1B2A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
            if (d != null) ...[
              const SizedBox(width: 10),
              Text(ArHuntRules.distanceHint(d).replaceFirst('about ', '~'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ],
            if (trend.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(trend == 'WARMER' ? '▲ WARMER' : '▼ COLDER',
                  style: TextStyle(
                      color: trend == 'WARMER'
                          ? const Color(0xFFFFB703)
                          : const Color(0xFF7CC4F2),
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ],
          ]),
        ));
  }
}

/// Help behind the (i) button.
class ArHelpSheet extends StatelessWidget {
  const ArHelpSheet({super.key, required this.objectLabel, this.mode});
  final String objectLabel;
  final String? mode;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: Colors.white, fontSize: 14, height: 1.35);
    Widget line(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 22,
                child: Text(n,
                    style: body.copyWith(
                        color: const Color(0xFFFFB703),
                        fontWeight: FontWeight.w800))),
            Expanded(child: Text(t, style: body)),
          ]),
        );
    return SafeArea(
      child: Container(
        key: const ValueKey('ar_help'),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          border: Border.all(color: const Color(0xFFFFB703), width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to find the $objectLabel',
                    style: body.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: const Color(0xFFFFB703))),
                const SizedBox(height: 10),
                line('1', 'Walk to the area. The arrow points the way.'),
                line('2',
                    'The $objectLabel hides somewhere in the area. HOT, WARM, COOL or COLD and the metres say how close you are; WARMER or COLDER says if you are getting closer.'),
                line('3',
                    'A few steps away it appears. Hold it inside the circle, then tap Collect.'),
                const SizedBox(height: 4),
                Text('Stay safe',
                    style: body.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE5452B))),
                const SizedBox(height: 4),
                const Text(
                    'Look up while you walk. Stay off roads and away from crowds, and mind steps, water and trees.',
                    style: body),
                if (mode != null) ...[
                  const SizedBox(height: 10),
                  Text('Mode: $mode',
                      style:
                          body.copyWith(color: Colors.white70, fontSize: 12)),
                ],
                const SizedBox(height: 8),
              ]),
        ),
      ),
    );
  }
}

/// Plan 77: the server's word on a finished game, on the end panel: your best
/// here, your ranks, and the top 5 at this place.
class ArGameEndExtra extends StatelessWidget {
  const ArGameEndExtra(
      {super.key,
      this.result,
      this.error,
      this.done = false,
      this.busy = false});
  final ArGameResult? result;
  final String? error;
  final bool done;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final small = PixelType.small(context, color: PixelPalette.ink);
    String show(int v) => r != null && r.lowerIsBetter
        ? '${(v / 1000).toStringAsFixed(1)} s'
        : '$v';
    return Column(
        key: const ValueKey('ar_game_result'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            Text('TASK COMPLETE!',
                style: PixelType.title(context, color: PixelPalette.greenDeep))
          else if (error != null)
            Text(error!,
                textAlign: TextAlign.center,
                style: PixelType.small(context, color: PixelPalette.red))
          else if (busy)
            Text('Saving...', style: small)
          else if (r != null) ...[
            if (r.best != null)
              Text(
                  'YOUR BEST HERE ${show(r.best!)}${r.rankPlace != null ? ' · #${r.rankPlace}' : ''}',
                  style: small),
            if (r.rankWeek != null)
              Text('#${r.rankWeek} IN PANGASINAN THIS WEEK', style: small),
            if (r.top.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('TOP AT THIS PLACE',
                  style: PixelType.small(context, color: PixelPalette.slate)),
              for (final e in r.top.take(5))
                Text('${e.rank}. ${e.name}  ${show(e.score)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context,
                        color: e.isSelf
                            ? PixelPalette.greenDeep
                            : PixelPalette.ink)),
            ],
          ],
        ]);
  }
}
