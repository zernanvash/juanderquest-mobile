import '../../spots/utils/relocation_math.dart';
import 'builder_models.dart';

/// Maximum allowed distance (in meters) of a task fence from the destination.
const double kQuestTaskMaxDistanceMeters = 5000.0;

/// Pure validation & resume logic for the Plan 118 7-page quest wizard.
class QuestWizardLogic {
  static const int totalPages = 7;

  /// Page 1 / 7: Name (3–60 chars).
  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Name must be at least 3 characters.';
    }
    if (trimmed.length > 60) {
      return 'Name must be 60 characters or fewer.';
    }
    return null;
  }

  /// Page 2 / 7: About (10–280 chars) + Category required.
  static String? validateAbout(String description, String category) {
    final trimmed = description.trim();
    if (trimmed.length < 10) {
      return 'Tell travelers what they will do (at least 10 characters).';
    }
    if (trimmed.length > 280) {
      return 'Keep it compact (280 characters or fewer).';
    }
    if (!questCategories.any((c) => c.value == category)) {
      return 'Pick a category.';
    }
    return null;
  }

  /// Page 3 / 7: Task type must be one of the 5 supported checkpoint types.
  static bool isValidTaskType(String? type) =>
      type == 'location' ||
      type == 'qr' ||
      type == 'photo' ||
      type == 'ar' ||
      type == 'action';

  /// Returns true when the task type needs the extra task-details page (still shown as "4 / 7").
  static bool needsTaskDetailsPage(String type) =>
      type == 'qr' || type == 'photo' || type == 'ar' || type == 'action';

  /// Page 4 / 7: Where — pin must be within destination area (<= 5 km) when spot coords exist.
  static String? validateTaskLocation({
    required double lat,
    required double lng,
    double? spotLat,
    double? spotLng,
  }) {
    if (lat < 4.5 || lat > 21.5 || lng < 116.0 || lng > 127.0) {
      return 'Pin must be inside the Philippines.';
    }
    if (spotLat != null &&
        spotLng != null &&
        (spotLat != 0 || spotLng != 0)) {
      final dist = haversineMeters(spotLat, spotLng, lat, lng);
      if (dist > kQuestTaskMaxDistanceMeters) {
        return 'Pin must be within 5 km of the destination.';
      }
    }
    return null;
  }

  /// Extra (4 / 7) Task details validation per task_validation.dart rules.
  static String? validateTaskDetails(BuilderTask task) {
    if (task.title.trim().length < 3) {
      return 'Task title needs at least 3 characters.';
    }
    if (task.checkpointType == 'photo') {
      final ver = task.verification;
      if (ver is PhotoVerification && ver.prompt.trim().length < 5) {
        return 'Photo prompt must be at least 5 characters.';
      }
    }
    if (task.checkpointType == 'action') {
      final ver = task.verification;
      if (ver is ActionVerification) {
        final kind = ver.task['kind'] as String? ?? '';
        if (kind == 'complete_quiz') {
          final quizId = ver.task['quiz_id'] as String?;
          if (quizId == null || quizId.trim().isEmpty) {
            return 'Enter or pick a cultural quiz ID.';
          }
        }
        if (kind == 'save_spot' || kind == 'like_spot') {
          final spotId = ver.task['spot_id'] as String?;
          if (spotId == null || spotId.trim().isEmpty) {
            return 'Destination ID is required for this action.';
          }
        }
      }
    }
    return null;
  }

  /// Page 5 / 7: Task list requires at least 1 task (max 10).
  static String? validateTaskList(List<BuilderTask> tasks) {
    if (tasks.isEmpty) {
      return 'Add at least 1 task.';
    }
    if (tasks.length > 10) {
      return 'A quest can have at most 10 tasks.';
    }
    return null;
  }

  /// Page 6 / 7: Reward must be 50, 75, or 100.
  static String? validateReward(int? rewardPoints) {
    if (rewardPoints != 50 && rewardPoints != 75 && rewardPoints != 100) {
      return 'Pick a reward: 50, 75, or 100 points.';
    }
    return null;
  }

  /// Returns the 1-based page number (1..7) where a draft should resume.
  /// Complete drafts (and published quests in edit mode) open straight on page 7.
  static int firstIncompletePage(QuestBuilderState state) {
    if (validateName(state.title) != null) return 1;
    if (validateAbout(state.description, state.category) != null) return 2;
    if (state.tasks.isEmpty) return 3;
    if (validateReward(state.rewardPoints) != null) return 6;
    return 7;
  }

  /// Creates a sensible default task for the given checkpoint type at [lat]/[lng].
  static BuilderTask buildDefaultTask({
    required String type,
    required int stepOrder,
    required double lat,
    required double lng,
    String spotName = 'the destination',
    String? spotId,
  }) {
    final key = 'task_new_${DateTime.now().microsecondsSinceEpoch}_$stepOrder';
    final fence = GeoFence(lat: lat, lng: lng, radiusMeters: 100);
    switch (type) {
      case 'qr':
        return BuilderTask(
          key: key,
          stepOrder: stepOrder,
          title: 'Scan QR at $spotName',
          description: 'Find and scan the quest QR marker on site.',
          required: true,
          checkpointType: 'qr',
          verification: QrVerification(
            fence: fence.copyWith(radiusMeters: 80),
            scanMode: 'traveler_scans',
          ),
        );
      case 'photo':
        return BuilderTask(
          key: key,
          stepOrder: stepOrder,
          title: 'Take a photo at $spotName',
          description: 'Snap a clear photo of the landmark.',
          required: true,
          checkpointType: 'photo',
          verification: PhotoVerification(
            prompt: 'Take a photo of $spotName',
            fence: fence,
            requireGps: true,
          ),
        );
      case 'ar':
        return BuilderTask(
          key: key,
          stepOrder: stepOrder,
          title: 'Find AR relic at $spotName',
          description: 'Open AR view and collect the floating relic.',
          required: true,
          checkpointType: 'ar',
          verification: ArVerification(
            fence: fence.copyWith(radiusMeters: 50),
            object: 'token',
            color: '#FFB703',
          ),
        );
      case 'action':
        return BuilderTask(
          key: key,
          stepOrder: stepOrder,
          title: 'Save $spotName',
          description: 'Complete the in-app action for this place.',
          required: true,
          checkpointType: 'action',
          verification: ActionVerification(
            task: {
              'kind': 'save_spot',
              if (spotId != null && spotId.isNotEmpty) 'spot_id': spotId,
            },
          ),
        );
      case 'location':
      default:
        return BuilderTask(
          key: key,
          stepOrder: stepOrder,
          title: 'Arrive at $spotName',
          description: 'Check in when you reach the pinned spot.',
          required: true,
          checkpointType: 'location',
          verification: LocationVerification(fence: fence),
        );
    }
  }

  /// Extracts the GeoFence from any BuilderTask (falling back to [fallbackLat]/[fallbackLng]).
  static GeoFence fenceForTask(
    BuilderTask task,
    double fallbackLat,
    double fallbackLng,
  ) {
    final ver = task.verification;
    if (ver is LocationVerification) return ver.fence;
    if (ver is QrVerification) return ver.fence;
    if (ver is PhotoVerification && ver.fence != null) return ver.fence!;
    if (ver is ArVerification) return ver.fence;
    return GeoFence(lat: fallbackLat, lng: fallbackLng, radiusMeters: 100);
  }

  /// Returns a copy of [task] with its fence updated.
  static BuilderTask withFence(BuilderTask task, GeoFence fence) {
    final ver = task.verification;
    if (ver is LocationVerification) {
      return task.copyWith(verification: LocationVerification(fence: fence));
    }
    if (ver is QrVerification) {
      return task.copyWith(
        verification: QrVerification(
          fence: fence,
          markerCode: ver.markerCode,
          scanMode: ver.scanMode,
        ),
      );
    }
    if (ver is PhotoVerification) {
      return task.copyWith(
        verification: PhotoVerification(
          prompt: ver.prompt,
          fence: fence,
          requireGps: ver.requireGps,
        ),
      );
    }
    if (ver is ArVerification) {
      return task.copyWith(verification: ver.copyWith(fence: fence));
    }
    return task;
  }
}
