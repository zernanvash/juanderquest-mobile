import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../models/spot_model.dart';
import '../utils/exif_gps.dart';
import '../utils/spot_location_handoff.dart';
import '../studio/pixel/studio_icons.dart';
import '../studio/pixel/studio_text.dart';
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
  late final JdqMap _map;
  late final Future<String> _style;
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
    _map = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    _map.onCameraIdle = _onCameraIdle;
    _map.onTapEmpty = (point) =>
        unawaited(_map.easeTo(point, _map.camera.zoom, reducedMotion: true));
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
    unawaited(
      _map.easeTo(
        LatLng(initial.pin.lat, initial.pin.lng),
        initial.pin.zoom,
        reducedMotion: true,
      ),
    );
  }

  @override
  void dispose() {
    _panTimer?.cancel();
    _saveTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _movePin(double lat, double lng, SpotLocationSource source,
      {bool moveMap = true, double? zoom}) {
    setState(() {
      _pin = StudioPin(lat, lng, zoom ?? _pin.zoom);
      _source = source;
    });
    if (moveMap) {
      unawaited(
        _map.easeTo(LatLng(lat, lng), zoom ?? _pin.zoom, reducedMotion: true),
      );
    }
    _scheduleSave();
  }

  void _onCameraIdle() {
    final cam = _map.camera;
    if ((cam.center.latitude - _pin.lat).abs() < 1e-6 &&
        (cam.center.longitude - _pin.lng).abs() < 1e-6 &&
        (cam.zoom - _pin.zoom).abs() < 1e-3) {
      return;
    }
    _panTimer?.cancel();
    _panTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _movePin(cam.center.latitude, cam.center.longitude,
          SpotLocationSource.mapCrosshair,
          moveMap: false, zoom: cam.zoom);
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
      setState(() => _note = 'Location set from your photo’s GPS');
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
    final user = ref.watch(authProvider).user;
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: Column(
              children: [
                PixelAppBar(
                  title: 'Spot Discovery Studio',
                  onBack:
                      canPop ? () => Navigator.of(context).maybePop() : null,
                  actions: [
                    if (_draftSaved && _published == null)
                      Text(
                        'Draft saved',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: initial == null
                      ? const Center(
                          child: PixelLoader(label: 'Starting studio'))
                      : _published != null
                          ? _Celebration(
                              spot: _published!,
                              pin: _pin,
                              onAddAnother: _addAnother,
                            )
                          : SpotPostingSheet(
                              key: ValueKey('studio-$_session'),
                              embedded: true,
                              initialLat: _pin.lat,
                              initialLng: _pin.lng,
                              initialDraft: initial.draft,
                              initialRecognition: initial.recognition,
                              header: _buildMapHeader(initial),
                              footerBuilder: (draft, media, isVideo) =>
                                  SpotPostcard(
                                draft: draft,
                                handle:
                                    user?.publicHandle ?? user?.displayName,
                                coverPath: isVideo ? null : media?.path,
                              ),
                              onDraftChanged: _onDraftChanged,
                              onPhotoPicked: _onPhotoPicked,
                              onPublished: _onPublished,
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapHeader(InitialSpotLocation initial) {
    final grid = PixelGrid.of(context);
    final photoFar = _photoGps != null &&
            metersBetween(_photoGps!.lat, _photoGps!.lng, _pin.lat, _pin.lng) >
                _photoSnapMeters
        ? _photoGps
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: _mapHeight,
        child: Stack(children: [
          Builder(
            key: const ValueKey('studio_map'),
            builder: (context) {
              final sat = satelliteOn(ref);
              unawaited(_map.setSatellite(sat));
              return JdqMapCanvas(
                map: _map,
                style: _style,
                extraAttribution: sat ? MapConfig.satelliteAttribution : null,
                fallback: const ColoredBox(color: PixelPalette.paperDim),
                onFallback: () {},
              );
            },
          ),
          // The pin stays in the centre; the map moves under it.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: PixelSprite(StudioIcons.pin, scale: 3),
              ),
            ),
          ),
          const Positioned(top: 8, left: 8, child: SatelliteToggleButton()),
          Positioned(
            top: 8,
            right: 8,
            child: PixelButton(
              key: const ValueKey('studio_use_gps'),
              label: 'Use my GPS',
              variant: PixelButtonVariant.secondary,
              loading: _locating,
              onPressed: _locating ? null : () => _useGps(),
            ),
          ),
        ]),
      ),
      if (_note != null || _source == SpotLocationSource.fallbackAnchor)
        Container(
          margin: EdgeInsets.fromLTRB(grid.px(3), grid.px(2), grid.px(3), 0),
          child: PixelPanel(
            style: PixelBoxStyle.gold,
            child: Text(
              _note ??
                  'Starting at Lingayen. Move the map, use your GPS, or add a photo taken at the spot.',
              key: const ValueKey('studio_location_note'),
              style: PixelType.body(context, color: PixelPalette.goldDeep),
            ),
          ),
        ),
      if (photoFar != null)
        Container(
          margin: EdgeInsets.fromLTRB(grid.px(3), grid.px(2), grid.px(3), 0),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This photo was taken ${metersBetween(photoFar.lat, photoFar.lng, _pin.lat, _pin.lng).round()} m from the pin.',
                  style: PixelType.body(context),
                ),
                SizedBox(height: grid.px(1)),
                PixelButton(
                  key: const ValueKey('studio_move_to_photo'),
                  label: 'Move pin to photo location',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () {
                    _movePin(photoFar.lat, photoFar.lng,
                        SpotLocationSource.photoExif,
                        zoom: 17);
                    setState(() {
                      _photoGps = null;
                      _note = 'Pin moved to where the photo was taken';
                    });
                  },
                ),
              ],
            ),
          ),
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
    final grid = PixelGrid.of(context);
    final category = studioCategoryName(draft.category);
    final place = [draft.barangay, draft.municipality]
        .where((p) => p.isNotEmpty)
        .join(', ');
    final credit = handle?.trim();
    final discovered =
        'Discovered by ${credit == null || credit.isEmpty ? 'you' : credit}';
    Widget cover;
    if (coverPath != null) {
      cover = Image.file(File(coverPath!),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const DitherBackground(
                top: PixelPalette.greenMid,
                bottom: PixelPalette.greenDeep,
              ));
    } else if (coverUrl != null && coverUrl!.isNotEmpty) {
      cover = Image.network(coverUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const DitherBackground(
                top: PixelPalette.greenMid,
                bottom: PixelPalette.greenDeep,
              ));
    } else {
      cover = const DitherBackground(
        top: PixelPalette.greenMid,
        bottom: PixelPalette.greenDeep,
      );
    }
    return PixelPanel(
      key: const ValueKey('spot_postcard'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!stamp) ...[
          Text('Live atlas postcard',
              style: PixelType.small(context, color: PixelPalette.greenDark)),
          SizedBox(height: grid.px(1)),
        ],
        SizedBox(
          height: grid.px(60),
          child: Stack(fit: StackFit.expand, children: [
            cover,
            Positioned(
              left: grid.px(1),
              top: grid.px(1),
              right: grid.px(1),
              child:
                  Wrap(spacing: grid.px(1), runSpacing: grid.px(1), children: [
                PixelChip(
                  '$category · ${studioSubcategoryName(draft.subcategory)}',
                  style: PixelBoxStyle.slot,
                ),
                if (stamp) PixelChip(discovered),
              ]),
            ),
          ]),
        ),
        SizedBox(height: grid.px(2)),
        Text(draft.name.trim().isEmpty ? 'Your new spot' : draft.name.trim(),
            style: PixelType.title(context)),
        Text(place.isEmpty ? 'Pangasinan' : place,
            style: PixelType.body(context, color: PixelPalette.greenDark)),
        SizedBox(height: grid.px(1)),
        Text(
            draft.description.trim().isEmpty
                ? 'Your story about this place will appear here.'
                : draft.description.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context, color: PixelPalette.slate)),
        if (!stamp) ...[
          SizedBox(height: grid.px(1)),
          Text(discovered,
              style: PixelType.small(context, color: PixelPalette.slate)),
        ],
      ]),
    );
  }
}

