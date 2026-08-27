import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'vector3d.dart';
import 'mesh3d.dart';

enum ShapeType {
  token('🪙 Quest Token', 'Gold medallion with radial facets'),
  gem('💎 Explorer Gem', 'Faceted octahedron crystal'),
  crate('📦 Artifact Crate', 'Ancient treasure discovery cube'),
  beacon('📍 Geo Beacon', 'Floating spatial waypoint anchor'),
  orb('⚽ Geodesic Orb', 'Spherical icosahedron relic'),
  pyramid('🔺 Heritage Pyramid', 'Ancient architectural monument');

  final String label;
  final String description;
  const ShapeType(this.label, this.description);
}

class ShapesFactory {
  /// Generates a procedural 3D mesh based on [type] and primary [themeColor].
  static Mesh3D createShape(ShapeType type, {Color themeColor = const Color(0xFFFFB703)}) {
    switch (type) {
      case ShapeType.token:
        return createToken(color: themeColor);
      case ShapeType.gem:
        return createGem(color: themeColor);
      case ShapeType.crate:
        return createCrate(color: themeColor);
      case ShapeType.beacon:
        return createBeacon(color: themeColor);
      case ShapeType.orb:
        return createOrb(color: themeColor);
      case ShapeType.pyramid:
        return createPyramid(color: themeColor);
    }
  }

  /// 🪙 3D Quest Token (Faceted Gold Coin Cylinder)
  static Mesh3D createToken({
    double radius = 1.0,
    double thickness = 0.22,
    int segments = 16,
    Color color = const Color(0xFFFFB703),
  }) {
    final vertices = <Vector3D>[];
    final faces = <PolygonFace>[];

    final halfT = thickness / 2;

    // Top & Bottom Center Vertices
    const topCenterIdx = 0;
    const bottomCenterIdx = 1;
    vertices.add(Vector3D(0, 0, halfT));

    vertices.add(Vector3D(0, 0, -halfT));

    // Ring vertices
    for (int i = 0; i < segments; i++) {
      final theta = (i * 2 * math.pi) / segments;
      final x = radius * math.cos(theta);
      final y = radius * math.sin(theta);
      vertices.add(Vector3D(x, y, halfT)); // Top ring
      vertices.add(Vector3D(x, y, -halfT)); // Bottom ring
    }

    final topColor = color;
    final sideColor = Color.fromARGB(
      color.alpha,
      (color.red * 0.85).round(),
      (color.green * 0.85).round(),
      (color.blue * 0.85).round(),
    );
    final bottomColor = Color.fromARGB(
      color.alpha,
      (color.red * 0.70).round(),
      (color.green * 0.70).round(),
      (color.blue * 0.70).round(),
    );

    for (int i = 0; i < segments; i++) {
      final nextI = (i + 1) % segments;
      final topCurr = 2 + i * 2;
      final botCurr = topCurr + 1;
      final topNext = 2 + nextI * 2;
      final botNext = topNext + 1;

      // Top Cap Triangle
      faces.add(PolygonFace(
        vertexIndices: [topCenterIdx, topCurr, topNext],
        baseColor: (i % 2 == 0) ? topColor : Color.lerp(topColor, Colors.white, 0.2)!,
      ));

      // Bottom Cap Triangle
      faces.add(PolygonFace(
        vertexIndices: [bottomCenterIdx, botNext, botCurr],
        baseColor: bottomColor,
      ));

      // Side Quad
      faces.add(PolygonFace(
        vertexIndices: [topCurr, botCurr, botNext, topNext],
        baseColor: sideColor,
      ));
    }

    return Mesh3D(name: 'Quest Token', vertices: vertices, faces: faces);
  }

