import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

/// Authored quest item returned by `GET /users/:handle/quests`.
class ProfileAuthoredQuest {
  const ProfileAuthoredQuest({
    required this.id,
    required this.title,
    required this.status,
    required this.rewardPoints,
    required this.stepCount,
    this.spotName,
    this.locationName,
  });

  final String id;
  final String title;
  final String status;
  final int rewardPoints;
  final int stepCount;
  final String? spotName;
  final String? locationName;

  factory ProfileAuthoredQuest.fromJson(Map<String, dynamic> j) =>
      ProfileAuthoredQuest(
        id: j['id'].toString(),
        title: j['title']?.toString() ?? '',
        status: j['status']?.toString() ?? 'published',
        rewardPoints: (j['reward_points'] as num?)?.toInt() ?? 0,
        stepCount: (j['step_count'] as num?)?.toInt() ?? 1,
        spotName: j['spot_name'] as String?,
        locationName: j['location_name'] as String?,
      );
}

/// Progress item returned by `GET /me/progress` or `GET /users/:handle/progress`.
class ProfileProgressAttempt {
  const ProfileProgressAttempt({
    required this.attemptId,
    required this.questId,
    required this.title,
    required this.verifiedRequired,
    required this.totalRequired,
    required this.status,
    this.nextTaskTitle,
    this.completedAt,
    this.rewardPoints = 0,
  });

  final String attemptId;
  final String questId;
  final String title;
  final int verifiedRequired;
  final int totalRequired;
  final String status;
  final String? nextTaskTitle;
  final DateTime? completedAt;
  final int rewardPoints;

  double get ratio => totalRequired <= 0
      ? (status == 'completed' ? 1.0 : 0.0)
      : (verifiedRequired / totalRequired).clamp(0.0, 1.0);

  bool get isCompleted => status == 'completed';

  factory ProfileProgressAttempt.fromJson(Map<String, dynamic> j) =>
      ProfileProgressAttempt(
        attemptId: j['attempt_id'].toString(),
        questId: j['quest_id'].toString(),
        title: j['title']?.toString() ?? '',
        verifiedRequired: (j['verified_required'] as num?)?.toInt() ?? 0,
        totalRequired: (j['total_required'] as num?)?.toInt() ?? 1,
        status: j['status']?.toString() ?? 'in_progress',
        nextTaskTitle: j['next_task_title'] as String?,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse('${j['completed_at']}')
            : null,
        rewardPoints: (j['reward_points'] as num?)?.toInt() ?? 0,
      );
}

class ProfileProgressState {
  const ProfileProgressState({
    required this.progressPublic,
    required this.items,
    this.isPrivate = false,
  });

  final bool progressPublic;
  final List<ProfileProgressAttempt> items;
  final bool isPrivate;
}

class ProfileTimelineItem {
  const ProfileTimelineItem({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.title,
    required this.href,
    required this.underReview,
    required this.status,
    required this.at,
    this.subtitle,
  });

  final String id;
  final String kind;
  final String subjectId;
  final String title;
  final String? subtitle;
  final String href;
  final bool underReview;
  final String status;
  final DateTime? at;

  factory ProfileTimelineItem.fromJson(Map<String, dynamic> j) =>
      ProfileTimelineItem(
        id: j['id'].toString(),
        kind: j['kind']?.toString() ?? '',
        subjectId: j['subject_id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle'] as String?,
        href: j['href']?.toString() ?? '',
        underReview: j['under_review'] == true,
        status: j['status']?.toString() ?? '',
        at: DateTime.tryParse('${j['at']}'),
      );
}

class ProfileTimelineState {
  const ProfileTimelineState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<ProfileTimelineItem> items;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final String? error;

