import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../models/quest_model.dart';
import '../providers/quest_provider.dart';

/// Quests created in the last [window], newest first.
List<QuestModel> newQuests(
  List<QuestModel> quests, {
  required DateTime now,
  Duration window = const Duration(hours: 72),
}) {
  final fresh = quests
      .where(
          (q) => q.createdAt != null && now.difference(q.createdAt!) <= window)
      .toList()
    ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  return fresh;
}

/// Owner 2026-11-18: "display newly uploaded quests at the very top of the
/// feed so users don't have to scroll to find them". Top of Explore.
class NewQuestsStrip extends ConsumerStatefulWidget {
  const NewQuestsStrip({super.key, this.now});

  /// Clock override for tests.
  final DateTime? now;

  @override
  ConsumerState<NewQuestsStrip> createState() => _NewQuestsStripState();
}

class _NewQuestsStripState extends ConsumerState<NewQuestsStrip> {
  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final quests = withoutTestContent(
      ref.watch(questProvider).quests,
      (q) => q.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final fresh =
        newQuests(quests, now: widget.now ?? DateTime.now()).take(6).toList();
    if (fresh.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('explore_new_quests'),
      padding: EdgeInsets.only(bottom: grid.px(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'New quests', tl: 'Bagong quest'),
            icon: DesignerArt.questMarker,
            value: '${fresh.length}',
          ),
          SizedBox(height: grid.px(2)),
          for (final quest in fresh) ...[
            _NewQuestRow(quest: quest),
            SizedBox(height: grid.px(2)),
          ],
        ],
      ),
    );
  }
}

class _NewQuestRow extends StatelessWidget {
  const _NewQuestRow({required this.quest});

  final QuestModel quest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return GestureDetector(
      key: ValueKey('explore_new_quest_${quest.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/quests/${quest.id}', extra: quest),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Row(
          children: [
            PixelChip(
              tr(context, en: 'NEW', tl: 'BAGO'),
              style: PixelBoxStyle.gold,
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.body(context, color: PixelPalette.ink),
                  ),
                  Text(
                    quest.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
            SizedBox(width: grid.px(1)),
            Text(
              '+${quest.rewardPoints}',
              style: PixelType.small(context, color: PixelPalette.greenDark),
            ),
          ],
        ),
      ),
    );
  }
}
