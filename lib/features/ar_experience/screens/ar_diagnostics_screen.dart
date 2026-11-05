import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../map/pixel/map_marker_art.dart';
import '../core/ar_device.dart';
import '../core/ar_hunt.dart';
import '../core/ar_math.dart';
import '../core/camera_optics.dart';
import '../core/heading_fusion.dart';
import '../core/world_ar.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_calibration_panel.dart';
import '../widgets/ar_camera_layer.dart';
import '../widgets/ar_overlay.dart';

/// Developer-only AR bench (Settings → Developer): live sensor numbers and a
/// test object you can place in front of you without a quest.
class ArDiagnosticsScreen extends StatefulWidget {
  const ArDiagnosticsScreen({super.key});

  @override
  State<ArDiagnosticsScreen> createState() => _ArDiagnosticsScreenState();
}

class _ArDiagnosticsScreenState extends State<ArDiagnosticsScreen> {
  final ArDevice _device = ArDevice();
  CameraOptics _optics = CameraOptics.fallback;
  Map<String, bool> _caps = const {};
  double _previewAspect = 4 / 3;
  Vec3? _object;
  bool _ready = false;
  bool _denied = false;
  bool _worldEnabled = false;
  WorldArAvailability? _worldAvailability;
  CompassObjectProjector? _projector;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  Future<void> _start() async {
    PermissionStatus status;
    try {
      status = await Permission.camera.request();
    } catch (_) {
      status = PermissionStatus.denied;
    }
    if (!status.isGranted) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    _optics = await ArDevice.cameraOptics();
    _caps = await ArDevice.capabilities();
    _worldEnabled = await WorldArPrefs.enabled();
    _worldAvailability = await WorldArSupport.check();
    _device.start();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _projector?.dispose();
    _device.dispose();
    super.dispose();
  }

  void _placeAhead() {
    final camera = _device.pose.value.camera;
    setState(() => _object = ArHuntRules.spawnPosition(camera.bearing));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final focal =
        _optics.focalPixels(screen: size, previewAspect: _previewAspect);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            ArCameraLayer(
              onPreviewAspect: (a) => setState(() => _previewAspect = a),
            ),
          if (_ready && _object != null)
            ArObjectLayer(
              object: (_projector ??= CompassObjectProjector(
                pose: _device.pose,
                focalPx: focal,
                screen: size,
              ))
                ..focalPx = focal
                ..screen = size
                ..position = _object,
              mesh: ShapesFactory.createShape(ShapeType.gem),
              color: const Color(0xFFFFB703),
              collectable: false,
              onTap: () {},
            ),
          const ArReticle(active: false, size: 64),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelIconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/settings'),
                    icon: MapMarkerArt.iconClose,
                    semanticLabel: 'Back to settings',
                    style: PixelBoxStyle.parchment,
                  ),
                  const SizedBox(height: 8),
                  if (_denied)
                    const Text('Camera permission denied.',
                        style: TextStyle(color: Colors.white)),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder<ArPose>(
                        valueListenable: _device.pose,
                        builder: (context, pose, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Readout(lines: _lines(pose, focal)),
                            const SizedBox(height: 8),
                            PixelPanel(
                              style: PixelBoxStyle.parchment,
                              padding: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'World AR (ARCore, beta)',
                                          style: PixelType.body(context),
                                        ),
                                        Text(
                                          'Use ARCore in quests when available. '
                                          'ARCore: ${_worldAvailability?.name ?? '…'}',
                                          style: PixelType.small(
                                            context,
                                            color: PixelPalette.slate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PixelSwitch(
                                    key: const ValueKey('ar_diag_world_toggle'),
                                    value: _worldEnabled,
                                    onChanged: (v) async {
                                      await WorldArPrefs.setEnabled(v);
                                      if (mounted) {
                                        setState(() => _worldEnabled = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            PixelButton(
                              key: const ValueKey('ar_diag_replay_tutorial'),
                              label: 'Replay AR tutorial',
                              variant: PixelButtonVariant.secondary,
                              onPressed: () async {
                                await ArTutorialPrefs.reset();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Juan's AR tips will show on the next AR task."),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Leave room for the bottom button.
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PixelButton(
                    key: const ValueKey('ar_diag_place'),
                    onPressed: _ready ? _placeAhead : null,
                    label: _object == null
                        ? 'Place test object ahead'
                        : 'Move test object ahead',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _lines(ArPose pose, double focal) {
    final cam = pose.camera;
    final caps = _caps.entries
        .map((e) => '${e.key}:${e.value ? 'yes' : 'no'}')
        .join(' ');
    return [
      'Tier: Compass AR (C)',
      'Source: ${pose.source.name}${_device.failed ? ' (no native stream)' : ''}',
      'Sensors: ${caps.isEmpty ? '—' : caps}',
      'Bearing: ${cam.bearing.toStringAsFixed(1)}°  '
          'Elevation: ${cam.elevation.toStringAsFixed(1)}°',
      'Heading accuracy: ${pose.headingAccuracyDeg?.toStringAsFixed(0) ?? '—'}°  '
          'Mag status: ${pose.magneticStatus ?? '—'}',
      'Camera FOV: ${_optics.longFovDeg.toStringAsFixed(1)}° × '
          '${_optics.shortFovDeg.toStringAsFixed(1)}° '
          '(${_optics.measured ? 'measured' : 'default'})',
      'Focal: ${focal.toStringAsFixed(0)} px  Preview: '
          '${_previewAspect.toStringAsFixed(2)}',
    ];
  }
}

class _Readout extends StatelessWidget {
  final List<String> lines;

  const _Readout({required this.lines});

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Text(
              l,
              style: PixelType.small(
                context,
                color: PixelPalette.paper,
              ),
            ),
        ],
      ),
    );
  }
}
