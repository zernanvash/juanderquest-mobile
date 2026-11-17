import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Plan 56: one of the caller's own quests from `GET /me/quests`.
class MyQuest {
  const MyQuest({
    required this.id,
    required this.title,
    required this.status,
    required this.stepCount,
    this.spotName,
  });

  final String id;
  final String title;
  final String status;
  final int stepCount;
  final String? spotName;

  factory MyQuest.fromJson(Map<String, dynamic> j) => MyQuest(
        id: j['id'].toString(),
        title: j['title']?.toString() ?? '',
        status: j['status']?.toString() ?? 'published',
        stepCount: (j['step_count'] as num?)?.toInt() ?? 0,
        spotName: (j['spot'] as Map?)?['name']?.toString(),
      );
}

/// `status`: draft | published | paused.
final myQuestsProvider = FutureProvider.autoDispose
    .family<List<MyQuest>, String>((ref, status) async {
  final response = await ref
      .read(apiClientProvider)
      .dio
      .get('/me/quests', queryParameters: {'status': status});
  final data = response.data is Map ? response.data['data'] : null;
  final list = data is Map ? data['quests'] : null;
  if (list is! List) throw StateError('My quests response was not understood.');
  return list
      .whereType<Map>()
      .map((q) => MyQuest.fromJson(Map<String, dynamic>.from(q)))
      .toList();
});

class MyQuestsScreen extends ConsumerStatefulWidget {
  const MyQuestsScreen({super.key});

  @override
  ConsumerState<MyQuestsScreen> createState() => _MyQuestsScreenState();
}

class _MyQuestsScreenState extends ConsumerState<MyQuestsScreen> {
  String _status = 'draft';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myQuestsProvider(_status));
    final tabs = {
      'draft': tr(context, en: 'Drafts', tl: 'Draft'),
      'published': tr(context, en: 'Published', tl: 'Nailathala'),
      'paused': tr(context, en: 'Paused', tl: 'Naka-pause'),
    };
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'My quests', tl: 'Mga quest ko'),
                  onBack: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).maybePop()
                      : context.go('/profile'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: grid.px(4), vertical: grid.px(2)),
                  child: Wrap(
                    spacing: grid.px(2),
                    runSpacing: grid.px(1),
                    children: [
                      for (final e in tabs.entries)
                        PixelChip(
                          e.value,
                          key: ValueKey('my_quests_${e.key}'),
                          style: _status == e.key
                              ? PixelBoxStyle.gold
                              : PixelBoxStyle.parchment,
                          onTap: () => setState(() => _status = e.key),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(myQuestsProvider(_status).future),
                    child: async.when(
                      loading: () => const Center(child: PixelLoader()),
                      error: (_, __) => _message(
                        grid,
                        PixelEmptyState(
                          key: const ValueKey('my_quests_error'),
                          title: tr(context,
                              en: 'Could not load your quests',
                              tl: 'Hindi makuha ang mga quest mo'),
                          action: PixelButton(
                            label: tr(context, en: 'Retry', tl: 'Subukan muli'),
                            onPressed: () =>
                                ref.invalidate(myQuestsProvider(_status)),
                          ),
                        ),
                      ),
                      data: (quests) => quests.isEmpty
                          ? _message(
                              grid,
                              PixelEmptyState(
                                key: const ValueKey('my_quests_empty'),
                                title: tr(context,
                                    en: 'Nothing here yet', tl: 'Wala pa rito'),
                                message: tr(context,
                                    en: 'Create a quest from one of your posted places.',
                                    tl: 'Gumawa ng quest mula sa isang lugar na naipost mo.'),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                  grid.px(4),
                                  grid.px(1),
                                  grid.px(4),
                                  grid.px(4) +
                                      MediaQuery.paddingOf(context).bottom),
                              itemCount: quests.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: grid.px(2)),
                              itemBuilder: (context, i) =>
                                  _row(context, grid, quests[i]),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _message(PixelGrid grid, Widget child) => ListView(
        padding: EdgeInsets.all(grid.px(4)),
        children: [child],
      );

  Widget _row(BuildContext context, PixelGrid grid, MyQuest q) {
    final steps = tr(context,
        en: '${q.stepCount} ${q.stepCount == 1 ? 'task' : 'tasks'}',
        tl: '${q.stepCount} gawain');
    final subtitle = [
      if (q.spotName != null) q.spotName!,
      steps,
      if (q.status == 'draft')
        tr(context,
            en: 'Draft, finish to publish',
            tl: 'Draft, tapusin para mailathala'),
    ].join(' · ');
    return PixelPanel(
      key: ValueKey('my_quest_${q.id}'),
      style: PixelBoxStyle.parchment,
      child: Padding(
        padding: EdgeInsets.all(grid.px(1)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.title.isEmpty
                        ? tr(context,
                            en: 'Untitled quest', tl: 'Walang pamagat')
                        : q.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.body(context, color: PixelPalette.ink),
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
            SizedBox(width: grid.px(2)),
            PixelButton(
              key: ValueKey('my_quest_edit_${q.id}'),
              label: tr(context, en: 'Edit ›', tl: 'I-edit ›'),
              variant: PixelButtonVariant.secondary,
              onPressed: () async {
                await context.push('/quests/${q.id}/edit');
                if (mounted) ref.invalidate(myQuestsProvider(_status));
              },
            ),
          ],
        ),
      ),
    );
  }
}
