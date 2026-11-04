import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/providers/auth_provider.dart';
import '../../cultural_quizzes/models/cultural_quiz_model.dart';
import '../../spots/utils/spot_location_handoff.dart';
import '../../vote/models/governance_proposal_model.dart';

/// Open municipal proposals for the Progress tab. Kept local to Home so the
/// panel can show a real loading/empty/error state with a retry.
final homeProposalsProvider = FutureProvider<List<GovernanceProposalModel>>((
  ref,
) async {
  final response = await ref.read(apiClientProvider).dio.get('/proposals');
  final body = response.data;
  final data = body is Map ? body['data'] : null;
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map(
        (item) =>
            GovernanceProposalModel.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((proposal) => proposal.id.isNotEmpty)
      .toList();
});

class HomeNearbyQuizzes {
  const HomeNearbyQuizzes({required this.items, required this.origin});

  final List<NearbyQuizInvitationModel> items;

  /// `gps`, `map` (last map view) or `default` (Lingayen anchor).
  final String origin;

  String get originLabel => switch (origin) {
        'gps' => 'Near you',
        'map' => 'Around your last map view',
        _ => 'Around Lingayen',
      };
}

/// Cultural quizzes around the traveler. Only uses an already-granted
/// location permission; never prompts from Home. Falls back to the last map
/// view, then the Lingayen anchor, so the panel still works without GPS.
final homeNearbyQuizProvider = FutureProvider<HomeNearbyQuizzes>((ref) async {
  var lat = lingayenAnchor.lat;
  var lng = lingayenAnchor.lng;
  var origin = 'default';

  final lastCenter = ref.read(lastMapCenterProvider);
  if (lastCenter != null) {
    lat = lastCenter.lat;
    lng = lastCenter.lng;
    origin = 'map';
  }

  try {
    if (await Geolocator.isLocationServiceEnabled()) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        );
        lat = position.latitude;
        lng = position.longitude;
        origin = 'gps';
      }
    }
  } catch (_) {
    // Keep the map/default origin; the API call below still gets a chance.
  }

  final response = await ref
      .read(apiClientProvider)
      .dio
      .post('/quizzes/nearby', data: {'lat': lat, 'lng': lng});
  final body = response.data;
  final data = body is Map ? body['data'] : null;
  if (data is! List) {
    throw StateError('Nearby quizzes response was not understood.');
  }
  return HomeNearbyQuizzes(
    origin: origin,
    items: data
        .whereType<Map>()
        .map(
          (item) => NearbyQuizInvitationModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((quiz) => quiz.quizId.isNotEmpty)
        .toList(),
  );
});
