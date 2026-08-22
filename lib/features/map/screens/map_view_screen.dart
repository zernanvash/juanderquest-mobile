import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  MapLibreMapController? _mapController;
  QuestModel? _selectedQuest;
  bool _mapError = false;
  final Map<String, QuestModel> _circleToQuestMap = {};
  bool _listenerRegistered = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;

    if (!_listenerRegistered) {
      _listenerRegistered = true;
      controller.onCircleTapped.add((circle) {
        final quests = ref.read(questProvider).quests;
        if (quests.isEmpty) return;

        final circleId = circle.id;
        final matchedQuest = _circleToQuestMap[circleId];

        if (matchedQuest != null) {
          setState(() => _selectedQuest = matchedQuest);
        } else {
          final circleGeo = circle.options.geometry;
          if (circleGeo != null) {
            for (final q in quests) {
              if ((q.gpsLat - circleGeo.latitude).abs() < 0.005 &&
                  (q.gpsLng - circleGeo.longitude).abs() < 0.005) {
                setState(() => _selectedQuest = q);
                break;
              }
            }
          }
        }
      });
    }

    _syncQuestMarkers();
  }

  Future<void> _syncQuestMarkers() async {
    if (_mapController == null) return;

    try {
      await _mapController!.clearCircles();
      _circleToQuestMap.clear();

      final quests = ref.read(questProvider).quests;
      for (final quest in quests) {
        final circle = await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(quest.gpsLat, quest.gpsLng),
            circleColor: MapConfig.markerGoldHex,
            circleRadius: 12.0,
            circleStrokeWidth: 3.0,
            circleStrokeColor: MapConfig.markerBorderHex,
          ),
        );
        _circleToQuestMap[circle.id] = quest;
      }
    } catch (_) {
      if (mounted) setState(() => _mapError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);

    ref.listen(questProvider, (previous, next) {
      if (next.quests != previous?.quests) {
        _syncQuestMarkers();
      }
    });

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Geographic Discovery Map'),
        ),
      ),
      body: Stack(
        children: [
          // Pangasinan Regional Map Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              image: DecorationImage(
                image: AssetImage('assets/images/pangasinan_banner.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 180,
                  left: 120,
                  child: _buildMapPin(
                    questTitle: 'Hundred Islands Eco Trek',
                    onTap: () {
                      if (questState.quests.isNotEmpty) {
                        setState(() => _selectedQuest = questState.quests.first);
                      }
                    },
                  ),
                ),
                Positioned(
                  top: 100,
                  right: 90,
                  child: _buildMapPin(
                    questTitle: 'Bolinao Lighthouse',
                    onTap: () {
                      if (questState.quests.length > 1) {
                        setState(() => _selectedQuest = questState.quests[1]);
                      }
                    },
                  ),
                ),
                Positioned(
                  bottom: 220,
                  left: 100,
                  child: _buildMapPin(
                    questTitle: 'Manaoag Shrine',
                    onTap: () {
                      if (questState.quests.length > 2) {
                        setState(() => _selectedQuest = questState.quests[2]);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Vector Map Layer
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
              onStyleLoadedCallback: () {
                _syncQuestMarkers();
              },
            ),

          // Map Header Control Overlay
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pangasinan Vector Map',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.woodBrown,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Text(
                        '${questState.quests.length} Spots',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected Spot/Quest Bottom Sheet Modal Card
          if (_selectedQuest != null)
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              child: Card(
                elevation: 8,
                color: AppColors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedQuest!.title,
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.woodBrown,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                            onPressed: () => setState(() => _selectedQuest = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedQuest!.locationName,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: AppSpacing.roundedSm,
                              ),
                              child: Text(
                                _selectedQuest!.categoryDisplay,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${_selectedQuest!.rewardPoints} PTS',
                            style: TextStyle(
                              color: AppColors.woodBrown,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'View Details',
                        onPressed: () {
                          final questToLaunch = _selectedQuest;
                          setState(() => _selectedQuest = null);
                          context.push('/quests/${questToLaunch!.id}', extra: questToLaunch);
                        },
                        icon: Icons.explore_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapPin({required String questTitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppSpacing.roundedSm,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              questTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.woodBrown,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.sunGold,
            size: 32,
          ),
        ],
      ),
    );
  }
}
