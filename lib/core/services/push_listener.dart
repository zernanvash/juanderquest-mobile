import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'push_routing.dart';
import 'push_service.dart';

/// App-wide push handling, mounted once under MaterialApp:
/// - registers this phone whenever someone is signed in and notifications
///   are already allowed (no prompt),
/// - opens the notification's screen when it is tapped (app in background or
///   launched from the notification),
/// - shows notifications that arrive while the app is open as a snack bar.
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
    if (ref.read(authProvider).isAuthenticated) {
      unawaited(ref.read(pushServiceProvider).syncIfPermitted());
    }
  }

  void _open(RemoteMessage message) {
    final route = appRouteForPushHref(message.data['href'] as String?);
    try {
      ref.read(routerProvider).push(route);
    } catch (e) {
      debugPrint('[Push] Could not open $route: $e');
    }
  }

  void _showInApp(RemoteMessage message) {
    if (!mounted) return;
    final title = message.notification?.title ?? 'JuanDerQuest';
    final body = message.notification?.body;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text(body == null || body.isEmpty ? title : '$title\n$body',
            maxLines: 3, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'View', onPressed: () => _open(message)),
      ),
    );
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