  ProfileTimelineState copyWith({
    List<ProfileTimelineItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) =>
      ProfileTimelineState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

Map<String, dynamic>? _dataMap(dynamic body) {
  if (body is Map && body['data'] is Map) {
    return Map<String, dynamic>.from(body['data'] as Map);
  }
  return null;
}

final profileQuestsProvider = FutureProvider.autoDispose
    .family<List<ProfileAuthoredQuest>, String>((ref, handle) async {
  final clean = handle.trim().replaceFirst('@', '');
  if (clean.isEmpty) return const [];
  final res = await ref.read(apiClientProvider).dio.get('/users/$clean/quests');
  final raw = _dataMap(res.data)?['quests'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => ProfileAuthoredQuest.fromJson(Map<String, dynamic>.from(m)))
      .toList();
});

/// Key is `''` for `/me/progress` or target handle for `/users/:handle/progress`.
final profileProgressProvider = FutureProvider.autoDispose
    .family<ProfileProgressState, String>((ref, targetKey) async {
  final clean = targetKey.trim().replaceFirst('@', '');
  final path = clean.isEmpty ? '/me/progress' : '/users/$clean/progress';
  try {
    final res = await ref.read(apiClientProvider).dio.get(path);
    final data = _dataMap(res.data);
    final list = data != null && data['items'] is List
        ? data['items'] as List
        : const [];
    return ProfileProgressState(
      progressPublic: data != null && data['progress_public'] == true,
      items: list
          .whereType<Map>()
          .map((m) =>
              ProfileProgressAttempt.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  } on DioException catch (e) {
    final body = e.response?.data;
    final code = body is Map && body['error'] is Map
        ? (body['error'] as Map)['code']
        : null;
    if (e.response?.statusCode == 403 && code == 'PROGRESS_PRIVATE') {
      return const ProfileProgressState(
        progressPublic: false,
        items: [],
        isPrivate: true,
      );
    }
    rethrow;
  }
});

Future<bool> setProfileProgressPublic(
    WidgetRef ref, bool progressPublic) async {
  final res = await ref.read(apiClientProvider).dio.put(
    '/me/profile-privacy',
    data: {'progress_public': progressPublic},
  );
  ref.invalidate(profileProgressProvider(''));
  return _dataMap(res.data)?['progress_public'] == true;
}

class ProfileTimelineNotifier extends StateNotifier<ProfileTimelineState> {
  ProfileTimelineNotifier(this._ref, this._handle)
      : super(const ProfileTimelineState(loading: true)) {
    loadInitial();
  }

  final Ref _ref;
  final String _handle;

  Future<void> loadInitial() async {
    final clean = _handle.trim().replaceFirst('@', '');
    if (clean.isEmpty) {
      state = const ProfileTimelineState(items: [], loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res =
          await _ref.read(apiClientProvider).dio.get('/users/$clean/timeline');
      final data = res.data is Map ? res.data['data'] : null;
      final list = data is Map && data['items'] is List
          ? data['items'] as List
          : const [];
      final next = data is Map ? data['next_cursor'] as String? : null;
      if (!mounted) return;
      state = ProfileTimelineState(
        items: list
            .whereType<Map>()
            .map((m) =>
                ProfileTimelineItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        nextCursor: next,
        loading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Unable to load timeline.',
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    final clean = _handle.trim().replaceFirst('@', '');
    if (cursor == null || state.loadingMore || clean.isEmpty) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final res = await _ref.read(apiClientProvider).dio.get(
        '/users/$clean/timeline',
        queryParameters: {'cursor': cursor},
      );
      final data = res.data is Map ? res.data['data'] : null;
      final list = data is Map && data['items'] is List
          ? data['items'] as List
          : const [];
      final next = data is Map ? data['next_cursor'] as String? : null;
      if (!mounted) return;
      final more = list
          .whereType<Map>()
          .map(
              (m) => ProfileTimelineItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      state = state.copyWith(
        items: [...state.items, ...more],
        nextCursor: next,
        clearCursor: next == null,
        loadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false, error: 'Unable to load more.');
    }
  }
}

final profileTimelineProvider = StateNotifierProvider.autoDispose
    .family<ProfileTimelineNotifier, ProfileTimelineState, String>(
  (ref, handle) => ProfileTimelineNotifier(ref, handle),
);
