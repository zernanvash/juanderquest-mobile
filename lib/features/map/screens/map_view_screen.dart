import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../onboarding/page_tutorials.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_theme.dart';
import '../../../core/widgets/satellite_toggle.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cultural_quizzes/providers/cultural_quiz_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../map_done_quests.dart';
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
import '../utils/map_focus.dart';
import '../utils/map_marker_hierarchy.dart';
import '../widgets/map_orientation_button.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key, this.initialQuestId, this.initialSpotId});

  final String? initialQuestId;
  final String? initialSpotId;

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen>
    with WidgetsBindingObserver {
  late final JdqMap _nativeMap;
  // Plan 91a: live quiz radar feed while the Map tab is on screen and the
  // app is in the foreground. Starts only after permission is already granted.
  StreamSubscription<Position>? _quizRadarGps;
  bool _quizRadarFeedWanted = false;
  bool _appResumed = true;
  late final Future<String> _style;
  String _pinSignature = '';
  // Owner 2026-11-18: done quests show greyed out; DONE hides them.
  bool _showDoneQuests = true;
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nativeMap = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    unawaited(
      _nativeMap.setSatellite(
        MapConfig.satelliteAvailable() && ref.read(satelliteModeProvider),
      ),
    );
    // Plan 100 WP-9: done quests need the traveler's submissions.
    Future.microtask(() {
      if (mounted) {
        unawaited(ref.read(submissionProvider.notifier).fetchSubmissions());
      }
    });
    _nativeMap.onTapEmpty = _handleMapTap;
    _nativeMap.onTapPlace = (id) {
      if (_focusedArea?.id == id) return;
      for (final area in _areas) {
        if (area.id == id) {
          unawaited(_focusArea(area));
          break;
        }
      }
    };
    _nativeMap.onCameraIdle = () {
      _scheduleAreaRefresh();
      _scheduleMapSpotsRefresh();
      _updateAimCenter();
      _rememberCenter();
      if (mounted) setState(() {});
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
          _nativeMap.setMyLocation(true);
          unawaited(
            ref.read(quizRadarProvider.notifier).checkWithLocation(
                  lat: pos.latitude,
                  lng: pos.longitude,
                  origin: 'gps',
                ),
          );
          _quizRadarFeedWanted = true;
          _syncQuizRadarFeed();
        }
      }
    } catch (_) {}
  }

  JdqCamera get _camera => _nativeMap.camera;

  void _move(LatLng point, double zoom) {
    unawaited(
      _nativeMap.easeTo(
        point,
        zoom,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  void _fit(List<LatLng> points, EdgeInsets padding) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    unawaited(
      _nativeMap.fitBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
        padding,
      ),
    );
  }

  Widget _canvas({bool satellite = false}) {
    return JdqMapCanvas(
      map: _nativeMap,
      style: _style,
      fallback: const ColoredBox(color: PixelPalette.paperDim),
      extraAttribution: satellite ? MapConfig.satelliteAttribution : null,
      onFallback: () {},
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
  CancelToken? _mapSpotsCancelToken;
  int _mapSpotsRequest = 0;
  List<SpotMapMarker> _mapMarkers = const [];
  List<SpotMapCluster> _mapClusters = const [];
  bool _hasViewportMapData = false;
  final Map<String, SpotModel> _spotDetailCache = {};

  late final AdminAreaApi _areaApi = AdminAreaApi(
    ref.read(apiClientProvider).dio,
  );
  List<AdminArea> _areas = const [];
  AdminArea? _focusedArea;
  AreaShape? _focusedShape;
  LatLng? _preFocusCenter;
  double? _preFocusZoom;
  Timer? _areaRefreshTimer;
  int _areaRequest = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncQuizRadarFeed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncQuizRadarFeed();
  }

  void _syncQuizRadarFeed() {
    final visible = mounted && TickerMode.of(context);
    if (_quizRadarFeedWanted && visible && _appResumed) {
      _quizRadarGps ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen(
        (pos) => unawaited(
          ref.read(quizRadarProvider.notifier).checkWithLocation(
                lat: pos.latitude,
                lng: pos.longitude,
                origin: 'gps',
              ),
        ),
        onError: (_) {},
      );
    } else {
      _quizRadarGps?.cancel();
      _quizRadarGps = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quizRadarGps?.cancel();
    _nativeMap.dispose();
    _clusterRefreshTimer?.cancel();
    _mapSpotsCancelToken?.cancel('disposed');
    _areaRefreshTimer?.cancel();
    _aimTimer?.cancel();
    _centerTimer?.cancel();
    super.dispose();
  }

  void _scheduleMapSpotsRefresh() {
    _clusterRefreshTimer?.cancel();
    _mapSpotsCancelToken?.cancel('camera_moved');
    _clusterRefreshTimer = Timer(
      const Duration(milliseconds: 300),
      _refreshMapSpots,
    );
  }

  Future<void> _refreshMapSpots() async {
    if (!mounted) return;
    final JdqCamera camera;
    try {
      camera = _camera;
    } catch (_) {
      return;
    }
    var west = camera.southWest.longitude.clamp(-180.0, 180.0).toDouble();
    var south = camera.southWest.latitude.clamp(-90.0, 90.0).toDouble();
    var east = camera.northEast.longitude.clamp(-180.0, 180.0).toDouble();
    var north = camera.northEast.latitude.clamp(-90.0, 90.0).toDouble();
    if (west >= east) {
      west = (camera.center.longitude - 0.05).clamp(-180.0, 179.9).toDouble();
      east = (camera.center.longitude + 0.05).clamp(-179.9, 180.0).toDouble();
    }
    if (south >= north) {
      south = (camera.center.latitude - 0.05).clamp(-90.0, 89.9).toDouble();
      north = (camera.center.latitude + 0.05).clamp(-89.9, 90.0).toDouble();
    }
    final request = ++_mapSpotsRequest;
    _mapSpotsCancelToken?.cancel('superseded');
    final token = CancelToken();
    _mapSpotsCancelToken = token;
    try {
      final response = await ref.read(apiClientProvider).dio.get(
            '/spots/map',
            queryParameters: <String, dynamic>{
              'bbox':
                  '${west.toStringAsFixed(5)},${south.toStringAsFixed(5)},${east.toStringAsFixed(5)},${north.toStringAsFixed(5)}',
              'zoom': camera.zoom.floor().clamp(0, 22),
            },
            cancelToken: token,
          );
      if (!mounted || token.isCancelled || request != _mapSpotsRequest) return;
      final body = response.data;
      if (body is! Map || body['data'] is! Map) return;
      final parsed = SpotMapViewResponse.fromEnvelope(
        Map<String, dynamic>.from(body),
      );
      setState(() {
        _mapMarkers = parsed.markers;
        _mapClusters = parsed.clusters;
        _hasViewportMapData = true;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
    } catch (_) {
      // Preserve currently visible map pins on transient failures.
    } finally {
      if (identical(_mapSpotsCancelToken, token)) {
        _mapSpotsCancelToken = null;
      }
    }
  }

  Future<void> _hydrateMarkerSpot(SpotMapMarker marker) async {
    final cached = _spotDetailCache[marker.id];
    if (cached != null && cached.municipality.isNotEmpty) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/spots/${Uri.encodeComponent(marker.slug)}');
      final raw = response.data is Map ? response.data['data'] : null;
      if (raw is! Map) return;
      final full = SpotModel.fromJson(Map<String, dynamic>.from(raw));
      _spotDetailCache[full.id] = full;
      if (!mounted || _selectedSpot?.id != marker.id) return;
      setState(() => _selectedSpot = full);
    } catch (_) {}
  }

  void _zoomToCluster(SpotMapCluster cluster) {
    setState(() {
      _selectedSpot = null;
      _selectedQuest = null;
    });
    if (cluster.bbox.length == 4) {
      final west = cluster.bbox[0];
      final south = cluster.bbox[1];
      final east = cluster.bbox[2];
      final north = cluster.bbox[3];
      if ((east - west).abs() >= 0.0005 || (north - south).abs() >= 0.0005) {
        final minLat = math.min(south, north);
        final maxLat = math.max(south, north);
        final minLng = math.min(west, east);
        final maxLng = math.max(west, east);
        final padLat = (maxLat - minLat) < 0.0005 ? 0.002 : 0.0;
        final padLng = (maxLng - minLng) < 0.0005 ? 0.002 : 0.0;
        unawaited(
          _nativeMap.fitBounds(
            LatLng(minLat - padLat, minLng - padLng),
            LatLng(maxLat + padLat, maxLng + padLng),
            const EdgeInsets.all(48),
          ),
        );
        return;
      }
    }
    _move(LatLng(cluster.lat, cluster.lng), math.max(_camera.zoom + 2.0, 13.5));
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
      await _nativeMap.setPlaces(areas);
    } catch (_) {
      // Names are an enhancement; the map works without them.
    }
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
      showPixelToast(
        context,
        'The boundary of ${area.name} is not available yet.',
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
    await _nativeMap.setFocusArea(shape);
    _fit(shape.outlinePoints, const EdgeInsets.fromLTRB(32, 140, 32, 120));
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
    unawaited(_nativeMap.clearFocus());
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
      _refreshMapSpots();
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
      final cachedMatch = _spotDetailCache[spotId] ??
          ref
              .read(spotDiscoveryProvider)
              .spots
              .where((s) => s.id == spotId || s.slug == spotId)
              .firstOrNull;
      if (cachedMatch != null) {
        _deepLinkHandled = true;
        setState(() {
          _selectedSpot = cachedMatch;
          _selectedQuest = null;
        });
        _focusPlace(cachedMatch.gpsLat, cachedMatch.gpsLng, 16.0);
        return;
      }
      final markerMatch = _mapMarkers
          .where((m) => m.id == spotId || m.slug == spotId)
          .firstOrNull;
      if (markerMatch != null) {
        _deepLinkHandled = true;
        setState(() {
          _selectedSpot = markerMatch.toSpotModel();
          _selectedQuest = null;
        });
        _focusPlace(markerMatch.lat, markerMatch.lng, 16.0);
        unawaited(_hydrateMarkerSpot(markerMatch));
        return;
      }
      _deepLinkHandled = true;
      unawaited(
        ref
            .read(apiClientProvider)
            .dio
            .get('/spots/${Uri.encodeComponent(spotId)}')
            .then((res) {
          final raw = res.data is Map ? res.data['data'] : null;
          if (!mounted || raw is! Map) return;
          final fetched = SpotModel.fromJson(
            Map<String, dynamic>.from(raw),
          );
          _spotDetailCache[fetched.id] = fetched;
          setState(() {
            _selectedSpot = fetched;
            _selectedQuest = null;
          });
          _focusPlace(fetched.gpsLat, fetched.gpsLng, 16.0);
        }).catchError((_) {}),
      );
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
      if (_hasViewportMapData) ...[
        for (final m in _mapMarkers) LatLng(m.lat, m.lng),
        for (final c in _mapClusters) LatLng(c.lat, c.lng),
      ] else
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

    _fit(points, const EdgeInsets.all(50));
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
    _spotDetailCache[result.id] = result;
    setState(() {
      _selectedSpot = result;
      _selectedQuest = null;
    });
    unawaited(_refreshMapSpots());
    _focusPlace(result.gpsLat, result.gpsLng, 14.0);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showPixelToastOn(
          messenger,
          'Location services are turned off. Turn them on, or search and pan the map instead.',
          duration: const Duration(seconds: 4),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showPixelToastOn(
          messenger,
          'Location permission was denied. Search or pan the map instead.',
          duration: const Duration(seconds: 4),
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
      unawaited(
        ref.read(quizRadarProvider.notifier).checkWithLocation(
              lat: position.latitude,
              lng: position.longitude,
              origin: 'gps',
            ),
      );
      _quizRadarFeedWanted = true;
      _syncQuizRadarFeed();
      final camera = _camera;
      _nativeMap.setMyLocation(true);
      _move(
        location,
        _pinPlacementActive
            ? math.max(camera.zoom, 17)
            : (camera.zoom < 14 ? 14.0 : camera.zoom),
      );
      if (position.accuracy > 2000) {
        showPixelToastOn(
          messenger,
          'Approximate location shown (±${position.accuracy.round()} m). Move to an open area for a better fix.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (_) {
      showPixelToastOn(
        messenger,
        'Finding your location timed out or failed. Try again, or search and pan the map instead.',
        duration: const Duration(seconds: 4),
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
        _refreshMapSpots(),
        ref.refresh(choiceSpotlightProvider.future),
        // Plan 100 WP-9: which quests are done (throttled by the provider).
        ref.read(submissionProvider.notifier).fetchSubmissions(),
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

    final currentZoom = _nativeMap.camera.zoom;
    final isTownFocused = _focusedArea != null;

    List<QuestModel> visibleQuests;
    List<SpotModel> visibleSpots = const [];
    List<SpotMapMarker> visibleMapMarkers = const [];
    List<SpotMapCluster> visibleMapClusters = const [];

    if (isTownFocused) {
      visibleQuests =
          quests.where((q) => _inFocusedArea(q.gpsLat, q.gpsLng)).toList();
      if (_hasViewportMapData) {
        visibleMapMarkers =
            _mapMarkers.where((m) => _inFocusedArea(m.lat, m.lng)).toList();
      } else {
        visibleSpots = <SpotModel>[
          ...plannedSpots.ordinary,
          ...plannedSpots.winners,
        ].where((s) => _inFocusedArea(s.gpsLat, s.gpsLng)).toList();
      }
    } else if (_hasViewportMapData) {
      visibleQuests =
          currentZoom >= kQuestPinsMinZoom ? quests : const <QuestModel>[];
      visibleMapMarkers = _mapMarkers;
      visibleMapClusters = _mapClusters;
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

    // Owner 2026-11-18: "Once a Quest is done, it should be grey out and
    // there should be an option to hide it" (replaces Plan 100's hide-by-default).
    final submissions = ref.watch(submissionProvider).submissions;
    final questDone = mapQuestDone(submissions);
    final completedQuestIds = <String>{
      for (final q in quests)
        if (questDone(q)) q.id,
    };
    final hasDoneQuests = visibleQuests.any(questDone) ||
        visibleMapMarkers.any(
          (m) =>
              m.markerKind == 'quest' &&
              m.activeQuestIds.isNotEmpty &&
              m.activeQuestIds.every(completedQuestIds.contains),
        );
    visibleQuests = mapVisibleQuests(
      visibleQuests,
      questDone,
      showDone: _showDoneQuests,
    );

    final pins = buildUnifiedMapPins(
      clusters: visibleMapClusters,
      viewportMarkers: visibleMapMarkers,
      fallbackSpots: visibleSpots,
      hasViewportMapData: _hasViewportMapData,
      visibleQuests: visibleQuests,
      completedQuestIds: completedQuestIds,
      showDoneQuests: _showDoneQuests,
    );
    _nativeMap.onTapPin = (id) {
      if (id.startsWith('cluster:')) {
        final idx = int.tryParse(id.substring('cluster:'.length));
        if (idx != null && idx >= 0 && idx < visibleMapClusters.length) {
          _zoomToCluster(visibleMapClusters[idx]);
          return;
        }
      }
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
      for (final m in visibleMapMarkers) {
        if ('spot:${m.id}' == id) {
          final resolved = _spotDetailCache[m.id] ?? m.toSpotModel();
          setState(() {
            _selectedSpot = resolved;
            _selectedQuest = null;
          });
          _focusPlace(m.lat, m.lng, 14);
          unawaited(_hydrateMarkerSpot(m));
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
    final signature = pins
        .map(
          (p) =>
              '${p.id}:${p.point}:${p.label}:${p.kindWire}:${p.done}:${p.clusterCount}',
        )
        .join('|');
    if (signature != _pinSignature) {
      _pinSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_nativeMap.setPins(pins));
      });
    }

    return Theme(
      data: PixelTheme.build(),
      child: PageTutorialHost(
        page: TutorialPage.map,
        suppressed: _pinPlacementActive,
        stepsBuilder: (ctx) => buildPageTutorialSteps(ctx, TutorialPage.map),
        child: JdqScaffold(
          padding: EdgeInsets.zero,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(PixelAppBar.heightOf(context)),
            child: PixelAppBar(
              title: 'MAP',
              isTab: true,
              actions: [
                const TutorialHelpButton(page: TutorialPage.map),
                const SizedBox(width: 8),
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
              _canvas(satellite: satellite),

              // Top posting banner
              if (_pinPlacementActive)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: PixelPanel(
                    key: const ValueKey('map_post_spot_banner'),
                    style: PixelBoxStyle.gold,
                    padding: 8,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PixelText(
                                'POST A DESTINATION SPOT',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.woodDeep,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PixelIconButton(
                          icon: MapMarkerArt.iconClose,
                          iconHeight: 24, // Plan 100 WP-8
                          semanticLabel: 'Cancel',
                          style: PixelBoxStyle.parchment,
                          onPressed: _cancelPinPlacement,
                        ),
                      ],
                    ),
                  ),
                ),

              // Owner 2026-11-17: no quiz prompt on the map; nearby quizzes
              // reach travelers as notifications and the in-app banner.

              // Top-Right Floating Map Tool Controls
              Positioned(
                top: _pinPlacementActive ? 84 : 12,
                right: 12,
                child: Column(
                  children: [
                    // Orientation reset button
                    if (mapNeedsOrientationReset(
                      _nativeMap.camera.bearing,
                      _nativeMap.camera.tilt,
                    )) ...[
                      MapOrientationButton(
                        bearing: _nativeMap.camera.bearing,
                        tilt: _nativeMap.camera.tilt,
                        onPressed: () =>
                            unawaited(_nativeMap.resetOrientation()),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Plan 100 WP-9: bring back finished quests as shadows.
                    if (hasDoneQuests) ...[
                      Tooltip(
                        message: _showDoneQuests
                            ? tr(
                                context,
                                en: 'Hide done quests',
                                tl: 'Itago ang tapos na quest',
                              )
                            : tr(
                                context,
                                en: 'Show done quests',
                                tl: 'Ipakita ang tapos na quest',
                              ),
                        child: Semantics(
                          button: true,
                          toggled: _showDoneQuests,
                          label: _showDoneQuests
                              ? tr(
                                  context,
                                  en: 'Hide done quests',
                                  tl: 'Itago ang tapos na quest',
                                )
                              : tr(
                                  context,
                                  en: 'Show done quests',
                                  tl: 'Ipakita ang tapos na quest',
                                ),
                          child: ExcludeSemantics(
                            child: PixelChip(
                              tr(context, en: 'DONE', tl: 'TAPOS'),
                              key: const ValueKey('map_show_done_quests'),
                              style: _showDoneQuests
                                  ? PixelBoxStyle.gold
                                  : PixelBoxStyle.parchment,
                              onTap: () => setState(
                                () => _showDoneQuests = !_showDoneQuests,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Satellite toggle
                    if (MapConfig.satelliteAvailable()) ...[
                      Tooltip(
                        message: satellite ? 'Show map' : 'Show satellite',
                        child: PixelIconButton(
                          icon: MapMarkerArt.iconSatellite,
                          iconHeight: 24, // Plan 100 WP-8
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
                                iconHeight: 24, // Plan 100 WP-8
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
                        iconHeight: 24, // Plan 100 WP-8
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
                                iconHeight: 24, // Plan 100 WP-8
                                semanticLabel: 'Reload Coordinates',
                                style: PixelBoxStyle.parchment,
                                onPressed: _refreshData,
                              ),
                      ),
                    ),
                    // Map Marker Legend (Plan 122a)
                    const SizedBox(height: 4),
                    Tooltip(
                      message: 'Map Legend',
                      child: PixelIconButton(
                        key: const ValueKey('map_legend_btn'),
                        icon: MapMarkerArt.localPartnerPin,
                        iconHeight: 24,
                        semanticLabel: 'Map Legend',
                        style: PixelBoxStyle.parchment,
                        onPressed: _showMapLegendSheet,
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
                  child: MapAreaBanner(
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

              // Standalone Bottom-Right Post Spot Button (Plan 82b)
              if (!_pinPlacementActive &&
                  _selectedQuest == null &&
                  _selectedSpot == null &&
                  _focusedArea == null)
                Positioned(
                  right: 12,
                  bottom: 28,
                  child: Semantics(
                    label: 'Post a destination spot',
                    button: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: PixelButton(
                        key: const ValueKey('map_post_spot_fab'),
                        label: MediaQuery.sizeOf(context).width >
                                MediaQuery.sizeOf(context).height
                            ? '+'
                            : '+ POST SPOT',
                        style: PixelBoxStyle.gold,
                        onPressed: _startPinPlacement,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanTitle(String rawTitle) {
    var t = rawTitle.trim();
    for (final prefix in const [
      'SIM · ',
      'SIM: ',
      'SIM - ',
      'SIM ·',
      'SIM:',
      'TEST · ',
      'TEST: ',
      'TEST - ',
      'TEST ·',
      'TEST:',
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

    final localPartner = isQuest ? null : _selectedSpot!.localPartner;
    final spotActiveQuestId = !isQuest
        ? (_selectedSpot!.activeQuestIds.isNotEmpty
            ? _selectedSpot!.activeQuestIds.first
            : _selectedSpot!.questId)
        : null;
    final modeBadge = isQuest
        ? _questGameBadge(_selectedQuest!)
        : (_selectedSpot!.category.trim().isNotEmpty
            ? _selectedSpot!.category.toUpperCase()
            : 'DESTINATION SPOT');
    final bountyOrStatus = isQuest
        ? '+${_selectedQuest!.rewardPoints} mJDQ'
        : (spotActiveQuestId != null ? '★ QUEST HERE' : null);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PixelPanel(
                        style:
                            isQuest ? PixelBoxStyle.gold : PixelBoxStyle.green,
                        padding: 1,
                        child: Text(
                          modeBadge,
                          style: PixelType.small(
                            context,
                            color:
                                isQuest ? PixelPalette.ink : PixelPalette.white,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (localPartner != null)
                        PixelPanel(
                          key: const ValueKey('inspector_local_partner_badge'),
                          style: PixelBoxStyle.gold,
                          padding: 1,
                          child: Text(
                            'LOCAL PARTNER',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.ink,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (isQuest)
                        PixelPanel(
                          style: PixelBoxStyle.slot,
                          padding: 1,
                          child: MjdqAmount(
                            _selectedQuest!.rewardPoints,
                            sign: true,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.woodDeep,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        )
                      else if (bountyOrStatus != null)
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
                      if (isTest)
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
                  ),
                ),
                SizedBox(width: grid.px(0.5)),
                PixelIconButton(
                  icon: MapMarkerArt.iconClose,
                  iconHeight: 24, // Plan 100 WP-8
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
                                    child: isQuest
                                        ? const PixelSprite(
                                            DesignerArt.questMarker,
                                            scale: 2,
                                          )
                                        : const SizedBox.square(
                                            dimension: 32,
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: PixelSprite(
                                                DesignerArt.spotMarker,
                                                scale: 1,
                                              ),
                                            ),
                                          ),
                                  ),
                                )
                              : Center(
                                  child: isQuest
                                      ? const PixelSprite(
                                          DesignerArt.questMarker,
                                          scale: 2,
                                        )
                                      : const SizedBox.square(
                                          dimension: 32,
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: PixelSprite(
                                              DesignerArt.spotMarker,
                                              scale: 1,
                                            ),
                                          ),
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
            if (localPartner != null || spotActiveQuestId != null) ...[
              SizedBox(height: grid.px(0.75)),
              Row(
                children: [
                  if (spotActiveQuestId != null)
                    Expanded(
                      child: PixelButton(
                        key: const ValueKey('inspector_open_quest_btn'),
                        label: 'OPEN QUEST',
                        style: PixelBoxStyle.gold,
                        onPressed: () =>
                            context.push('/quests/$spotActiveQuestId'),
                      ),
                    ),
                  if (spotActiveQuestId != null && localPartner != null)
                    SizedBox(width: grid.px(1)),
                  if (localPartner != null)
                    Expanded(
                      child: PixelButton(
                        key: const ValueKey('inspector_view_partner_btn'),
                        label: 'VIEW PARTNER',
                        variant: PixelButtonVariant.secondary,
                        onPressed: () => context.push(
                          '/merchants/${localPartner.merchantId}',
                        ),
                      ),
                    ),
                ],
              ),
            ],
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

  void _showMapLegendSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: PixelPanel(
          key: const ValueKey('map_legend_sheet'),
          style: PixelBoxStyle.parchment,
          padding: 3,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MAP PIN LEGEND',
                  style: PixelType.body(
                    ctx,
                    color: PixelPalette.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _legendRow(
                  ctx,
                  const PixelSprite(DesignerArt.spotMarker, scale: 1),
                  'Destination',
                  'Published place to explore on the map.',
                ),
                const SizedBox(height: 8),
                _legendRow(
                  ctx,
                  const PixelSprite(MapMarkerArt.localPartnerPin, scale: 2),
                  'Local Partner',
                  'Destination linked to a verified Merchant Hub.',
                ),
                const SizedBox(height: 8),
                _legendRow(
                  ctx,
                  const PixelSprite(DesignerArt.questMarker, scale: 2),
                  'Quest Available',
                  'Upgraded pin with an active published quest.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendRow(
    BuildContext ctx,
    Widget icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 32,
          child: FittedBox(fit: BoxFit.contain, child: icon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: PixelType.body(
                  ctx,
                  color: PixelPalette.ink,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: PixelType.small(ctx, color: PixelPalette.woodDeep),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MapAreaBanner extends StatelessWidget {
  final AdminArea area;
  final int questsCount;
  final int spotsCount;
  final VoidCallback onClear;
  final VoidCallback onPinSpot;

  const MapAreaBanner({
    super.key,
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
          // Team review 2026-11-19: "zoom out and x do same thing, remove
          // zoom out, just a small x with no background box".
          Tooltip(
            message: tr(context, en: 'Close map', tl: 'Isara ang mapa'),
            child: PixelIconButton(
              key: const ValueKey('area_clear'),
              icon: MapMarkerArt.iconClose,
              iconHeight: 16,
              boxed: false,
              semanticLabel: tr(context, en: 'Close map', tl: 'Isara ang mapa'),
              onPressed: onClear,
            ),
          ),
        ],
      ),
    );
  }
}
