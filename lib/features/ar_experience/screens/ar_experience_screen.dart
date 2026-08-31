import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../quests/models/quest_model.dart';
import '../../submissions/providers/submission_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/error_dialog.dart';
import '../../../core/widgets/designer_guide.dart';
import '../engine/spatial_math.dart';
import '../engine/shapes_factory.dart';
import '../controllers/sensor_fusion_controller.dart';
import '../widgets/ar_camera_viewport.dart';
import '../widgets/ar_radar_compass_hud.dart';
import '../widgets/world_anchored_overlay.dart';
import '../widgets/ar_3d_canvas.dart';

class ARExperienceScreen extends ConsumerStatefulWidget {
  final QuestModel? quest;
  final String? questId;

  const ARExperienceScreen({super.key, this.quest, this.questId});

  @override
  ConsumerState<ARExperienceScreen> createState() => _ARExperienceScreenState();
}

class _ARExperienceScreenState extends ConsumerState<ARExperienceScreen>
    with SingleTickerProviderStateMixin {
  QuestModel? _quest;
  bool _isLoadingQuest = false;
  Position? _currentPosition;
  bool _markerDetected = false;
  bool _isCapturingGPS = true;
  String? _gpsError;
  StreamSubscription<Position>? _positionSub;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _quest = widget.quest;
    if (_quest == null && widget.questId != null) {
      _fetchQuestById(widget.questId!);
    } else {
      _captureRealGPS();
    }
  }

  Future<void> _fetchQuestById(String qId) async {
    setState(() => _isLoadingQuest = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/quests/$qId');
      if (res.statusCode == 200 && res.data['success'] == true) {
        if (mounted) {
          setState(() {
            _quest = QuestModel.fromJson(res.data['data']);
            _isLoadingQuest = false;
          });
          _captureRealGPS();
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingQuest = false);
    }
  }

  Future<void> _checkPermissionRationaleAndCapture() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;

    if (!cameraStatus.isGranted || !locationStatus.isGranted) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFAF9F5),
          title: Text(
            'Camera & Location Access Required',
            style: GoogleFonts.epilogue(
              color: const Color(0xFF582F0E),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'JuanderQuest uses your camera to recognize destination markers and location services to verify quest completion radius.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF514532),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.epilogue(color: const Color(0xFF837560)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: const Color(0xFF6B4B00),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    _captureRealGPS();
  }

  Future<void> _captureRealGPS() async {
    setState(() {
      _isCapturingGPS = true;
      _gpsError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsError = 'Location services are disabled on device.';
            _isCapturingGPS = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _gpsError = 'Location permission denied.';
              _isCapturingGPS = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsError = 'Location permission permanently denied. Enable in Settings.';
            _isCapturingGPS = false;
          });
        }
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {}

      if (pos != null) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _isCapturingGPS = false;
          });
          _startPositionTracking();
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsError = 'Unable to acquire GPS fix. Please ensure location services are ON.';
            _isCapturingGPS = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsError = 'GPS error: ${e.toString()}';
          _isCapturingGPS = false;
        });
      }
    }
  }

  void _startPositionTracking() {
    unawaited(_positionSub?.cancel());
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
          _isCapturingGPS = false;
          _gpsError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _gpsError = 'Live GPS tracking interrupted. Tap refresh to retry.';
          _isCapturingGPS = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  void _acquireMarker() {
    if (_markerDetected) return;
    setState(() => _markerDetected = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2D6A4F),
        content: Text(
          'Quest target acquired. Ready to submit proof.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showProofConfirmationModal() {
    if (_quest == null || _currentPosition == null) return;

    final distanceMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _quest!.gpsLat,
      _quest!.gpsLng,
    ).round();

    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final subState = ref.watch(submissionProvider);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5C4AC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF2D6A4F), size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Confirm Quest Proof',
                        style: GoogleFonts.epilogue(
                          color: const Color(0xFF582F0E),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD5C4AC).withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Quest Name', _quest!.title, isBold: true),
                        const Divider(height: 16),
                        _buildSummaryRow('Calculated Distance',
                            '${distanceMeters}m (Target radius: ${_quest!.radiusMeters}m)'),
                        const SizedBox(height: 6),
                        _buildSummaryRow(
                            'GPS Accuracy', '±${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Captured Timestamp', timestamp),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Reward Points', '+${_quest!.rewardPoints} PTS',
                            valueColor: const Color(0xFF7D5800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.privacy_tip_outlined, color: Color(0xFF2D6A4F), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS and photo proof are used solely for quest verification and administrator audit.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF2D6A4F),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: subState.isSubmitting
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                setState(() => _markerDetected = false);
                              },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFD5C4AC)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: Text('Retake',
                            style: GoogleFonts.epilogue(color: const Color(0xFF582F0E))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: subState.isSubmitting
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _submitProof();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: subState.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Submit Proof',
                                  style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              color: valueColor ?? const Color(0xFF582F0E),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitProof() async {
    if (_quest == null || _currentPosition == null) {
      GlobalErrorDialog.show(
        context,
        title: 'GPS Signal Required',
        message:
            'Your current location could not be acquired. Please ensure location services (GPS) are turned ON on your device.',
        icon: Icons.gps_off_rounded,
        iconColor: const Color(0xFFBC4749),
        buttonText: 'Retry GPS',
        onPressed: _captureRealGPS,
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(submissionProvider.notifier).submitProof(
          questId: _quest!.id,
          markerCode: _quest!.markerCode,
          capturedLat: _currentPosition!.latitude,
          capturedLng: _currentPosition!.longitude,
          accuracy: _currentPosition!.accuracy,
        );

    if (success) {
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Proof submitted successfully! Awaiting admin verification.'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
        context.pushReplacement('/history');
      }
    } else {
      final subState = ref.read(submissionProvider);
      final err = subState.error;
      final errCode = subState.errorCode;

      if (mounted) {
        if (errCode == 'OUT_OF_RANGE') {
          GlobalErrorDialog.show(
            context,
            title: 'Outside Quest Radius',
            message: err ??
                'You are outside the required location radius for this quest. Please travel to the physical destination in Pangasinan.',
            icon: Icons.location_off_rounded,
            iconColor: const Color(0xFFBC4749),
            buttonText: 'Got It',
          );
        } else if (errCode == 'ALREADY_COMPLETED') {
          GlobalErrorDialog.show(
            context,
            title: 'Quest Already Completed',
            message: 'You have already completed this quest and earned your demo points reward.',
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF3F6653),
            buttonText: 'View History',
            onPressed: () => context.pushReplacement('/history'),
          );
        } else if (errCode == 'SUBMISSION_PENDING') {
          GlobalErrorDialog.show(
            context,
            title: 'Submission Awaiting Review',
            message:
                'You already have a proof submission pending administrator verification for this quest.',
            icon: Icons.hourglass_top_rounded,
            iconColor: const Color(0xFFFFB703),
            buttonText: 'View History',
            onPressed: () => context.pushReplacement('/history'),
          );
        } else {
          GlobalErrorDialog.show(
            context,
            title: 'Submission Failed',
            message: err ?? 'Could not submit quest proof due to a network or server error.',
            icon: Icons.error_outline_rounded,
            iconColor: const Color(0xFFBC4749),
            buttonText: 'Try Again',
          );
        }
      }
    }
  }

  void _showARHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFAF9F5),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Color(0xFF7D5800)),
            const SizedBox(width: 8),
            Text(
              'AR Spatial Viewfinder Guide',
              style: GoogleFonts.epilogue(
                  color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to discover and claim your quest:',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, color: const Color(0xFF582F0E), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Look around in your physical surroundings. The radar in the top left shows the direction of the destination marker.\n'
                '2. Aim your camera towards the floating 3D Gold Quest Token until the reticle locks.\n'
                '3. Once locked on, review your GPS radius accuracy and submit proof for administrator verification.',
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF514532), fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: const Color(0xFF6B4B00),
            ),
            child: Text('Understood', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuest || _quest == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1C1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
      );
    }

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    double? distanceMeters;
    bool isWithinRadius = false;

    if (_currentPosition != null) {
      distanceMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _quest!.gpsLat,
        _quest!.gpsLng,
      );
      isWithinRadius = distanceMeters <= _quest!.radiusMeters;
    }

    final subState = ref.watch(submissionProvider);
    final sensorOrientation = ref.watch(sensorFusionProvider);

    final hasUsableGps = _currentPosition != null &&
        _currentPosition!.accuracy > 0 &&
        _currentPosition!.accuracy <= 100;
    final hasUsableOrientation = sensorOrientation.hasHardwareSensors &&
        sensorOrientation.isCalibrated &&
        sensorOrientation.isHeadingReliable;
    final spatialTrackingReady = hasUsableGps && hasUsableOrientation;

    final targetBearing = hasUsableGps
        ? SpatialMath.calculateBearing(
            fromLat: _currentPosition!.latitude,
            fromLng: _currentPosition!.longitude,
            toLat: _quest!.gpsLat,
            toLng: _quest!.gpsLng,
          )
        : sensorOrientation.headingDegrees;
    final relativeAzimuth = SpatialMath.normalizeAngleDelta(
      targetBearing,
      sensorOrientation.headingDegrees,
    );
    final relativePitch = SpatialMath.calculateRelativePitch(
      targetElevationDeg: 0.0,
      devicePitchDeg: sensorOrientation.pitchDegrees,
    );

    final screenSize = MediaQuery.of(context).size;
    final projectedPoint = SpatialMath.projectWorldToScreen(
      relativeAzimuthDeg: relativeAzimuth,
      pitchDeg: relativePitch,
      rollDeg: sensorOrientation.rollDegrees,
      distanceMeters: distanceMeters ?? 25.0,
      screenSize: screenSize,
    );

    final isReticleLocked = spatialTrackingReady &&
        isWithinRadius &&
        projectedPoint.isInReticleLockCone;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Hardware Camera Viewport Feed
          const ArCameraViewport(),

          // 2. World-Anchored 3D Spatial Overlay
          if (!_markerDetected && spatialTrackingReady)
            WorldAnchoredOverlay(
              point: projectedPoint,
              questTitle: _quest!.title,
              shapeType: ShapeType.token,
              isReticleLocked: isReticleLocked,
              onTap: _acquireMarker,
            ),

          // 3. Central Reticle & Scanning Frame (Dynamic color when locked on)
          Center(
            child: UiSpecContainer(
              spec: const UiSpec(
                title: 'AR Viewfinder & 3D Model Target',
                figmaLayer: '#AR_Viewfinder_Reticle',
                dimensions: 'Fullscreen 1080x1920 (Reticle: 240x240dp)',
                dataBinding: 'quest.markerImageUrl / quest.markerCode',
                stateNotes: 'Scanning (Yellow) -> Reticle Lock (Emerald Pulse) -> Marker Detected (3D Coin spin)',
                uxNotes: 'Dashed green reticle upon spatial lock. 3D coin model rotates with specular lighting.',
                deferred: true,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (_markerDetected || isReticleLocked)
                            ? const Color(0xFF2D6A4F)
                            : const Color(0xFFFFB703),
                        width: isReticleLocked ? 3.0 : 2.0,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  // Reticle Crosshairs
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_markerDetected || isReticleLocked)
                          ? const Color(0xFF52B788)
                          : const Color(0xFFFFB703).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Animated 3D Relic when Detected / Claimed
          if (_markerDetected)
            Center(
              child: disableAnimations
                  ? Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFB703),
                      ),
                      child: const Center(
                        child: Icon(Icons.stars_rounded, size: 68, color: Color(0xFF582F0E)),
                      ),
                    )
                  : SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          final rotY = _rotationController.value * 2 * 3.14159265;
                          return Ar3dCanvas(
                            mesh: ShapesFactory.createShape(ShapeType.token,
                                themeColor: const Color(0xFFFFB703)),
                            rotX: 0.35,
                            rotY: rotY,
                            rotZ: 0.0,
                            scale: 90.0,
                            renderStyle: RenderStyle.hybrid,
                            showShadow: true,
                          );
                        },
                      ),
                    ),
            ),

          // 5. Header HUD with 360° Radar & GPS Guards
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Top Radar & Distance Telemetry
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArRadarCompassHud(
                          deviceHeading: sensorOrientation.headingDegrees,
                          targetBearing: targetBearing,
                          relativeAzimuth: relativeAzimuth,
                          relativePitch: relativePitch,
                          distanceMeters: distanceMeters ?? 0.0,
                          isVisibleInFov: spatialTrackingReady &&
                              projectedPoint.isVisibleInViewport,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7D5800).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Tier 3: Geo-Spatial AR',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 26),
                              onPressed: () => context.pop(),
                            ),
                            Expanded(
                              child: Text(
                                _quest!.title,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.epilogue(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.explore_rounded,
                                  color: Color(0xFFFFB703), size: 24),
                              tooltip: 'Calibrate Compass',
                              onPressed: () => context.push('/ar-calibration?returnTo=/quests/${_quest!.id}/ar'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.view_in_ar_rounded,
                                  color: Colors.white70, size: 24),
                              tooltip: 'AR 3D Sandbox',
                              onPressed: () => context.push('/ar-playground'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.help_outline, color: Colors.white70, size: 24),
                              tooltip: 'Help',
                              onPressed: _showARHelpDialog,
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        // GPS & Distance HUD Card
                        UiSpecContainer(
                          spec: const UiSpec(
                            title: 'GPS Verification Guard HUD',
                            figmaLayer: '#AR_GPS_Guard_Card',
                            dimensions: 'Width: 100% - 24dp padding, Height: auto (~56dp)',
                            dataBinding:
                                'geolocator.position vs quest.gpsLat/gpsLng (radiusMeters)',
                            stateNotes:
                                'Acquiring (White) -> In-Range (Emerald Green) -> Out-of-Range (Coral Alert)',
                            uxNotes:
                                'Server enforces strict 422 OUT_OF_RANGE error on proof submission.',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.72),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD5C4AC).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _gpsError != null ? Icons.error_outline : Icons.gps_fixed,
                                  color: _gpsError != null
                                      ? const Color(0xFFBC4749)
                                      : const Color(0xFFFFB703),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_isCapturingGPS)
                                        Text('Acquiring real GPS coordinates...',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white, fontSize: 11))
                                      else if (_gpsError != null)
                                        Text(_gpsError!,
                                            style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFFBC4749),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold))
                                      else ...[
                                        Text(
                                          'GPS: ±${_currentPosition?.accuracy.toStringAsFixed(1)}m accuracy',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        if (distanceMeters != null)
                                          Text(
                                            'Distance: ${distanceMeters.round()}m (${isWithinRadius ? 'Within ${_quest!.radiusMeters}m radius' : 'Outside ${_quest!.radiusMeters}m radius'})',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: isWithinRadius
                                                  ? const Color(0xFFBEEAD1)
                                                  : const Color(0xFFF4A261),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_gpsError != null)
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                                    onPressed: _checkPermissionRationaleAndCapture,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Controls
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (!_markerDetected) ...[
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'AR Scanning Trigger Button',
                      figmaLayer: '#AR_Trigger_Scan_Button',
                      dimensions: 'Full width button, Height: 48dp, Radius: 12dp',
                      dataBinding: 'Local state toggle -> starts marker tracking & coin animation',
                      stateNotes: 'Initial state -> active press',
                      uxNotes: 'Gold button with Epilogue bold typography and camera scanner icon.',
                      deferred: true,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isReticleLocked ? _acquireMarker : null,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(
                        isReticleLocked
                            ? 'Lock Acquired - Tap to Collect'
                            : !spatialTrackingReady
                                ? 'Waiting for Spatial Tracking'
                                : !isWithinRadius
                                    ? 'Move Within Quest Radius'
                                    : 'Center Target to Lock',
                        style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: isReticleLocked ? const Color(0xFF2D6A4F) : const Color(0xFFFFB703),
                        foregroundColor: isReticleLocked ? Colors.white : const Color(0xFF6B4B00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: (_markerDetected &&
                          hasUsableGps &&
                          isWithinRadius &&
                          !subState.isSubmitting)
                      ? _showProofConfirmationModal
                      : null,
                  icon: subState.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    subState.isSubmitting
                        ? 'Submitting Proof...'
                        : _markerDetected
                            ? 'Collect Proof & Submit'
                            : 'Aim at the Marker First',
                    style: GoogleFonts.epilogue(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
