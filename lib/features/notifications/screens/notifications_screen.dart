import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await ref.read(apiClientProvider).dio.get('/notifications');
      final raw = response.data?['data']?['items'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _items = raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        _loading = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Notifications are unavailable right now. Try again.'; });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await ref.read(apiClientProvider).dio.patch('/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        _items = _items.map((item) => item['id'] == id ? {...item, 'read': true} : item).toList();
      });
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update that notification. Please retry.')),
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
            dimensions: 'Scrollable notification cards with readable status and timestamp',
            dataBinding: 'GET /api/v1/notifications; PATCH /api/v1/notifications/:id/read',
            stateNotes: 'Loading, empty, retryable unavailable, unread, and read states',
            uxNotes: 'In-app transactional updates only; no push notification permission required.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: AppSpacing.md), OutlinedButton(onPressed: _load, child: const Text('Retry'))]))
                    : _items.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Text('You’re all caught up. Funding and quest updates will appear here.')))
                        : Column(
                            children: _items.map((item) {
                              final read = item['read'] == true;
                              return Card(
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: ListTile(
                                  leading: Icon(item['kind'] == 'quest_reward' ? Icons.stars_rounded : Icons.campaign_outlined,
                                      color: read ? AppColors.textSecondary : AppColors.primary),
                                  title: Text(item['title']?.toString() ?? 'Update', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(item['message']?.toString() ?? '')),
                                  trailing: read ? const Icon(Icons.check, color: AppColors.textSecondary) : IconButton(
                                    tooltip: 'Mark as read',
                                    icon: const Icon(Icons.mark_email_read_outlined),
                                    onPressed: () => _markRead(item['id'].toString()),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
          ),
        ),
      );
}
