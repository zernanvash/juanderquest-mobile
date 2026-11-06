import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/services/push_routing.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  bool? _pushOn;
  bool _enablingPush = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPush();
  }

  Future<void> _checkPush() async {
    final on = await ref.read(pushServiceProvider).isPermitted();
    if (mounted) setState(() => _pushOn = on);
  }

  Future<void> _enablePush() async {
    setState(() => _enablingPush = true);
    final granted =
        await ref.read(pushServiceProvider).requestPermissionAndRegister();
    if (!mounted) return;
    setState(() {
      _enablingPush = false;
      _pushOn = granted;
    });
    showPixelToast(
      context,
      granted
          ? 'Notifications are on for this phone.'
          : 'Notifications are off. You can allow them in Android Settings.',
    );
  }

  /// Shown until the phone allows notifications.
  Widget _pushCard(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      key: const ValueKey('notifications_push_card'),
      style: PixelBoxStyle.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get these on your phone',
            style: PixelType.title(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Rewards, quest funding, sponsorships and Plaza activity, even when the app is closed.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('notifications_enable_push'),
            label: 'Turn on notifications',
            variant: PixelButtonVariant.secondary,
            loading: _enablingPush,
            onPressed: _enablingPush ? null : _enablePush,
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(apiClientProvider).dio.get('/notifications');
      final raw =
          response.data?['data']?['items'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Notifications are unavailable right now. Try again.';
      });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await ref.read(apiClientProvider).dio.patch('/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((item) => item['id'] == id ? {...item, 'read': true} : item)
            .toList();
      });
    } on DioException {
      if (!mounted) return;
      showPixelToast(
          context, 'Could not update that notification. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Notifications',
                    // Always a way back: without history, return to Home.
                    onBack: () => canPop
                        ? Navigator.of(context).maybePop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (_pushOn == false) ...[
                          _pushCard(context, grid),
                          SizedBox(height: grid.px(3)),
                        ],
                        _inbox(context, grid),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inbox(BuildContext context, PixelGrid grid) {
    if (_loading) {
      return const Center(child: PixelLoader(label: 'Loading notifications'));
    }
    if (_error != null) {
      return PixelPanel(
        style: PixelBoxStyle.red,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: PixelType.body(context, color: PixelPalette.white),
            ),
            SizedBox(height: grid.px(2)),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                key: const ValueKey('notifications_retry'),
                label: 'Retry',
                onPressed: _load,
              ),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return PixelPanel(
        style: PixelBoxStyle.parchment,
        child: PixelEmptyState(
          key: const ValueKey('notifications_empty'),
          title: 'All caught up',
          message:
              'You’re all caught up. Funding and quest updates will appear here.',
          action: PixelButton(
            key: const ValueKey('notifications_browse_quests'),
            label: 'Browse quests',
            onPressed: () => context.go('/quests'),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final item in _items) ...[
          _notificationCard(context, grid, item),
          SizedBox(height: grid.px(2)),
        ],
      ],
    );
  }

  Widget _notificationCard(
      BuildContext context, PixelGrid grid, Map<String, dynamic> item) {
    final read = item['read'] == true;
    final id = item['id'].toString();
    return PixelPanel(
      style: read ? PixelBoxStyle.parchment : PixelBoxStyle.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: ValueKey('notification_$id'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!read) _markRead(id);
              context.push(appRouteForPushHref(item['href']?.toString()));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? 'Update',
                  style: PixelType.title(
                    context,
                    color: read ? PixelPalette.ink : PixelPalette.white,
                  ),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  item['message']?.toString() ?? '',
                  style: PixelType.body(
                    context,
                    color: read ? PixelPalette.slate : PixelPalette.cream,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(
                item['kind'] == 'quest_reward' ? 'Reward' : 'Campaign',
                style: read ? PixelBoxStyle.slot : PixelBoxStyle.gold,
              ),
              if (read)
                const PixelChip('Read', style: PixelBoxStyle.slot)
              else
                Tooltip(
                  message: 'Mark as read',
                  child: PixelButton(
                    key: ValueKey('notification_read_$id'),
                    label: 'Mark as read',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => _markRead(id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
