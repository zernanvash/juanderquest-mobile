import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:latlong2/latlong.dart';

// Owner 2026-11-26: "map inaccurate preview on destination details". The venue preview
// calls easeTo(spot, 16) before the map has loaded; the engine used to drop that call,
// so the preview opened on the default camera (central Pangasinan, zoom 10.5).
void main() {
  test('easeTo before the map is ready becomes the starting camera', () async {
    final map = MapLibreJdqMap();
    const spot = LatLng(16.4023, 120.5960); // Baguio, outside the default view
    await map.easeTo(spot, 16.0, reducedMotion: true);
    expect(map.camera.center, spot);
    expect(map.camera.zoom, 16.0);
    map.dispose();
  });
}
