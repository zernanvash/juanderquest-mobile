import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/designer_guide.dart';
import '../engine/vector3d.dart';
import '../engine/shapes_factory.dart';
import '../widgets/ar_3d_canvas.dart';

enum EnvironmentMode {
  studio('🌌 Studio Matrix'),
  sunset('🌅 Pangasinan Sunset'),
  cameraView('📷 Camera AR View');

  final String label;
  const EnvironmentMode(this.label);
}

class ArPlaygroundScreen extends StatefulWidget {
  const ArPlaygroundScreen({super.key});

  @override
  State<ArPlaygroundScreen> createState() => _ArPlaygroundScreenState();
}

class _ArPlaygroundScreenState extends State<ArPlaygroundScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  // 3D Model State
  ShapeType _currentShape = ShapeType.token;
  RenderStyle _renderStyle = RenderStyle.hybrid;
  Color _themeColor = const Color(0xFFFFB703); // Sun Gold
  double _scale = 95.0;

  // Rotation & Motion State
  double _rotX = 0.35;
  double _rotY = 0.45;
  double _rotZ = 0.0;
  bool _autoRotate = true;
  final double _autoRotateSpeed = 1.0; // multiplier

  // Environment & Light
  EnvironmentMode _environment = EnvironmentMode.studio;
  final Vector3D _lightSource = const Vector3D(1.0, 1.8, 2.2);


  // Interaction / Gamified Claim Feedback
  bool _isCollected = false;
  int _collectedTokens = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (_autoRotate) {
          setState(() {
            _rotY += 0.018 * _autoRotateSpeed;
            _rotX = 0.28 + 0.12 * math.sin(_ticker.value * 2 * math.pi);
          });
        }
      });
    _ticker.repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _resetOrientation() {
    setState(() {
      _rotX = 0.35;
      _rotY = 0.45;
      _rotZ = 0.0;
      _scale = 95.0;
    });
  }

  void _onShapeClaim() {
    setState(() {
      _isCollected = true;
      _collectedTokens += 25;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        content: Row(

          children: [
            const Text('✨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spatial Artifact Discovered!',
                    style: GoogleFonts.epilogue(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    '+25 mJDQ added to your demo wallet',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCollected = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeMesh = ShapesFactory.createShape(_currentShape, themeColor: _themeColor);

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'AR 3D Engine Sandbox',
                style: GoogleFonts.epilogue(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.woodBrown,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.woodBrown),
            tooltip: 'Reset Orientation',
            onPressed: _resetOrientation,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Dynamic Background Viewport
          _buildEnvironmentBackground(),

          // 2. 3D Canvas with Gesture Manipulation
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _rotY += details.delta.dx * 0.012;
                  _rotX -= details.delta.dy * 0.012;
                });
              },
              onDoubleTap: _resetOrientation,
              child: UiSpecContainer(
                spec: const UiSpec(
                  title: 'AR 3D Interactive Canvas',
                  figmaLayer: '#AR_3D_Viewport',
                  dimensions: 'Full Screen Viewport',
                  dataBinding: 'ShapesFactory -> Ar3dPainter',
                  stateNotes: 'Real-time Lambertian diffuse shading with Painter Z-sorting',
                  uxNotes: 'Smooth touch rotation (pan), scale (pinch), and tap-to-claim',
                ),
                child: AnimatedScale(
                  scale: _isCollected ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Ar3dCanvas(
                    mesh: activeMesh,
                    rotX: _rotX,
                    rotY: _rotY,
                    rotZ: _rotZ,
                    scale: _scale,
                    renderStyle: _renderStyle,
                    lightSource: _lightSource,
                    showShadow: _environment != EnvironmentMode.studio,
                    onTap: _onShapeClaim,
                  ),
                ),
              ),
            ),
          ),

          // 3. Top Floating Info & Environment Controls (Responsive Wrap)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: AppSpacing.roundedPill,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        '$_collectedTokens mJDQ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: AppSpacing.roundedLg,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<EnvironmentMode>(
                        value: _environment,
                        isDense: true,
                        dropdownColor: const Color(0xFF1E293B),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                        onChanged: (val) {
                          if (val != null) setState(() => _environment = val);
                        },
                        items: EnvironmentMode.values.map((env) {
                          return DropdownMenuItem(
                            value: env,
                            child: Text(env.label, style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),

          // 4. Center Camera HUD Reticle (when in Camera AR Mode)
          if (_environment == EnvironmentMode.cameraView) _buildCameraHudReticle(),

          // 5. Bottom Floating Shape & Material Tool Deck
          Positioned(
            left: 8,
            right: 8,
            bottom: 12,
            child: _buildBottomControlsDeck(),
          ),
        ],
      ),
    );
  }

  /// Builds the background layer based on active [_environment].
  Widget _buildEnvironmentBackground() {
    switch (_environment) {
      case EnvironmentMode.studio:
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.2),
              radius: 1.2,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
            ),
          ),
        );
      case EnvironmentMode.sunset:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A154B), Color(0xFFC84B31), Color(0xFFF7B05B)],
            ),
          ),
        );
      case EnvironmentMode.cameraView:
        return Container(
          color: const Color(0xFF111827),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simulated Camera Grid Pattern
              Opacity(
                opacity: 0.15,
                child: CustomPaint(
                  painter: _GridPatternPainter(),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Builds the camera crosshair and spatial altitude HUD.
  Widget _buildCameraHudReticle() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sunGold.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sunGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: AppSpacing.roundedPill,
              border: Border.all(color: AppColors.sunGold.withOpacity(0.5)),
            ),
            child: Text(
              '🎯 Tap 3D Shape to Collect',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.sunGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the bottom expandable controls card for switching shapes, colors, and render styles.
  Widget _buildBottomControlsDeck() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.92),
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Responsive Shape Chips (Zero Overflow Wrap)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: ShapeType.values.map((type) {
              final isSelected = _currentShape == type;
              return ChoiceChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                label: Text(
                  type.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: const Color(0xFF1E293B),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _currentShape = type;
                      if (type == ShapeType.token) _themeColor = const Color(0xFFFFB703);
                      if (type == ShapeType.gem) _themeColor = const Color(0xFF2D6A4F);
                      if (type == ShapeType.crate) _themeColor = const Color(0xFF582F0E);
                      if (type == ShapeType.beacon) _themeColor = const Color(0xFFD90429);
                      if (type == ShapeType.orb) _themeColor = const Color(0xFF0284C7);
                      if (type == ShapeType.pyramid) _themeColor = const Color(0xFFE07A5F);
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Row 2: Render Style, Color Swatches, and Rotation Switch
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Style Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: Colors.white24),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RenderStyle>(
                      value: _renderStyle,
                      isDense: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10),
                      onChanged: (val) {
                        if (val != null) setState(() => _renderStyle = val);
                      },
                      items: RenderStyle.values.map((style) {
                        return DropdownMenuItem(
                          value: style,
                          child: Text(style.label, style: const TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),


              // Color Palette Swatches
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Color(0xFFFFB703), // Sun Gold
                  const Color(0xFF2D6A4F), // Emerald
                  const Color(0xFF0284C7), // Sky Blue
                  const Color(0xFFD90429), // Ruby Red
                  const Color(0xFF7209B7), // Amethyst
                  const Color(0xFF582F0E), // Wood Brown
                ].map((c) {
                  final isSelected = _themeColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _themeColor = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Auto-Rotate Switch
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Spin',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70),
                  ),
                  Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: _autoRotate,
                      activeColor: AppColors.sunGold,
                      onChanged: (val) => setState(() => _autoRotate = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Simple subtle grid pattern for Simulated Camera Mode.

class _GridPatternPainter extends CustomPainter {
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
