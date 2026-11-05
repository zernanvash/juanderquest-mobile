import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import 'home_widgets.dart';

/// The JuanChoice community card from Pixel lab B's Progress tab.
class HomeJuanChoiceCard extends ConsumerWidget {
  const HomeJuanChoiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(choiceOverviewProvider);
    return overview.when(
      loading: () => const HomeInlineLoading(label: 'Loading JuanChoice'),
      error: (_, __) => HomeErrorPanel(
        message: 'JuanChoice is unavailable.',
        retryKey: const ValueKey('home_juanchoice_retry'),
        onRetry: () => ref.invalidate(choiceOverviewProvider),
      ),
      data: (data) {
        final current = data.current;
        final open = current != null && data.isCampaignOpen(current);
        final detail =
            open ? ref.watch(choiceDetailProvider(current.id)) : null;
        return _JuanChoiceContent(
          overview: data,
          openCampaign: open ? current : null,
          detail: detail,
        );
      },
    );
  }
}

class _JuanChoiceContent extends StatelessWidget {
  const _JuanChoiceContent({
    required this.overview,
    required this.openCampaign,
    required this.detail,
  });

  final ChoiceOverview overview;
  final ChoiceCampaign? openCampaign;
  final AsyncValue<ChoiceDetail>? detail;

  static int _daysLeft(ChoiceOverview overview, ChoiceCampaign campaign) {
    final serverTime = overview.serverTime;
    final receivedAt = overview.receivedAt;
    final DateTime now;
    if (serverTime != null) {
      final elapsed = overview.monotonicClock?.elapsed ??
          (receivedAt == null
              ? Duration.zero
              : DateTime.now().difference(receivedAt));
      now = serverTime.add(elapsed);
    } else {
      now = DateTime.now();
    }
    final remaining = campaign.closesAt.difference(now);
    if (remaining <= Duration.zero) return 0;
    return (remaining.inHours / 24).ceil();
  }

  static String _daysLabel(int days) {
    if (days <= 0) return 'Closes today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final campaign = openCampaign;
    final previous = overview.previous;
    final winners = previous == null
        ? const <ChoiceStanding>[]
        : previous.standings
            .where(
              (standing) => previous.coWinnerIds.contains(standing.candidateId),
            )
            .toList();
    final title = campaign != null
        ? 'Voting now: ${campaign.theme}'
        : previous != null
            ? 'Last results: ${previous.periodLabel}'
            : 'Community vote';
    final target = campaign != null ? '/choice/${campaign.id}' : '/choice';
    return Semantics(
      container: true,
      button: true,
      label: 'JuanChoice. $title',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('home_juanchoice_card'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(target),
          child: PixelPanel(
            style: PixelBoxStyle.tooltip,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelSprite(DesignerArt.juanChoice, scale: 2),
                    SizedBox(width: grid.px(2)),
                    Expanded(
                      child: Text(
                        'JuanChoice',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    Flexible(
                      child: PixelChip(
                        campaign != null ? 'Vote open' : 'Community',
                        style: campaign != null
                            ? PixelBoxStyle.green
                            : PixelBoxStyle.gold,
                        textColor: campaign != null
                            ? PixelPalette.white
                            : PixelPalette.ink,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: grid.px(2)),
                if (campaign != null) ...[
                  PixelText.rich(
                    'Voting now: {sun:${campaign.theme}}',
                    maxLines: 2,
                    style: PixelType.body(context, color: PixelPalette.paper),
                  ),
                  SizedBox(height: grid.px(1)),
                  PixelText.rich(
                    '{paper:${_daysLabel(_daysLeft(overview, campaign))}} · ${_ballotLabel(detail)}',
                    maxLines: 2,
                    style: PixelType.small(context, color: PixelPalette.cream),
                  ),
                ] else if (previous != null) ...[
                  PixelText.rich(
                    'Last results: {sun:${previous.periodLabel}}',
                    maxLines: 2,
                    style: PixelType.body(context, color: PixelPalette.paper),
                  ),
                  SizedBox(height: grid.px(1)),
                  if (winners.isEmpty)
                    Text(
                      'No winner this round.',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.cream,
                      ),
                    )
                  else
                    for (final winner in winners.take(2))
                      PixelText.rich(
                        '{paper:${winner.spotName}} · {sun:${winner.votes} votes}',
                        maxLines: 2,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.cream,
                        ),
                      ),
                  if (winners.length > 2)
                    Text(
                      '+${winners.length - 2} more winners',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.paperDim,
                      ),
                    ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    '${previous.validBallots} ballots counted',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.paperDim,
                    ),
                  ),
                ] else
                  Text(
                    'No community vote is open and no results are in yet.',
                    style: PixelType.small(context, color: PixelPalette.cream),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ballotLabel(AsyncValue<ChoiceDetail>? detail) {
    if (detail == null) return 'you have not voted yet';
    if (detail.isLoading) return 'checking your ballot';
    final value = detail.asData?.value;
    if (value == null) return 'vote status unavailable';
    return value.ballot == null ? 'you have not voted yet' : 'you voted';
  }
}
