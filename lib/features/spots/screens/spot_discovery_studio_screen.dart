import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../utils/exif_gps.dart';
import '../utils/spot_location_handoff.dart';
import '../utils/spot_posting.dart';
import '../widgets/spot_posting_sheet.dart';

/// Plan 70: Spot Discovery Studio (`/map/add-spot`). A full page with the map on top, the
/// one-page composer, and a live postcard. It always has a pin (see spot_location_handoff.dart).
class SpotDiscoveryStudioScreen extends ConsumerStatefulWidget {
  const SpotDiscoveryStudioScreen(
      {super.key, this.routePin, this.routeRecognition});

  final StudioPin? routePin;
  final SpotRecognitionResult? routeRecognition;

  @override
  ConsumerState<SpotDiscoveryStudioScreen> createState() =>
      _SpotDiscoveryStudioScreenState();
}

class _SpotDiscoveryStudioScreenState
    extends ConsumerState<SpotDiscoveryStudioScreen> {
  static const _mapHeight = 200.0;
  static const _photoSnapMeters = 50.0;

  InitialSpotLocation? _initial;
  late StudioPin _pin;
  SpotLocationSource _source = SpotLocationSource.fallbackAnchor;
  int _session = 0; // bumps on "Add another spot" to start a fresh composer
  final _mapController = MapController();
  Timer? _panTimer;
  Timer? _saveTimer;
  bool _locating = false;
  String? _note;
  PhotoGps? _photoGps;
  bool _draftSaved = false;
  SpotPostingDraft? _lastDraft;
  SpotModel? _published;

  @override
  void initState() {
    super.initState();
    final route = widget.routePin;
    if (route != null) {
      // Tier 1: render at once.
      _apply(resolveInitialSpotLocation(
          fromRoute: route, routeRecognition: widget.routeRecognition));
    } else {
      _resolveWithoutRoute();
    }
  }

  Future<void> _resolveWithoutRoute() async {
    final saved = await ref.read(spotDraftStoreProvider).load();
    if (!mounted) return;
    setState(() => _apply(resolveInitialSpotLocation(
        saved: saved, lastMapCenter: ref.read(lastMapCenterProvider))));
    if (isSoftPin(_source)) unawaited(_useGps(auto: true));
  }

  void _apply(InitialSpotLocation initial) {
    _initial = initial;
    _pin = initial.pin;
    _source = initial.source;
  }

  @override
  void dispose() {
    _panTimer?.cancel();
    _saveTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _movePin(double lat, double lng, SpotLocationSource source,
      {bool moveMap = true, double? zoom}) {
    setState(() {
      _pin = StudioPin(lat, lng, zoom ?? _pin.zoom);
      _source = source;
    });
    if (moveMap) {
      try {
        _mapController.move(LatLng(lat, lng), zoom ?? _pin.zoom);
      } catch (_) {
        // The map is not laid out yet; it opens on the new pin.
      }
    }
    _scheduleSave();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _panTimer?.cancel();
    _panTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _movePin(camera.center.latitude, camera.center.longitude,
          SpotLocationSource.mapCrosshair,
          moveMap: false, zoom: camera.zoom);
    });
  }

  Future<void> _useGps({bool auto = false}) async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location is turned off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !auto) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is off.');
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      if (!mounted) return;
      if (!insidePhilippines(position.latitude, position.longitude)) {
        throw StateError('You are outside the Philippines.');
      }
      // The traveler already chose a place.
      if (auto && !isSoftPin(_source)) return;
      _movePin(
          position.latitude, position.longitude, SpotLocationSource.userGps,
          zoom: 17);
      setState(() => _note = null);
    } catch (error) {
      if (mounted && !auto) {
        setState(() => _note =
            '${error is StateError ? error.message : 'Could not get your location.'} Move the map to the spot instead.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onPhotoPicked(XFile photo) async {
    PhotoGps? gps;
    try {
      final file = File(photo.path);
      final raf = await file.open();
      final Uint8List head;
      try {
        head = await raf.read(exifHeadBytes);
      } finally {
        await raf.close();
      }
      gps = parseJpegGps(head);
    } catch (_) {
      gps = null;
    }
    if (!mounted || gps == null) return;
    if (isSoftPin(_source)) {
      _movePin(gps.lat, gps.lng, SpotLocationSource.photoExif, zoom: 17);
      setState(() => _note = '✨ Location set from your photo’s GPS');
    } else {
      setState(() => _photoGps = gps);
    }
  }

  void _onDraftChanged(SpotPostingDraft draft) {
    _lastDraft = draft;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      final draft = _lastDraft;
      if (draft == null || _published != null) return;
      await ref.read(spotDraftStoreProvider).save(_pin, _source, draft);
      ref.read(lastMapCenterProvider.notifier).state = _pin;
      if (mounted) setState(() => _draftSaved = true);
    });
  }

  Future<void> _onPublished(SpotModel spot) async {
    _saveTimer?.cancel();
    await ref.read(spotDraftStoreProvider).clear();
    if (mounted) setState(() => _published = spot);
  }

  void _addAnother() {
    setState(() {
      _published = null;
      _photoGps = null;
      _note = null;
      _draftSaved = false;
      _lastDraft = null;
      _initial = InitialSpotLocation(
          pin: _pin, source: SpotLocationSource.mapCrosshair);
      _session++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initial;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spot Discovery Studio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text('Pangasinan Atlas',
                  style: TextStyle(fontSize: 11, color: AppColors.primary)),
            ]),
        actions: [
          if (_draftSaved && _published == null)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                  child: Text('✓ Draft saved',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted))),
            ),
        ],
      ),
      body: initial == null
          ? const Center(child: CircularProgressIndicator())
          : _published != null
              ? _Celebration(
                  spot: _published!, pin: _pin, onAddAnother: _addAnother)
              : SpotPostingSheet(
                  key: ValueKey('studio-$_session'),
                  embedded: true,
                  initialLat: _pin.lat,
                  initialLng: _pin.lng,
                  initialDraft: initial.draft,
                  initialRecognition: initial.recognition,
                  header: _buildMapHeader(initial),
                  footerBuilder: (draft, media, isVideo) => SpotPostcard(
                    draft: draft,
                    handle: ref.watch(authProvider).user?.handle,
                    coverPath: isVideo ? null : media?.path,
                  ),
                  onDraftChanged: _onDraftChanged,
                  onPhotoPicked: _onPhotoPicked,
                  onPublished: _onPublished,
                ),
    );
  }

  Widget _buildMapHeader(InitialSpotLocation initial) {
    final photoFar = _photoGps != null &&
            metersBetween(_photoGps!.lat, _photoGps!.lng, _pin.lat, _pin.lng) >
                _photoSnapMeters
        ? _photoGps
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: _mapHeight,
        child: Stack(children: [
          FlutterMap(
            key: const ValueKey('studio_map'),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(initial.pin.lat, initial.pin.lng),
              initialZoom: initial.pin.zoom,
              minZoom: 8,
              maxZoom: 19,
              onPositionChanged: _onMapMoved,
              onTap: (_, point) =>
                  _mapController.move(point, _mapController.camera.zoom),
            ),
            children: [
              buildBaseTileLayer(satellite: satelliteOn(ref)),
              if (satelliteOn(ref)) const SatelliteAttribution(),
            ],
          ),
          // The pin stays in the centre; the map moves under it.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_pin,
                    size: 40,
                    color: AppColors.sunGold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black38)]),
              ),
            ),
          ),
          const Positioned(top: 8, left: 8, child: SatelliteToggleButton()),
          Positioned(
            top: 8,
            right: 8,
            child: FilledButton.tonalIcon(
              key: const ValueKey('studio_use_gps'),
              onPressed: _locating ? null : () => _useGps(),
              icon: _locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Use my GPS'),
            ),
          ),
        ]),
      ),
      if (_note != null || _source == SpotLocationSource.fallbackAnchor)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.08),
              borderRadius: AppSpacing.roundedMd),
          child: Text(
            _note ??
                'Starting at Lingayen. Move the map, use your GPS, or add a photo taken at the spot.',
            key: const ValueKey('studio_location_note'),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
      if (photoFar != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE), borderRadius: AppSpacing.roundedMd),
          child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                    'This photo was taken ${metersBetween(photoFar.lat, photoFar.lng, _pin.lat, _pin.lng).round()} m from the pin.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF0C4A6E))),
                TextButton(
                  key: const ValueKey('studio_move_to_photo'),
                  onPressed: () {
                    _movePin(photoFar.lat, photoFar.lng,
                        SpotLocationSource.photoExif,
                        zoom: 17);
                    setState(() {
                      _photoGps = null;
                      _note = '📍 Pin moved to where the photo was taken';
                    });
                  },
                  child: const Text('Move pin to photo location'),
                ),
              ]),
        ),
    ]);
  }
}

