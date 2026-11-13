import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/map_config.dart';
import '../theme/app_colors.dart';

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
