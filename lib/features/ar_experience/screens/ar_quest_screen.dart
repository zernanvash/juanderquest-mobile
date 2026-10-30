import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/providers/auth_provider.dart';
import '../../quests/models/quest_model.dart';
import '../core/ar_device.dart';
import '../core/ar_hunt.dart';
import '../core/ar_task.dart';
import '../core/camera_optics.dart';
import '../core/heading_fusion.dart';
import '../core/world_ar.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_camera_layer.dart';
import '../widgets/ar_overlay.dart';

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

  @override
  ConsumerState<ArQuestScreen> createState() => _ArQuestScreenState();
}

class _ArQuestScreenState extends ConsumerState<ArQuestScreen> {
  /// Fall back to Compass AR if World AR can't track for this long.
  static const worldTrackingGrace = Duration(seconds: 8);

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
  final ValueNotifier<ArScreenObject?> _worldObject = ValueNotifier(null);
  CompassObjectProjector? _compassObject;

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
          await WorldArSupport.requestInstall()) {
        a = WorldArAvailability.installed;
      }
      if (a == WorldArAvailability.installed) tier = ArTier.world;
    }
    if (mounted) setState(() => _tier = tier);
  }

  void _fallBackToCompass() {
    final world = _world;
    _world = null;
    world?.frame.removeListener(_onWorldFrame);
    world?.dispose();
    _worldObject.value = null;
    if (mounted) setState(() => _tier = ArTier.compass);
  }

  void _onWorldViewCreated(int id) {
    final session = WorldArSession(id);
    session.frame.addListener(_onWorldFrame);
    _world = session;
  }

  void _onWorldFrame() {
    final frame = _world?.frame.value;
    final hunt = _hunt;
    if (frame == null || hunt == null || !mounted) return;
    if (frame.error != null) {
      _fallBackToCompass();
      return;
    }
    final now = DateTime.now();
    if (!frame.tracking) {
      _worldNotTrackingSince ??= now;
      if (now.difference(_worldNotTrackingSince!) > worldTrackingGrace &&
          frame.anchor == null) {
        _fallBackToCompass();
        return;
      }
    } else {
      _worldNotTrackingSince = null;
    }

    final screen = MediaQuery.sizeOf(context);
    final p = WorldProjection.project(frame, screen);
    if (p == null) {
      _worldObject.value = null;
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

    // Once the object is unlocked, drop it on the first ground plane ahead.
    final searching = hunt.phase == ArHuntPhase.searching ||
        hunt.phase == ArHuntPhase.aligned;
    if (searching &&
        frame.tracking &&
        frame.anchor == null &&
        frame.planes > 0 &&
        !_placing) {
      _placing = true;
      _world!.placeAnchor().whenComplete(() => _placing = false);
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
            _WorldArView(onCreated: _onWorldViewCreated)
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

  List<Widget> _buildScene(ArTaskSpec task, ArHuntController hunt) {
    final phase = hunt.phase;
    final unlocked = phase == ArHuntPhase.searching ||
        phase == ArHuntPhase.aligned ||
        phase == ArHuntPhase.submitting;
    final world = _tier == ArTier.world;
    final frame = _world?.frame.value;
    final waitingForGround = world && unlocked && frame?.anchor == null;
    String? searchingHint;
    if (waitingForGround) {
      searchingHint = (frame?.tracking ?? false)
          ? 'Point at the ground a few steps ahead.'
          : frame?.trackingHint ?? 'Move your phone slowly to scan the ground.';
    }
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
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ArStatusCard(
            phase: phase,
            error: hunt.error,
            searchingHint: searchingHint,
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
          IconButton.filledTonal(
            key: const ValueKey('ar_close'),
            onPressed: _close,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close AR',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Step ${task.stepOrder} · Find the ${task.objectLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (mode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const ValueKey('ar_mode_chip'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFB703).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFFFB703)
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          mode,
                          style: const TextStyle(
                              color: Color(0xFFFFB703),
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Native ARCore camera view (Hybrid Composition, needed for a SurfaceView).
class _WorldArView extends StatelessWidget {
  final ValueChanged<int> onCreated;

  const _WorldArView({required this.onCreated});

  static const viewType = 'jdq/arcore_view';

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(onCreated);
        controller.create();
        return controller;
      },
    );
  }
}

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
        ArHuntPhase.searching => 2,
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
        detail = 'Follow the arrow. The $objectLabel appears when you arrive.';
        icon = Icons.directions_walk_rounded;
        break;
      case ArHuntPhase.unlocking:
        title = 'You have arrived';
        detail = 'Unlocking the $objectLabel…';
        icon = Icons.lock_open_rounded;
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
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF582F0E)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
