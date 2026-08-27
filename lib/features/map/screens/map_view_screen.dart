import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

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
  final MapController _mapController = MapController();
  QuestModel? _selectedQuest;
  SpotModel? _selectedSpot;
  String _activeFilter = 'all'; // 'all', 'quests', 'spots'
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Auto-select initial quest if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quests = ref.read(questProvider).quests;
      if (quests.isNotEmpty && _selectedQuest == null && _selectedSpot == null) {
        setState(() {
          _selectedQuest = quests.first;
        });
      }
    });
  }

  void _fitAllBounds() {
    final quests = ref.read(questProvider).quests;
    final spots = ref.read(spotDiscoveryProvider).spots;

    final points = <LatLng>[];

    if (_activeFilter == 'all' || _activeFilter == 'quests') {
      for (final q in quests) {
        points.add(LatLng(q.gpsLat, q.gpsLng));
      }
    }
    if (_activeFilter == 'all' || _activeFilter == 'spots') {
      for (final s in spots) {
        points.add(LatLng(s.gpsLat, s.gpsLng));
      }
    }

    if (points.isEmpty) {
      _mapController.move(
        const LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
        MapConfig.defaultZoom,
      );
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 13.0);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(questProvider.notifier).fetchQuests(),
        ref.read(spotDiscoveryProvider.notifier).load(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _navigateTo(String name, String address, double lat, double lng) {
    context.push(
      '/navigate?lat=$lat&lng=$lng&name=${Uri.encodeComponent(name)}&address=${Uri.encodeComponent(address)}',
    );
  }


  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final spotState = ref.watch(spotDiscoveryProvider);

    final quests = questState.quests;
    final spots = spotState.spots;

    final markers = <Marker>[];

    // 1. Quests Markers (Gold Badges)
    if (_activeFilter == 'all' || _activeFilter == 'quests') {
      for (final quest in quests) {
        final isSelected = _selectedQuest?.id == quest.id;
        markers.add(
          Marker(
            point: LatLng(quest.gpsLat, quest.gpsLng),
            width: isSelected ? 44 : 38,
            height: isSelected ? 44 : 38,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedQuest = quest;
                  _selectedSpot = null;
                });
                _mapController.move(LatLng(quest.gpsLat, quest.gpsLng), 13.0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF582F0E) : Colors.white,
                    width: isSelected ? 2.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🏆',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 2. Spots Markers (Emerald Badges)
    if (_activeFilter == 'all' || _activeFilter == 'spots') {
      for (final spot in spots) {
        final isSelected = _selectedSpot?.id == spot.id;
        markers.add(
          Marker(
            point: LatLng(spot.gpsLat, spot.gpsLng),
            width: isSelected ? 40 : 34,
            height: isSelected ? 40 : 34,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSpot = spot;
                  _selectedQuest = null;
                });
                _mapController.move(LatLng(spot.gpsLat, spot.gpsLng), 13.0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 2.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '📍',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

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
                'Pangasinan Tourism Map',
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
          // 1. Edge-to-Edge OpenStreetMap Canvas (1:1 with Web Leaflet engine)
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
              initialZoom: MapConfig.defaultZoom,
              minZoom: 6.0,
              maxZoom: 19.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                subdomains: MapConfig.subdomains,
                userAgentPackageName: MapConfig.userAgentPackageName,
                maxZoom: 20,
              ),

              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Top-Left Floating Header & Filter Panel (Web Parity)
          Positioned(
            top: 12,
            left: 12,
            right: 64, // Space for right-side action buttons
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: AppSpacing.roundedXl,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${quests.length} Quests • ${spots.length} Spots Active',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/search'),
                        child: const Text(
                          'Search →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Filter Segment Buttons
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildFilterChip('all', 'All'),
                      _buildFilterChip('quests', '🏆 Quests'),
                      _buildFilterChip('spots', '📍 Spots'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Top-Right Floating Map Tool Controls (Web Parity)
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                // Fit All Bounds / Recenter
                FloatingActionButton.small(
                  heroTag: 'fit_bounds_map',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _fitAllBounds,
                  tooltip: 'Fit All Markers',
                  child: const Icon(Icons.explore_rounded, size: 18),
                ),
                const SizedBox(height: 8),
                // Reload Coordinates
                FloatingActionButton.small(
                  heroTag: 'refresh_map',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.woodBrown,
                  onPressed: _isRefreshing ? null : _refreshData,
                  tooltip: 'Reload Coordinates',
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.woodBrown),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ),

          // 4. Bottom-Left Floating Marker Inspector Overlay Card (Web Parity)
          if (_selectedQuest != null || _selectedSpot != null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.roundedPill,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLowContrast,
          ),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isQuest ? AppColors.sunGold.withOpacity(0.25) : AppColors.primary.withOpacity(0.12),
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isQuest ? '🏆' : '📍',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isQuest ? 'Interactive Quest Trail' : 'Tourism Destination Spot',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isQuest ? AppColors.woodBrown : AppColors.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                onTap: () => _navigateTo(title, location, lat, lng),
                child: Container(

                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
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
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
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
