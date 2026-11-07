import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import '../ar_experience/core/ar_device.dart';
import '../ar_experience/core/ar_hunt.dart';
import '../ar_experience/core/ar_math.dart';
import '../ar_experience/core/camera_optics.dart';
import '../ar_experience/engine/shapes_factory.dart';
import '../ar_experience/widgets/ar_camera_layer.dart';
import '../ar_experience/widgets/ar_overlay.dart';

/// AR Lab: the object-collection AR task's models as players see them (owner
/// 2026-11-07: "include the object collection ar task in the lab too so i can see
/// the models and looks"). Uses the same compass-AR camera layer, projector and
/// 3D object layer as a quest's AR task; pick a model, place it ahead, tap it to
/// collect.
class ArCollectLabScreen extends StatefulWidget {
  const ArCollectLabScreen({super.key});

  @override
  State<ArCollectLabScreen> createState() => _ArCollectLabScreenState();
}

class _ArCollectLabScreenState extends State<ArCollectLabScreen> {
  final ArDevice _device = ArDevice();
  CameraOptics _optics = CameraOptics.fallback;
  double _previewAspect = 4 / 3;
  CompassObjectProjector? _projector;
  Vec3? _object;
  ShapeType _shape = ShapeType.token;
  bool _ready = false;
  bool _denied = false;
  int _collected = 0;
  String? _callout;
  Timer? _calloutTimer;

  static const _color = PixelPalette.sun;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _start();
  }

  Future<void> _start() async {
    if (!(await Permission.camera.request()).isGranted) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    _optics = await ArDevice.cameraOptics();
    _device.start();
    if (mounted) setState(() => _ready = true);
  }

  void _placeAhead() {
    final camera = _device.pose.value.camera;
    setState(() => _object = ArHuntRules.spawnPosition(camera.bearing));
  }

  void _collect() {
    HapticFeedback.heavyImpact();
    _calloutTimer?.cancel();
    setState(() {
      _collected++;
      _callout = 'COLLECTED!';
      _object = null;
    });
    _calloutTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _callout = null);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _calloutTimer?.cancel();
    _projector?.dispose();
    _device.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final focal = _optics.focalPixels(screen: size, previewAspect: _previewAspect);
    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          if (_ready) ArCameraLayer(onPreviewAspect: (a) => setState(() => _previewAspect = a)),
          if (_ready && _object != null)
            ArObjectLayer(
              key: ValueKey(_shape),
              object: (_projector ??= CompassObjectProjector(pose: _device.pose, focalPx: focal, screen: size))
                ..focalPx = focal
                ..screen = size
                ..position = _object,
              mesh: ShapesFactory.createShape(_shape, themeColor: _color),
              color: _color,
              collectable: true,
              onTap: _collect,
            ),
          const ArReticle(active: false, size: 64),
          if (_callout != null)
            Center(
              child: FittedBox(
                child: Text(_callout!,
                    style: PixelType.display(context, color: PixelPalette.sun)
                        .copyWith(shadows: const [Shadow(color: PixelPalette.ink, offset: Offset(3, 3))])),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PixelPanel(
                  style: PixelBoxStyle.inkDialogue,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Text('COLLECT OBJECTS', style: PixelType.title(context, color: PixelPalette.sun)),
                      Text('COLLECTED $_collected', style: PixelType.small(context, color: PixelPalette.mist)),
                    ],
                  ),
                ),
                if (_denied)
                  Text('Camera permission is needed.', style: PixelType.body(context, color: PixelPalette.paper)),
                const Spacer(),
                PixelPanel(
                  style: PixelBoxStyle.parchment,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_shape.label, textAlign: TextAlign.center, style: PixelType.title(context)),
                    Text(_shape.description, textAlign: TextAlign.center, style: PixelType.small(context)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                      for (final s in ShapeType.values)
                        PixelButton(
                          key: ValueKey('shape_${s.name}'),
                          label: s.name.toUpperCase(),
                          variant: s == _shape ? PixelButtonVariant.primary : PixelButtonVariant.secondary,
                          onPressed: () => setState(() => _shape = s),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    PixelButton(
                      key: const ValueKey('place_object'),
                      label: _object == null ? 'PLACE AHEAD' : 'PLACE AGAIN',
                      expand: true,
                      onPressed: _ready ? _placeAhead : null,
                    ),
                    const SizedBox(height: 4),
                    Text('Tap the object to collect it.', textAlign: TextAlign.center, style: PixelType.small(context)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