  /// 💎 3D Explorer Gem (Faceted Octahedron Crystal)
  static Mesh3D createGem({
    double radius = 1.0,
    double height = 1.5,
    Color color = const Color(0xFF2D6A4F),
  }) {
    final vertices = [
      Vector3D(0, height, 0), // 0: Top Tip
      Vector3D(radius, 0, 0), // 1: Right
      Vector3D(0, 0, radius), // 2: Front
      Vector3D(-radius, 0, 0), // 3: Left
      Vector3D(0, 0, -radius), // 4: Back
      Vector3D(0, -height, 0), // 5: Bottom Tip
    ];

    final brightEmerald = Color.lerp(color, Colors.white, 0.25)!;
    final deepEmerald = Color.lerp(color, Colors.black, 0.2)!;

    final faces = [
      // Top Pyramid Faces
      PolygonFace(vertexIndices: [0, 2, 1], baseColor: brightEmerald),
      PolygonFace(vertexIndices: [0, 3, 2], baseColor: color),
      PolygonFace(vertexIndices: [0, 4, 3], baseColor: deepEmerald),
      PolygonFace(vertexIndices: [0, 1, 4], baseColor: color),

      // Bottom Pyramid Faces
      PolygonFace(vertexIndices: [5, 1, 2], baseColor: deepEmerald),
      PolygonFace(vertexIndices: [5, 2, 3], baseColor: color),
      PolygonFace(vertexIndices: [5, 3, 4], baseColor: brightEmerald),
      PolygonFace(vertexIndices: [5, 4, 1], baseColor: deepEmerald),
    ];

    return Mesh3D(name: 'Explorer Gem', vertices: vertices, faces: faces);
  }

  /// 📦 3D Artifact Crate (Cube with Beveled Colors)
  static Mesh3D createCrate({
    double size = 1.0,
    Color color = const Color(0xFF582F0E),
  }) {
    final s = size;
    final vertices = [
      Vector3D(-s, -s, -s), // 0
      Vector3D(s, -s, -s), // 1
      Vector3D(s, s, -s), // 2
      Vector3D(-s, s, -s), // 3
      Vector3D(-s, -s, s), // 4
      Vector3D(s, -s, s), // 5
      Vector3D(s, s, s), // 6
      Vector3D(-s, s, s), // 7
    ];

    final topColor = Color.lerp(color, const Color(0xFFFFB703), 0.3)!;
    final sideColor = color;
    final bottomColor = Color.lerp(color, Colors.black, 0.4)!;

    final faces = [
      // Front (Z+)
      PolygonFace(vertexIndices: [4, 5, 6, 7], baseColor: sideColor),
      // Back (Z-)
      PolygonFace(vertexIndices: [1, 0, 3, 2], baseColor: bottomColor),
      // Top (Y+)
      PolygonFace(vertexIndices: [7, 6, 2, 3], baseColor: topColor),
      // Bottom (Y-)
      PolygonFace(vertexIndices: [0, 1, 5, 4], baseColor: bottomColor),
      // Right (X+)
      PolygonFace(vertexIndices: [5, 1, 2, 6], baseColor: Color.lerp(sideColor, Colors.white, 0.15)!),
      // Left (X-)
      PolygonFace(vertexIndices: [0, 4, 7, 3], baseColor: Color.lerp(sideColor, Colors.black, 0.25)!),
    ];

    return Mesh3D(name: 'Artifact Crate', vertices: vertices, faces: faces);
  }

