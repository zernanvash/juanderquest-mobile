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
import '../core/ar_device.dart';
import '../core/ar_hunt.dart';
import '../core/ar_task.dart';
import '../core/camera_optics.dart';
import '../core/heading_fusion.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_camera_layer.dart';
import '../widgets/ar_overlay.dart';

/// Plays one Plan 43 AR task (Plan 47 Tier C "Compass AR").
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
  final ArDevice _device = ArDevice();
  ArTaskSpec? _task;
  ArHuntController? _hunt;
  StreamSubscription<Position>? _gps;
  CameraOptics _optics = CameraOptics.fallback;
  double _previewAspect = 4 / 3;
  String? _setupError;
  bool _permissionsDenied = false;

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

  void _onPose() => _hunt?.onCamera(_device.pose.value.camera);

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
    _device.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (task != null && !_permissionsDenied)
            ArCameraLayer(
              onPreviewAspect: (a) => setState(() => _previewAspect = a),
            ),
          if (task != null && hunt != null) ..._buildScene(task, hunt),
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
          else if (task == null)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB703))),
        ],
      ),
    );
  }

  List<Widget> _buildScene(ArTaskSpec task, ArHuntController hunt) {
    final size = MediaQuery.sizeOf(context);
    final focal =
        _optics.focalPixels(screen: size, previewAspect: _previewAspect);
    final phase = hunt.phase;
    final showObject = hunt.objectPosition != null &&
        (phase == ArHuntPhase.searching ||
            phase == ArHuntPhase.aligned ||
            phase == ArHuntPhase.submitting);
    return [
      if (showObject) ...[
        ArReticle(active: phase == ArHuntPhase.aligned),
        ArObjectLayer(
          pose: _device.pose,
          position: hunt.objectPosition!,
          focalPx: focal,
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
      _CompassHint(pose: _device.pose, phase: phase),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildBottom(hunt),
        ),
      ),
    ];
  }

  Widget _buildTopBar(ArTaskSpec? task) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottom(ArHuntController hunt) {
    return ArStatusCard(
      phase: hunt.phase,
      error: hunt.error,
      onCollect: hunt.collect,
      onDone: () => _close(completed: true),
      onRetry: () =>
          hunt.retry(cameraBearing: _device.pose.value.camera.bearing),
    );
  }
}

/// Bottom card: what to do now, plus the one relevant action.
class ArStatusCard extends StatelessWidget {
  final ArHuntPhase phase;
  final String? error;
  final VoidCallback onCollect;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  const ArStatusCard({
    super.key,
    required this.phase,
    required this.error,
    required this.onCollect,
    required this.onDone,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    Widget? action;
    switch (phase) {
      case ArHuntPhase.locating:
        text = 'Finding your location…';
        break;
      case ArHuntPhase.outside:
        text = 'Walk into the AR area to reveal the object.';
        break;
      case ArHuntPhase.unlocking:
        text = 'You are here! Unlocking the AR object…';
        break;
      case ArHuntPhase.searching:
        text = 'Look around. Centre the object in the ring.';
        break;
      case ArHuntPhase.aligned:
        text = 'Got it in sight. Tap to collect!';
        action = FilledButton.icon(
          key: const ValueKey('ar_collect'),
          onPressed: onCollect,
          icon: const Icon(Icons.back_hand_rounded),
          label: const Text('Collect'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            minimumSize: const Size.fromHeight(52),
          ),
        );
        break;
      case ArHuntPhase.submitting:
        text = 'Verifying…';
        break;
      case ArHuntPhase.verified:
        text = 'AR task complete!';
        action = FilledButton(
          key: const ValueKey('ar_done'),
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Back to quest'),
        );
        break;
      case ArHuntPhase.failed:
        text = error ?? 'Something went wrong.';
        action = OutlinedButton(
          key: const ValueKey('ar_retry'),
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Try again'),
        );
        break;
    }
    // Never cover more than half the screen, even at large text sizes.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      key: const ValueKey('ar_status_card'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            if (action != null) ...[const SizedBox(height: 10), action],
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
