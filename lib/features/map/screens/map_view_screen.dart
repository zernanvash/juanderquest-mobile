import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/map_config.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/utils/spot_location_handoff.dart';
import '../../spots/utils/spot_posting.dart';
import '../../spots/widgets/pin_aim_card.dart';
import '../engine/jdq_map.dart';
import '../engine/jdq_map_canvas.dart';
import '../engine/maplibre_jdq_map.dart';
import '../pixel/map_marker_art.dart';
import '../utils/admin_areas.dart';
import '../utils/map_cluster.dart';
import '../utils/map_focus.dart';
import '../widgets/map_cluster_list_sheet.dart';
import '../widgets/map_orientation_button.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key, this.initialQuestId, this.initialSpotId});

  final String? initialQuestId;
  final String? initialSpotId;

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  final MapController _mapController = MapController();
  late final JdqMap _nativeMap;
  late final Future<String> _style;
  bool _basicMap = false;
  bool _fellBack = false;
  String _pinSignature = '';
  bool _deepLinkHandled = false;

  bool get _native => !_basicMap;

  @override
  void initState() {
    super.initState();
    _nativeMap = ref.read(jdqMapFactoryProvider)();
    _basicMap = _nativeMap is MapLibreJdqMap &&
        (kIsWeb ||
            ![
              TargetPlatform.android,
              TargetPlatform.iOS,
            ].contains(defaultTargetPlatform));
    _style = _native ? ref.read(mapStyleProvider.future) : Future.value('');
    unawaited(
      _nativeMap.setSatellite(
        MapConfig.satelliteAvailable() && ref.read(satelliteModeProvider),
      ),
    );
    _nativeMap.onTapEmpty = _handleMapTap;
    _nativeMap.onTapPlace = (id) {
      for (final area in _areas) {
        if (area.id == id) {
          unawaited(_focusArea(area));
          break;
        }
      }
    };
    _nativeMap.onCameraIdle = () {
      _scheduleAreaRefresh();
      _updateAimCenter();
      _rememberCenter();
      if (mounted) setState(() => _clusterZoom = _nativeMap.camera.zoom);
    };

    _initSelection();
    _checkPassiveLocation();
  }

  Future<void> _checkPassiveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && mounted) {
          setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
          if (_native) _nativeMap.setMyLocation(true);
        }
      }
    } catch (_) {}
  }

  JdqCamera get _camera {
    if (_native) return _nativeMap.camera;
    final c = _mapController.camera;
    return JdqCamera(
      center: c.center,
      zoom: c.zoom,
      size: c.size,
      southWest: c.visibleBounds.southWest,
      northEast: c.visibleBounds.northEast,
    );
  }

  void _move(LatLng point, double zoom) {
    if (_native) {
      unawaited(
        _nativeMap.easeTo(
          point,
          zoom,
          reducedMotion: MediaQuery.disableAnimationsOf(context),
        ),
      );
    } else {
      _mapController.move(point, zoom);
    }
  }

  void _fit(LatLngBounds bounds, EdgeInsets padding, {double? maxZoom}) {
    if (_native) {
      unawaited(
        _nativeMap.fitBounds(bounds.southWest, bounds.northEast, padding),
      );
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: padding,
          maxZoom: maxZoom ?? double.infinity,
        ),
      );
    }
  }

  Widget _canvas(Widget raster, {bool satellite = false}) {
    if (_basicMap && !_fellBack) return raster;
    return JdqMapCanvas(
      map: _nativeMap,
      style: _style,
      fallback: raster,
      extraAttribution: satellite ? MapConfig.satelliteAttribution : null,
      onFallback: () {
        if (mounted) {
          setState(() {
            _basicMap = true;
            _fellBack = true;
          });
        }
      },
    );
  }

  QuestModel? _selectedQuest;
  SpotModel? _selectedSpot;
  static const double kQuestPinsMinZoom = 9.5;
  static const double kSpotPinsMinZoom = 11.0;
  bool _isRefreshing = false;
  bool _locating = false;
  LatLng? _userLocation;
  bool _pinPlacementActive = false;
  Timer? _centerTimer;
  LatLng? _aimCenter;
  Timer? _clusterRefreshTimer;
  DateTime _lastClusterRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  double? _pendingClusterZoom;
  double _clusterZoom = MapConfig.defaultZoom;

  late final AdminAreaApi _areaApi = AdminAreaApi(
    ref.read(apiClientProvider).dio,
  );
  List<AdminArea> _areas = const [];
  bool _resolvingArea = false;
  AdminArea? _focusedArea;
  AreaShape? _focusedShape;
  LatLng? _preFocusCenter;
  double? _preFocusZoom;
  Timer? _areaRefreshTimer;
  int _areaRequest = 0;

  @override
  void dispose() {
    _nativeMap.dispose();
    _clusterRefreshTimer?.cancel();
    _areaRefreshTimer?.cancel();
    _aimTimer?.cancel();
    _centerTimer?.cancel();
    super.dispose();
  }

  void _scheduleAreaRefresh() {
    _areaRefreshTimer?.cancel();
    _areaRefreshTimer = Timer(const Duration(milliseconds: 450), _refreshAreas);
  }

  Future<void> _refreshAreas() async {
    if (!mounted) return;
    final JdqCamera camera;
    try {
      camera = _camera;
    } catch (_) {
      return; // Map not laid out yet.
    }
    final request = ++_areaRequest;
    try {
      final areas = await _areaApi.visible(
        minLat: camera.southWest.latitude,
        minLng: camera.southWest.longitude,
        maxLat: camera.northEast.latitude,
        maxLng: camera.northEast.longitude,
        zoom: camera.zoom,
      );
      if (!mounted || request != _areaRequest) return;
      setState(() => _areas = areas);
      if (_native) await _nativeMap.setPlaces(areas);
    } catch (_) {
      // Names are an enhancement; the map works without them.
    }
  }

  Future<AdminArea?> _areaAt(LatLng point) async {
    final zoom = _camera.zoom;
    final levels = _focusedArea != null && _focusedArea!.level != 'province'
        ? const {'barangay'}
        : _focusedArea?.level == 'province' || zoom >= 9
            ? const {'city', 'municipality', 'town'}
            : const {'province'};
    final candidates = _areas
        .where(
          (a) =>
              levels.contains(a.level) &&
              a.id != _focusedArea?.id &&
              areaBboxContains(a.bbox, point.latitude, point.longitude),
        )
        .toList()
      ..sort(
        (a, b) => areaBboxSize(a.bbox).compareTo(areaBboxSize(b.bbox)),
      );
    for (final a in candidates.take(6)) {
      try {
        final shape = await _areaApi.shape(a.id);
        if (shape != null && shape.contains(point.latitude, point.longitude)) {
          return a;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }
    return null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The boundary of ${area.name} is not available yet.'),
        ),
      );
      return;
    }
    final camera = _camera;
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
    if (_native) await _nativeMap.setFocusArea(shape);
    _fit(
      LatLngBounds.fromPoints(shape.outlinePoints),
      const EdgeInsets.fromLTRB(32, 140, 32, 120),
    );
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
    if (_native) unawaited(_nativeMap.clearFocus());
    if (center != null && zoom != null) _move(center, zoom);
  }

  bool _inFocusedArea(double lat, double lng) =>
      _focusedShape?.contains(lat, lng) ?? true;

  void _rememberCenter() {
    _centerTimer?.cancel();
    _centerTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final camera = _camera;
      ref.read(lastMapCenterProvider.notifier).state = StudioPin(
        camera.center.latitude,
        camera.center.longitude,
        camera.zoom,
      );
    });
  }

  void _scheduleClusterRefresh(MapCamera camera, bool hasGesture) {
    _scheduleAreaRefresh();
    _rememberCenter();
    if (_pinPlacementActive) {
      _aimTimer ??= Timer(const Duration(milliseconds: 120), () {
        _aimTimer = null;
        _updateAimCenter();
      });
    }
    _pendingClusterZoom = camera.zoom;
    final now = DateTime.now();
    final remaining =
        const Duration(milliseconds: 150) - now.difference(_lastClusterRefresh);
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
        items.add(
          MapClusterListItem(
            id: id,
            title: quest.title,
            subtitle: quest.locationName,
            icon: Icons.explore_rounded,
          ),
        );
        continue;
      }
      final spot = spotsByPointId[id];
      if (spot != null) {
        items.add(
          MapClusterListItem(
            id: id,
            title: spot.name,
            subtitle: spot.address.trim().isNotEmpty
                ? spot.address
                : spot.municipality,
            icon: Icons.place_rounded,
          ),
        );
      }
    }

    final selectedPointId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MapClusterListSheet(
        items: items,
        onSelect: (id) => Navigator.of(sheetContext).pop(id),
      ),
    );
    if (!mounted || selectedPointId == null) return;

    final quest = questsByPointId[selectedPointId];
    if (quest != null) {
      setState(() {
        _selectedQuest = quest;
        _selectedSpot = null;
      });
      _focusPlace(quest.gpsLat, quest.gpsLng, 13.0);
      return;
    }
    final spot = spotsByPointId[selectedPointId];
    if (spot != null) {
      setState(() {
        _selectedSpot = spot;
        _selectedQuest = null;
      });
      _focusPlace(spot.gpsLat, spot.gpsLng, 13.0);
    }
  }

  Timer? _aimTimer;

  void _updateAimCenter() {
    if (!_pinPlacementActive || !mounted) return;
    final center = _camera.center;
    if (_aimCenter == center) return;
    setState(() => _aimCenter = center);
  }

  void _initSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAreas();
      _handleDeepLink();
    });
  }

  void _handleDeepLink() {
    String? questId = widget.initialQuestId;
    String? spotId = widget.initialSpotId;
    try {
      final query = GoRouterState.of(context).uri.queryParameters;
      if (query['post'] == '1') _startPinPlacement();
      questId ??= query['quest'];
      spotId ??= query['spot'];
    } catch (_) {
      // Not under a GoRouter (tests).
    }

    if (questId != null && questId.isNotEmpty) {
      final quests = ref.read(questProvider).quests;
      final match = quests.where((q) => q.id == questId).firstOrNull;
      if (match != null) {
        _deepLinkHandled = true;
        setState(() {
          _selectedQuest = match;
          _selectedSpot = null;
        });
        _focusPlace(match.gpsLat, match.gpsLng, 16.0);
        return;
      }
    }

    if (spotId != null && spotId.isNotEmpty) {
      final spots = ref.read(spotDiscoveryProvider).spots;
      final match = spots.where((s) => s.id == spotId).firstOrNull;
      if (match != null) {
        _deepLinkHandled = true;
        setState(() {
          _selectedSpot = match;
          _selectedQuest = null;
        });
        _focusPlace(match.gpsLat, match.gpsLng, 16.0);
        return;
      }
    }
  }

  void _fitAllBounds() {
    final showTest = ref.read(showTestContentProvider);
    final quests = withoutTestContent(
      ref.read(questProvider).quests,
      (q) => q.isTest,
      showTest: showTest,
    );
    final spots = withoutTestContent(
      ref.read(spotDiscoveryProvider).spots,
      (s) => s.isTest,
      showTest: showTest,
    );

    final points = <LatLng>[
      for (final q in quests) LatLng(q.gpsLat, q.gpsLng),
      for (final s in spots) LatLng(s.gpsLat, s.gpsLng),
    ];

    if (points.isEmpty) {
      _move(
        const LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng),
        MapConfig.defaultZoom,
      );
      return;
    }

    if (points.length == 1) {
      _move(points.first, 13.0);
      return;
    }

    _fit(LatLngBounds.fromPoints(points), const EdgeInsets.all(50));
  }

  void _focusPlace(double lat, double lng, double fallbackZoom) {
    final camera = _camera;
    final zoom = camera.zoom < fallbackZoom ? fallbackZoom : camera.zoom;
    final target = focusTargetAboveCard(
      lat: lat,
      lng: lng,
      zoom: zoom,
      mapHeightPx: camera.size.height,
    );
    _move(target, zoom);
  }

  void _startPinPlacement() {
    setState(() {
      _pinPlacementActive = true;
      _selectedQuest = null;
      _selectedSpot = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAimCenter());
  }

  void _cancelPinPlacement() {
    setState(() => _pinPlacementActive = false);
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (!_pinPlacementActive) {
      final shape = _focusedShape;
      if (shape != null && !shape.contains(point.latitude, point.longitude)) {
        _clearArea();
        return;
      }
      if (_resolvingArea) return;
      _resolvingArea = true;
      try {
        final area = await _areaAt(point);
        if (area != null && mounted) await _focusArea(area);
      } finally {
        _resolvingArea = false;
      }
      return;
    }
    _move(point, math.max(_camera.zoom, 16));
  }

  Future<void> _continueWithPlace(
    double lat,
    double lng,
    SpotRecognitionResult? recognition,
  ) async {
    setState(() => _pinPlacementActive = false);
    final zoom = math.max(_camera.zoom, 15).round();
    ref.read(lastMapCenterProvider.notifier).state = StudioPin(
      lat,
      lng,
      zoom.toDouble(),
    );
    final result = await context.push<Object?>(
      '/map/add-spot?lat=${lat.toStringAsFixed(6)}&lng=${lng.toStringAsFixed(6)}&zoom=$zoom',
      extra: recognition,
    );
    if (!mounted || result is! SpotModel) return;
    setState(() {
      _selectedSpot = result;
      _selectedQuest = null;
    });
    ref.invalidate(spotDiscoveryProvider);
    _focusPlace(result.gpsLat, result.gpsLng, 14.0);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are turned off. Turn them on, or search and pan the map instead.',
            ),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission was denied. Search or pan the map instead.',
            ),
          ),
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
      final camera = _camera;
      if (_native) _nativeMap.setMyLocation(true);
      _move(
        location,
        _pinPlacementActive
            ? math.max(camera.zoom, 17)
            : (camera.zoom < 14 ? 14.0 : camera.zoom),
      );
      if (position.accuracy > 2000) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Approximate location shown (±${position.accuracy.round()} m). Move to an open area for a better fix.',
            ),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Finding your location timed out or failed. Try again, or search and pan the map instead.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
    ref.listen(questProvider, (_, __) {
      if (!_deepLinkHandled) _handleDeepLink();
    });
    ref.listen(spotDiscoveryProvider, (_, __) {
      if (!_deepLinkHandled) _handleDeepLink();
    });

    final satellite = satelliteOn(ref);
    ref.listen<bool>(
      satelliteModeProvider,
      (_, on) => unawaited(
        _nativeMap.setSatellite(on && MapConfig.satelliteAvailable()),
      ),
    );

    final questState = ref.watch(questProvider);
    final spotState = ref.watch(spotDiscoveryProvider);
    final spotlight = ref.watch(choiceSpotlightProvider).valueOrNull;

    final showTest = ref.watch(showTestContentProvider);
    final quests = withoutTestContent(
      questState.quests,
      (q) => q.isTest,
      showTest: showTest,
    );
    final spots = withoutTestContent(
      spotState.spots,
      (s) => s.isTest,
      showTest: showTest,
    );
    final plannedSpots = planChoiceSpotlight(
      spots,
      (spot) => spot.id,
      spotlight,
    );

    final markers = <Marker>[];
    final currentZoom = _native ? _nativeMap.camera.zoom : _clusterZoom;
    final isTownFocused = _focusedArea != null;

    final List<QuestModel> visibleQuests;
    final List<SpotModel> visibleSpots;

    if (isTownFocused) {
      visibleQuests =
          quests.where((q) => _inFocusedArea(q.gpsLat, q.gpsLng)).toList();
      visibleSpots = <SpotModel>[
        ...plannedSpots.ordinary,
        ...plannedSpots.winners,
      ].where((s) => _inFocusedArea(s.gpsLat, s.gpsLng)).toList();
    } else if (currentZoom >= kSpotPinsMinZoom) {
      visibleQuests = quests;
      visibleSpots = <SpotModel>[
        ...plannedSpots.ordinary,
        ...plannedSpots.winners,
      ];
    } else if (currentZoom >= kQuestPinsMinZoom) {
      visibleQuests = quests;
      visibleSpots = const [];
    } else {
      visibleQuests = const [];
      visibleSpots = const [];
    }
    final questsByPointId = <String, QuestModel>{};
    final spotsByPointId = <String, SpotModel>{};
    final clusterInputs = <MapClusterPoint>[];

    for (final quest in visibleQuests) {
      final id = 'quest:${quest.id}';
      questsByPointId[id] = quest;
      clusterInputs.add(
        MapClusterPoint(
          id: id,
          kind: MapClusterPointKind.quest,
          lat: quest.gpsLat,
          lng: quest.gpsLng,
          pinned: _selectedQuest?.id == quest.id ||
              quest.funding?.status == 'active',
        ),
      );
    }
    for (final spot in visibleSpots) {
      final id = 'spot:${spot.id}';
      spotsByPointId[id] = spot;
      clusterInputs.add(
        MapClusterPoint(
          id: id,
          kind: MapClusterPointKind.spot,
          lat: spot.gpsLat,
          lng: spot.gpsLng,
          pinned: _selectedSpot?.id == spot.id || spot.saved,
        ),
      );
    }

    final clusterResults = clusterPoints(clusterInputs, _clusterZoom);
    for (final result in clusterResults) {
      if (result is MapCluster) {
        markers.add(
          Marker(
            point: LatLng(result.lat, result.lng),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: PixelClusterChip(
              count: result.count,
              hasQuest: result.hasQuest,
              onTap: () {
                if (result.hasNonZeroSpan) {
                  _fit(
                    LatLngBounds(
                      LatLng(result.minLat, result.minLng),
                      LatLng(result.maxLat, result.maxLng),
                    ),
                    const EdgeInsets.all(48),
                    maxZoom: math.min(_camera.zoom + 3, 16),
                  );
                } else {
                  _openIdenticalCluster(
                    result,
                    questsByPointId,
                    spotsByPointId,
                  );
                }
              },
            ),
          ),
        );
      } else if (result is MapPointResult) {
        final quest = questsByPointId[result.id];
        if (quest != null) {
          final isSelected = _selectedQuest?.id == quest.id;
          markers.add(
            Marker(
              point: LatLng(quest.gpsLat, quest.gpsLng),
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: PixelSelectedMarkerHopper(
                key: ValueKey('map_marker_${quest.id}'),
                selected: isSelected,
                child: Semantics(
                  button: true,
                  label: 'Quest: ${quest.title}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      pixelTick(context);
                      setState(() {
                        _selectedQuest = quest;
                        _selectedSpot = null;
                      });
                      _focusPlace(quest.gpsLat, quest.gpsLng, 14.0);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: const Center(
                        child: PixelSprite(DesignerArt.questMarker, scale: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          continue;
        }

        final spot = spotsByPointId[result.id];
        if (spot == null) continue;
        final isSelected = _selectedSpot?.id == spot.id;
        markers.add(
          Marker(
            point: LatLng(spot.gpsLat, spot.gpsLng),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: PixelSelectedMarkerHopper(
              key: ValueKey('map_marker_${spot.id}'),
              selected: isSelected,
              child: Semantics(
                button: true,
                label: 'Spot: ${spot.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    pixelTick(context);
                    setState(() {
                      _selectedSpot = spot;
                      _selectedQuest = null;
                    });
                    _focusPlace(spot.gpsLat, spot.gpsLng, 14.0);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: const Center(
                      child: PixelSprite(MapMarkerArt.spotPin, scale: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Semantics(
            label: 'Your current location',
            child: const PixelSprite(MapMarkerArt.youAreHere, scale: 2),
          ),
        ),
      );
    }

    if (_native) {
      final pins = <JdqPin>[
        for (final q in visibleQuests)
          JdqPin(
            'quest:${q.id}',
            LatLng(q.gpsLat, q.gpsLng),
            q.title,
            quest: true,
          ),
        for (final s in visibleSpots)
          JdqPin('spot:${s.id}', LatLng(s.gpsLat, s.gpsLng), s.name),
      ];
      _nativeMap.onTapPin = (id) {
        for (final q in visibleQuests) {
          if ('quest:${q.id}' == id) {
            setState(() {
              _selectedQuest = q;
              _selectedSpot = null;
            });
            _focusPlace(q.gpsLat, q.gpsLng, 14);
            return;
          }
        }
        for (final s in visibleSpots) {
          if ('spot:${s.id}' == id) {
            setState(() {
              _selectedSpot = s;
              _selectedQuest = null;
            });
            _focusPlace(s.gpsLat, s.gpsLng, 14);
            return;
          }
        }
      };
      final signature =
          pins.map((p) => '${p.id}:${p.point}:${p.label}').join('|');
      if (signature != _pinSignature) {
        _pinSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _native) unawaited(_nativeMap.setPins(pins));
        });
      }
    }

    final Widget tileLayer = buildBaseTileLayer(satellite: satellite);

    final rasterMap = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(
          MapConfig.pangasinanLat,
          MapConfig.pangasinanLng,
        ),
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
        tileLayer,
        if (_focusedShape != null)
          PolygonLayer(
            polygons: [
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
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          showFlutterMapAttribution: false,
          alignment: AttributionAlignment.bottomRight,
          attributions: [
            if (satellite)
              const TextSourceAttribution(MapConfig.satelliteAttribution),
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () async {
                try {
                  await launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
              },
            ),
          ],
        ),
      ],
    );

    return Theme(
      data: PixelTheme.build(),
      child: JdqScaffold(
        padding: EdgeInsets.zero,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: PixelAppBar(
            title: 'MAP',
            isTab: true,
            actions: [
              PixelIconButton(
                icon: DesignerArt.search,
                semanticLabel: 'Search Spots',
                style: PixelBoxStyle.parchment,
                onPressed: () => context.push('/search'),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            _canvas(rasterMap, satellite: satellite),

            // Top-Right Floating Map Tool Controls
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  // Orientation reset button
                  if (_native &&
                      mapNeedsOrientationReset(
                        _nativeMap.camera.bearing,
                        _nativeMap.camera.tilt,
                      )) ...[
                    MapOrientationButton(
                      bearing: _nativeMap.camera.bearing,
                      tilt: _nativeMap.camera.tilt,
                      onPressed: () => unawaited(_nativeMap.resetOrientation()),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Satellite toggle
                  if (MapConfig.satelliteAvailable()) ...[
                    Tooltip(
                      message: satellite ? 'Show map' : 'Show satellite',
                      child: PixelIconButton(
                        icon: MapMarkerArt.iconSatellite,
                        semanticLabel:
                            satellite ? 'Show map' : 'Show satellite',
                        style: satellite
                            ? PixelBoxStyle.gold
                            : PixelBoxStyle.parchment,
                        onPressed: () {
                          ref.read(satelliteModeProvider.notifier).state =
                              !satellite;
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Pin a New Destination
                  Tooltip(
                    message: _pinPlacementActive
                        ? 'Cancel Pin Placement'
                        : 'Pin a New Destination',
                    child: PixelIconButton(
                      icon: MapMarkerArt.iconAddPin,
                      semanticLabel: _pinPlacementActive
                          ? 'Cancel Pin Placement'
                          : 'Pin a New Destination',
                      style: _pinPlacementActive
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.parchment,
                      onPressed: () {
                        if (_pinPlacementActive) {
                          _cancelPinPlacement();
                        } else {
                          _startPinPlacement();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Use My Location
                  Tooltip(
                    message: 'Use My Location',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: _locating
                          ? const PixelPanel(
                              style: PixelBoxStyle.parchment,
                              padding: 2,
                              child: Center(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: PixelLoader(artPx: 4, label: ''),
                              ),
                            )
                          : PixelIconButton(
                              icon: MapMarkerArt.iconLocateMe,
                              semanticLabel: 'Use My Location',
                              style: PixelBoxStyle.parchment,
                              onPressed: _useMyLocation,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Fit All Bounds / Recenter
                  Tooltip(
                    message: 'Fit All Markers',
                    child: PixelIconButton(
                      icon: MapMarkerArt.iconFitBounds,
                      semanticLabel: 'Fit All Markers',
                      style: PixelBoxStyle.parchment,
                      onPressed: _fitAllBounds,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Reload Coordinates
                  Tooltip(
                    message: 'Reload Coordinates',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: _isRefreshing
                          ? const PixelPanel(
                              style: PixelBoxStyle.parchment,
                              padding: 2,
                              child: Center(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: PixelLoader(artPx: 4, label: ''),
                              ),
                            )
                          : PixelIconButton(
                              icon: MapMarkerArt.iconRefresh,
                              semanticLabel: 'Reload Coordinates',
                              style: PixelBoxStyle.parchment,
                              onPressed: _refreshData,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Pin crosshair reticle when placing a pin
            if (_pinPlacementActive)
              const Positioned.fill(child: PixelCrosshairReticle()),

            // Pin aim card
            if (_pinPlacementActive)
              Positioned(
                left: 12,
                right: 64,
                bottom: 28,
                child: PinAimCard(
                  lat: _aimCenter?.latitude,
                  lng: _aimCenter?.longitude,
                  locating: _locating,
                  onUseMyLocation: _useMyLocation,
                  onCancel: _cancelPinPlacement,
                  onContinue: _continueWithPlace,
                ),
              ),

            // Focused area banner
            if (_focusedArea != null &&
                _selectedQuest == null &&
                _selectedSpot == null)
              Positioned(
                bottom: 28,
                left: 12,
                right: 12,
                child: _AreaBanner(
                  area: _focusedArea!,
                  questsCount: visibleQuests.length,
                  spotsCount: visibleSpots.length,
                  onClear: _clearArea,
                  onPinSpot: _startPinPlacement,
                ),
              ),

            // Marker Inspector Overlay Card
            if (_selectedQuest != null || _selectedSpot != null)
              Positioned(
                bottom: 28,
                left: 12,
                right: 12,
                child: _buildMarkerInspectorCard(),
              ),
          ],
        ),
      ),
    );
  }

  String _cleanTitle(String rawTitle) {
    var t = rawTitle.trim();
    for (final prefix in const [
      'SIM · ', 'SIM: ', 'SIM - ', 'SIM ·', 'SIM:',
      'TEST · ', 'TEST: ', 'TEST - ', 'TEST ·', 'TEST:',
    ]) {
      if (t.toUpperCase().startsWith(prefix)) {
        return t.substring(prefix.length).trim();
      }
    }
    return t;
  }

  bool _isTestItem(String rawTitle, bool isTestFlag) {
    if (isTestFlag) return true;
    final upper = rawTitle.toUpperCase().trim();
    return upper.startsWith('SIM') || upper.startsWith('TEST');
  }

  String _questGameBadge(QuestModel quest) {
    for (final step in quest.steps) {
      final v = step.verification;
      if (v != null && v.containsKey('game')) {
        final game = v['game']?.toString().toLowerCase();
        switch (game) {
          case 'tumbang_preso':
            return '★ AR TUMBANG PRESO';
          case 'shooting_hoop':
            return '★ AR RING SHOOT';
          case 'pana':
            return '★ AR PANA';
          case 'pabitin_palayok':
            return '★ AR PALAYOK';
          case 'sipa':
            return '★ AR SIPA';
          case 'collect':
          default:
            return '★ AR RELIC';
        }
      }
    }
    for (final step in quest.steps) {
      if (step.checkpointType == 'ar') return '★ AR RELIC';
    }
    switch (quest.category.toLowerCase()) {
      case 'eco':
        return '★ ECO QUEST';
      case 'cultural':
      case 'heritage':
        return '★ HERITAGE QUEST';
      default:
        return '★ QUEST TRAIL';
    }
  }

  Widget _buildMarkerInspectorCard() {
    final grid = PixelGrid.of(context);
    final isQuest = _selectedQuest != null;
    final rawTitle = isQuest ? _selectedQuest!.title : _selectedSpot!.name;
    final cleanTitle = _cleanTitle(rawTitle);
    final isTest = _isTestItem(
      rawTitle,
      isQuest ? _selectedQuest!.isTest : _selectedSpot!.isTest,
    );

    final town = isQuest
        ? _selectedQuest!.locationName
        : (_selectedSpot!.address.trim().isNotEmpty
            ? _selectedSpot!.address
            : _selectedSpot!.municipality);
    final lat = isQuest ? _selectedQuest!.gpsLat : _selectedSpot!.gpsLat;
    final lng = isQuest ? _selectedQuest!.gpsLng : _selectedSpot!.gpsLng;

    String townAndDistance = town;
    double? distanceMeters;
    if (_userLocation != null) {
      distanceMeters = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        lat,
        lng,
      );
      final distanceStr = distanceMeters <= 100
          ? "You're right here! (≤100m)"
          : '${distanceMeters < 1000 ? '${distanceMeters.round()}m' : '${(distanceMeters / 1000).toStringAsFixed(1)}km'} away';
      townAndDistance = '$town · $distanceStr';
    }

    final modeBadge = isQuest
        ? _questGameBadge(_selectedQuest!)
        : (_selectedSpot!.category.trim().isNotEmpty
            ? _selectedSpot!.category.toUpperCase()
            : 'DESTINATION SPOT');
    final bountyOrStatus = isQuest
        ? '+${_selectedQuest!.rewardPoints} mJDQ'
        : (_selectedSpot!.questId != null ? '★ QUEST HERE' : null);

    final imageUrl =
        isQuest ? _selectedQuest!.markerImageUrl : _selectedSpot!.imageUrl;

    final String descriptionLine;
    if (isQuest) {
      if (_selectedQuest!.description.trim().isNotEmpty) {
        descriptionLine = _selectedQuest!.description.trim();
      } else {
        final count = _selectedQuest!.steps.length;
        descriptionLine =
            '⚑ $count ${count == 1 ? 'Task' : 'Tasks'} · Official Quest';
      }
    } else {
      if (_selectedSpot!.description.trim().isNotEmpty) {
        descriptionLine = _selectedSpot!.description.trim();
      } else if (_selectedSpot!.questId != null) {
        descriptionLine = '★ Active quest available here';
      } else {
        descriptionLine = _selectedSpot!.municipality;
      }
    }

    final radiusMeters = isQuest
        ? (_selectedQuest!.radiusMeters > 0
            ? _selectedQuest!.radiusMeters
            : 100)
        : 100;
    final isWithinRadius =
        isQuest && distanceMeters != null && distanceMeters <= radiusMeters;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(198.0, MediaQuery.sizeOf(context).height * 0.35),
      ),
      child: PixelPanel(
        key: const ValueKey('marker_inspector_card'),
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PixelPanel(
                  style: isQuest ? PixelBoxStyle.gold : PixelBoxStyle.green,
                  padding: 1,
                  child: Text(
                    modeBadge,
                    style: PixelType.small(
                      context,
                      color: isQuest ? PixelPalette.ink : PixelPalette.white,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (bountyOrStatus != null) ...[
                  SizedBox(width: grid.px(0.5)),
                  PixelPanel(
                    style: PixelBoxStyle.slot,
                    padding: 1,
                    child: Text(
                      bountyOrStatus,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.woodDeep,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                if (isTest) ...[
                  SizedBox(width: grid.px(0.5)),
                  PixelPanel(
                    style: PixelBoxStyle.slot,
                    padding: 1,
                    child: Text(
                      'TEST',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.amber,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const Spacer(),
                PixelIconButton(
                  icon: MapMarkerArt.iconClose,
                  semanticLabel: 'Close card',
                  style: PixelBoxStyle.parchment,
                  onPressed: () {
                    setState(() {
                      _selectedQuest = null;
                      _selectedSpot = null;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: grid.px(0.5)),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: PixelPanel(
                        style: PixelBoxStyle.slot,
                        padding: 0,
                        child: ClipRect(
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: PixelSprite(
                                      isQuest
                                          ? DesignerArt.questMarker
                                          : MapMarkerArt.spotPin,
                                      scale: 2,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: PixelSprite(
                                    isQuest
                                        ? DesignerArt.questMarker
                                        : MapMarkerArt.spotPin,
                                    scale: 2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cleanTitle,
                            style: PixelType.body(
                              context,
                              color: PixelPalette.ink,
                            ).copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: grid.px(0.25)),
                          Text(
                            townAndDistance,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.slate,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: grid.px(0.25)),
                          Text(
                            descriptionLine,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.woodDeep,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: grid.px(1)),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: isWithinRadius ? 'START QUEST' : 'ROUTE HERE',
                    variant: PixelButtonVariant.primary,
                    onPressed: () {
                      if (isWithinRadius && isQuest) {
                        context.push('/quests/${_selectedQuest!.id}');
                      } else {
                        _navigateTo(cleanTitle, town, lat, lng);
                      }
                    },
                  ),
                ),
                SizedBox(width: grid.px(1)),
                Expanded(
                  child: PixelButton(
                    label: isQuest ? 'VIEW DETAILS' : 'EXPLORE SPOT',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () {
                      if (isQuest) {
                        context.push('/quests/${_selectedQuest!.id}');
                      } else {
                        context.push(
                          '/explore/${_selectedSpot!.slug}',
                          extra: _selectedSpot,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaBanner extends StatelessWidget {
  final AdminArea area;
  final int questsCount;
  final int spotsCount;
  final VoidCallback onClear;
  final VoidCallback onPinSpot;

  const _AreaBanner({
    required this.area,
    required this.questsCount,
    required this.spotsCount,
    required this.onClear,
    required this.onPinSpot,
  });

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = questsCount + spotsCount;

    final String subtitle;
    if (total == 0) {
      subtitle = 'No spots pinned here yet — be the first Scout!';
    } else {
      final qPart = '$questsCount ${questsCount == 1 ? 'Quest' : 'Quests'}';
      final sPart = '$spotsCount ${spotsCount == 1 ? 'Spot' : 'Spots'}';
      subtitle = '$qPart · $sPart in this town';
    }

    return PixelPanel(
      key: const ValueKey('area_banner'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(
                    context,
                    color: PixelPalette.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          if (total == 0) ...[
            PixelButton(
              label: '+ PIN SPOT',
              variant: PixelButtonVariant.primary,
              onPressed: onPinSpot,
            ),
            SizedBox(width: grid.px(0.5)),
          ],
          PixelButton(
            label: 'ZOOM OUT',
            variant: PixelButtonVariant.secondary,
            onPressed: onClear,
          ),
          SizedBox(width: grid.px(0.5)),
          PixelIconButton(
            key: const ValueKey('area_clear'),
            icon: MapMarkerArt.iconClose,
            semanticLabel: 'Clear area focus',
            style: PixelBoxStyle.parchment,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
