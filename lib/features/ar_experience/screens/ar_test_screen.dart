import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/sensor_fusion_controller.dart';
import '../engine/shapes_factory.dart';
import '../engine/spatial_math.dart';
import '../widgets/ar_3d_canvas.dart';
import '../widgets/ar_camera_viewport.dart';
import '../widgets/ar_radar_compass_hud.dart';


/// Represents a 3D object dynamically spawned in physical space.
class SummonedArObject {
  final String id;
  final ShapeType shapeType;
  final double worldBearingDeg;
  final double worldPitchDeg;
  final double distanceMeters;
  final double scale;
  final Color color;
  final RenderStyle renderStyle;
  final DateTime summonedAt;

  const SummonedArObject({
    required this.id,
    required this.shapeType,
    required this.worldBearingDeg,
    required this.worldPitchDeg,
    this.distanceMeters = 8.0,
    this.scale = 1.0,
    this.color = AppColors.sunGold,
    this.renderStyle = RenderStyle.hybrid,
    required this.summonedAt,
  });

  SummonedArObject copyWith({
    ShapeType? shapeType,
    double? worldBearingDeg,
    double? worldPitchDeg,
    double? distanceMeters,
    double? scale,
    Color? color,
    RenderStyle? renderStyle,
  }) {
    return SummonedArObject(
      id: id,
      shapeType: shapeType ?? this.shapeType,
      worldBearingDeg: worldBearingDeg ?? this.worldBearingDeg,
      worldPitchDeg: worldPitchDeg ?? this.worldPitchDeg,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      scale: scale ?? this.scale,
      color: color ?? this.color,
      renderStyle: renderStyle ?? this.renderStyle,
      summonedAt: summonedAt,
    );
  }
}

class ArTestScreen extends ConsumerStatefulWidget {
  const ArTestScreen({super.key});

  @override
  ConsumerState<ArTestScreen> createState() => _ArTestScreenState();
}

