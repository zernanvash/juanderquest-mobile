import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_feedback.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../../core/pixel/pixel_text_3d.dart';
import '../../../dashboard/pixel/home_pixel_art.dart';
import '../../models/spot_model.dart';

/// One colour badge on an Explore post (owner 2026-11-16): a small boxed
/// icon at the post's top right, from signals the app already has.
class ExploreBadge {
  const ExploreBadge({
    required this.id,
    required this.label,
    required this.meaning,
    required this.icon,
    required this.style,
    this.medallion = false,
  });

  final String id;
  final String label;
  final String meaning;
  final PixelArt icon;
  final PixelBoxStyle style;

  /// Plan 103 (owner 2026-11-18): the new medallion art has its own rim, so
  /// it is drawn without the coloured box.
  final bool medallion;

  static const verified = ExploreBadge(
    id: 'verified',
    label: 'LGU verified',
    meaning: 'The local government confirmed this place.',
    icon: DesignerArt.badgeVerified,
    style: PixelBoxStyle.coin,
    medallion: true,
  );
  static const quest = ExploreBadge(
    id: 'quest',
    label: 'Has a quest',
    meaning: 'There is a quest you can play here.',
    icon: DesignerArt.questMarker,
    style: PixelBoxStyle.gold,
  );
  static const gem = ExploreBadge(
    id: 'gem',
    label: 'Hidden gem',
    meaning: 'A lesser-known place picked for you.',
    icon: DesignerArt.badgeGem,
    style: PixelBoxStyle.darkWood,
    medallion: true,
  );
  static const quiet = ExploreBadge(
    id: 'quiet',
    label: 'Quiet now',
    meaning: 'Few people are here right now.',
    icon: DesignerArt.salakot,
    style: PixelBoxStyle.green,
  );
  static const fiesta = ExploreBadge(
    id: 'fiesta',
    label: 'Fiesta this month',
    meaning: 'This town has a festival this month.',
    icon: HomePixelArt.calendar,
    style: PixelBoxStyle.red,
  );
}

/// The badges a spot earns. [gemIds] are today's hidden gems; [fiestaTowns]
/// are lower-case towns with a festival this month.
List<ExploreBadge> exploreBadgesFor(
  SpotModel spot, {
  Set<String> gemIds = const {},
  Set<String> fiestaTowns = const {},
}) {
  final reasons = spot.reasons.map((r) => r.toLowerCase());
  return [
    if (spot.trustLevel.toLowerCase() == 'lgu_verified') ExploreBadge.verified,
    if (spot.questId != null && spot.questId!.trim().isNotEmpty)
      ExploreBadge.quest,
    if (gemIds.contains(spot.id) ||
        gemIds.contains(spot.slug) ||
        reasons.any((r) => r.contains('hidden gem')))
      ExploreBadge.gem,
    if (spot.crowdStatus.toLowerCase() == 'quiet') ExploreBadge.quiet,
    if (fiestaTowns.contains(normalizeTown(spot.municipality)))
      ExploreBadge.fiesta,
  ];
}

String normalizeTown(String raw) => raw
    .toLowerCase()
    .replaceAll(' city', '')
    .replaceAll(' municipality', '')
    .trim();

/// The badge strip. Tapping it lists what each badge means.
class ExploreBadgeRow extends StatelessWidget {
  const ExploreBadgeRow({super.key, required this.badges, this.spotName});

  final List<ExploreBadge> badges;
  final String? spotName;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      label: 'Badges: ${badges.map((b) => b.label).join(', ')}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('explore_badges'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            showExploreBadges(context, badges, spotName: spotName);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < badges.length; i++) ...[
                if (i > 0) SizedBox(width: grid.px(1)),
                if (badges[i].medallion)
                  KeyedSubtree(
                    key: ValueKey('explore_badge_${badges[i].id}'),
                    child: PixelIconFit(badges[i].icon, box: 30),
                  )
                else
                  PixelPanel(
                    key: ValueKey('explore_badge_${badges[i].id}'),
                    style: badges[i].style.copyWith(corner: 2, shadowPx: 0),
                    padding: 1,
                    // Owner 2026-11-17: badges were too small to read.
                    child: PixelIconFit(badges[i].icon, box: 24),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showExploreBadges(
  BuildContext context,
  List<ExploreBadge> badges, {
  String? spotName,
}) {
  final grid = PixelGrid.of(context);
  return showPixelDialog<void>(
    context: context,
    title: 'Badges',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spotName != null) ...[
          Text(
            spotName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
        ],
        for (final b in badges) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.medallion)
                PixelIconFit(b.icon, box: 40)
              else
                PixelPanel(
                  style: b.style.copyWith(corner: 2, shadowPx: 0),
                  padding: 2,
                  child: PixelIconFit(b.icon, box: 32),
                ),
              SizedBox(width: grid.px(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.label,
                      style: PixelType.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      b.meaning,
                      style:
                          PixelType.small(context, color: PixelPalette.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(3)),
        ],
      ],
    ),
  );
}
