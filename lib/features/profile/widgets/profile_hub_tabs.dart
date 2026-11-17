import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/open_route.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../spots/models/spot_model.dart';
import '../providers/profile_hub_provider.dart';

class ProfileQuestsTab extends ConsumerWidget {
  const ProfileQuestsTab({
    super.key,
    required this.targetHandle,
    required this.isMine,
    required this.userSpotsAsync,
  });

  final String targetHandle;
  final bool isMine;
  final AsyncValue<List<SpotModel>> userSpotsAsync;

  void _openCreateQuest(BuildContext context) {
    final spots = userSpotsAsync.valueOrNull ?? const <SpotModel>[];
    if (spots.isEmpty) {
      showPixelToast(
        context,
        tr(
          context,
          en: 'Post a destination first before creating a quest.',
          tl: 'Mag-post muna ng lugar bago gumawa ng quest.',
        ),
      );
      context.push('/map/add-spot');
      return;
    }
    if (spots.length == 1) {
      context.push('/explore/${spots.first.slug}/quests/new',
          extra: spots.first);
      return;
    }
    showPixelDialog<void>(
      context: context,
      title: tr(context, en: 'Choose a destination', tl: 'Pumili ng lugar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in spots.take(6)) ...[
            PixelButton(
              label: s.name,
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                context.push('/explore/${s.slug}/quests/new', extra: s);
              },
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
      actions: [
        PixelButton(
          label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
          variant: PixelButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final async = targetHandle.isEmpty
        ? const AsyncValue<List<ProfileAuthoredQuest>>.data([])
        : ref.watch(profileQuestsProvider(targetHandle));
    final count = async.maybeWhen(
      data: (list) => '${list.length}',
      orElse: () => null,
    );

    return PixelPanel(
      key: const ValueKey('profile_quests_panel'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelSectionTitle(
                tr(context, en: 'Quests', tl: 'Mga Quest'),
                value: count,
                valueColor: PixelPalette.greenDark,
              ),
              if (isMine)
                PixelButton(
                  key: const ValueKey('profile_create_quest'),
                  label: tr(context, en: '+ Create quest', tl: '+ Gumawa'),
                  onPressed: () => _openCreateQuest(context),
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          async.when(
            loading: () => Center(
              key: const ValueKey('profile_quests_loading'),
              child: PixelLoader(
                label: tr(
                  context,
                  en: 'Loading quests',
                  tl: 'Kinakarga ang mga quest',
                ),
              ),
            ),
            error: (_, __) => Column(
              key: const ValueKey('profile_quests_error'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    context,
                    en: 'Could not load quests.',
                    tl: 'Hindi makuha ang mga quest.',
                  ),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  key: const ValueKey('profile_quests_retry'),
                  label: tr(context, en: 'Try again', tl: 'Subukan muli'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: () =>
                      ref.invalidate(profileQuestsProvider(targetHandle)),
                ),
              ],
            ),
            data: (quests) {
              if (quests.isEmpty) {
                return Text(
                  key: const ValueKey('profile_quests_empty'),
                  isMine
                      ? tr(
                          context,
                          en: 'No quests created yet. Build one for your destination!',
                          tl: 'Wala pang nagawang quest. Gumawa para sa lugar mo!',
                        )
                      : tr(
                          context,
                          en: 'No published quests yet.',
                          tl: 'Wala pang nailathalang quest.',
                        ),
                  style: PixelType.body(context, color: PixelPalette.slate),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, q) in quests.indexed) ...[
                    if (i > 0)
                      Container(
                        height: grid.unit,
                        color: PixelPalette.paperDim,
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: grid.px(1),
                            runSpacing: grid.px(1),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (isMine)
                                PixelChip(
                                  q.status.toUpperCase(),
                                  style: q.status == 'published'
                                      ? PixelBoxStyle.green
                                      : PixelBoxStyle.gold,
                                  textColor: q.status == 'published'
                                      ? PixelPalette.white
                                      : PixelPalette.ink,
                                ),
                              PixelChip(
                                '+${q.rewardPoints} pts',
                                style: PixelBoxStyle.slot,
                              ),
                            ],
                          ),
                          SizedBox(height: grid.px(1)),
                          Text(
                            q.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.title(context),
                          ),
                          SizedBox(height: grid.px(1)),
                          Text(
                            [
                              if (q.spotName != null) q.spotName!,
                              if (q.spotName == null && q.locationName != null)
                                q.locationName!,
                              tr(
                                context,
                                en: '${q.stepCount} tasks',
                                tl: '${q.stepCount} gawain',
                              ),
                            ].join(' · '),
                            style: PixelType.small(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                          SizedBox(height: grid.px(2)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PixelButton(
                              key: ValueKey('profile_quest_open_${q.id}'),
                              label: isMine && q.status != 'published'
                                  ? tr(context, en: 'Edit ›', tl: 'I-edit ›')
                                  : tr(context, en: 'Open ›', tl: 'Buksan ›'),
                              variant: PixelButtonVariant.secondary,
                              onPressed: () => context.push(
                                isMine && q.status != 'published'
                                    ? '/quests/${q.id}/edit'
                                    : '/quests/${q.id}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileProgressTab extends ConsumerStatefulWidget {
  const ProfileProgressTab({
    super.key,
    required this.targetKey,
    required this.isMine,
  });

  /// Empty string `''` when viewing own `/me/progress`; else target handle.
  final String targetKey;
  final bool isMine;

  @override
  ConsumerState<ProfileProgressTab> createState() => _ProfileProgressTabState();
}

class _ProfileProgressTabState extends ConsumerState<ProfileProgressTab> {
  bool? _optimisticPublic;
  bool _savingPrivacy = false;

  Future<void> _togglePrivacy(bool next) async {
    setState(() {
      _optimisticPublic = next;
      _savingPrivacy = true;
    });
    try {
      final saved = await setProfileProgressPublic(ref, next);
      if (mounted) {
        setState(() => _optimisticPublic = saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticPublic = null);
        showPixelToast(
          context,
          tr(
            context,
            en: 'Could not update progress visibility.',
            tl: 'Hindi mabago ang privacy ng progreso.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final key = widget.isMine ? '' : widget.targetKey;
    final async = (!widget.isMine && key.isEmpty)
        ? const AsyncValue<ProfileProgressState>.data(
            ProfileProgressState(progressPublic: false, items: []),
          )
        : ref.watch(profileProgressProvider(key));

    return async.when(
      loading: () => PixelPanel(
        key: const ValueKey('profile_progress_loading'),
        style: PixelBoxStyle.parchment,
        child: Center(
          child: PixelLoader(
            label: tr(
              context,
              en: 'Loading quest progress',
              tl: 'Kinakarga ang progreso',
            ),
          ),
        ),
      ),
      error: (_, __) => PixelPanel(
        key: const ValueKey('profile_progress_error'),
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(tr(context, en: 'Progress', tl: 'Progreso')),
            SizedBox(height: grid.px(1)),
            Text(
              tr(
                context,
                en: 'Could not load quest progress.',
                tl: 'Hindi makuha ang progreso ng quest.',
              ),
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('profile_progress_retry'),
              label: tr(context, en: 'Try again', tl: 'Subukan muli'),
              variant: PixelButtonVariant.secondary,
              onPressed: () => ref.invalidate(profileProgressProvider(key)),
            ),
          ],
        ),
      ),
      data: (data) {
        if (!widget.isMine && data.isPrivate) {
          return PixelPanel(
            key: const ValueKey('profile_progress_private'),
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelSectionTitle(tr(context, en: 'Progress', tl: 'Progreso')),
                SizedBox(height: grid.px(1)),
                Text(
                  tr(
                    context,
                    en: 'This explorer keeps quest progress private.',
                    tl: 'Pribado ang progreso ng explorer na ito.',
                  ),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ),
          );
        }

        final isPublic = _optimisticPublic ?? data.progressPublic;
        final active = data.items.where((i) => !i.isCompleted).toList();
        final completed = data.items.where((i) => i.isCompleted).toList();

        return Column(
          key: const ValueKey('profile_progress_panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isMine) ...[
              PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          en: 'Show my progress on my profile',
                          tl: 'Ipakita ang progreso ko sa profile',
                        ),
                        style: PixelType.body(context),
                      ),
                    ),
                    SizedBox(width: grid.px(2)),
                    PixelSwitch(
                      key: const ValueKey('profile_progress_privacy_switch'),
                      value: isPublic,
                      semanticLabel: tr(
                        context,
                        en: 'Show my progress on my profile',
                        tl: 'Ipakita ang progreso ko sa profile',
                      ),
                      onChanged: _savingPrivacy ? (_) {} : _togglePrivacy,
                    ),
                  ],
                ),
              ),
              SizedBox(height: grid.px(3)),
            ],
            PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PixelSectionTitle(
                    tr(context, en: 'In progress', tl: 'Kasalukuyan'),
                    value: '${active.length}',
                    valueColor: PixelPalette.greenDark,
                  ),
                  SizedBox(height: grid.px(2)),
                  if (active.isEmpty)
                    Text(
                      key: const ValueKey('profile_progress_empty'),
                      tr(
                        context,
                        en: 'No active quests right now. Pick a quest to begin!',
                        tl: 'Walang aktibong quest ngayon. Pumili ng quest para magsimula!',
                      ),
                      style: PixelType.body(context, color: PixelPalette.slate),
                    )
                  else
                    for (final (i, item) in active.indexed) ...[
                      if (i > 0)
                        Container(
                          height: grid.unit,
                          color: PixelPalette.paperDim,
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.title(context),
                            ),
                            SizedBox(height: grid.px(1)),
                            Text(
                              item.nextTaskTitle != null
                                  ? tr(
                                      context,
                                      en: 'Step ${item.verifiedRequired} of ${item.totalRequired} · Next: ${item.nextTaskTitle}',
                                      tl: 'Hakbang ${item.verifiedRequired} sa ${item.totalRequired} · Susunod: ${item.nextTaskTitle}',
                                    )
                                  : tr(
                                      context,
                                      en: 'Step ${item.verifiedRequired} of ${item.totalRequired}',
                                      tl: 'Hakbang ${item.verifiedRequired} sa ${item.totalRequired}',
                                    ),
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            SizedBox(height: grid.px(1)),
                            PixelProgressBar(
                              value: item.ratio,
                              segments: item.totalRequired.clamp(1, 10),
                              color: PixelPalette.greenBright,
                            ),
                            if (widget.isMine) ...[
                              SizedBox(height: grid.px(2)),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: PixelButton(
                                  key: ValueKey(
                                      'profile_progress_resume_${item.questId}'),
                                  label: tr(
                                    context,
                                    en: 'Resume ›',
                                    tl: 'Ipagpatuloy ›',
                                  ),
                                  variant: PixelButtonVariant.secondary,
                                  onPressed: () =>
                                      context.push('/quests/${item.questId}'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
            if (completed.isNotEmpty) ...[
              SizedBox(height: grid.px(3)),
              PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelSectionTitle(
                      tr(context, en: 'Completed', tl: 'Natapos'),
                      value: '${completed.length}',
                      valueColor: PixelPalette.greenDark,
                    ),
                    SizedBox(height: grid.px(1)),
                    for (final (i, item) in completed.indexed) ...[
                      if (i > 0)
                        Container(
                          height: grid.unit,
                          color: PixelPalette.paperDim,
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: PixelType.title(context),
                                  ),
                                  if (item.completedAt != null)
                                    Text(
                                      item.completedAt!
                                          .toLocal()
                                          .toIso8601String()
                                          .split('T')
                                          .first,
                                      style: PixelType.small(
                                        context,
                                        color: PixelPalette.slate,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: grid.px(1)),
                            PixelChip('+${item.rewardPoints} pts'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ProfileTimelineTab extends ConsumerWidget {
  const ProfileTimelineTab({super.key, required this.targetHandle});

  final String targetHandle;

  String _kindLabel(BuildContext context, String kind) => switch (kind) {
        'quest_completion' => tr(context, en: 'QUEST', tl: 'QUEST'),
        'destination' => tr(context, en: 'SPOT', tl: 'LUGAR'),
        'spot_photo' => tr(context, en: 'PHOTO', tl: 'LARAWAN'),
        'quiz_pass' => tr(context, en: 'QUIZ', tl: 'PAGSUSULIT'),
        _ => tr(context, en: 'ACTIVITY', tl: 'GAWAIN'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    if (targetHandle.isEmpty) {
      return PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Text(
          tr(context, en: 'No activity yet.', tl: 'Wala pang aktibidad.'),
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      );
    }

    final state = ref.watch(profileTimelineProvider(targetHandle));

    return PixelPanel(
      key: const ValueKey('profile_timeline_panel'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Timeline', tl: 'Kasaysayan'),
            value: state.loading ? null : '${state.items.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(2)),
          if (state.loading && state.items.isEmpty)
            Center(
              key: const ValueKey('profile_timeline_loading'),
              child: PixelLoader(
                label: tr(
                  context,
                  en: 'Loading timeline',
                  tl: 'Kinakarga ang kasaysayan',
                ),
              ),
            )
          else if (state.error != null && state.items.isEmpty)
            Column(
              key: const ValueKey('profile_timeline_error'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    context,
                    en: 'Could not load timeline.',
                    tl: 'Hindi makuha ang kasaysayan.',
                  ),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  key: const ValueKey('profile_timeline_retry'),
                  label: tr(context, en: 'Try again', tl: 'Subukan muli'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => ref
                      .read(profileTimelineProvider(targetHandle).notifier)
                      .loadInitial(),
                ),
              ],
            )
          else if (state.items.isEmpty)
            Text(
              key: const ValueKey('profile_timeline_empty'),
              tr(
                context,
                en: 'No timeline entries yet. Complete a quest or share a spot!',
                tl: 'Wala pang laman ang kasaysayan. Tumapos ng quest o mag-post ng lugar!',
              ),
              style: PixelType.body(context, color: PixelPalette.slate),
            )
          else ...[
            for (final (i, item) in state.items.indexed) ...[
              if (i > 0)
                Container(
                  height: grid.unit,
                  color: PixelPalette.paperDim,
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.href.isEmpty
                    ? null
                    : () => openRoute(context, item.href),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: grid.px(1),
                        runSpacing: grid.px(1),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PixelChip(
                            _kindLabel(context, item.kind),
                            style: PixelBoxStyle.slot,
                          ),
                          if (item.underReview)
                            PixelChip(
                              tr(
                                context,
                                en: 'UNDER REVIEW',
                                tl: 'SINUSURI',
                              ),
                              style: PixelBoxStyle.gold,
                            ),
                          if (item.at != null)
                            Text(
                              item.at!
                                  .toLocal()
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.title(context),
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Text(
                          item.subtitle!,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (state.nextCursor != null) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('profile_timeline_load_more'),
                label: tr(context, en: 'Load more', tl: 'Ipakita pa'),
                variant: PixelButtonVariant.secondary,
                expand: true,
                loading: state.loadingMore,
                onPressed: state.loadingMore
                    ? null
                    : () => ref
                        .read(profileTimelineProvider(targetHandle).notifier)
                        .loadMore(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
