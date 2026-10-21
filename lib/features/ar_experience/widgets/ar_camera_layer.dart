import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-screen rear camera preview scaled with `BoxFit.cover`.
///
/// Reports the stream's aspect ratio so the projector can compute the real
/// focal length. Releases the camera when the app goes to the background.
class ArCameraLayer extends StatefulWidget {
  final ValueChanged<double>? onPreviewAspect;

  const ArCameraLayer({super.key, this.onPreviewAspect});

  @override
  State<ArCameraLayer> createState() => _ArCameraLayerState();
}

class _ArCameraLayerState extends State<ArCameraLayer>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final c = _controller;
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
      widget.onPreviewAspect?.call(controller.value.aspectRatio);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'CameraAccessDenied'
            ? 'Camera access is off. Allow it in Settings to play AR.'
            : 'The camera could not start.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'The camera could not start.');
    } finally {
      _starting = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return ColoredBox(
        color: const Color(0xFF0F172A),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: Color(0xFFFFB703))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final ar = c.value.aspectRatio;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth * ar,
              child: CameraPreview(c),
            ),
          ),
        ),
      );
    });
  }
}
