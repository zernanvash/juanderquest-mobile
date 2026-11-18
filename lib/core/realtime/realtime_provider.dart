import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/local_notifications_provider.dart';
import '../../features/plaza/plaza_provider.dart';
import '../../features/quests/providers/quest_provider.dart';
import '../../features/submissions/providers/submission_provider.dart';
import '../network/api_client.dart';
import 'realtime_service.dart';

final realtimeConnectorProvider =
    Provider<RealtimeConnector>((_) => connectWebSocket);

/// Bursts (e.g. a reward credits points and sends a notification) collapse
/// into one refresh per kind.
final realtimeDebounceProvider =
    Provider<Duration>((_) => const Duration(milliseconds: 500));

/// Bumped on a `notification` event; an open Notifications screen reloads.
final notificationsChangedProvider = StateProvider<int>((_) => 0);

/// Bumped on a `funding` event; an open funding screen reloads.
final fundingChangedProvider = StateProvider<int>((_) => 0);

/// Maps a realtime event type to the refresh it triggers.
Map<String, void Function()> realtimeHandlers(Ref ref) => {
      'notification': () {
        ref.invalidate(serverUnreadNotificationsProvider);
        ref.read(notificationsChangedProvider.notifier).state++;
      },
      'points': () => ref.read(authProvider.notifier).refreshProfile(),
      'submission': () =>
          ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
      'quest_published': () => ref
          .read(questProvider.notifier)
          .fetchQuests(category: ref.read(questProvider).selectedCategory),
      'plaza_activity': () {
        // The feed is autoDispose: when Plaza is closed it loads fresh on open.
        if (ref.exists(plazaFeedProvider)) {
          ref
              .read(plazaFeedProvider.notifier)
              .loadFeed(reset: true, quiet: true);
        }
      },
      'funding': () => ref.read(fundingChangedProvider.notifier).state++,
    };

/// Collects event types for [delay] and then runs each handler once.
class RealtimeDispatcher {
  RealtimeDispatcher(this.handlers, this.delay);

  final Map<String, void Function()> handlers;
  final Duration delay;
  final Set<String> _pending = {};
  Timer? _timer;

  void add(Map<String, dynamic> event) {
    final type = event['type'];
    if (type is! String || !handlers.containsKey(type)) return;
    _pending.add(type);
    _timer ??= Timer(delay, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final types = _pending.toList();
    _pending.clear();
    for (final type in types) {
      try {
        handlers[type]!();
      } catch (_) {
        // A failed refresh must not stop the others.
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}

/// Live connection to `/api/v1/realtime` while signed in. Read once at startup
/// (LifecycleCoordinator), which also pauses it in the background.
final realtimeProvider = Provider<RealtimeService>((ref) {
  final dispatcher = RealtimeDispatcher(
      realtimeHandlers(ref), ref.watch(realtimeDebounceProvider));
  final service = RealtimeService(
    uriBuilder: () => realtimeUriFor(ApiClient.apiBaseUrl),
    onEvent: dispatcher.add,
    connector: ref.watch(realtimeConnectorProvider),
  );
  ref.listen<String?>(
    authProvider.select((s) => s.isAuthenticated ? s.token : null),
    (_, token) => token == null ? service.stop() : service.start(token),
    fireImmediately: true,
  );
  ref.onDispose(() {
    service.dispose();
    dispatcher.dispose();
  });
  return service;
});
