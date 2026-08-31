import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/ar_diagnostics_controller.dart';

class ArCameraViewport extends ConsumerStatefulWidget {
  final Widget? overlayChild;
  final Function(CameraController? controller)? onControllerReady;

  const ArCameraViewport({
    super.key,
    this.overlayChild,
    this.onControllerReady,
  });

  @override
  ConsumerState<ArCameraViewport> createState() => _ArCameraViewportState();
}

class _ArCameraViewportState extends ConsumerState<ArCameraViewport>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  bool _noCameraAvailable = false;
  bool _isInitializing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[ArCameraViewport] AppLifecycleState changed to: $state');
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('[ArCameraViewport] Disposing camera controller for backgrounding');
      controller.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isInitialized = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
              status: 'suspended',
            );
      });
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[ArCameraViewport] App resumed -> reinitializing camera stream');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initCamera();
      });
    }
  }


  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    final stopwatch = Stopwatch()..start();

    debugPrint('[ArCameraViewport] Beginning camera initialization sequence...');
    ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
          status: 'initializing',
        );

    final previousController = _cameraController;
    _cameraController = null;
    if (previousController != null) {
      debugPrint('[ArCameraViewport] Disposing previous camera controller instance');
      await previousController.dispose();
    }

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _noCameraAvailable = false;
        _errorMessage = null;
      });
    }

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        debugPrint('[ArCameraViewport] Camera permission denied');
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _errorMessage =
                'Camera permission is required for Augmented Reality scanning.';
          });
          ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
                status: 'permission_denied',
                exceptionCode: 'PERMISSION_DENIED',
              );
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[ArCameraViewport] No hardware cameras detected');
        if (mounted) {
          setState(() {
            _noCameraAvailable = true;
            _errorMessage =
                'No hardware camera detected (Emulated Environment).';
          });
          ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
                status: 'no_hardware_camera',
                exceptionCode: 'NO_CAMERAS',
              );
        }
        return;
      }

      // Prefer back/rear camera for AR
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      debugPrint('[ArCameraViewport] Selected camera: ${selectedCamera.name}, direction: ${selectedCamera.lensDirection}');

      CameraController? controller;
      Object? initializationError;
      String chosenPresetName = 'medium';

      for (final preset in const [
        ResolutionPreset.medium,
        ResolutionPreset.high,
      ]) {
        debugPrint('[ArCameraViewport] Trying resolution preset: $preset');
        final candidate = CameraController(
          selectedCamera,
          preset,
          enableAudio: false,
        );
        try {
          await candidate.initialize();
          controller = candidate;
          chosenPresetName = preset.name;
          debugPrint('[ArCameraViewport] Successfully initialized camera with preset: $preset');
          break;
        } catch (error) {
          debugPrint('[ArCameraViewport] Failed with preset $preset: $error');
          initializationError = error;
          await candidate.dispose();
        }
      }

      if (controller == null) {
        throw CameraException(
          'CameraInitializationFailed',
          initializationError?.toString() ?? 'Camera preview could not start.',
        );
      }

      stopwatch.stop();
      final initDuration = stopwatch.elapsedMilliseconds;
      final previewSize = controller.value.previewSize ?? const Size(1280, 720);

      debugPrint('[ArCameraViewport] Camera stream active in ${initDuration}ms. Preview Size: $previewSize, Aspect Ratio: ${controller.value.aspectRatio}');

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isInitialized = true;
          _permissionDenied = false;
          _noCameraAvailable = false;
        });

        ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
              status: 'streaming',
              lens: selectedCamera.lensDirection.name,
              preset: chosenPresetName,
              width: previewSize.width,
              height: previewSize.height,
              aspectRatio: controller.value.aspectRatio,
              initDurationMs: initDuration,
            );

        widget.onControllerReady?.call(controller);
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('[ArCameraViewport] Camera exception caught: $e');
      if (mounted) {
        setState(() {
          _noCameraAvailable = true;
          _errorMessage = 'Camera initialization: $e';
        });
        ref.read(arDiagnosticsProvider.notifier).updateCameraTelemetry(
              status: 'error',
              exceptionCode: e.toString(),
            );
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagState = ref.watch(arDiagnosticsProvider);

    // Layer 1 Diagnostic Override: Solid background
    if (diagState.showSolidBackground) {
      return Container(
        color: const Color(0xFF003844),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sunGold),
                ),
                child: Text(
                  'Diagnostic Solid Background Active (Layer 1 OK)',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (widget.overlayChild != null) widget.overlayChild!,
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Video Feed Layer or Fallback
        if (diagState.showCameraPreview &&
            _isInitialized &&
            _cameraController != null)
          _buildLetterboxFreeCameraPreview()
        else if (_permissionDenied)
          _buildPermissionDeniedView()
        else if (_noCameraAvailable)
          _buildSimulatedEnvironmentView()
        else if (!diagState.showCameraPreview)
          Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Text(
                'Camera Preview Disabled in Diagnostics',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          )
        else
          _buildLoadingCameraView(),

        // 2. Overlay Layer
        if (widget.overlayChild != null) widget.overlayChild!,
      ],
    );
  }

  /// Scales and centers camera preview to fill edge-to-edge screen without distortion.
  Widget _buildLetterboxFreeCameraPreview() {
    final controller = _cameraController!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCameraView() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.sunGold, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Initializing Camera Stream...',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Color(0xFFD90429), size: 48),
            const SizedBox(height: 16),
            Text(
              'Camera Access Required',
              style: GoogleFonts.epilogue(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Please enable camera permission in device settings to explore AR quests.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16))),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatedEnvironmentView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.2,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle spatial matrix grid
          Opacity(
            opacity: 0.12,
            child: CustomPaint(
              painter: _StudioGridPainter(),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.sunGold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Simulated Viewport (No Hardware Camera)',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage ?? 'Camera preview is unavailable.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const ValueKey('ar_camera_retry_button'),
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
