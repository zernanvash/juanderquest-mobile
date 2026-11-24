import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../celebrations/celebration.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../../merchant/screens/merchant_page_screen.dart';
import '../models/suki_models.dart';
import '../providers/suki_provider.dart';
import '../suki_scan_flow.dart';
import '../widgets/suki_card_view.dart';
import '../widgets/suki_pass_sheet.dart';
import '../widgets/suki_points_menu.dart';
import '../widgets/suki_reward_ladder.dart';
import 'suki_cards_screen.dart' show SukiErrorPanel;

/// Plan 107 (`/suki/:programId`): one shop's card, its rewards and the pass.
class SukiCardScreen extends ConsumerWidget {
  const SukiCardScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sukiProgramProvider(programId));
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'Suki Card', tl: 'Suki Card'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: state.when(
                    loading: () => Center(
                        child: PixelLoader(
                            label: tr(context,
                                en: 'Loading card', tl: 'Kinukuha ang card'))),
                    error: (error, _) => ListView(
                      padding: EdgeInsets.all(grid.gutter),
                      children: [SukiErrorPanel(error: error)],
                    ),
                    data: (data) => _body(context, ref, grid, data),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showPass(
      BuildContext context, WidgetRef ref, SukiProgram p) async {
    final before = ref.read(sukiProgramProvider(programId)).valueOrNull;
    final done = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PixelPalette.parchment,
      builder: (_) => SukiPassSheet(programId: p.id, shopName: p.merchant.name),
    );
    if (done == null) return;
    ref.invalidate(sukiProgramProvider(programId));
    ref.invalidate(mySukiCardsProvider);
    if (!context.mounted) return;
    // J3: the sheet closed because staff recorded the visit.
    final card = done is SukiCardProgress ? done : null;
    final completed = card != null &&
        card.visits == 0 &&
        card.cycle > (before?.card?.cycle ?? card.cycle);
    final n = completed
        ? (before?.card?.required ?? card.required)
        : (card?.visits ?? 0);
    final m = completed ? n : (card?.required ?? p.visitsRequired);
    await showCelebration(
      context,
      StampEarned(
        title: completed ? 'SUKI REWARD!' : 'SUKI VISIT!',
        stampName: tr(context,
            en: 'Visit $n of $m at ${p.merchant.name}',
            tl: 'Bisita $n sa $m sa ${p.merchant.name}'),
        stamp: HomePixelArt.stampCheck,
        actionLabel: tr(context, en: 'Continue', tl: 'Tuloy'),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    PixelGrid grid,
    SukiProgramDetail data,
  ) {
    final p = data.program;
    final card = data.card;
    final passButton = PixelButton(
      key: const ValueKey('suki_show_pass'),
      label: tr(context, en: 'Show my Suki pass', tl: 'Ipakita ang Suki pass'),
      variant: p.staffScan
          ? PixelButtonVariant.primary
          : PixelButtonVariant.secondary,
      expand: true,
      onPressed: () => _showPass(context, ref, p),
    );

    return RefreshIndicator(
      color: PixelPalette.green,
      backgroundColor: PixelPalette.parchment,
      // v0.3.10: a failed refresh (Suki switched off, offline) shows the
      // error panel; it must not escape as an uncaught error.
      onRefresh: () async {
        try {
          ref.invalidate(sukiProgramProvider(programId));
          await ref.read(sukiProgramProvider(programId).future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(grid.gutter, grid.px(3), grid.gutter,
            grid.px(8) + MediaQuery.paddingOf(context).bottom),
        children: [
          for (final reward in data.rewards) ...[
            _reward(context, grid, reward),
            SizedBox(height: grid.px(3)),
          ],
          SukiCardView(
            program: p,
            card: card,
            tiers: data.effectiveTiers,
            points: card?.points ?? p.points,
            onShowPass: () => _showPass(context, ref, p),
            onShopTap: p.merchant.id.isEmpty
                ? null
                : () => openMerchantPage(context, p.merchant.id),
          ),
          if (card?.visitedToday == true) ...[
            SizedBox(height: grid.px(2)),
            Text(
              tr(context,
                  en: 'Visited today. Come back tomorrow!',
                  tl: 'Bumisita ka na ngayon. Balik bukas!'),
              key: const ValueKey('suki_visited_today'),
              style: PixelType.small(context, color: PixelPalette.greenDark),
            ),
          ],
          if (p.staffScan) ...[
            SizedBox(height: grid.px(2)),
            Text(
              tr(context,
                  en: 'This shop scans your pass at the counter.',
                  tl: 'Sa counter i-scan ng staff ang pass mo.'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
          if (data.effectiveTiers.length > 1 ||
              (card?.tiers.isNotEmpty ?? false)) ...[
            SizedBox(height: grid.px(3)),
            SukiRewardLadder(
              tiers: data.effectiveTiers,
              visits: card?.visits ?? 0,
            ),
          ],
          if (p.points.enabled) ...[
            SizedBox(height: grid.px(3)),
            SukiPointsMenu(
              program: p,
              points: card?.points ?? p.points,
              menu: data.pointsMenu,
              cardId: card?.cardId,
            ),
          ],
          SizedBox(height: grid.px(3)),
          if (p.staffScan)
            passButton
          else ...[
            PixelButton(
              key: const ValueKey('suki_card_scan'),
              label: tr(context, en: 'Scan Suki', tl: 'I-scan ang Suki'),
              expand: true,
              onPressed: () => scanSukiStandee(context, ref),
            ),
            SizedBox(height: grid.px(2)),
            passButton,
          ],
        ],
      ),
    );
  }

  Widget _reward(BuildContext context, PixelGrid grid, SukiReward reward) {
    return PixelPanel(
      key: ValueKey('suki_reward_${reward.id}'),
      style: PixelBoxStyle.gold,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, en: 'Your reward', tl: 'Ang reward mo'),
              textAlign: TextAlign.center, style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(reward.rewardText,
              textAlign: TextAlign.center, style: PixelType.body(context)),
          SizedBox(height: grid.px(2)),
          if (reward.claimable) ...[
            Center(
              child: PixelPanel(
                style: PixelBoxStyle.slot.copyWith(fill: PixelPalette.white),
                padding: 2,
                child: QrImageView(
                  data: reward.code,
                  size: 180,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Suki reward QR code',
                ),
              ),
            ),
            SizedBox(height: grid.px(1)),
            SelectableText(reward.code,
                textAlign: TextAlign.center, style: PixelType.body(context)),
            SizedBox(height: grid.px(1)),
            Text(
              tr(context,
                  en: 'Show this at the counter. Staff scan it once.',
                  tl: 'Ipakita sa counter. Isang beses lang i-scan.'),
              textAlign: TextAlign.center,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            if (reward.expiresAt != null)
              Text(
                tr(context,
                    en: 'Valid until ${_day(reward.expiresAt!)}',
                    tl: 'Hanggang ${_day(reward.expiresAt!)}'),
                textAlign: TextAlign.center,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
          ] else
            Text(
              reward.expired
                  ? tr(context,
                      en: 'This reward has expired.',
                      tl: 'Expired na ang reward.')
                  : tr(context, en: 'Claimed', tl: 'Nakuha na'),
              key: ValueKey('suki_reward_state_${reward.id}'),
              textAlign: TextAlign.center,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
        ],
      ),
    );
  }
}

String _day(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}
