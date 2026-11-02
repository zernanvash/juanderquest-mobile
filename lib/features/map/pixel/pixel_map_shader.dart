import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Shader utilities and FragmentProgram cache for the pixel map.
abstract final class PixelMapShader {
  static Future<ui.FragmentProgram?>? _loadFuture;

  /// Loads the pixel map fragment program from assets once.
  static Future<ui.FragmentProgram?> load() {
    return _loadFuture ??= () async {
      try {
        return await ui.FragmentProgram.fromAsset('shaders/pixel_map.frag');
      } catch (error) {
        debugPrint('[PixelMapShader] FragmentProgram unavailable: $error');
        return null;
      }
    }();
  }

  /// Calculates the cell size in whole device pixels.
  ///
  /// Mathematical formula:
  ///   devicePerArt = (artPx * dpr).round()
  ///   uCell = devicePerArt * cellArt
  ///
  /// Guarantees integer device pixel grid alignment across various DPRs (e.g. 2.0, 2.625, 3.0).
  static double computeUCell({
    required double artPx,
    required double dpr,
    int cellArt = 2,
  }) {
    final devicePerArt = (artPx * dpr).round().clamp(1, 64).toInt();
    return (devicePerArt * cellArt).toDouble();
  }
}

/// Controller managing a single [ui.FragmentShader] instance lifecycle and uniforms.
class PixelMapShaderController {
  PixelMapShaderController();

  ui.FragmentShader? _shader;
  double? _lastCell;
  double? _lastSpread;

  ui.FragmentShader? get shader => _shader;
  bool get isReady => _shader != null;

  /// Initializes the shader from [program] if not yet created.
  void init(ui.FragmentProgram program) {
    _shader ??= program.fragmentShader();
  }

  /// Updates shader uniforms if cell size or spread changed.
  void updateUniforms({required double uCell, double uSpread = 0.12}) {
    if (_shader == null) return;
    if (_lastCell != uCell || _lastSpread != uSpread) {
      _shader!.setFloat(2, uCell);
      _shader!.setFloat(3, uSpread);
      _lastCell = uCell;
      _lastSpread = uSpread;
    }
  }

  /// Disposes the underlying native shader.
  void dispose() {
    _shader?.dispose();
    _shader = null;
    _lastCell = null;
    _lastSpread = null;
  }
}
