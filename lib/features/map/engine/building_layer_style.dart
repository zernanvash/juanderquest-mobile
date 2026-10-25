import 'package:maplibre_gl/maplibre_gl.dart' as gl;

/// Full paint definition used both when creating and updating the 3D layer.
///
/// `setLayerProperties` sends null-valued fields to native MapLibre, where
/// they reset existing paint values to defaults. Keep every paint property
/// here when changing only the tilt-dependent opacity.
gl.FillExtrusionLayerProperties buildingLayerProperties({
  required double opacity,
}) =>
    gl.FillExtrusionLayerProperties(
      fillExtrusionColor: '#C6C2B9',
      fillExtrusionHeight: [
        'coalesce',
        ['get', 'render_height'],
        3
      ],
      fillExtrusionBase: [
        'coalesce',
        ['get', 'render_min_height'],
        0
      ],
      fillExtrusionOpacity: opacity,
      fillExtrusionVerticalGradient: true,
    );