class _ArTestScreenState extends ConsumerState<ArTestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  final List<SummonedArObject> _summonedObjects = [];

  // Calibration settings
  double _objectDistance = 8.0;
  double _objectScale = 1.0;
  RenderStyle _activeRenderStyle = RenderStyle.hybrid;
  Color _activeColor = const Color(0xFFFFB703);
  bool _showTelemetry = true;
  bool _autoSpin = true;

  // FPS Counter tracking
  double _fps = 60.0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  late final TimingsCallback _timingsCallback;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _timingsCallback = (timings) {
      if (!mounted) return;
      _frameCount += timings.length;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
      if (elapsed >= 500) {
        setState(() {
          _fps = (_frameCount * 1000.0) / elapsed;
          _frameCount = 0;
          _lastFpsUpdate = now;
        });
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    _spinController.dispose();
    super.dispose();
  }

  void _summonObject(ShapeType type) {
    final sensor = ref.read(sensorFusionProvider);
    if (!sensor.hasHardwareSensors ||
        !sensor.isCalibrated ||
        !sensor.isHeadingReliable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compass is not ready. Keep the phone upright and calibrate first.',
          ),
        ),
      );
      return;
    }
    final newObj = SummonedArObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      shapeType: type,
      worldBearingDeg: sensor.headingDegrees,
      worldPitchDeg: sensor.pitchDegrees,
      distanceMeters: _objectDistance,
      scale: _objectScale,
      color: _activeColor,
      renderStyle: _activeRenderStyle,
      summonedAt: DateTime.now(),
    );

    setState(() {
      _summonedObjects.clear(); // Keep 1 primary calibrated anchor for testing
      _summonedObjects.add(newObj);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          '✨ Summoned ${_getShapeName(type)} at Heading ${sensor.headingDegrees.toStringAsFixed(1)}°',
          style: GoogleFonts.plusJakartaSans(color: AppColors.sunGold, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _clearObjects() {
    setState(() => _summonedObjects.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E293B),
        content: Text('Cleared all spatial anchors.'),
      ),
    );
  }

  String _getShapeName(ShapeType type) {
    switch (type) {
      case ShapeType.crate:
        return '📦 Simple Box / Crate';
      case ShapeType.beacon:
        return '🔺 Cone / Waypoint Beacon';
      case ShapeType.token:
        return '🪙 Quest Token';
      case ShapeType.gem:
        return '💎 Explorer Gem';
      case ShapeType.orb:
        return '⚽ Geodesic Orb';
      case ShapeType.pyramid:
        return '🏛️ Monument Pyramid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorOrientation = ref.watch(sensorFusionProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Hardware Camera Viewport Feed
          const ArCameraViewport(),

          // 2. World-Anchored Summoned 3D Objects
          ..._summonedObjects.map((obj) {
            final relativeAzimuth = SpatialMath.normalizeAngleDelta(
              obj.worldBearingDeg,
              sensorOrientation.headingDegrees,
            );
            final relativePitch = obj.worldPitchDeg - sensorOrientation.pitchDegrees;

            final projectedPoint = SpatialMath.projectWorldToScreen(
              relativeAzimuthDeg: relativeAzimuth,
              pitchDeg: relativePitch,
              rollDeg: sensorOrientation.rollDegrees,
              distanceMeters: obj.distanceMeters,
              screenSize: screenSize,
            );

            if (!projectedPoint.isVisibleInViewport) {
              return const SizedBox.shrink();
            }

            final mesh = ShapesFactory.createShape(obj.shapeType, themeColor: obj.color);
            final baseScale = (75.0 * projectedPoint.scaleFactor * obj.scale).clamp(30.0, 220.0);
            final entityX = projectedPoint.offset.dx;
            final entityY = projectedPoint.offset.dy;

            return AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                final rotY = _autoSpin ? _spinController.value * 2 * math.pi : 0.0;
                final rotX = 0.35 + 0.1 * math.sin(_spinController.value * 2 * math.pi);

                return Positioned(
                  left: entityX - (baseScale * 1.5),
                  top: entityY - (baseScale * 1.5),
                  child: Opacity(
                    opacity: projectedPoint.opacity,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF2D6A4F),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Raycast hit: ${_getShapeName(obj.shapeType)}',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: baseScale * 3.0,
                        height: baseScale * 3.0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Aura Ground Ring
                            Container(
                              width: baseScale * 1.5,
                              height: baseScale * 1.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: obj.color.withOpacity(0.35),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),

                            // 3D Canvas
                            Ar3dCanvas(
                              mesh: mesh,
                              rotX: rotX,
                              rotY: rotY,
                              rotZ: 0.0,
                              scale: baseScale,
                              renderStyle: obj.renderStyle,
                              showShadow: true,
                            ),

                            // Distance & Tap Label
                            Positioned(
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: AppSpacing.roundedPill,
                                  border: Border.all(color: obj.color.withOpacity(0.6), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🎯', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${obj.distanceMeters.toStringAsFixed(0)}m • Tap to Claim',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.sunGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 3. Top Header Bar & Radar HUD
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderBar(context),
                  if (_summonedObjects.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ArRadarCompassHud(
                        deviceHeading: sensorOrientation.headingDegrees,
                        targetBearing: _summonedObjects.first.worldBearingDeg,
                        relativeAzimuth: SpatialMath.normalizeAngleDelta(
                          _summonedObjects.first.worldBearingDeg,
                          sensorOrientation.headingDegrees,
                        ),
                        relativePitch: _summonedObjects.first.worldPitchDeg - sensorOrientation.pitchDegrees,
                        distanceMeters: _summonedObjects.first.distanceMeters,
                        isVisibleInFov: SpatialMath.projectWorldToScreen(
                          relativeAzimuthDeg: SpatialMath.normalizeAngleDelta(
                            _summonedObjects.first.worldBearingDeg,
                            sensorOrientation.headingDegrees,
                          ),
                          pitchDeg: _summonedObjects.first.worldPitchDeg - sensorOrientation.pitchDegrees,
                          rollDeg: sensorOrientation.rollDegrees,
                          distanceMeters: _summonedObjects.first.distanceMeters,
                          screenSize: screenSize,
                        ).isVisibleInViewport,
                      ),
                    ),
                  if (_showTelemetry) _buildTelemetryOverlay(sensorOrientation, screenSize),
                ],
              ),
            ),
          ),

          // 4. Bottom Object Summoner Deck & Calibration Controls
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: _buildBottomControlPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AR Spatial Testbed',
                    style: GoogleFonts.epilogue(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Object Summoner & Calibration Mode',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.sunGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.explore_rounded, color: AppColors.sunGold, size: 20),
            tooltip: 'Calibrate Compass',
            onPressed: () => context.push('/ar-calibration?returnTo=/ar-test'),
          ),
          IconButton(
            icon: Icon(
              _showTelemetry ? Icons.data_usage_rounded : Icons.data_usage_outlined,
              color: _showTelemetry ? AppColors.sunGold : Colors.white70,
              size: 20,
            ),
            tooltip: 'Toggle Live Telemetry',
            onPressed: () => setState(() => _showTelemetry = !_showTelemetry),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            tooltip: 'Calibration Controls',
            onPressed: _showCalibrationModal,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryOverlay(SensorOrientation sensor, Size screenSize) {
    final activeAnchor = _summonedObjects.isNotEmpty ? _summonedObjects.first : null;
    final relAzimuth = activeAnchor != null
        ? SpatialMath.normalizeAngleDelta(activeAnchor.worldBearingDeg, sensor.headingDegrees)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: AppColors.sunGold, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    'FPS: ${_fps.toStringAsFixed(1)}',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'Heading: ${sensor.headingDegrees.toStringAsFixed(1)}° (${_getCardinal(sensor.headingDegrees)})',
                style: GoogleFonts.plusJakartaSans(color: AppColors.sunGold, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Tilt: Pitch ${sensor.pitchDegrees.toStringAsFixed(1)}° • Roll ${sensor.rollDegrees.toStringAsFixed(1)}°',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 9.5),
          ),
          if (activeAnchor != null) ...[
            const SizedBox(height: 2),
            Text(
              'Anchor: Bearing ${activeAnchor.worldBearingDeg.toStringAsFixed(1)}° (Rel: ${relAzimuth.toStringAsFixed(1)}°) • Dist: ${activeAnchor.distanceMeters.toStringAsFixed(0)}m',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF52B788), fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Summon 3D Spatial Object',
                  style: GoogleFonts.epilogue(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (_summonedObjects.isNotEmpty)
                GestureDetector(
                  onTap: _clearObjects,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Color(0xFFD90429), size: 13),
                        const SizedBox(width: 3),
                        Text(
                          'Reset Anchor',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFD90429), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

          ),
          const SizedBox(height: 8),

          // Object Spawning Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummonButton('📦 Box / Crate', ShapeType.crate, const Color(0xFFD4A373)),
                const SizedBox(width: 6),
                _buildSummonButton('🔺 Cone / Beacon', ShapeType.beacon, const Color(0xFFE63946)),
                const SizedBox(width: 6),
                _buildSummonButton('🪙 Quest Token', ShapeType.token, const Color(0xFFFFB703)),
                const SizedBox(width: 6),
                _buildSummonButton('💎 Explorer Gem', ShapeType.gem, const Color(0xFF2A9D8F)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummonButton(String label, ShapeType type, Color color) {

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: Colors.white,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _summonObject(type),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showCalibrationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AR Calibration & Optics',
                          style: GoogleFonts.epilogue(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Distance Slider
                    Text(
                      'Spawn Distance: ${_objectDistance.toStringAsFixed(0)}m',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                    ),
                    Slider(
                      value: _objectDistance,
                      min: 2.0,
                      max: 30.0,
                      divisions: 14,
                      activeColor: AppColors.sunGold,
                      onChanged: (val) {
                        setModalState(() => _objectDistance = val);
                        setState(() {
                          _objectDistance = val;
                          if (_summonedObjects.isNotEmpty) {
                            _summonedObjects[0] = _summonedObjects[0].copyWith(distanceMeters: val);
                          }
                        });
                      },
                    ),

                    // Scale Slider
                    Text(
                      'Scale Multiplier: ${_objectScale.toStringAsFixed(1)}x',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                    ),
                    Slider(
                      value: _objectScale,
                      min: 0.5,
                      max: 2.5,
                      divisions: 8,
                      activeColor: AppColors.sunGold,
                      onChanged: (val) {
                        setModalState(() => _objectScale = val);
                        setState(() {
                          _objectScale = val;
                          if (_summonedObjects.isNotEmpty) {
                            _summonedObjects[0] = _summonedObjects[0].copyWith(scale: val);
                          }
                        });
                      },
                    ),

                    // Render Style Switcher
                    Text(
                      'Render Shading Style',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStyleChip(setModalState, 'Solid', RenderStyle.solid),
                        const SizedBox(width: 8),
                        _buildStyleChip(setModalState, 'Wireframe', RenderStyle.wireframe),
                        const SizedBox(width: 8),
                        _buildStyleChip(setModalState, 'Hybrid', RenderStyle.hybrid),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Color Tint Chooser
                    Text(
                      'Object Theme Color',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildColorDot(setModalState, const Color(0xFFFFB703), 'Sun Gold'),
                        const SizedBox(width: 10),
                        _buildColorDot(setModalState, const Color(0xFF2A9D8F), 'Emerald'),
                        const SizedBox(width: 10),
                        _buildColorDot(setModalState, const Color(0xFFE63946), 'Ruby Red'),
                        const SizedBox(width: 10),
                        _buildColorDot(setModalState, const Color(0xFF457B9D), 'Ocean Blue'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Auto Spin Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '3D Auto-Spin Animation',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                      ),
                      activeColor: AppColors.sunGold,
                      value: _autoSpin,
                      onChanged: (val) {
                        setModalState(() => _autoSpin = val);
                        setState(() => _autoSpin = val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorDot(void Function(void Function()) setModalState, Color color, String tooltip) {
    final isSelected = _activeColor == color;
    return GestureDetector(
      onTap: () {
        setModalState(() => _activeColor = color);
        setState(() {
          _activeColor = color;
          if (_summonedObjects.isNotEmpty) {
            _summonedObjects[0] = _summonedObjects[0].copyWith(color: color);
          }
        });
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }


  Widget _buildStyleChip(void Function(void Function()) setModalState, String label, RenderStyle style) {
    final isSelected = _activeRenderStyle == style;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.sunGold,
      backgroundColor: Colors.white12,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _activeRenderStyle = style);
          setState(() {
            _activeRenderStyle = style;
            if (_summonedObjects.isNotEmpty) {
              _summonedObjects[0] = _summonedObjects[0].copyWith(renderStyle: style);
            }
          });
        }
      },
    );
  }

  String _getCardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    final idx = ((deg + 22.5) % 360) ~/ 45;
    return dirs[idx];
  }
}
