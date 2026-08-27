class MapConfig {
  /// OpenStreetMap Standard Tile Layer (100% Free, Zero Watermarks, Zero API Key Required)
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const List<String> subdomains = [];

  /// OpenStreetMap Humanitarian (HOT) Warm Pastel Style (Zero Watermarks)
  static const String hotTileUrl = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
  static const List<String> hotSubdomains = ['a', 'b', 'c'];

  static const String userAgentPackageName = 'dev.zernanvash.juanderquest';

  // Pangasinan Default Coordinates
  static const double pangasinanLat = 16.0350;
  static const double pangasinanLng = 120.3330;
  static const double defaultZoom = 10.5;

  // Pin Styling Colors
  static const String markerGoldHex = '#FFB703';
  static const String markerBorderHex = '#582F0E';
}
