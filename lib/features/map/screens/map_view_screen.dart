import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/map_config.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/utils/spot_posting.dart';
import '../../spots/widgets/spot_posting_sheet.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/admin_areas.dart';
import '../utils/map_focus.dart';
import '../utils/map_cluster.dart';
import '../utils/map_list.dart';
import '../widgets/map_cluster_list_sheet.dart';
import '../widgets/trail_preview_card.dart';

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
  bool _locating = false;
  LatLng? _userLocation;
  bool _pinPlacementActive = false;
  SpotPostingDraft? _pendingDraft;
  int _pendingResumeStep = 0;
  Timer? _clusterRefreshTimer;
  DateTime _lastClusterRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  double? _pendingClusterZoom;
  double _clusterZoom = MapConfig.defaultZoom;

  // Plan 45 §9 / Plan 47 B2: clickable town & province names with real
  // PSA/NAMRIA boundaries.
  late final AdminAreaApi _areaApi =
      AdminAreaApi(ref.read(apiClientProvider).dio);
  List<AdminArea> _areas = const [];
  Set<String> _visibleLabelIds = const {};
  AdminArea? _focusedArea;
  AreaShape? _focusedShape;
  LatLng? _preFocusCenter;
  double? _preFocusZoom;
  Timer? _areaRefreshTimer;
  int _areaRequest = 0;

  @override
  void dispose() {
    _clusterRefreshTimer?.cancel();
    _areaRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleAreaRefresh() {
    _areaRefreshTimer?.cancel();
    _areaRefreshTimer =
        Timer(const Duration(milliseconds: 450), _refreshAreas);
  }

  Future<void> _refreshAreas() async {
    if (!mounted) return;
    final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      return; // Map not laid out yet.
    }
    final b = camera.visibleBounds;
    final request = ++_areaRequest;
    try {
      final areas = await _areaApi.visible(
        minLat: b.south,
        minLng: b.west,
        maxLat: b.north,
        maxLng: b.east,
        zoom: camera.zoom,
      );
      if (!mounted || request != _areaRequest) return;
      setState(() {
        _areas = areas;
        _visibleLabelIds = _declutter(areas, camera);
      });
    } catch (_) {
      // Names are an enhancement; the map works without them.
    }
  }

  Set<String> _declutter(List<AdminArea> areas, MapCamera camera) {
    return declutterAreaLabels([
      for (final a in areas)
        AreaLabelBox(
          a.id,
          camera.latLngToScreenOffset(a.label),
          areaLabelSize(a.name, province: a.level == 'province'),
          (a.level == 'province' ? 100000 : 0) + a.spotCount,
        ),
    ]);
  }

  Future<void> _focusArea(AdminArea area) async {
    AreaShape? shape;
    try {
      shape = await _areaApi.shape(area.id);
    } catch (_) {
      shape = null;
    }
    if (!mounted) return;
    if (shape == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('The boundary of ${area.name} is not available yet.')));
      return;
    }
    final camera = _mapController.camera;
    setState(() {
      if (_focusedArea == null) {
        _preFocusCenter = camera.center;
        _preFocusZoom = camera.zoom;
      }
      _focusedArea = area;
      _focusedShape = shape;
      _selectedQuest = null;
      _selectedSpot = null;
    });
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(shape.outlinePoints),
      padding: const EdgeInsets.fromLTRB(32, 140, 32, 120),
    ));
  }

  void _clearArea() {
    final center = _preFocusCenter;
    final zoom = _preFocusZoom;
    setState(() {
      _focusedArea = null;
      _focusedShape = null;
      _preFocusCenter = null;
      _preFocusZoom = null;
    });
    if (center != null && zoom != null) _mapController.move(center, zoom);
  }

  bool _inFocusedArea(double lat, double lng) =>
      _focusedShape?.contains(lat, lng) ?? true;

  void _scheduleClusterRefresh(MapCamera camera, bool hasGesture) {
    _scheduleAreaRefresh();
    _pendingClusterZoom = camera.zoom;
    final now = DateTime.now();
    final remaining = const Duration(milliseconds: 150) - now.difference(_lastClusterRefresh);
    if (remaining <= Duration.zero) {
      _clusterRefreshTimer?.cancel();
      _flushClusterRefresh();
      return;
    }
    _clusterRefreshTimer ??= Timer(remaining, _flushClusterRefresh);
  }

  void _flushClusterRefresh() {
    _clusterRefreshTimer = null;
    _lastClusterRefresh = DateTime.now();
    final zoom = _pendingClusterZoom;
    _pendingClusterZoom = null;
    if (mounted && zoom != null && _clusterZoom != zoom) {
      setState(() => _clusterZoom = zoom);
    }
  }

  Future<void> _openIdenticalCluster(
    MapCluster cluster,
    Map<String, QuestModel> questsByPointId,
    Map<String, SpotModel> spotsByPointId,
  ) async {
    final items = <MapClusterListItem>[];
    for (final id in cluster.ids) {
      final quest = questsByPointId[id];
      if (quest != null) {
        items.add(MapClusterListItem(
          id: id,
          title: quest.title,
          subtitle: quest.locationName,
          icon: Icons.explore_rounded,
        ));
        continue;
      }
      final spot = spotsByPointId[id];
      if (spot != null) {
        items.add(MapClusterListItem(
          id: id,
          title: spot.name,
          subtitle: spot.address.trim().isNotEmpty ? spot.address : spot.municipality,
          icon: Icons.place_rounded,
        ));
      }
    }

    final selectedPointId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => MapClusterListSheet(
        items: items,
        onSelect: (id) => Navigator.of(sheetContext).pop(id),
      ),
    );
    if (!mounted || selectedPointId == null) return;

    final quest = questsByPointId[selectedPointId];
    if (quest != null) {
      setState(() { _selectedQuest = quest; _selectedSpot = null; });
      _focusPlace(quest.gpsLat, quest.gpsLng, 13.0);
      return;
    }
    final spot = spotsByPointId[selectedPointId];
    if (spot != null) {
      setState(() { _selectedSpot = spot; _selectedQuest = null; });
      _focusPlace(spot.gpsLat, spot.gpsLng, 13.0);
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-select initial quest if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAreas();
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

  /// Centers a selected pin so it stays visible above the floating card.
  void _focusPlace(double lat, double lng, double fallbackZoom) {
    final camera = _mapController.camera;
    final zoom = camera.zoom < fallbackZoom ? fallbackZoom : camera.zoom;
    final target = focusTargetAboveCard(
      lat: lat,
      lng: lng,
      zoom: zoom,
      mapHeightPx: camera.size.height,
    );
    _mapController.move(target, zoom);
  }

  /// Map-first posting: arm pin placement, then open the progressive wizard.
  void _startPinPlacement() {
    setState(() {
      _pinPlacementActive = true;
      _selectedQuest = null;
      _selectedSpot = null;
    });
  }

  void _cancelPinPlacement() {
    setState(() => _pinPlacementActive = false);
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (!_pinPlacementActive) {
      // Tapping outside the highlighted area focuses out (web D7/D12).
      final shape = _focusedShape;
      if (shape != null && !shape.contains(point.latitude, point.longitude)) {
        _clearArea();
      }
      return;
    }
    setState(() => _pinPlacementActive = false);
    await _openPostingSheet(point.latitude, point.longitude);
  }

  Future<void> _openPostingSheet(double lat, double lng) async {
    final draft = _pendingDraft;
    final resumeStep = _pendingResumeStep;
    final result = await showModalBottomSheet<SpotPostingSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotPostingSheet(
        initialLat: lat,
        initialLng: lng,
        initialDraft: draft,
        initialStep: resumeStep,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _pendingDraft = null;
        _pendingResumeStep = 0;
      });
      return;
    }
    if (result.movePinRequested) {
      setState(() {
        _pendingDraft = result.draft;
        _pendingResumeStep = result.resumeStep;
        _pinPlacementActive = true;
      });
      return;
    }
    final published = result.publishedSpot;
    if (published != null) {
      setState(() {
        _pendingDraft = null;
        _pendingResumeStep = 0;
        _selectedSpot = published;
        _selectedQuest = null;
      });
      ref.invalidate(spotDiscoveryProvider);
      _focusPlace(published.gpsLat, published.gpsLng, 14.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${published.name} published.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Explicit locate flow: no request before the traveler asks, honest fallbacks.
  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Location services are turned off. Turn them on, or search and pan the map instead.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Location permission was denied. Search or pan the map instead.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = location);
      final camera = _mapController.camera;
      _mapController.move(location, camera.zoom < 14 ? 14.0 : camera.zoom);
      if (position.accuracy > 2000) {
        messenger.showSnackBar(
          SnackBar(content: Text('Approximate location shown (±${position.accuracy.round()} m). Move to an open area for a better fix.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Finding your location timed out or failed. Try again, or search and pan the map instead.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Accessible map/list fallback: the same filter semantics as the pins.
  Future<void> _openPlacesList() async {
    final quests = ref.read(questProvider).quests;
    final spots = ref.read(spotDiscoveryProvider).spots;
    final entries = filterMapEntries(
      quests: quests,
      spots: spots,
      activeFilter: _activeFilter,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Places (${entries.length})',
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Text(
                            'No places match this filter yet. Adjust the map filters or refresh the map data.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return ListTile(
                              minVerticalPadding: 10,
                              leading: Text(
                                entry.isQuest ? '🏆' : '📍',
                                style: const TextStyle(fontSize: 18),
                              ),
                              title: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.woodBrown,
                                ),
                              ),
                              subtitle: Text(
                                entry.isQuest
                                    ? '${entry.subtitle} • +${entry.rewardPoints ?? 0} mJDQ'
                                    : entry.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                setState(() {
                                  if (entry.isQuest) {
                                    _selectedQuest =
                                        quests.firstWhere((q) => q.id == entry.id);
                                    _selectedSpot = null;
                                  } else {
                                    _selectedSpot =
                                        spots.firstWhere((s) => s.id == entry.id);
                                    _selectedQuest = null;
                                  }
                                });
                                _focusPlace(entry.lat, entry.lng, 13.0);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(questProvider.notifier).fetchQuests(),
        ref.read(spotDiscoveryProvider.notifier).load(),
        ref.refresh(choiceSpotlightProvider.future),
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
    final spotlight = ref.watch(choiceSpotlightProvider).valueOrNull;

    final quests = questState.quests;
    final spots = spotState.spots;
    final plannedSpots = planChoiceSpotlight(spots, (spot) => spot.id, spotlight);

    final markers = <Marker>[];
    final visibleQuests = (_activeFilter == 'all' || _activeFilter == 'quests')
        ? quests.where((q) => _inFocusedArea(q.gpsLat, q.gpsLng)).toList()
        : <QuestModel>[];
    final visibleSpots = (_activeFilter == 'all' || _activeFilter == 'spots')
        ? <SpotModel>[...plannedSpots.ordinary, ...plannedSpots.winners]
            .where((s) => _inFocusedArea(s.gpsLat, s.gpsLng))
            .toList()
        : <SpotModel>[];
    final questsByPointId = <String, QuestModel>{};
    final spotsByPointId = <String, SpotModel>{};
    final clusterInputs = <MapClusterPoint>[];

    for (final quest in visibleQuests) {
      final id = 'quest:${quest.id}';
      questsByPointId[id] = quest;
      clusterInputs.add(MapClusterPoint(
        id: id,
        kind: MapClusterPointKind.quest,
        lat: quest.gpsLat,
        lng: quest.gpsLng,
        pinned: _selectedQuest?.id == quest.id || quest.funding?.status == 'active',
      ));
    }
    for (final spot in visibleSpots) {
      final id = 'spot:${spot.id}';
      spotsByPointId[id] = spot;
      clusterInputs.add(MapClusterPoint(
        id: id,
        kind: MapClusterPointKind.spot,
        lat: spot.gpsLat,
        lng: spot.gpsLng,
        pinned: _selectedSpot?.id == spot.id || spot.saved,
      ));
    }

    final clusterResults = clusterPoints(clusterInputs, _clusterZoom);
    for (final result in clusterResults) {
      if (result is MapCluster) {
        final size = result.count < 10 ? 34.0 : result.count < 50 ? 40.0 : 48.0;
        markers.add(Marker(
          point: LatLng(result.lat, result.lng),
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Semantics(
            label: '${result.count} destinations, zoom in',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (result.hasNonZeroSpan) {
                  _mapController.fitCamera(CameraFit.bounds(
                    bounds: LatLngBounds(
                      LatLng(result.minLat, result.minLng),
                      LatLng(result.maxLat, result.maxLng),
                    ),
                    padding: const EdgeInsets.all(48),
                    maxZoom: math.min(_mapController.camera.zoom + 3, 16),
                  ));
                } else {
                  _openIdenticalCluster(result, questsByPointId, spotsByPointId);
                }
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: result.hasQuest ? AppColors.sunGold : Colors.white,
                    width: result.hasQuest ? 3 : 2,
                  ),
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: Center(
                  child: Text(
                    '${result.count}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ));
      } else if (result is MapPointResult) {
        final quest = questsByPointId[result.id];
        if (quest != null) {
          final isSelected = _selectedQuest?.id == quest.id;
          markers.add(Marker(
            point: LatLng(quest.gpsLat, quest.gpsLng),
            width: isSelected ? 44 : 38,
            height: isSelected ? 44 : 38,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                setState(() { _selectedQuest = quest; _selectedSpot = null; });
                _focusPlace(quest.gpsLat, quest.gpsLng, 13.0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF935610),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFB703) : const Color(0xFFFAF9F5),
                    width: isSelected ? 2.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(child: Icon(Icons.explore_rounded, color: const Color(0xFFFFB703), size: isSelected ? 24 : 20)),
              ),
            ),
          ));
          continue;
        }

        final spot = spotsByPointId[result.id];
        if (spot == null) continue;
        final isSelected = _selectedSpot?.id == spot.id;
        final isSpotlight = plannedSpots.winners.any((item) => item.id == spot.id);
        final size = isSpotlight ? (isSelected ? 48.0 : 42.0) : (isSelected ? 40.0 : 34.0);
        markers.add(Marker(
          point: LatLng(spot.gpsLat, spot.gpsLng),
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Semantics(
            label: isSpotlight ? 'JuanChoice community spotlight: ${spot.name}' : spot.name,
            button: true,
            child: GestureDetector(
              onTap: () {
                setState(() { _selectedSpot = spot; _selectedQuest = null; });
                _focusPlace(spot.gpsLat, spot.gpsLng, 13.0);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSpotlight ? AppColors.sunGold : const Color(0xFF1B4332),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpotlight ? AppColors.woodBrown : (isSelected ? const Color(0xFF52B788) : const Color(0xFFFAF9F5)),
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: Icon(
                  isSpotlight ? Icons.workspace_premium_rounded : Icons.park_rounded,
                  color: isSpotlight ? AppColors.woodBrown : const Color(0xFFFAF9F5),
                  size: isSpotlight ? (isSelected ? 28 : 24) : (isSelected ? 22 : 18),
                ),
              ),
            ),
          ),
        ));
      }
    }

    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        child: Semantics(
          label: 'Your current location',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x591D4ED8), spreadRadius: 3, blurRadius: 2),
                BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ),
      ));
    }

    final pendingDraft = _pendingDraft;
    if (_pinPlacementActive && pendingDraft?.lat != null && pendingDraft?.lng != null) {
      markers.add(Marker(
        point: LatLng(pendingDraft!.lat!, pendingDraft.lng!),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Semantics(
          label: 'Draft destination pin',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.sunGold.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sunGold, width: 3),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.woodBrown, size: 22),
          ),
        ),
      ));
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
                'Destination Map',
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
            options: MapOptions(
              initialCenter: const LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
              initialZoom: MapConfig.defaultZoom,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(MapConfig.phMinLat, MapConfig.phMinLng),
                  const LatLng(MapConfig.phMaxLat, MapConfig.phMaxLng),
                ),
              ),
              onPositionChanged: _scheduleClusterRefresh,
              onTap: (_, point) => _handleMapTap(point),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              buildBaseTileLayer(),

              if (_focusedShape != null)
                PolygonLayer(polygons: [
                  // Dim everything outside the focused area.
                  Polygon(
                    points: const [
                      LatLng(MapConfig.phMinLat - 5, MapConfig.phMinLng - 5),
                      LatLng(MapConfig.phMinLat - 5, MapConfig.phMaxLng + 5),
                      LatLng(MapConfig.phMaxLat + 5, MapConfig.phMaxLng + 5),
                      LatLng(MapConfig.phMaxLat + 5, MapConfig.phMinLng - 5),
                    ],
                    holePointsList: [
                      for (final p in _focusedShape!.polygons) p.outer,
                    ],
                    color: Colors.black.withValues(alpha: 0.28),
                  ),
                  for (final p in _focusedShape!.polygons)
                    Polygon(
                      points: p.outer,
                      holePointsList: p.holes,
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2.5,
                    ),
                ]),

              MarkerLayer(markers: [
                for (final a in _areas)
                  if (_visibleLabelIds.contains(a.id) &&
                      a.id != _focusedArea?.id)
                    Marker(
                      point: a.label,
                      width: areaLabelSize(a.name,
                              province: a.level == 'province')
                          .width,
                      height: 26,
                      alignment: Alignment.center,
                      child: _AreaLabel(
                        area: a,
                        onTap: () => _focusArea(a),
                      ),
                    ),
              ]),

              MarkerLayer(markers: markers),

              // OSM policy compliance: keep visible attribution on the canvas.
              RichAttributionWidget(
                showFlutterMapAttribution: false,
                alignment: AttributionAlignment.bottomRight,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () async {
                      try {
                        await launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        // Attribution link is best-effort; the text itself stays visible.
                      }
                    },
                  ),
                ],
              ),
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _openPlacesList,
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'List ☰',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.woodBrown,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => context.push('/search'),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Search →',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                // Pin a New Destination (map-first posting entry)
                FloatingActionButton.small(
                  heroTag: 'pin_destination_map',
                  backgroundColor: _pinPlacementActive ? AppColors.sunGold : Colors.white,
                  foregroundColor: _pinPlacementActive ? AppColors.woodBrown : AppColors.primary,
                  onPressed: () {
                    if (_pinPlacementActive) {
                      _cancelPinPlacement();
                    } else {
                      _startPinPlacement();
                    }
                  },
                  tooltip: _pinPlacementActive ? 'Cancel Pin Placement' : 'Pin a New Destination',
                  child: const Icon(Icons.add_location_alt_rounded, size: 18),
                ),
                const SizedBox(height: 8),
                // Use My Location (explicit action; no background tracking)
                FloatingActionButton.small(
                  heroTag: 'locate_me_map',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                  onPressed: _locating ? null : _useMyLocation,
                  tooltip: 'Use My Location',
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                ),
                const SizedBox(height: 8),
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

          // 4. Armed pin placement banner
          if (_pinPlacementActive)
            Positioned(
              top: 110,
              left: 12,
              right: 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.sunGold.withOpacity(0.95),
                  borderRadius: AppSpacing.roundedLg,
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 16, color: AppColors.woodBrown),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _pendingDraft != null
                            ? 'Tap the map to move the destination pin.'
                            : 'Tap the map to place your destination pin.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.woodBrown,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelPinPlacement,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Focused area banner: name, what's inside, and a way out.
          if (_focusedArea != null &&
              _selectedQuest == null &&
              _selectedSpot == null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: _AreaBanner(
                area: _focusedArea!,
                places: visibleQuests.length + visibleSpots.length,
                onClear: _clearArea,
                onList: _openPlacesList,
              ),
            ),

          // 5. Bottom-Left Floating Marker Inspector Overlay Card (Web Parity)
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
    final location = isQuest
        ? _selectedQuest!.locationName
        : (_selectedSpot!.address.trim().isNotEmpty
            ? _selectedSpot!.address
            : _selectedSpot!.municipality);
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

          // Place description without exposing raw coordinates.
          Text(
            location,
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

          // Trail preview: honest in-development card for destination spots only.
          if (!isQuest) ...[
            const SizedBox(height: 10),
            TrailPreviewCard(key: ValueKey(_selectedSpot!.id)),
          ],

          // Attribution stays visible even while this card covers the map corner.
          const SizedBox(height: 6),
          const Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Tappable town/province name on the map (no counts, as on the web).
class _AreaLabel extends StatelessWidget {
  final AdminArea area;
  final VoidCallback onTap;

  const _AreaLabel({required this.area, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final province = area.level == 'province';
    return Semantics(
      button: true,
      label: 'Show ${area.name}',
      child: GestureDetector(
        key: ValueKey('area_label_${area.id}'),
        onTap: onTap,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.woodBrown.withValues(alpha: 0.25)),
            ),
            child: Text(
              area.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: province ? 13 : 11,
                fontWeight: province ? FontWeight.w900 : FontWeight.w700,
                color: AppColors.woodBrown,
                letterSpacing: province ? 0.6 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaBanner extends StatelessWidget {
  final AdminArea area;
  final int places;
  final VoidCallback onClear;
  final VoidCallback onList;

  const _AreaBanner({
    required this.area,
    required this.places,
    required this.onClear,
    required this.onList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('area_banner'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(area.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge
                        .copyWith(fontWeight: FontWeight.w800)),
                Text(
                  '${area.levelLabel} · $places ${places == 1 ? 'place' : 'places'} on the map',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'List places',
            onPressed: onList,
            icon: const Icon(Icons.list_rounded, color: AppColors.primary),
          ),
          IconButton(
            key: const ValueKey('area_clear'),
            tooltip: 'Show all areas',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
