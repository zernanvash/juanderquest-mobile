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
import '../../../app/open_route.dart';
import '../../../core/services/push_routing.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/local_notifications_provider.dart';

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

  /// Plan 100 WP-5: phone-made items (nearby quizzes) first, then the server's.
  List<Map<String, dynamic>> get _all =>
      [...ref.watch(localNotificationsProvider), ..._items];

  Future<void> _markRead(String id) async {
    if (id.startsWith(localNotificationPrefix)) {
      ref.read(localNotificationReadsProvider.notifier).markRead([id]);
      return;
    }
    try {
      await ref.read(apiClientProvider).dio.patch('/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((item) => item['id'] == id ? {...item, 'read': true} : item)
            .toList();
      });
      ref.invalidate(serverUnreadNotificationsProvider);
    } on DioException {
      if (!mounted) return;
      showPixelToast(
          context, 'Could not update that notification. Please retry.');
    }
  }

  bool _markingAllRead = false;

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    ref.read(localNotificationReadsProvider.notifier).markRead(
          ref.read(localNotificationsProvider).map((i) => i['id'] as String),
        );
    if (!_items.any((i) => i['read'] != true)) return;
    setState(() => _markingAllRead = true);
    try {
      await ref.read(apiClientProvider).dio.post('/notifications/read-all');
      if (!mounted) return;
      setState(() {
        _items = _items.map((item) => {...item, 'read': true}).toList();
        _markingAllRead = false;
      });
      ref.invalidate(serverUnreadNotificationsProvider);
    } on DioException {
      if (!mounted) return;
      setState(() => _markingAllRead = false);
      showPixelToast(context, 'Could not mark all as read. Please retry.');
    }
  }

  static String _kindLabel(String? kind) {
    switch (kind) {
      case 'quest_reward':
        return 'REWARD';
      case 'weekly_recap':
        return 'PLAZA';
      case 'nearby_quiz':
        return 'NEARBY';
      default:
        return 'UPDATE';
    }
  }

  static String _formatRelativeTime(dynamic raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) return '';
    final dt = DateTime.tryParse(s)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
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
            // Owner 2026-11-18 (v0.3.1): a wooden notice board.
            backgroundColor: PixelPalette.woodNight,
            body: DitherBackground(
              top: PixelPalette.woodDeep,
              bottom: PixelPalette.woodNight,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Notifications',
                    // Always a way back: without history, return to Home.
                    onBack: () => canPop
                        ? Navigator.of(context).maybePop()
                        : context.go('/dashboard'),
                    actions: [
                      if (!_loading && _all.any((i) => i['read'] != true))
                        PixelButton(
                          key: const ValueKey('notifications_read_all'),
                          label: _markingAllRead ? 'READING…' : 'READ ALL',
                          variant: PixelButtonVariant.secondary,
                          onPressed: _markingAllRead ? null : _markAllRead,
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
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
    final items = _all;
    if (items.isEmpty) {
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
    return NoticeBoard(
      key: const ValueKey('notifications_board'),
      child: Column(
        // Full-width cards (owner phone check 2026-11-16: short cards shrank).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: grid.px(4)),
            _notificationCard(context, grid, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _notificationCard(
      BuildContext context, PixelGrid grid, Map<String, dynamic> item) {
    final read = item['read'] == true;
    final id = item['id'].toString();
    final href = item['href']?.toString() ?? '';
    final timeLabel = _formatRelativeTime(item['created_at']);
    void open() {
      if (!read) _markRead(id);
      if (href.isNotEmpty) openRoute(context, appRouteForPushHref(href));
    }

    // Owner 2026-11-18 (v0.3.3): the whole note opens it (no OPEN button);
    // MARK READ sits bottom right; unread notes are marked NEW.
    return Semantics(
      button: true,
      label: '${read ? '' : 'New. '}${item['title'] ?? 'Update'}',
      child: GestureDetector(
        key: ValueKey('notification_$id'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: PinnedNote(
          read: read,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!read) ...[
                    const PixelChip(
                      'NEW',
                      key: ValueKey('notification_new_badge'),
                      style: PixelBoxStyle.red,
                      textColor: PixelPalette.white,
                    ),
                    SizedBox(width: grid.px(1)),
                  ],
                  Flexible(
                    child: PixelChip(
                      _kindLabel(item['kind']?.toString()),
                      style: read ? PixelBoxStyle.slot : PixelBoxStyle.gold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: grid.px(1)),
              Text(
                item['title']?.toString() ?? 'Update',
                style: PixelType.title(
                  context,
                  color: read ? PixelPalette.slate : PixelPalette.ink,
                ),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                item['message']?.toString() ?? '',
                style: PixelType.body(
                  context,
                  color: read ? PixelPalette.slate : PixelPalette.woodDeep,
                ),
              ),
              SizedBox(height: grid.px(2)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      timeLabel,
                      style:
                          PixelType.small(context, color: PixelPalette.slate),
                    ),
                  ),
                  if (read)
                    Text(
                      'READ',
                      key: ValueKey('notification_is_read_$id'),
                      style: PixelType.labelSmall(context,
                          color: PixelPalette.slate),
                    )
                  else
                    PixelButton(
                      key: ValueKey('notification_read_$id'),
                      label: 'MARK READ',
                      variant: PixelButtonVariant.secondary,
                      onPressed: () => _markRead(id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner 2026-11-18 (v0.3.1): the notifications sit on a wooden notice board:
/// horizontal planks with a dark frame.
class NoticeBoard extends StatelessWidget {
  const NoticeBoard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.darkWood.copyWith(corner: 3, shadowPx: 2),
      padding: 2,
      child: CustomPaint(
        painter: _PlankPainter(grid.px(1)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              grid.px(3), grid.px(5), grid.px(3), grid.px(3)),
          child: child,
        ),
      ),
    );
  }
}

class _PlankPainter extends CustomPainter {
  _PlankPainter(this.unit);

  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = PixelPalette.wood);
    final seam = Paint()..color = PixelPalette.woodDeep;
    final light = Paint()..color = PixelPalette.woodMid;
    final plank = unit * 14;
    var row = 0;
    for (var y = plank; y < size.height; y += plank, row++) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, unit), seam);
      canvas.drawRect(Rect.fromLTWH(0, y + unit, size.width, unit), light);
      // Staggered vertical joints, like real boards.
      final x = (row.isEven ? 0.3 : 0.7) * size.width;
      canvas.drawRect(
          Rect.fromLTWH(x, y - plank + unit, unit, plank - unit), seam);
    }
  }

  @override
  bool shouldRepaint(_PlankPainter old) => old.unit != unit;
}

/// A paper note pinned to the [NoticeBoard]. Unread notes are bright with a
/// red pin; read ones are dimmer with a brass pin.
class PinnedNote extends StatelessWidget {
  const PinnedNote({super.key, required this.read, required this.child});

  final bool read;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final pin = grid.px(4);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PixelPanel(
          style: read
              ? PixelBoxStyle.parchment.copyWith(fill: PixelPalette.paperDim)
              : PixelBoxStyle.parchment.copyWith(fill: PixelPalette.cream),
          child: Padding(
            padding: EdgeInsets.only(top: grid.px(1)),
            child: child,
          ),
        ),
        Positioned(
          top: -pin / 2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              key: ValueKey(read ? 'notice_pin_read' : 'notice_pin_unread'),
              width: pin,
              height: pin,
              decoration: BoxDecoration(
                color: read ? PixelPalette.goldDeep : PixelPalette.red,
                border: Border.all(
                    color: PixelPalette.woodNight, width: grid.px(1)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
