class MapConfig {
  /// CartoDB Voyager Vector-rendered retina raster tiles (Crisp, warm, modern vector aesthetic)
  static const String tileUrl = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
  static const String fallbackTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackageName = 'dev.zernanvash.juanderquest';

  // Vector style JSON references for GL renderers
  static const String vectorStyleUrl = 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
  static const String fallbackStyleUrl = 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  // Pangasinan Default Coordinates
  static const double pangasinanLat = 16.0350;
  static const double pangasinanLng = 120.3330;
  static const double defaultZoom = 10.5;

  // Pin Styling Colors
  static const String markerGoldHex = '#FFB703';
  static const String markerBorderHex = '#582F0E';
}
