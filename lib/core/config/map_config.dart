class MapConfig {
  /// Fetch volunteer OSM tiles through the bounded first-party proxy.
  static const String tileUrl = String.fromEnvironment(
    'TILE_URL_TEMPLATE',
    defaultValue:
        'https://juanderquest.app/map-tiles/{z}/{x}/{y}.png?style=osm-standard-v1',
  );

  static const String userAgentPackageName = 'dev.zernanvash.juanderquest';

  static const int maxNativeZoom = 18;
  static const double maxZoom = 19;
  static const double minZoom = 5;

  static const double phMinLat = 4.5;
  static const double phMaxLat = 21.5;
  static const double phMinLng = 116.0;
  static const double phMaxLng = 127.0;

  // Pangasinan Default Coordinates
  static const double pangasinanLat = 16.0350;
  static const double pangasinanLng = 120.3330;
  static const double defaultZoom = 10.5;

  // Pin Styling Colors
  static const String markerGoldHex = '#FFB703';
  static const String markerBorderHex = '#582F0E';
}
