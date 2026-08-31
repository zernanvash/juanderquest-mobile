import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ArCameraViewport extends StatefulWidget {
  final Widget? overlayChild;
  final Function(CameraController? controller)? onControllerReady;

  const ArCameraViewport({
    super.key,
    this.overlayChild,
    this.onControllerReady,
  });

  @override
  State<ArCameraViewport> createState() => _ArCameraViewportState();
}

class _ArCameraViewportState extends State<ArCameraViewport>
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
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    final previousController = _cameraController;
    _cameraController = null;
    if (previousController != null) {
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
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _errorMessage =
                'Camera permission is required for Augmented Reality scanning.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _noCameraAvailable = true;
            _errorMessage =
                'No hardware camera detected (Emulated Environment).';
          });
        }
        return;
      }

      // Prefer back/rear camera for AR
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      CameraController? controller;
      Object? initializationError;
      for (final preset in const [
        ResolutionPreset.high,
        ResolutionPreset.medium
      ]) {
        final candidate = CameraController(
          selectedCamera,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        try {
          await candidate.initialize();
          controller = candidate;
          break;
        } catch (error) {
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

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isInitialized = true;
          _permissionDenied = false;
          _noCameraAvailable = false;
        });
        widget.onControllerReady?.call(controller);
      } else {
        await controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _noCameraAvailable = true;
          _errorMessage = 'Camera initialization: $e';
        });
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Video Feed Layer or Graceful Fallback
        if (_isInitialized && _cameraController != null)
          _buildLetterboxFreeCameraPreview()
        else if (_permissionDenied)
          _buildPermissionDeniedView()
        else if (_noCameraAvailable)
          _buildSimulatedEnvironmentView()
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
    final previewSize = controller.value.previewSize ?? const Size(1920, 1080);
    // In portrait mode, width and height of preview are swapped
    final cameraAspectRatio = previewSize.height / previewSize.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
        double scale = 1.0;

        if (screenAspectRatio > cameraAspectRatio) {
          scale = screenAspectRatio / cameraAspectRatio;
        } else {
          scale = cameraAspectRatio / screenAspectRatio;
        }

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(
              child: CameraPreview(controller),
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
                  color: Colors.black.withOpacity(0.6),
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
