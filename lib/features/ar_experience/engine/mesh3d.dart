import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'vector3d.dart';

/// Represents a single triangular or quad polygon face of a 3D mesh.
class PolygonFace {
  final List<int> vertexIndices;
  final Color baseColor;
  final bool isDoubleSided;
  final double shininess; // 0 for matte, 16..64 for metallic / crystal shine

  const PolygonFace({
    required this.vertexIndices,
    required this.baseColor,
    this.isDoubleSided = false,
    this.shininess = 32.0,
  });

  /// Computes the face normal in world space.
  Vector3D computeNormal(List<Vector3D> transformedVertices) {
    if (vertexIndices.length < 3) return const Vector3D(0, 0, 1);
    final v0 = transformedVertices[vertexIndices[0]];
    final v1 = transformedVertices[vertexIndices[1]];
    final v2 = transformedVertices[vertexIndices[2]];
    final edge1 = v1 - v0;
    final edge2 = v2 - v0;
    return edge1.cross(edge2).normalize();
  }

  /// Computes the average depth (Z-centroid) for Painter's algorithm sorting.
  double computeCentroidZ(List<Vector3D> transformedVertices) {
    double sumZ = 0;
    for (final idx in vertexIndices) {
      sumZ += transformedVertices[idx].z;
    }
    return sumZ / vertexIndices.length;
  }
}

/// A 3D Geometric Mesh containing vertices and polygonal faces.
class Mesh3D {
  final String name;
  final List<Vector3D> vertices;
  final List<PolygonFace> faces;

  const Mesh3D({
    required this.name,
    required this.vertices,
    required this.faces,
  });

  /// Creates a transformed copy of the mesh vertices.
  List<Vector3D> transform({
    required double rotX,
    required double rotY,
    required double rotZ,
    required double scale,
    Vector3D translation = Vector3D.zero,
  }) {
    return vertices.map((v) {
      final scaled = v * scale;
      final rotated = scaled.rotate(rotX, rotY, rotZ);
      return rotated + translation;
    }).toList();
  }

  /// Calculates shaded surface color based on Blinn-Phong lighting model
  /// (Ambient + Lambertian Diffuse + Specular Highlights).
  static Color calculateShading({
    required Color baseColor,
    required Vector3D normal,
    required Vector3D lightDirection,
    double ambient = 0.38,
    double diffuse = 0.58,
    double specular = 0.35,
    double shininess = 24.0,
  }) {
    final normLight = lightDirection.normalize();
    // 1. Diffuse component (Lambert's cosine law)
    double diffuseIntensity = normal.dot(normLight);
    if (diffuseIntensity < 0) diffuseIntensity = 0;

    // 2. Specular component (Blinn-Phong halfway vector towards camera V=(0,0,1))
    const viewDir = Vector3D(0, 0, 1);
    final halfway = (normLight + viewDir).normalize();
    double specIntensity = normal.dot(halfway);
    if (specIntensity > 0 && diffuseIntensity > 0) {
      specIntensity = math.pow(specIntensity, shininess).toDouble();
    } else {
      specIntensity = 0.0;
    }

    final totalLight = (ambient + diffuse * diffuseIntensity).clamp(0.0, 1.0);
    final specularAdd = (specular * specIntensity * 255.0).round().clamp(0, 255);

    final r = ((baseColor.red * totalLight).round() + specularAdd).clamp(0, 255);
    final g = ((baseColor.green * totalLight).round() + specularAdd).clamp(0, 255);
    final b = ((baseColor.blue * totalLight).round() + specularAdd).clamp(0, 255);

    return Color.fromARGB(baseColor.alpha, r, g, b);
  }
}
