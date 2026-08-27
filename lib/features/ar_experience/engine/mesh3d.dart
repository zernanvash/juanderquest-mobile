import 'package:flutter/material.dart';
import 'vector3d.dart';


/// Represents a single triangular or quad polygon face of a 3D mesh.
class PolygonFace {
  final List<int> vertexIndices;
  final Color baseColor;
  final bool isDoubleSided;

  const PolygonFace({
    required this.vertexIndices,
    required this.baseColor,
    this.isDoubleSided = false,
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

  /// Calculates shaded surface color based on Lambertian diffuse + ambient lighting.
  static Color calculateShading({
    required Color baseColor,
    required Vector3D normal,
    required Vector3D lightDirection,
    double ambient = 0.35,
    double diffuse = 0.65,
  }) {
    final normLight = lightDirection.normalize();
    // Lambert's cosine law (dot product of normal & light vector)
    double intensity = normal.dot(normLight);
    if (intensity < 0) intensity = 0;

    final totalLight = (ambient + diffuse * intensity).clamp(0.0, 1.0);

    return Color.fromARGB(
      baseColor.alpha,
      (baseColor.red * totalLight).round().clamp(0, 255),
      (baseColor.green * totalLight).round().clamp(0, 255),
      (baseColor.blue * totalLight).round().clamp(0, 255),
    );
  }
}
