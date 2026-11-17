import 'package:flutter/material.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../ar_experience/core/ar_math.dart';
import '../../quests/models/quest_model.dart';
import '../models/spot_model.dart';

class SpotQuestMatch {
  const SpotQuestMatch({
    required this.quest,
    required this.reason,
    required this.isSpotOwn,
    required this.distanceMeters,
  });

  final QuestModel quest;
  final String reason;
  final bool isSpotOwn;
  final double distanceMeters;
}

/// Matches quests that start at [spot] or have a start/step within 1,000 m.
List<SpotQuestMatch> matchSpotQuests(
  SpotModel spot,
  List<QuestModel> rawQuests, {
  required bool showTest,
}) {
  final visible = withoutTestContent(
    rawQuests,
    (q) => q.isTest,
    showTest: showTest,
  );
  final hasSpotCoords = spot.gpsLat != 0 || spot.gpsLng != 0;
  final matches = <SpotQuestMatch>[];

  for (final q in visible) {
    if (spot.questId != null && q.id == spot.questId) {
      matches.add(
        SpotQuestMatch(
          quest: q,
          reason: 'Starts here',
          isSpotOwn: true,
          distanceMeters: 0,
        ),
      );
      continue;
    }
    if (!hasSpotCoords) continue;

    double? startDist;
    if (q.gpsLat != 0 || q.gpsLng != 0) {
      startDist = ArGeo.distanceMeters(
        spot.gpsLat,
        spot.gpsLng,
        q.gpsLat,
        q.gpsLng,
      );
    }

    double? minStepDist;
    for (final s in q.steps) {
      if (s.gpsLat == null || s.gpsLng == null) continue;
      final d = ArGeo.distanceMeters(
        spot.gpsLat,
        spot.gpsLng,
        s.gpsLat!,
        s.gpsLng!,
      );
      if (minStepDist == null || d < minStepDist) {
        minStepDist = d;
      }
    }

    if (startDist != null && startDist <= 1000) {
      matches.add(
        SpotQuestMatch(
          quest: q,
          reason: 'Nearby',
          isSpotOwn: false,
          distanceMeters: startDist,
        ),
      );
    } else if (minStepDist != null && minStepDist <= 1000) {
      matches.add(
        SpotQuestMatch(
          quest: q,
          reason: 'Stop on this quest',
          isSpotOwn: false,
          distanceMeters: minStepDist,
        ),
      );
    }
  }

  matches.sort((a, b) {
    if (a.isSpotOwn != b.isSpotOwn) return a.isSpotOwn ? -1 : 1;
    return a.distanceMeters.compareTo(b.distanceMeters);
  });
  return matches;
}

/// Pixel-styled bottom sheet listing every quest at a spot.
class TheaterQuestPickerSheet extends StatelessWidget {
  const TheaterQuestPickerSheet({
    super.key,
    required this.spot,
    required this.matches,
    required this.canCreateQuest,
    required this.onPlayQuest,
    required this.onCreateQuest,
  });

  final SpotModel spot;
  final List<SpotQuestMatch> matches;
  final bool canCreateQuest;
  final ValueChanged<String> onPlayQuest;
  final VoidCallback onCreateQuest;

  static Future<void> show(
    BuildContext context, {
    required SpotModel spot,
    required List<SpotQuestMatch> matches,
    required bool canCreateQuest,
    required ValueChanged<String> onPlayQuest,
    required VoidCallback onCreateQuest,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TheaterQuestPickerSheet(
        spot: spot,
        matches: matches,
        canCreateQuest: canCreateQuest,
        onPlayQuest: (questId) {
          Navigator.of(ctx).pop();
          onPlayQuest(questId);
        },
        onCreateQuest: () {
          Navigator.of(ctx).pop();
          onCreateQuest();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Material(
      color: PixelPalette.ink,
      child: Padding(
        padding: EdgeInsets.only(
          left: grid.px(3),
          right: grid.px(3),
          top: grid.px(3),
          bottom: MediaQuery.paddingOf(context).bottom + grid.px(3),
        ),
        child: SingleChildScrollView(
          key: const ValueKey('spot_quest_picker_sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: PixelSectionTitle(
                      'PLAY QUEST',
                      colors: PixelText3DColors.cream,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      alignment: Alignment.center,
                      child: Text(
                        '✕',
                        style:
                            PixelType.title(context, color: PixelPalette.paper),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: grid.px(1)),
              Text(
                spot.name,
                style: PixelType.small(context, color: PixelPalette.mist),
              ),
              SizedBox(height: grid.px(2)),
              for (var i = 0; i < matches.length; i++) ...[
                if (i > 0)
                  Container(
                    height: grid.unit,
                    margin: EdgeInsets.symmetric(vertical: grid.px(1.5)),
                    color: PixelPalette.paper.withValues(alpha: 0.18),
                  ),
                _QuestPickerRow(
                  match: matches[i],
                  onPlay: () => onPlayQuest(matches[i].quest.id),
                ),
              ],
              if (canCreateQuest) ...[
                SizedBox(height: grid.px(3)),
                PixelButton(
                  key: const ValueKey('spot_create_quest_button'),
                  label: 'Create a quest here',
                  variant: PixelButtonVariant.secondary,
                  expand: true,
                  onPressed: onCreateQuest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestPickerRow extends StatelessWidget {
  const _QuestPickerRow({
    required this.match,
    required this.onPlay,
  });

  final SpotQuestMatch match;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final q = match.quest;

    return Padding(
      key: ValueKey('spot_quest_row_${q.id}'),
      padding: EdgeInsets.symmetric(vertical: grid.px(1)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(context, color: PixelPalette.paper)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: grid.px(1)),
                Wrap(
                  spacing: grid.px(1.5),
                  runSpacing: grid.px(1),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PixelChip(
                      match.reason,
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                    MjdqAmount(
                      q.rewardPoints,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.sun,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: grid.px(2)),
          PixelButton(
            key: ValueKey('spot_quest_play_${q.id}'),
            label: 'PLAY',
            variant: PixelButtonVariant.primary,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}
