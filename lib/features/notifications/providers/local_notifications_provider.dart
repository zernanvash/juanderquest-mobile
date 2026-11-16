import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/providers/auth_provider.dart';
import '../../cultural_quizzes/providers/cultural_quiz_provider.dart';

/// Plan 100 WP-5 (owner: the quiz banner covers Home): "now available" alerts
/// live in Notifications instead. They are made on the phone from the quiz
/// radar, one per quiz per day, and their read state stays on the phone.
const localNotificationPrefix = 'local:';

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class LocalNotificationReads extends StateNotifier<Set<String>> {
  LocalNotificationReads([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const {}) {
    _restore();
  }

  static const _key = 'jdq_local_notifications_read';
  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || !mounted) return;
      final ids = (jsonDecode(raw) as List).whereType<String>();
      state = {...state, ...ids};
    } catch (_) {
      // No stored reads (or no secure storage, as in tests).
    }
  }

  void markRead(Iterable<String> ids) {
    final add = ids.where((id) => !state.contains(id));
    if (add.isEmpty) return;
    state = {...state, ...add};
    // Only today's ids matter (ids carry the date), so storage stays small.
    final today = _today();
    final keep = state.where((id) => id.endsWith(today)).toList();
    _storage.write(key: _key, value: jsonEncode(keep)).catchError((_) {});
  }
}

final localNotificationReadsProvider =
    StateNotifierProvider<LocalNotificationReads, Set<String>>(
  (ref) => LocalNotificationReads(),
);

/// Quizzes you are standing at and haven't done, shaped like `/notifications`
/// items so the inbox renders them the same way.
final localNotificationsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final quizzes =
      ref.watch(quizRadarProvider.select((s) => s.inRangeIncomplete));
  final reads = ref.watch(localNotificationReadsProvider);
  final today = _today();
  return [
    for (final q in quizzes)
      {
        'id': '${localNotificationPrefix}quiz:${q.quizId}:$today',
        'kind': 'nearby_quiz',
        'title': 'Quiz unlocked: ${q.title}',
        'message': q.destinationName.isEmpty
            ? 'You are close enough to play it now.'
            : 'You are at ${q.destinationName}. Play it now.',
        'href': '/cultural-quizzes/${q.quizId}',
        'read': reads.contains('${localNotificationPrefix}quiz:${q.quizId}:$today'),
      },
  ];
});

/// Unread server notifications, for the count on the Home bell.
final serverUnreadNotificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  try {
    final response =
        await ref.read(apiClientProvider).dio.get('/notifications');
    final raw = response.data?['data']?['items'];
    if (raw is! List) return 0;
    return raw.whereType<Map>().where((i) => i['read'] != true).length;
  } catch (_) {
    return 0;
  }
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final local = ref
      .watch(localNotificationsProvider)
      .where((i) => i['read'] != true)
      .length;
  return local + (ref.watch(serverUnreadNotificationsProvider).valueOrNull ?? 0);
});
