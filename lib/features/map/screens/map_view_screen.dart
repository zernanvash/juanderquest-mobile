import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  MapLibreMapController? _mapController;
  QuestModel? _selectedQuest;
  SpotModel? _selectedSpot;
  bool _mapError = false;
  bool _isStyleLoaded = false;
  String _activeFilter = 'all'; // 'all', 'quests', 'spots'
  final Map<String, dynamic> _circleToItemMap = {};
  bool _listenerRegistered = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;

    if (!_listenerRegistered) {
      _listenerRegistered = true;
      controller.onCircleTapped.add((circle) {
        final item = _circleToItemMap[circle.id];
        if (item is QuestModel) {
          setState(() {
            _selectedQuest = item;
            _selectedSpot = null;
          });
        } else if (item is SpotModel) {
          setState(() {
            _selectedSpot = item;
            _selectedQuest = null;
          });
        }
      });
    }
  }

  void _onStyleLoaded() {
    if (mounted) {
      setState(() {
        _isStyleLoaded = true;
        _mapError = false;
      });
    }
    _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    if (_mapController == null || !_isStyleLoaded) return;

    try {
      await _mapController!.clearCircles();
      _circleToItemMap.clear();

      final quests = ref.read(questProvider).quests;
      final spots = ref.read(spotDiscoveryProvider).spots;

      // Add Quest Markers
      if (_activeFilter == 'all' || _activeFilter == 'quests') {
        for (final quest in quests) {
          final circle = await _mapController!.addCircle(
            CircleOptions(
              geometry: LatLng(quest.gpsLat, quest.gpsLng),
              circleColor: MapConfig.markerGoldHex,
              circleRadius: 13.0,
              circleStrokeWidth: 3.0,
              circleStrokeColor: MapConfig.markerBorderHex,
            ),
          );
          _circleToItemMap[circle.id] = quest;
        }
      }

      // Add Spot Markers
      if (_activeFilter == 'all' || _activeFilter == 'spots') {
        for (final spot in spots) {
          final circle = await _mapController!.addCircle(
            CircleOptions(
              geometry: LatLng(spot.gpsLat, spot.gpsLng),
              circleColor: '#2D6A4F',
              circleRadius: 10.0,
              circleStrokeWidth: 2.5,
              circleStrokeColor: '#FFFFFF',
            ),
          );
          _circleToItemMap[circle.id] = spot;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _mapError = true);
    }
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
          zoom: MapConfig.defaultZoom,
        ),
      ),
    );
  }

  Future<void> _launchDirections(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final spotState = ref.watch(spotDiscoveryProvider);

    ref.listen(questProvider, (previous, next) {
      if (next.quests != previous?.quests) _syncMarkers();
    });

    ref.listen(spotDiscoveryProvider, (previous, next) {
      if (next.spots != previous?.spots) _syncMarkers();
    });

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Interactive Tourism Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.primary),
            tooltip: 'Search Spots',
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Vector Map Layer
          if (!_mapError)
            MapLibreMap(
              styleString: MapConfig.vectorStyleUrl,
              initialCameraPosition: const CameraPosition(
                target: LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
                zoom: MapConfig.defaultZoom,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              trackCameraPosition: true,
              onStyleLoadedCallback: _onStyleLoaded,
            )
          else
            Container(
              color: AppColors.surfaceContainerHigh,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text('Vector Map Initializing...', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),

          // Loading Map Shimmer Overlay
          if (!_isStyleLoaded && !_mapError)
            Positioned.fill(
              child: Container(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading Pangasinan Map Tiles...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Floating Top Overlay Panel (Active Marker Stats + Mode Switcher)
          Positioned(
            top: 12,
            left: 12,
            right: 70, // Leaves space for top-right floating tool controls
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: AppSpacing.roundedXl,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Mode Filter Chips
                  _buildFilterChip('all', 'All (${questState.quests.length + spotState.spots.length})'),
                  _buildFilterChip('quests', '🏆 Quests (${questState.quests.length})'),
                  _buildFilterChip('spots', '📍 Spots (${spotState.spots.length})'),
                ],
              ),
            ),
          ),

          // 3. Floating Tool Controls (Top-Right)
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                // Recenter Button
                FloatingActionButton.small(
                  heroTag: 'recenter_map',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _recenterMap,
                  tooltip: 'Recenter Map',
                  child: const Icon(Icons.my_location_rounded, size: 18),
                ),
                const SizedBox(height: 8),
                // Reload Layers
                FloatingActionButton.small(
                  heroTag: 'refresh_map',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.woodBrown,
                  onPressed: () {
                    ref.read(questProvider.notifier).fetchQuests();
                    ref.read(spotDiscoveryProvider.notifier).load();
                    _syncMarkers();
                  },
                  tooltip: 'Refresh Markers',
                  child: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ),

          // 4. Floating Bottom Marker Inspector Sheet (Animates into view upon tap)
          if (_selectedQuest != null || _selectedSpot != null)
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: _buildMarkerInspectorCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = key);
        _syncMarkers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.roundedPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.woodBrown,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerInspectorCard() {
    final isQuest = _selectedQuest != null;
    final title = isQuest ? _selectedQuest!.title : _selectedSpot!.name;
    final location = isQuest ? _selectedQuest!.locationName : _selectedSpot!.municipality;
    final lat = isQuest ? _selectedQuest!.gpsLat : _selectedSpot!.gpsLat;
    final lng = isQuest ? _selectedQuest!.gpsLng : _selectedSpot!.gpsLng;
    final bountyText = isQuest ? '+${_selectedQuest!.rewardPoints} mJDQ' : (_selectedSpot!.questId != null ? '+250 mJDQ' : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type + Dismiss X Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isQuest ? AppColors.sunGold.withOpacity(0.25) : AppColors.primary.withOpacity(0.12),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isQuest ? Icons.emoji_events_rounded : Icons.place_rounded,
                      size: 12,
                      color: isQuest ? AppColors.woodBrown : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isQuest ? 'Interactive Quest Trail' : 'Tourism Destination',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isQuest ? AppColors.woodBrown : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  setState(() {
                    _selectedQuest = null;
                    _selectedSpot = null;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Title
          Text(
            title,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 2),

          // Location & Coordinates
          Text(
            '$location • (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Actions Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Navigate Button
              GestureDetector(
                onTap: () => _launchDirections(lat, lng),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Navigate',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // View Details / Play Quest Button
              GestureDetector(
                onTap: () {
                  if (isQuest) {
                    context.push('/quests/${_selectedQuest!.id}');
                  } else {
                    context.push('/explore/${_selectedSpot!.slug}', extra: _selectedSpot);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppSpacing.roundedPill,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.woodBrown),
                    ],
                  ),
                ),
              ),

              if (bountyText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.sunGold.withOpacity(0.2),
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: Text(
                    bountyText,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.woodBrown),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
