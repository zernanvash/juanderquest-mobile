import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../ar_experience/core/ar_math.dart';
import '../../auth/providers/auth_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class _SpotQuestMatch {
  const _SpotQuestMatch({
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

class TheaterQuestsSection extends ConsumerStatefulWidget {
  const TheaterQuestsSection({
    super.key,
    required this.spot,
  });

  final SpotModel spot;

  @override
  ConsumerState<TheaterQuestsSection> createState() =>
      _TheaterQuestsSectionState();
}

class _TheaterQuestsSectionState extends ConsumerState<TheaterQuestsSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final qState = ref.read(questProvider);
      if (qState.quests.isEmpty && !qState.isLoading) {
        ref.read(questProvider.notifier).fetchQuests();
      }
    });
  }

  List<_SpotQuestMatch> _matchQuests(
    List<QuestModel> rawQuests,
    bool showTest,
  ) {
    final visible = withoutTestContent(
      rawQuests,
      (q) => q.isTest,
      showTest: showTest,
    );
    final spot = widget.spot;
    final hasSpotCoords = spot.gpsLat != 0 || spot.gpsLng != 0;
    final matches = <_SpotQuestMatch>[];

    for (final q in visible) {
      if (spot.questId != null && q.id == spot.questId) {
        matches.add(
          _SpotQuestMatch(
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
          _SpotQuestMatch(
            quest: q,
            reason: 'Nearby',
            isSpotOwn: false,
            distanceMeters: startDist,
          ),
        );
      } else if (minStepDist != null && minStepDist <= 1000) {
        matches.add(
          _SpotQuestMatch(
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

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final quests = ref.watch(questProvider).quests;
    final showTest = ref.watch(showTestContentProvider);
    final signedIn = ref.watch(authProvider).user != null;

    final matches = _matchQuests(quests, showTest);
    final shown = _expanded ? matches : matches.take(3).toList();
    final hiddenCount = matches.length - shown.length;

    return TheaterPanel(
      key: const ValueKey('spot_quests_here_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QUESTS HERE',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          if (matches.isEmpty) ...[
            Text(
              'No quests here yet',
              style: PixelType.body(context, color: PixelPalette.paper),
            ),
            if (signedIn && widget.spot.slug.isNotEmpty) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('spot_create_quest_button'),
                label: 'Create a quest here',
                variant: PixelButtonVariant.primary,
                expand: true,
                onPressed: () => context.push(
                  '/explore/${widget.spot.slug}/quests/new',
                ),
              ),
            ],
          ] else ...[
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) SizedBox(height: grid.px(2)),
              _SpotQuestRow(
                match: shown[i],
                onTap: () => context.push('/quests/${shown[i].quest.id}'),
              ),
            ],
            if (hiddenCount > 0) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('spot_quests_more_button'),
                label: '+$hiddenCount more',
                variant: PixelButtonVariant.secondary,
                expand: true,
                onPressed: () => setState(() => _expanded = true),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SpotQuestRow extends StatelessWidget {
  const _SpotQuestRow({
    required this.match,
    required this.onTap,
  });

  final _SpotQuestMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final q = match.quest;
    final stepCount = q.steps.length;
    final stepLabel = stepCount == 1 ? '1 step' : '$stepCount steps';

    return GestureDetector(
      key: ValueKey('spot_quest_row_${q.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Text(
                  '${q.rewardPoints} mJDQ · $stepLabel',
                  style: PixelType.small(
                    context,
                    color: PixelPalette.greenDeep,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(
              q.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.body(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
