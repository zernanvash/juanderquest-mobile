import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/building_layer_style.dart';

void main() {
  test('opacity update preserves all visual extrusion paint properties', () {
    final serialized = buildingLayerProperties(opacity: 0.85)
        .toJson(skipNulls: false);

    expect(serialized['fill-extrusion-opacity'], 0.85);
    expect(serialized['fill-extrusion-color'], '#C6C2B9');
    expect(serialized['fill-extrusion-height'], [
      'coalesce',
      ['get', 'render_height'],
      3,
    ]);
    expect(serialized['fill-extrusion-base'], [
      'coalesce',
      ['get', 'render_min_height'],
      0,
    ]);
    expect(serialized['fill-extrusion-vertical-gradient'], isTrue);
  });
}
