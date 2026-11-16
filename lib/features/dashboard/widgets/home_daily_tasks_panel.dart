import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../providers/home_daily_provider.dart';

/// Plan 100 WP-4 (owner: "there no daily task panel in dashboard"): today's
/// missions from `/me/daily`, which the Concept B Home stopped showing.
/// Stamps earned here feed the STAMP box next to TOP REWARD.
class HomeDailyTasksPanel extends StatelessWidget {
  const HomeDailyTasksPanel({
    super.key,
    required this.missions,
    required this.onOpen,
    this.daily,
    this.loading = false,
  });

  final List<HomeDailyMission> missions;

  /// For the weekly chest line (owner 2026-11-17: show daily and weekly).
  final HomeDailyState? daily;
  final bool loading;

  /// Opens where a mission is done (by its `kind`).
  final ValueChanged<HomeDailyMission> onOpen;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final done = missions.where((m) => m.completed).length;
    final allDone = missions.isNotEmpty && done == missions.length;
    final d = daily;
    // Idle (owner 2026-11-16): the next task's reward pulses; all done, a
    // calm shimmer and a line saying so.
    final next = missions.where((m) => !m.completed).firstOrNull;
    return PixelShimmer(
      enabled: allDone,
      color: PixelPalette.greenLight,
      child: PixelPanel(
        key: const ValueKey('home_daily_tasks'),
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelSectionTitle(
              tr(context, en: 'DAILY TASKS', tl: 'GAWAIN NGAYON'),
              colors: PixelText3DColors.green,
              value: missions.isEmpty ? null : '$done/${missions.length}',
              valueColor: PixelPalette.greenDark,
            ),
            if (missions.isEmpty) ...[
              SizedBox(height: grid.px(2)),
              loading
                  ? const PixelLoader(label: 'Loading tasks')
                  : Text(
                      tr(context,
                          en: 'No tasks today. Check back tomorrow!',
                          tl: 'Walang gawain ngayon. Balik bukas!'),
                      key: const ValueKey('home_daily_none'),
                      style: PixelType.body(context, color: PixelPalette.slate),
                    ),
            ],
            for (final m in missions) ...[
              SizedBox(height: grid.px(2)),
              _TaskRow(
                mission: m,
                pulse: identical(m, next),
                onTap: () => onOpen(m),
              ),
            ],
            if (d != null && d.chestRequired > 0) ...[
              SizedBox(height: grid.px(3)),
              _WeeklyChest(daily: d),
            ],
            if (allDone) ...[
              SizedBox(height: grid.px(2)),
              Text(
                tr(context,
                    en: 'All done for today!', tl: 'Tapos na lahat ngayon!'),
                key: const ValueKey('home_daily_all_done'),
                style: PixelType.small(context, color: PixelPalette.greenDark)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.mission,
    required this.onTap,
    this.pulse = false,
  });

  final HomeDailyMission mission;
  final VoidCallback onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final m = mission;
    final progress = m.completed ? m.target : m.progress.clamp(0, m.target);
    return GestureDetector(
      key: ValueKey('home_daily_task_${m.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: m.completed
          ? () => showPixelToast(context, 'Done for today. Nice!')
          : () {
              pixelTick(context);
              onTap();
            },
      child: Row(
        children: [
          Text(
            m.completed ? '✓' : '•',
            style: PixelType.title(
              context,
              color: m.completed ? PixelPalette.greenDark : PixelPalette.stone,
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Text(
              m.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.body(
                context,
                color: m.completed ? PixelPalette.stone : PixelPalette.ink,
              ).copyWith(
                decoration: m.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          SizedBox(width: grid.px(2)),
          Text(
            '$progress/${m.target}',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(width: grid.px(2)),
          PixelPulse(
            enabled: pulse,
            child: PixelChip(
              '+${m.stamps}',
              style: PixelBoxStyle.gold,
              textColor: PixelPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// This week's chest: finish N daily tasks this week for bonus stamps.
class _WeeklyChest extends StatelessWidget {
  const _WeeklyChest({required this.daily});

  final HomeDailyState daily;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final done = daily.chestCompleted.clamp(0, daily.chestRequired);
    return Column(
      key: const ValueKey('home_weekly_chest'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                daily.chestEarned
                    ? tr(context,
                        en: 'WEEKLY CHEST OPENED', tl: 'NABUKSAN ANG BAUL')
                    : tr(context, en: 'WEEKLY CHEST', tl: 'BAUL NG LINGGO'),
                style: PixelType.small(context, color: PixelPalette.ink)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$done/${daily.chestRequired}',
              style: PixelType.small(context, color: PixelPalette.greenDark)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            if (daily.chestStamps > 0) ...[
              SizedBox(width: grid.px(2)),
              PixelChip(
                '+${daily.chestStamps}',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
              ),
            ],
          ],
        ),
        SizedBox(height: grid.px(1)),
        PixelProgressBar(
          value: daily.chestRequired == 0 ? 0 : done / daily.chestRequired,
          segments: daily.chestRequired.clamp(1, 10),
          color: PixelPalette.greenBright,
        ),
      ],
    );
  }
}
