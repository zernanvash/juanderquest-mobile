import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/config/map_config.dart';
import '../../quests/providers/quest_provider.dart';
import '../../quests/models/quest_model.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Quest Map',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF582F0E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Fallback Pangasinan Region Interactive Map Layout
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFE9E8E4),
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
                  left: 160,
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

          // MapLibre Vector Map Overlay
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

          // Map Control Legend Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_rounded, color: Color(0xFF7D5800), size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pangasinan Vector Map',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF582F0E),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBEEAD1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${questState.quests.length} Destinations',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF436B58),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected Quest Modal Sheet Overlay
          if (_selectedQuest != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                color: const Color(0xFFFAF9F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                              style: GoogleFonts.epilogue(
                                color: const Color(0xFF582F0E),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF837560)),
                            onPressed: () => setState(() => _selectedQuest = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedQuest!.locationName,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF837560),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3F6653).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedQuest!.categoryDisplay,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF3F6653),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '+${_selectedQuest!.rewardPoints} PTS',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF7D5800),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () {
                          final questToLaunch = _selectedQuest;
                          setState(() => _selectedQuest = null);
                          context.push('/quests/${questToLaunch!.id}', extra: questToLaunch);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: const Color(0xFFFFB703),
                          foregroundColor: const Color(0xFF6B4B00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'View Quest Details',
                          style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
                        ),
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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF582F0E),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(
            Icons.location_on,
            color: Color(0xFFFFB703),
            size: 32,
          ),
        ],
      ),
    );
  }
}
