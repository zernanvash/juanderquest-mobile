class MapConfig {
  /// Fetch volunteer OSM tiles through the bounded first-party proxy.
  static const String tileUrl = String.fromEnvironment(
    'TILE_URL_TEMPLATE',
    defaultValue:
        'https://juanderquest.app/map-tiles/{z}/{x}/{y}.png?style=osm-standard-v1',
  );

  static const String userAgentPackageName = 'dev.zernanvash.juanderquest';

  /// Esri World Imagery through an ArcGIS Location Platform key (owner 2026-10-30), passed with
  /// `--dart-define=ARCGIS_KEY=...` and never committed. No key → the Satellite switch is hidden.
  /// Tiles load straight from Esri (their terms do not allow proxying or caching them).
  static const String satelliteKey = String.fromEnvironment('ARCGIS_KEY');
  static const String satelliteAttribution =
      'Powered by Esri | Esri, Maxar, Earthstar Geographics, and the GIS User Community';

  static bool satelliteAvailable([String key = satelliteKey]) => key.trim().isNotEmpty;

  static String satelliteTileUrl([String key = satelliteKey]) =>
      'https://ibasemaps-api.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      '?token=${Uri.encodeQueryComponent(key.trim())}';

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
