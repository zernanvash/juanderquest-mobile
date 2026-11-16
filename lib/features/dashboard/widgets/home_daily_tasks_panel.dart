import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
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
  });

  final List<HomeDailyMission> missions;

  /// Opens where a mission is done (by its `kind`).
  final ValueChanged<HomeDailyMission> onOpen;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    final done = missions.where((m) => m.completed).length;
    return PixelPanel(
      key: const ValueKey('home_daily_tasks'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: PixelSectionTitle(
                  tr(context, en: 'DAILY TASKS', tl: 'GAWAIN NGAYON'),
                  colors: PixelText3DColors.green,
                ),
              ),
              PixelChip(
                '$done/${missions.length}',
                style: done == missions.length
                    ? PixelBoxStyle.green
                    : PixelBoxStyle.slot,
                textColor: done == missions.length
                    ? PixelPalette.white
                    : PixelPalette.ink,
              ),
            ],
          ),
          for (final m in missions) ...[
            SizedBox(height: grid.px(2)),
            _TaskRow(mission: m, onTap: () => onOpen(m)),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.mission, required this.onTap});

  final HomeDailyMission mission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final m = mission;
    final progress = m.completed ? m.target : m.progress.clamp(0, m.target);
    return GestureDetector(
      key: ValueKey('home_daily_task_${m.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: m.completed
          ? null
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
          PixelChip(
            '+${m.stamps}',
            style: PixelBoxStyle.gold,
            textColor: PixelPalette.ink,
          ),
        ],
      ),
    );
  }
}
