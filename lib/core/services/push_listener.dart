import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/open_route.dart';
import '../../app/router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/navigation/providers/active_trail_session_provider.dart';
import '../../features/navigation/services/trail_notification_bridge.dart';
import '../../features/notifications/providers/local_notifications_provider.dart';
import '../../features/onboarding/page_tutorials.dart';
import '../widgets/in_app_banner.dart';
import 'push_routing.dart';
import 'push_service.dart';

/// App-wide push handling, mounted once under MaterialApp:
/// - registers this phone whenever someone is signed in and notifications
///   are already allowed (no prompt),
/// - opens the notification's screen when it is tapped (app in background or
///   launched from the notification),
/// - shows notifications that arrive while the app is open as the in-app
///   banner ([InAppBannerHost]).
class PushListener extends ConsumerStatefulWidget {
  final Widget child;

  const PushListener({super.key, required this.child});

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener> {
  final List<StreamSubscription<RemoteMessage>> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
      _subs.add(FirebaseMessaging.onMessage.listen(_showInApp));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('[Push] Listener note: $e');
    }
    // Plan 124d: local trail stop-arrival notification taps.
    unawaited(ref.read(trailNotificationBridgeProvider).listenForTaps((tap) {
      if (!mounted) return;
      openTrailNotificationTap(
          ref.read(routerProvider), ref.read(activeTrailSessionProvider), tap);
    }));
    if (ref.read(authProvider).isAuthenticated) {
      unawaited(ref.read(pushServiceProvider).syncIfPermitted());
    }
  }

  void _open(RemoteMessage message) {
    final route = appRouteForNotification(
      href: message.data['href']?.toString(),
      kind: message.data['kind']?.toString(),
      data: message.data,
    );
    final notificationId =
        (message.data['notification_id'] ?? message.data['id'])?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        ref.read(authProvider).isAuthenticated) {
      unawaited(
        ref
            .read(apiClientProvider)
            .dio
            .patch('/notifications/$notificationId/read')
            .then((_) => ref.invalidate(serverUnreadNotificationsProvider))
            .catchError((_) {}),
      );
    }
    try {
      // Never block a deep link or notification tap with a page tour.
      ref.read(tutorialCoordinatorProvider.notifier).deferNextNavigation();
      // A tab page switches tabs; pushing it would stack it on this tab.
      openRouteWith(ref.read(routerProvider), route);
    } catch (e) {
      debugPrint('[Push] Could not open $route: $e');
    }
  }

  void _showInApp(RemoteMessage message) {
    if (!mounted) return;
    // Owner 2026-11-17: updates show as the in-app banner.
    ref.read(inAppBannerProvider.notifier).show(InAppBannerItem(
          id: message.messageId ??
              'push:${DateTime.now().millisecondsSinceEpoch}',
          title: message.notification?.title ?? 'JuanDerQuest',
          message: message.notification?.body,
          href: appRouteForNotification(
            href: message.data['href']?.toString(),
            kind: message.data['kind']?.toString(),
            data: message.data,
          ),
        ));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Register on every sign-in (new account on this phone included).
    ref.listen<bool>(
      authProvider.select((s) => s.isAuthenticated),
      (was, now) {
        if (now && was != true) {
          unawaited(ref.read(pushServiceProvider).syncIfPermitted());
        }
      },
    );
    return widget.child;
  }
}
