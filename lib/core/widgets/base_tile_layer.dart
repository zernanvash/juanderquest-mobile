import 'package:flutter_map/flutter_map.dart';

import '../config/map_config.dart';

/// Shared proxy-backed tile layer with flutter_map's native disk cache enabled.
TileLayer buildBaseTileLayer() => TileLayer(
      urlTemplate: MapConfig.tileUrl,
      userAgentPackageName: MapConfig.userAgentPackageName,
      maxNativeZoom: MapConfig.maxNativeZoom,
      maxZoom: MapConfig.maxZoom,
    );
