import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/push_routing.dart';
import '../../../core/services/push_service.dart';
import 'package:go_router/go_router.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(granted
          ? 'Notifications are on for this phone.'
          : 'Notifications are off. You can allow them in Android Settings.'),
    ));
  }

  /// Shown until the phone allows notifications.
  Widget _pushCard() {
    return Container(
      key: const ValueKey('notifications_push_card'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Get these on your phone',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'Rewards, quest funding, sponsorships and Plaza activity, even when the app is closed.'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('notifications_enable_push'),
            onPressed: _enablingPush ? null : _enablePush,
            icon: const Icon(Icons.notifications_active_rounded),
            label:
                Text(_enablingPush ? 'Turning on…' : 'Turn on notifications'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update that notification. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => JdqScaffold(
        scrollable: true,
        appBar: AppBar(title: const Text('Notifications')),
        body: UiSpecContainer(
          spec: const UiSpec(
            title: 'Durable Traveler Notifications',
            figmaLayer: '#Notifications_Inbox',
            dimensions:
                'Scrollable notification cards with readable status and timestamp',
            dataBinding:
                'GET /api/v1/notifications; PATCH /api/v1/notifications/:id/read',
            stateNotes:
                'Loading, empty, retryable unavailable, unread, and read states',
            uxNotes:
                'Inbox for every notification; push to the phone is optional (card shown until allowed).',
          ),
          child: Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.md, bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pushOn == false) _pushCard(),
                _inbox(),
              ],
            ),
          ),
        ),
      );

  Widget _inbox() => _loading
      ? const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator()))
      : _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: _load, child: const Text('Retry'))
            ]))
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                          'You’re all caught up. Funding and quest updates will appear here.')))
              : Column(
                  children: _items.map((item) {
                    final read = item['read'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        onTap: () {
                          if (!read) _markRead(item['id'].toString());
                          context.push(
                              appRouteForPushHref(item['href']?.toString()));
                        },
                        leading: Icon(
                            item['kind'] == 'quest_reward'
                                ? Icons.stars_rounded
                                : Icons.campaign_outlined,
                            color: read
                                ? AppColors.textSecondary
                                : AppColors.primary),
                        title: Text(item['title']?.toString() ?? 'Update',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(item['message']?.toString() ?? '')),
                        trailing: read
                            ? const Icon(Icons.check,
                                color: AppColors.textSecondary)
                            : IconButton(
                                tooltip: 'Mark as read',
                                icon:
                                    const Icon(Icons.mark_email_read_outlined),
                                onPressed: () =>
                                    _markRead(item['id'].toString()),
                              ),
                      ),
                    );
                  }).toList(),
                );
}
