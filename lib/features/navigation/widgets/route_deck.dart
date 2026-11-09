import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../providers/navigation_provider.dart';
import 'detour_sheet.dart';
import 'trail_offer_sheet.dart';

class RouteDeck extends StatelessWidget {
  final NavigationState state;
  final NavigationNotifier notifier;

  const RouteDeck({
    super.key,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final route = state.route;
    final isDirect = state.isDirectRoute;

    final distanceKm = route?.summary.distanceKm ?? 0.0;
    final durationFormatted = route?.summary.durationFormatted ?? '-- min';
    final isDegraded = route?.isStraightLineFallback ?? false;

    final directSummary = isDegraded
        ? 'ESTIMATE · ${distanceKm.toStringAsFixed(0)} KM'
        : '${distanceKm.toStringAsFixed(1)} KM · $durationFormatted';

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: grid.px(2)),
        children: [
          // Card 0: DIRECT ROUTE
          InkWell(
            key: const ValueKey('nav_card_direct_route'),
            onTap: notifier.selectDirectRoute,
            child: Container(
              width: 220,
              margin: EdgeInsets.only(right: grid.px(1)),
              child: PixelPanel(
                style: isDirect ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                padding: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'DIRECT ROUTE',
                            style: PixelType.small(
                              context,
                              color: isDirect ? PixelPalette.woodDeep : PixelPalette.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: PixelPalette.woodNight.withValues(alpha: 0.08),
                            border: Border.all(
                              color: isDirect ? PixelPalette.woodDeep : PixelPalette.stone,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            child: Text(
                              'FREE',
                              style: PixelType.small(
                                context,
                                color: isDirect ? PixelPalette.woodDeep : PixelPalette.slate,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      directSummary,
                      style: PixelType.body(
                        context,
                        color: isDirect ? PixelPalette.woodDeep : PixelPalette.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    InkWell(
                      key: const ValueKey('nav_btn_detours'),
                      onTap: () {
                        DetourSheet.show(
                          context,
                          availableDetours: state.availableDetours,
                          selectedDetours: state.selectedDetours,
                          onToggleDetour: notifier.toggleDetour,
                          onClear: notifier.clearDetours,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.selectedDetours.isNotEmpty
                                ? '+ ${state.selectedDetours.length} DETOURS'
                                : '+ SCENIC DETOURS',
                            style: PixelType.small(
                              context,
                              color: isDirect ? PixelPalette.woodDeep : PixelPalette.greenDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '>',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.woodDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cards 1..N: Nearby Curated Trails
          for (final trail in state.nearbyTrails) ...[
            Builder(
              builder: (context) {
                final isSelected =
                    !isDirect && state.selectedTrail?.id == trail.id;
                final isHiyas = trail.tier.isHiyas;
                final price = trail.unlockRule.pricePoints ?? 0;
                final tag = trail.isUnlocked
                    ? 'YOURS'
                    : isHiyas
                        ? 'HIYAS · $price PTS'
                        : 'FREE';

                return InkWell(
                  key: ValueKey('nav_card_trail_${trail.id}'),
                  onTap: () {
                    TrailOfferSheet.show(
                      context,
                      trail: trail,
                      onChoose: notifier.selectTrail,
                    );
                  },
                  child: Container(
                    width: 220,
                    margin: EdgeInsets.only(right: grid.px(1)),
                    child: PixelPanel(
                      style: isSelected
                          ? PixelBoxStyle.gold
                          : (isHiyas ? PixelBoxStyle.wood : PixelBoxStyle.parchment),
                      padding: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  trail.title.toUpperCase(),
                                  style: PixelType.small(
                                    context,
                                    color: isSelected
                                        ? PixelPalette.woodDeep
                                        : (isHiyas ? PixelPalette.gold : PixelPalette.ink),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isHiyas
                                      ? PixelPalette.gold.withValues(alpha: 0.15)
                                      : PixelPalette.woodNight.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: isSelected
                                        ? PixelPalette.woodDeep
                                        : (isHiyas ? PixelPalette.gold : PixelPalette.stone),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  child: Text(
                                    tag,
                                    style: PixelType.small(
                                      context,
                                      color: isSelected
                                          ? PixelPalette.woodDeep
                                          : (isHiyas ? PixelPalette.gold : PixelPalette.slate),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${trail.stopCount} STOPS · ${formatMinutes(trail.totalMinutes)}',
                            style: PixelType.body(
                              context,
                              color: isSelected
                                  ? PixelPalette.woodDeep
                                  : (isHiyas ? PixelPalette.paper : PixelPalette.woodDeep),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+${trail.rewardPoints} PTS',
                                style: PixelType.small(
                                  context,
                                  color: isSelected
                                      ? PixelPalette.woodDeep
                                      : (isHiyas ? PixelPalette.gold : PixelPalette.greenDark),
                                ),
                              ),
                              if (trail.passesHere)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: PixelPalette.paper.withValues(alpha: 0.8),
                                    border: Border.all(color: PixelPalette.mist, width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    child: Text(
                                      'PASSES HERE',
                                      style: PixelType.small(context, color: PixelPalette.woodMid),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