class _Celebration extends ConsumerWidget {
  const _Celebration(
      {required this.spot, required this.pin, required this.onAddAnother});

  final SpotModel spot;
  final StudioPin pin;
  final VoidCallback onAddAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final lat = spot.gpsLat, lng = spot.gpsLng;
    return SingleChildScrollView(
      key: const ValueKey('studio_celebration'),
      padding: EdgeInsets.all(grid.px(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Pinned to the Pangasinan atlas',
            textAlign: TextAlign.center,
            style: PixelType.small(context, color: PixelPalette.goldDeep)),
        SizedBox(height: grid.px(1)),
        Text('${spot.name} is on the map!',
            textAlign: TextAlign.center, style: PixelType.title(context)),
        SizedBox(height: grid.px(1)),
        Text(
            'Thank you for charting a new discovery. Travelers can find it right away.',
            textAlign: TextAlign.center,
            style: PixelType.body(context, color: PixelPalette.slate)),
        SizedBox(height: grid.px(3)),
        SpotPostcard(
          stamp: true,
          handle: ref.watch(authProvider).user?.publicHandle ??
              ref.watch(authProvider).user?.displayName,
          coverUrl: spot.imageUrl,
          draft: SpotPostingDraft(
              name: spot.name,
              municipality: spot.municipality,
              description: spot.description,
              category: spot.category),
        ),
        SizedBox(height: grid.px(3)),
        PixelButton(
          key: const ValueKey('studio_view_on_map'),
          label: 'View pin on map',
          expand: true,
          onPressed: () => context.canPop()
              ? context.pop(spot)
              : context.go('/map?lat=$lat&lng=$lng'),
        ),
        SizedBox(height: grid.px(2)),
        PixelButton(
          key: const ValueKey('studio_create_quest'),
          label: 'Create a quest here',
          expand: true,
          onPressed: () => context.push(
            '/explore/${spot.slug.isNotEmpty ? spot.slug : spot.id}/quests/new',
            extra: spot,
          ),
        ),
        SizedBox(height: grid.px(2)),
        PixelButton(
          key: const ValueKey('studio_navigate'),
          label: 'Navigate here',
          variant: PixelButtonVariant.secondary,
          expand: true,
          onPressed: () => context.push(
              '/navigate?name=${Uri.encodeQueryComponent(spot.name)}&lat=$lat&lng=$lng'),
        ),
        SizedBox(height: grid.px(2)),
        PixelButton(
          key: const ValueKey('studio_add_another'),
          label: 'Add another spot',
          variant: PixelButtonVariant.secondary,
          expand: true,
          onPressed: onAddAnother,
        ),
      ]),
    );
  }
}
