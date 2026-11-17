import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/open_route.dart';
import '../../app/router.dart';
import '../../features/notifications/providers/local_notifications_provider.dart';
import '../pixel/generated/designer_art.g.dart';
import '../pixel/generated/pixel_palette.g.dart';
import '../pixel/pixel_text_3d.dart';
import '../pixel/pixel_box.dart';
import '../pixel/pixel_grid.dart';
import '../pixel/pixel_text.dart';

/// One update shown at the top of the app.
@immutable
class InAppBannerItem {
  const InAppBannerItem({
    required this.id,
    required this.title,
    this.message,
    this.href,
  });

  final String id;
  final String title;
  final String? message;

  /// Where a tap goes (an app route); null only closes the banner.
  final String? href;
}

/// Owner 2026-11-17: "remove the quiz unlocked prompt in map, just put any
/// updates in notif, create an in-app banner if theres updates or
/// notification". One banner at a time; a newer update replaces it.
class InAppBannerController extends StateNotifier<InAppBannerItem?> {
  InAppBannerController() : super(null);

  static const showFor = Duration(seconds: 5);
  Timer? _timer;

  void show(InAppBannerItem item) {
    _timer?.cancel();
    state = item;
    _timer = Timer(showFor, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (mounted) state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final inAppBannerProvider =
    StateNotifierProvider<InAppBannerController, InAppBannerItem?>(
  (ref) => InAppBannerController(),
);

/// Mounted once under MaterialApp. Shows the banner over every screen and
/// raises one for each new phone-made notification (a quiz you just reached).
/// Server pushes arrive through [PushListener].
class InAppBannerHost extends ConsumerStatefulWidget {
  const InAppBannerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InAppBannerHost> createState() => _InAppBannerHostState();
}

class _InAppBannerHostState extends ConsumerState<InAppBannerHost> {
  /// Notifications already announced in this session.
  final _announced = <String>{};

  @override
  void initState() {
    super.initState();
    // Providers can't change while the tree builds, so announce after it.
    ref.listenManual<List<Map<String, dynamic>>>(
      localNotificationsProvider,
      (_, next) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announce(next);
      }),
      fireImmediately: true,
    );
  }

  void _announce(List<Map<String, dynamic>> items) {
    final fresh = items
        .where((i) => i['read'] != true && !_announced.contains(i['id']))
        .toList();
    _announced.addAll(items.map((i) => i['id'] as String));
    if (fresh.isEmpty) return;
    final i = fresh.last;
    ref.read(inAppBannerProvider.notifier).show(InAppBannerItem(
          id: i['id'] as String,
          title: i['title'] as String? ?? 'JuanDerQuest',
          message: i['message'] as String?,
          href: i['href'] as String?,
        ));
  }

  void _open(InAppBannerItem item) {
    ref.read(inAppBannerProvider.notifier).dismiss();
    if (item.id.startsWith(localNotificationPrefix)) {
      ref.read(localNotificationReadsProvider.notifier).markRead([item.id]);
    }
    final href = item.href;
    if (href == null || href.isEmpty) return;
    try {
      openRouteWith(ref.read(routerProvider), href);
    } catch (e) {
      debugPrint('[Banner] Could not open $href: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(inAppBannerProvider);
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -1.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: item == null
                  ? const SizedBox(key: ValueKey('in_app_banner_none'))
                  : InAppBanner(
                      key: ValueKey('in_app_banner_${item.id}'),
                      item: item,
                      onTap: () => _open(item),
                      onDismiss: () =>
                          ref.read(inAppBannerProvider.notifier).dismiss(),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class InAppBanner extends StatelessWidget {
  const InAppBanner({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final InAppBannerItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final message = item.message;
    return Padding(
      padding: EdgeInsets.all(grid.px(4)),
      child: Semantics(
        button: true,
        liveRegion: true,
        label: message == null ? item.title : '${item.title}. $message',
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey('in_app_banner'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            // Swipe it back up to hide it.
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) onDismiss();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: PixelPanel(
                style: PixelBoxStyle.darkWood.copyWith(shadowPx: 2),
                padding: 3,
                child: Row(
                  children: [
                    const PixelIconFit(DesignerArt.notifBell, box: 20),
                    SizedBox(width: grid.px(3)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.body(context,
                                    color: PixelPalette.paper)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (message != null && message.isNotEmpty)
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.small(context,
                                  color: PixelPalette.sunLight),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
