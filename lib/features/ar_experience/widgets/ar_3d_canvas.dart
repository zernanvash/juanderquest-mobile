import 'package:flutter/material.dart';
import '../engine/vector3d.dart';
import '../engine/mesh3d.dart';

enum RenderStyle {
  solid('Solid Shaded'),
  wireframe('Wireframe Glow'),
  hybrid('Shaded + Specular Glow');

  final String label;
  const RenderStyle(this.label);
}

class Ar3dCanvas extends StatelessWidget {
  final Mesh3D mesh;
  final double rotX;
  final double rotY;
  final double rotZ;
  final double scale;
  final RenderStyle renderStyle;
  final Vector3D lightSource;
  final Color? wireframeColor;
  final bool showShadow;
  final VoidCallback? onTap;

  const Ar3dCanvas({
    super.key,
    required this.mesh,
    required this.rotX,
    required this.rotY,
    required this.rotZ,
    this.scale = 100.0,
    this.renderStyle = RenderStyle.hybrid,
    this.lightSource = const Vector3D(1.2, 1.8, 2.2),
    this.wireframeColor,
    this.showShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _Ar3dPainter(
          mesh: mesh,
          rotX: rotX,
          rotY: rotY,
          rotZ: rotZ,
          scale: scale,
          renderStyle: renderStyle,
          lightSource: lightSource,
          wireframeColor: wireframeColor ?? Colors.white.withOpacity(0.45),
          showShadow: showShadow,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Ar3dPainter extends CustomPainter {
  final Mesh3D mesh;
  final double rotX;
  final double rotY;
  final double rotZ;
  final double scale;
  final RenderStyle renderStyle;
  final Vector3D lightSource;
  final Color wireframeColor;
  final bool showShadow;

  _Ar3dPainter({
    required this.mesh,
    required this.rotX,
    required this.rotY,
    required this.rotZ,
    required this.scale,
    required this.renderStyle,
    required this.lightSource,
    required this.wireframeColor,
    required this.showShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 1. Transform Vertices in 3D Space
    final transformed = mesh.transform(
      rotX: rotX,
      rotY: rotY,
      rotZ: rotZ,
      scale: scale,
    );

    // 2. Perspective Projection Setup
    const fov = 420.0;
    const cameraDistance = 380.0;

    final projected = transformed.map((v) {
      final p = v.project(
        fov: fov,
        cameraDistance: cameraDistance,
        screenWidth: size.width,
        screenHeight: size.height,
      );
      return Offset(p.x, p.y);
    }).toList();

    // 3. Ground Shadow (Simulated Spatial Depth Anchor)
    if (showShadow) {
      final shadowRadius = (scale * 0.70).clamp(18.0, 110.0);
      final shadowY = centerY + scale * 1.25;
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, shadowY),
          width: shadowRadius * 2,
          height: shadowRadius * 0.45,
        ),
        shadowPaint,
      );
    }

    // 4. Sort Faces by Centroid Depth (Painter's Algorithm: Back to Front)
    final sortedFaces = List<PolygonFace>.from(mesh.faces)
      ..sort((a, b) {
        final zA = a.computeCentroidZ(transformed);
        final zB = b.computeCentroidZ(transformed);
        return zB.compareTo(zA); // Larger Z (further away) drawn first
      });

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = wireframeColor;

    // 5. Render Polygonal Faces with Specular Highlights
    for (final face in sortedFaces) {
      if (face.vertexIndices.length < 3) continue;

      final normal = face.computeNormal(transformed);

      // Back-face Culling (unless double-sided)
      if (!face.isDoubleSided && normal.z < -0.05 && renderStyle != RenderStyle.wireframe) {
        continue;
      }

      final path = Path();
      final firstPt = projected[face.vertexIndices.first];
      path.moveTo(firstPt.dx, firstPt.dy);

      for (int i = 1; i < face.vertexIndices.length; i++) {
        final pt = projected[face.vertexIndices[i]];
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();

      // Render Solid Fill with Blinn-Phong Specular Diffuse Lighting
      if (renderStyle == RenderStyle.solid || renderStyle == RenderStyle.hybrid) {
        fillPaint.color = Mesh3D.calculateShading(
          baseColor: face.baseColor,
          normal: normal,
          lightDirection: lightSource,
          ambient: 0.38,
          diffuse: 0.58,
          specular: 0.32,
          shininess: face.shininess,
        );
        canvas.drawPath(path, fillPaint);
      }

      // Render Wireframe Outline / Specular Edges
      if (renderStyle == RenderStyle.wireframe || renderStyle == RenderStyle.hybrid) {
        if (renderStyle == RenderStyle.hybrid) {
          wirePaint.color = Colors.white.withOpacity(0.35);
          wirePaint.strokeWidth = 1.0;
        } else {
          wirePaint.color = face.baseColor.withOpacity(0.95);
          wirePaint.strokeWidth = 1.4;
        }
        canvas.drawPath(path, wirePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Ar3dPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.rotZ != rotZ ||
        oldDelegate.scale != scale ||
        oldDelegate.mesh != mesh ||
        oldDelegate.renderStyle != renderStyle ||
        oldDelegate.lightSource != lightSource;
  }
}