  /// 📍 3D Geo Beacon (Double Inverted Pyramids with Floating Ring)
  static Mesh3D createBeacon({
    double radius = 0.8,
    double height = 1.6,
    Color color = const Color(0xFFD90429),
  }) {
    final vertices = [
      Vector3D(0, height, 0), // 0: Top Tip
      Vector3D(radius, height * 0.4, 0), // 1
      Vector3D(0, height * 0.4, radius), // 2
      Vector3D(-radius, height * 0.4, 0), // 3
      Vector3D(0, height * 0.4, -radius), // 4
      const Vector3D(0, 0, 0), // 5: Center Point
      Vector3D(0, -height * 0.8, 0), // 6: Ground Pin Tip
    ];

    final brightPin = Color.lerp(color, Colors.white, 0.2)!;
    final darkPin = Color.lerp(color, Colors.black, 0.3)!;

    final faces = [
      // Top Pyramid
      PolygonFace(vertexIndices: [0, 2, 1], baseColor: brightPin),
      PolygonFace(vertexIndices: [0, 3, 2], baseColor: color),
      PolygonFace(vertexIndices: [0, 4, 3], baseColor: darkPin),
      PolygonFace(vertexIndices: [0, 1, 4], baseColor: color),

      // Inverted Neck
      PolygonFace(vertexIndices: [5, 1, 2], baseColor: color),
      PolygonFace(vertexIndices: [5, 2, 3], baseColor: brightPin),
      PolygonFace(vertexIndices: [5, 3, 4], baseColor: darkPin),
      PolygonFace(vertexIndices: [5, 4, 1], baseColor: color),

      // Lower Needle to Ground
      PolygonFace(vertexIndices: [6, 2, 1], baseColor: darkPin),
      PolygonFace(vertexIndices: [6, 3, 2], baseColor: color),
      PolygonFace(vertexIndices: [6, 4, 3], baseColor: brightPin),
      PolygonFace(vertexIndices: [6, 1, 4], baseColor: color),
    ];

    return Mesh3D(name: 'Geo Beacon', vertices: vertices, faces: faces);
  }

  /// ⚽ 3D Geodesic Orb (Icosahedron)
  static Mesh3D createOrb({
    double radius = 1.0,
    Color color = const Color(0xFF0284C7),
  }) {
    final phi = (1.0 + math.sqrt(5.0)) / 2.0;
    final r = radius / math.sqrt(1 + phi * phi);

    final rawVertices = [
      Vector3D(-r, phi * r, 0),
      Vector3D(r, phi * r, 0),
      Vector3D(-r, -phi * r, 0),
      Vector3D(r, -phi * r, 0),
      Vector3D(0, -r, phi * r),
      Vector3D(0, r, phi * r),
      Vector3D(0, -r, -phi * r),
      Vector3D(0, r, -phi * r),
      Vector3D(phi * r, 0, -r),
      Vector3D(phi * r, 0, r),
      Vector3D(-phi * r, 0, -r),
      Vector3D(-phi * r, 0, r),
    ];

    final indices = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];

    final faces = <PolygonFace>[];
    for (int i = 0; i < indices.length; i++) {
      final faceColor = (i % 3 == 0)
          ? Color.lerp(color, Colors.white, 0.3)!
          : (i % 3 == 1)
              ? color
              : Color.lerp(color, Colors.black, 0.25)!;
      faces.add(PolygonFace(vertexIndices: indices[i], baseColor: faceColor));
    }

    return Mesh3D(name: 'Geodesic Orb', vertices: rawVertices, faces: faces);
  }

  /// 🔺 3D Heritage Pyramid
  static Mesh3D createPyramid({
    double baseSize = 1.2,
    double height = 1.4,
    Color color = const Color(0xFFE07A5F),
  }) {
    final b = baseSize;
    final vertices = [
      Vector3D(0, height, 0), // 0: Peak
      Vector3D(-b, 0, b), // 1: Front-Left
      Vector3D(b, 0, b), // 2: Front-Right
      Vector3D(b, 0, -b), // 3: Back-Right
      Vector3D(-b, 0, -b), // 4: Back-Left
    ];

    final faces = [
      // Front Face
      PolygonFace(vertexIndices: [0, 1, 2], baseColor: Color.lerp(color, Colors.white, 0.2)!),
      // Right Face
      PolygonFace(vertexIndices: [0, 2, 3], baseColor: color),
      // Back Face
      PolygonFace(vertexIndices: [0, 3, 4], baseColor: Color.lerp(color, Colors.black, 0.3)!),
      // Left Face
      PolygonFace(vertexIndices: [0, 4, 1], baseColor: Color.lerp(color, Colors.black, 0.15)!),
      // Base
      PolygonFace(vertexIndices: [1, 4, 3, 2], baseColor: Color.lerp(color, Colors.black, 0.4)!),
    ];

    return Mesh3D(name: 'Heritage Pyramid', vertices: vertices, faces: faces);
  }
}
