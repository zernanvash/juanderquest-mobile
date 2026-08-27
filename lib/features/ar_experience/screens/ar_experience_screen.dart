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

class ARExperienceScreen extends ConsumerStatefulWidget {
  final QuestModel? quest;
  final String? questId;

  const ARExperienceScreen({super.key, this.quest, this.questId});

  @override
  ConsumerState<ARExperienceScreen> createState() => _ARExperienceScreenState();
}

class _ARExperienceScreenState extends ConsumerState<ARExperienceScreen> with SingleTickerProviderStateMixin {
  QuestModel? _quest;
  bool _isLoadingQuest = false;
  Position? _currentPosition;
  bool _markerDetected = false;
  bool _isCapturingGPS = true;
  String? _gpsError;
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
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _isCapturingGPS = false;
          });
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

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
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
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
                      border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Quest Name', _quest!.title, isBold: true),
                        const Divider(height: 16),
                        _buildSummaryRow('Calculated Distance', '${distanceMeters}m (Target radius: ${_quest!.radiusMeters}m)'),
                        const SizedBox(height: 6),
                        _buildSummaryRow('GPS Accuracy', '±${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Captured Timestamp', timestamp),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Reward Points', '+${_quest!.rewardPoints} PTS', valueColor: const Color(0xFF7D5800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
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
                        child: Text('Retake', style: GoogleFonts.epilogue(color: const Color(0xFF582F0E))),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Submit Proof', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
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
        message: 'Your current location could not be acquired. Please ensure location services (GPS) are turned ON on your device.',
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
            message: err ?? 'You are outside the required location radius for this quest. Please travel to the physical destination in Pangasinan.',
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
            message: 'You already have a proof submission pending administrator verification for this quest.',
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
              'Simulated AR Scanning',
              style: GoogleFonts.epilogue(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How this AR prototype works:',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF582F0E), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Point your camera towards the target destination marker.\n'
                '2. Tap "Simulate AR Marker Recognition" to trigger virtual marker tracking.\n'
                '3. When the 3D reward coin appears, tap "Collect Proof & Submit" to review your location accuracy and timestamp before final submission.',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF514532), fontSize: 12, height: 1.4),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Viewfinder Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B1C1A), Color(0xFF2D2A26)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.25,
                child: Image.network(
                  _quest!.markerImageUrl,
                  errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_scanner, size: 180, color: Color(0xFFD5C4AC)),
                ),
              ),
            ),
          ),

          // Reticle & 3D AR Target Area
          Center(
            child: UiSpecContainer(
              spec: const UiSpec(
                title: 'AR Viewfinder & 3D Model Target',
                figmaLayer: '#AR_Viewfinder_Reticle',
                dimensions: 'Fullscreen 1080x1920 (Reticle: 250x250dp)',
                dataBinding: 'quest.markerImageUrl / quest.markerCode',
                stateNotes: 'Scanning (Yellow pulse) -> Marker Detected (3D Coin spin)',
                uxNotes: 'Dashed green reticle upon computer vision lock. 3D coin model rotates at 4s loop.',
                deferred: true,
              ),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _markerDetected ? const Color(0xFF2D6A4F) : const Color(0xFFFFB703),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // Animated Coin
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
                  : RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFB703), Color(0xFF7D5800)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB703).withValues(alpha: 0.6),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.stars_rounded, size: 68, color: Colors.white),
                        ),
                      ),
                    ),
            ),

          // Header HUD
          SafeArea(
            child: Column(
              children: [
                // Disclosure Banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFF7D5800).withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: Text(
                    'AR PROTOTYPE MODE — Simulated Scanning',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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
                            icon: const Icon(Icons.view_in_ar_rounded, color: Color(0xFFFFB703), size: 24),
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

                      const SizedBox(height: 8),
                      // GPS & Distance HUD Card
                      UiSpecContainer(
                        spec: const UiSpec(
                          title: 'GPS Verification Guard HUD',
                          figmaLayer: '#AR_GPS_Guard_Card',
                          dimensions: 'Width: 100% - 24dp padding, Height: auto (~56dp)',
                          dataBinding: 'geolocator.position vs quest.gpsLat/gpsLng (radiusMeters)',
                          stateNotes: 'Acquiring (White) -> In-Range (Emerald Green) -> Out-of-Range (Coral Alert)',
                          uxNotes: 'Server enforces strict 422 OUT_OF_RANGE error on proof submission.',
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _gpsError != null ? Icons.error_outline : Icons.gps_fixed,
                                color: _gpsError != null ? const Color(0xFFBC4749) : const Color(0xFFFFB703),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isCapturingGPS)
                                      Text('Acquiring real GPS coordinates...', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11))
                                    else if (_gpsError != null)
                                      Text(_gpsError!, style: GoogleFonts.plusJakartaSans(color: const Color(0xFFBC4749), fontSize: 11, fontWeight: FontWeight.bold))
                                    else ...[
                                      Text(
                                        'GPS: ±${_currentPosition?.accuracy.toStringAsFixed(1)}m accuracy',
                                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      if (distanceMeters != null)
                                        Text(
                                          'Distance to target: ${distanceMeters.round()}m (${isWithinRadius ? 'Within ${_quest!.radiusMeters}m radius' : 'Outside ${_quest!.radiusMeters}m radius'})',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isWithinRadius ? const Color(0xFFBEEAD1) : const Color(0xFFF4A261),
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
                      onPressed: () => setState(() => _markerDetected = true),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(
                        'Simulate AR Marker Recognition',
                        style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFFFFB703),
                        foregroundColor: const Color(0xFF6B4B00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: (_markerDetected && _currentPosition != null && !subState.isSubmitting)
                      ? _showProofConfirmationModal
                      : null,
                  icon: subState.isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    subState.isSubmitting
                        ? 'Submitting Proof...'
                        : _markerDetected
                            ? 'Collect Proof & Submit'
                            : 'Scan Marker First',
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