/// The live "explorer postcard": how the spot will look once it is on the atlas.
class SpotPostcard extends StatelessWidget {
  const SpotPostcard(
      {super.key,
      required this.draft,
      this.handle,
      this.coverPath,
      this.coverUrl,
      this.stamp = false});

  final SpotPostingDraft draft;
  final String? handle;
  final String? coverPath;
  final String? coverUrl;
  final bool stamp;

  @override
  Widget build(BuildContext context) {
    final category = spotPostingCategories
            .where((c) => c['id'] == draft.category)
            .map((c) => c['label'] as String)
            .firstOrNull ??
        draft.category;
    final place = [draft.barangay, draft.municipality]
        .where((p) => p.isNotEmpty)
        .join(', ');
    final discovered = 'Discovered by ${handle != null ? '@$handle' : 'you'}';
    Widget cover;
    if (coverPath != null) {
      cover = Image.file(File(coverPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else if (coverUrl != null && coverUrl!.isNotEmpty) {
      cover = Image.network(coverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else {
      cover = const Center(child: Text('🏝️', style: TextStyle(fontSize: 40)));
    }
    return Card(
      key: const ValueKey('spot_postcard'),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!stamp)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text('✨ LIVE ATLAS POSTCARD',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.primary)),
          ),
        SizedBox(
          height: 120,
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Color(0xFF1B4332),
                Color(0xFF2D6A4F),
                Color(0xFFFFB703)
              ])),
            ),
            cover,
            Positioned(
              left: 8,
              top: 8,
              right: 8,
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                _pill('$category · ${draft.subcategory.replaceAll('_', ' ')}',
                    Colors.black54, Colors.white),
                if (stamp)
                  _pill('✨ $discovered', const Color(0xDD582F0E),
                      const Color(0xFFFFD166)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                draft.name.trim().isEmpty ? 'Your new spot' : draft.name.trim(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.woodBrown)),
            const SizedBox(height: 2),
            Text(place.isEmpty ? 'Pangasinan' : place,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(
                draft.description.trim().isEmpty
                    ? 'Your story about this place will appear here.'
                    : draft.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            if (!stamp) ...[
              const SizedBox(height: 6),
              Text(discovered,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ]),
        ),
      ]),
    );
  }

  static Widget _pill(String text, Color background, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: background, borderRadius: AppSpacing.roundedPill),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

