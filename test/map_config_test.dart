import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/config/map_config.dart';

void main() {
  test('mobile tiles use the first-party proxy and stop native requests at z18', () {
    expect(MapConfig.tileUrl, contains('/map-tiles/'));
    expect(MapConfig.tileUrl, isNot(contains('openstreetmap.org')));
    expect(MapConfig.maxNativeZoom, 18);
    expect(MapConfig.maxZoom, 19);
  });
}
