import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../submissions/providers/submission_provider.dart';

class CompanionMessage {
  final String id;
  final String title;
  final String body;
  final String? actionLabel;
  final String? route;
  const CompanionMessage(
      {required this.id,
      required this.title,
      required this.body,
      this.actionLabel,
      this.route});
}

class CompanionPreferences {
  final bool muted;
  final Set<String> dismissed;
  const CompanionPreferences({this.muted = false, this.dismissed = const {}});
}

class CompanionController extends StateNotifier<CompanionPreferences> {
  CompanionController() : super(const CompanionPreferences());
  void dismiss(String id) => state = CompanionPreferences(
      muted: state.muted, dismissed: {...state.dismissed, id});
  void toggleMuted() => state =
      CompanionPreferences(muted: !state.muted, dismissed: state.dismissed);
}

final companionControllerProvider =
    StateNotifierProvider<CompanionController, CompanionPreferences>(
        (ref) => CompanionController());

final companionMessageProvider =
    Provider.family<CompanionMessage?, int>((ref, tabIndex) {
  final preferences = ref.watch(companionControllerProvider);
  if (preferences.muted) return null;
  final discovery = ref.watch(spotDiscoveryProvider);
  final submissions = ref.watch(submissionProvider);

  CompanionMessage? message;
  if (discovery.failure != null && discovery.spots.isEmpty && tabIndex == 0) {
    message = const CompanionMessage(
        id: 'discovery-offline',
        title: 'Juan lost the trail',
        body:
            'I cannot reach destination updates right now. Check your connection and let’s try again.',
        actionLabel: 'Try again');
  } else if (submissions.submissions.any((item) => item.status == 'pending')) {
    message = const CompanionMessage(
        id: 'pending-review',
        title: 'Your proof is on its way',
        body:
            'A quest submission is pending review. I’ll keep it visible in your journey.',
        actionLabel: 'View history',
        route: '/history');
  } else if (tabIndex == 0 &&
      discovery.spots.any((spot) => spot.crowdStatus == 'estimated_busy')) {
    message = const CompanionMessage(
        id: 'busy-alternatives',
        title: 'Let’s keep the trip comfortable',
        body:
            'Some destinations may be busy based on recent app activity—not live occupancy. Open one to see quieter alternatives.');
  }
  // Owner 2026-11-04: the guide hints ("Adventure is nearby", "This is your
  // travel journal") came back on every launch; the first-run tutorial
  // (onboarding/pixel_tutorial.dart, once per account) replaces them.
  return message != null && !preferences.dismissed.contains(message.id)
      ? message
      : null;
});
