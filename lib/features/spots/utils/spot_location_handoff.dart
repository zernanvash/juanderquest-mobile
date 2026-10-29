import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot_store.dart';
import 'exif_gps.dart';
import 'spot_posting.dart';

/// Plan 70: /map/add-spot always has a location (same order as web `spot-location-handoff.ts`):
///   1. lat/lng from the map (plus the recognition it already fetched, passed as route extra)
///   2. the saved draft (survives the app being closed or evicted while the camera is open)
///   3. device GPS / photo EXIF (applied by the studio after it opens)
///   4. the last map view this session, else Lingayen Capitol
enum SpotLocationSource {
  mapCrosshair,
  userGps,
  photoExif,
  mapViewport,
  fallbackAnchor,
  draft
}

bool isSoftPin(SpotLocationSource source) =>
    source == SpotLocationSource.mapViewport ||
    source == SpotLocationSource.fallbackAnchor;

class StudioPin {
  const StudioPin(this.lat, this.lng, this.zoom);
  final double lat;
  final double lng;
  final double zoom;

  static StudioPin? tryParse(Object? lat, Object? lng, [Object? zoom]) {
    final la = double.tryParse('${lat ?? ''}'),
        lo = double.tryParse('${lng ?? ''}');
    if (la == null || lo == null || !insidePhilippines(la, lo)) return null;
    final z = double.tryParse('${zoom ?? ''}') ?? 17;
    return StudioPin(la, lo, z.clamp(8, 19).toDouble());
  }
}

const lingayenAnchor = StudioPin(16.0294, 120.2289, 15);

/// What the studio opens with (always a valid pin).
class InitialSpotLocation {
  const InitialSpotLocation(
      {required this.pin, required this.source, this.recognition, this.draft});
  final StudioPin pin;
  final SpotLocationSource source;
  final SpotRecognitionResult? recognition;
  final SpotPostingDraft? draft;
}

/// Last map centre this session (the map screen keeps it current).
final lastMapCenterProvider = StateProvider<StudioPin?>((ref) => null);

class SavedSpotDraft {
  const SavedSpotDraft(
      {required this.pin, required this.source, required this.draft});
  final StudioPin pin;
  final SpotLocationSource source;
  final SpotPostingDraft draft;
}

class SpotDraftStore {
  SpotDraftStore([SnapshotStore? store]) : _store = store ?? SnapshotStore();
  final SnapshotStore _store;
  static const key = 'spot_draft_v1';
  static const maxAge = Duration(days: 7);

  Future<void> save(
          StudioPin pin, SpotLocationSource source, SpotPostingDraft draft) =>
      _store.save(key, {
        'lat': pin.lat,
        'lng': pin.lng,
        'zoom': pin.zoom,
        'source': source.name,
        'draft': draft.toJson(),
      });

  Future<SavedSpotDraft?> load() async {
    final entry = await _store.load(key, maxAge: maxAge);
    final data = entry?.data;
    if (data is! Map) return null;
    final pin = StudioPin.tryParse(data['lat'], data['lng'], data['zoom']);
    if (pin == null) return null;
    final source = SpotLocationSource.values
            .where((s) => s.name == data['source'])
            .firstOrNull ??
        SpotLocationSource.draft;
    final draft = data['draft'] is Map
        ? SpotPostingDraft.fromJson(
            Map<String, dynamic>.from(data['draft'] as Map))
        : null;
    if (draft == null) return null;
    return SavedSpotDraft(pin: pin, source: source, draft: draft);
  }

  Future<void> clear() => _store.clear(key);
}

final spotDraftStoreProvider =
    Provider<SpotDraftStore>((ref) => SpotDraftStore());

bool _samePlace(StudioPin a, StudioPin b) =>
    (a.lat - b.lat).abs() <= 0.0002 && (a.lng - b.lng).abs() <= 0.0002;

/// Tiers 1, 2 and 4. [saved] is the draft loaded from disk (null when none).
InitialSpotLocation resolveInitialSpotLocation({
  StudioPin? fromRoute,
  SpotRecognitionResult? routeRecognition,
  SavedSpotDraft? saved,
  StudioPin? lastMapCenter,
}) {
  if (fromRoute != null) {
    final sameDraft =
        saved != null && _samePlace(fromRoute, saved.pin) ? saved : null;
    return InitialSpotLocation(
      pin: fromRoute,
      source: sameDraft?.source ?? SpotLocationSource.mapCrosshair,
      recognition: routeRecognition,
      draft: sameDraft?.draft,
    );
  }
  if (saved != null) {
    return InitialSpotLocation(
        pin: saved.pin, source: SpotLocationSource.draft, draft: saved.draft);
  }
  if (lastMapCenter != null) {
    return InitialSpotLocation(
        pin: lastMapCenter, source: SpotLocationSource.mapViewport);
  }
  return const InitialSpotLocation(
      pin: lingayenAnchor, source: SpotLocationSource.fallbackAnchor);
}