class _Celebration extends ConsumerWidget {
  const _Celebration(
      {required this.spot, required this.pin, required this.onAddAnother});

  final SpotModel spot;
  final StudioPin pin;
  final VoidCallback onAddAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = spot.gpsLat, lng = spot.gpsLng;
    return SingleChildScrollView(
      key: const ValueKey('studio_celebration'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('PINNED TO THE PANGASINAN ATLAS',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFB45309))),
        const SizedBox(height: 6),
        Text('${spot.name} is on the map!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.woodBrown)),
        const SizedBox(height: 4),
        const Text(
            'Thank you for charting a new discovery. Travelers can find it right away.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        SpotPostcard(
          stamp: true,
          handle: ref.watch(authProvider).user?.handle,
          coverUrl: spot.imageUrl,
          draft: SpotPostingDraft(
              name: spot.name,
              municipality: spot.municipality,
              description: spot.description,
              category: spot.category),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('studio_view_on_map'),
          onPressed: () => context.canPop()
              ? context.pop(spot)
              : context.go('/map?lat=$lat&lng=$lng'),
          icon: const Icon(Icons.map_rounded),
          label: const Text('View pin on map'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(
              '/navigate?name=${Uri.encodeQueryComponent(spot.name)}&lat=$lat&lng=$lng'),
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Navigate here'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('studio_add_another'),
          onPressed: onAddAnother,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add another spot'),
        ),
      ]),
    );
  }
}
