import 'package:flutter/material.dart';

import '../../features/quests/models/quest_model.dart';
import '../../features/quests/pixel/pixel_tag.dart';
import '../../features/quests/pixel/saved_quest_heart.dart';
import '../pixel/generated/designer_art.g.dart';
import '../pixel/generated/pixel_palette.g.dart';
import '../pixel/pixel_art.dart';
import '../pixel/pixel_background.dart';
import '../pixel/pixel_box.dart';
import '../pixel/pixel_controls.dart';
import '../pixel/pixel_grid.dart';
import '../pixel/pixel_text.dart';

class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.status,
    required this.onTap,
    this.onDirections,
    this.isFeatured = false,
    this.isSaved = false,
    this.onToggleSaved,
    this.dailyMission = false,
  });

  final QuestModel quest;
  final String status;
  final VoidCallback onTap;
  final VoidCallback? onDirections;
  final bool isFeatured;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final bool dailyMission;

  static const _sunFrame = PixelBoxStyle(
    fill: PixelPalette.sun,
    highlight: PixelPalette.sun,
    shade: PixelPalette.sun,
    outline: PixelPalette.sun,
    corner: 2,
    shadowPx: 0,
    bevel: false,
  );

  @override
  Widget build(BuildContext context) {
    if (status.toUpperCase() == 'COMPLETED') return _completedCard(context);
    final grid = PixelGrid.of(context);
    final card = PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dailyMission) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: PixelTag(
                'Daily mission · Complete a quest step',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
                maxWidth: grid.px(150),
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
          Stack(
            children: [
              PixelPanel(
                style: PixelBoxStyle.slot,
                sunken: true,
                padding: 1,
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: isFeatured ? 16 / 9 : 16 / 10,
                    child: quest.imageUrl != null
                        ? Image.network(
                            quest.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imagePlaceholder(context),
                          )
                        : _imagePlaceholder(context),
                  ),
                ),
              ),
              Positioned(
                top: grid.px(2),
                left: grid.px(2),
                child: Wrap(
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  children: [
                    PixelTag(
                      quest.categoryDisplay,
                      style: PixelBoxStyle.parchment,
                      textColor: PixelPalette.ink,
                      maxWidth: grid.px(70),
                    ),
                    if (quest.isTest)
                      PixelTag(
                        'Test',
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                        maxWidth: grid.px(35),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: grid.px(1),
                right: grid.px(1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelTag(
                      '+${quest.rewardPoints} mJDQ',
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                      maxWidth: grid.px(45),
                    ),
                    if (onToggleSaved != null)
                      SavedQuestHeart(
                        saved: isSaved,
                        questTitle: quest.title,
                        onToggle: onToggleSaved!,
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  quest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: grid.px(2)),
              _StatusChip(status: status),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(
            quest.locationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: PixelPalette.greenDark),
          ),
          SizedBox(height: grid.px(1)),
          PixelText.rich(
            quest.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                '${quest.radiusMeters}m geofence',
                style: PixelBoxStyle.slot,
                textColor: PixelPalette.slate,
              ),
              PixelChip(
                '${quest.steps.length} tasks',
                style: PixelBoxStyle.slot,
                textColor: PixelPalette.slate,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: ValueKey('quest_directions_${quest.id}'),
                  label: 'Directions',
                  style: PixelBoxStyle.wood,
                  textColor: PixelPalette.white,
                  expand: true,
                  onPressed: onDirections,
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelButton(
                  key: ValueKey('quest_open_${quest.id}'),
                  label: dailyMission ? 'Play >' : 'View quest >',
                  expand: true,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final wrapped = dailyMission
        ? PixelPanel(style: _sunFrame, padding: 1, child: card)
        : card;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: '${quest.title}. $status. ${quest.locationName}',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: wrapped,
      ),
    );
  }

  Widget _completedCard(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: '${quest.title}. Completed.',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          padding: 2,
          child: Row(
            children: [
              const PixelSprite(DesignerArt.questMarker, scale: 2),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      '${quest.locationName} · ${quest.categoryDisplay} · ${quest.steps.length} tasks',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(1)),
              const PixelChip(
                'Completed',
                style: PixelBoxStyle.green,
                textColor: PixelPalette.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final grid = PixelGrid.of(context);
    return DitherBackground(
      top: PixelPalette.paperDim,
      bottom: PixelPalette.paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelSprite(DesignerArt.questMarker, scale: 3),
            SizedBox(height: grid.px(1)),
            Text(
              quest.locationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: PixelPalette.stone),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (style, textColor) = switch (status.toUpperCase()) {
      'COMPLETED' => (PixelBoxStyle.green, PixelPalette.white),
      'PENDING REVIEW' => (PixelBoxStyle.gold, PixelPalette.ink),
      'REJECTED' => (PixelBoxStyle.red, PixelPalette.white),
      _ => (PixelBoxStyle.green, PixelPalette.white),
    };
    return PixelTag(
      status,
      style: style,
      textColor: textColor,
      maxWidth: 140,
    );
  }
}
