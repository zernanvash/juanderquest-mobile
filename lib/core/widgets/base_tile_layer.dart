import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/map_config.dart';
import '../theme/app_colors.dart';

/// Shared proxy-backed tile layer with flutter_map's native disk cache enabled.
/// With [satellite], Esri World Imagery is drawn instead (straight from Esri).
TileLayer buildBaseTileLayer({bool satellite = false}) => satellite
    ? TileLayer(
        key: const ValueKey('satellite_tiles'),
        urlTemplate: MapConfig.satelliteTileUrl(),
        userAgentPackageName: MapConfig.userAgentPackageName,
        maxNativeZoom: MapConfig.maxNativeZoom,
        maxZoom: MapConfig.maxZoom,
      )
    : TileLayer(
        urlTemplate: MapConfig.tileUrl,
        userAgentPackageName: MapConfig.userAgentPackageName,
        maxNativeZoom: MapConfig.maxNativeZoom,
        maxZoom: MapConfig.maxZoom,
      );

/// Map / Satellite choice, shared by every map for this app session.
final satelliteModeProvider = StateProvider<bool>((ref) => false);

/// True when satellite imagery is configured and switched on.
bool satelliteOn(WidgetRef ref) =>
    MapConfig.satelliteAvailable() && ref.watch(satelliteModeProvider);

/// Small Map / Satellite switch; hidden when no imagery key is configured.
class SatelliteToggleButton extends ConsumerWidget {
  const SatelliteToggleButton({super.key, this.available, this.compact = false});

  /// Overrides the configured key check (tests).
  final bool? available;

  /// Icon-only round button, matching the map tool column.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(available ?? MapConfig.satelliteAvailable())) return const SizedBox.shrink();
    final on = ref.watch(satelliteModeProvider);
    void toggle() => ref.read(satelliteModeProvider.notifier).state = !on;
    if (compact) {
      return FloatingActionButton.small(
        key: const ValueKey('satellite_toggle'),
        heroTag: 'satellite_toggle_map',
        backgroundColor: on ? AppColors.primary : Colors.white,
        foregroundColor: on ? Colors.white : AppColors.primary,
        onPressed: toggle,
        tooltip: on ? 'Show map' : 'Show satellite',
        child: Icon(on ? Icons.map_rounded : Icons.satellite_alt_rounded, size: 18),
      );
    }
    return FilledButton.tonalIcon(
      key: const ValueKey('satellite_toggle'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: toggle,
      icon: Icon(on ? Icons.map_rounded : Icons.satellite_alt_rounded, size: 16),
      label: Text(on ? 'Map' : 'Satellite'),
    );
  }
}

/// Esri credit shown on flutter_map canvases while satellite imagery is drawn.
class SatelliteAttribution extends StatelessWidget {
  const SatelliteAttribution({super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.white70,
          child: const Text(MapConfig.satelliteAttribution,
              style: TextStyle(fontSize: 9, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      );
}
