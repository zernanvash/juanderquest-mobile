import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../../suki/widgets/suki_card_skin.dart';
import 'merchant_suki_models.dart';
import 'suki_badge_art.dart';

/// Plan 107 / Plan 111: the live preview of what customers see (an empty card).
class SukiCardPreview extends StatelessWidget {
  const SukiCardPreview({
    super.key,
    required this.title,
    required this.visitsRequired,
    required this.rewardTag,
    required this.rewardText,
    this.tiers = const [],
  });

  final String title;
  final int visitsRequired;
  final String rewardTag;
  final String rewardText;
  final List<MerchantSukiTier> tiers;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final slot = grid.px(11);
    final byVisit = <int, MerchantSukiTier>{
      for (final t in tiers) t.visitNumber: t,
    };
    return PixelPanel(
      key: const ValueKey('suki_card_preview'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: PixelType.title(context)),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (var i = 1; i <= visitsRequired; i++)
                SizedBox.square(
                  dimension: slot,
                  child: PixelPanel(
                    style: i == visitsRequired || byVisit.containsKey(i)
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.slot,
                    sunken: i != visitsRequired && !byVisit.containsKey(i),
                    padding: 0,
                    child: Center(
                      child: i == visitsRequired || byVisit.containsKey(i)
                          ? PixelSprite(
                              SukiTierArt.byKey(byVisit[i]?.iconKey ?? 'gift'),
                              scale: 2)
                          : Text('$i',
                              textScaler: TextScaler.noScaling,
                              style: PixelType.small(context,
                                  color: PixelPalette.stone)),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(rewardTag,
                  key: const ValueKey('suki_preview_tag'),
                  style: PixelBoxStyle.gold),
              Text(
                tr(context,
                    en: '$visitsRequired visits for: $rewardText',
                    tl: '$visitsRequired bisita para sa: $rewardText'),
                style: PixelType.body(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plan 107 §6.7: the 30-day stats panel (aggregates and pseudonyms only).
class SukiStatsPanel extends StatelessWidget {
  const SukiStatsPanel({super.key, required this.stats, this.today});

  final MerchantSukiStats stats;

  /// Test seam; defaults to today's Manila date.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final s = stats;
    final end =
        today ?? DateTime.now().toUtc().add(const Duration(hours: 8)); // Manila
    final days = [
      for (var i = s.days - 1; i >= 0; i--)
        s.visitsByDay[_ymd(end.subtract(Duration(days: i)))] ?? 0,
    ];
    final peak = days.fold(0, (a, b) => b > a ? b : a);
    Widget stat(String label, int value) => Padding(
          padding: EdgeInsets.symmetric(vertical: grid.px(1) / 2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: PixelType.body(context))),
              SizedBox(width: grid.px(1)),
              Text('$value', style: PixelType.numbers(context)),
            ],
          ),
        );
    return PixelPanel(
      key: const ValueKey('loyalty_stats'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              tr(context,
                  en: 'Last ${s.days} days', tl: 'Huling ${s.days} araw'),
              style: PixelType.title(context)),
          SizedBox(height: grid.px(2)),
          SizedBox(
            key: const ValueKey('loyalty_stats_bars'),
            height: grid.px(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: FractionallySizedBox(
                        heightFactor:
                            peak == 0 ? 0.05 : (v / peak).clamp(0.05, 1),
                        child: ColoredBox(
                          color: v == 0
                              ? PixelPalette.mist
                              : PixelPalette.greenBright,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
          stat(tr(context, en: 'Visits', tl: 'Bisita'), s.totalVisits),
          stat(tr(context, en: 'Customers', tl: 'Customer'), s.uniqueCustomers),
          stat(tr(context, en: 'Came back', tl: 'Bumalik'), s.repeatCustomers),
          stat(
              tr(context,
                  en: 'New to JuanderQuest', tl: 'Bago sa JuanderQuest'),
              s.newToApp),
          stat(
              tr(context,
                  en: 'Vouchers confirmed', tl: 'Voucher na nakumpirma'),
              s.vouchersConfirmed),
          if (s.pointsIssued > 0 || s.pointsRedeemed > 0) ...[
            stat(tr(context, en: 'Points issued', tl: 'Naibigay na points'),
                s.pointsIssued),
            stat(
                tr(context, en: 'Points redeemed', tl: 'Nagamit na points'),
                s.pointsRedeemed),
          ],
          SizedBox(height: grid.px(2)),
          Text(
            tr(context,
                en: 'Rewards claimed: ${s.rewardsClaimed} of ${s.rewardsIssued}',
                tl: 'Nakuhang reward: ${s.rewardsClaimed} sa ${s.rewardsIssued}'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelProgressBar(value: s.claimRate, idle: false),
          if (s.topRegulars.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(tr(context, en: 'Top regulars', tl: 'Mga suki'),
                style: PixelType.small(context, color: PixelPalette.slate)),
            for (final r in s.topRegulars)
              Text('${r.label} · ${r.visits}', style: PixelType.body(context)),
          ],
        ],
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Plan 107 §7.4: the counter scan result. Returns true for "Scan next".
Future<bool> showSukiScanResult(
  BuildContext context,
  MerchantSukiScanResult result,
) async {
  final (icon, label, style) = switch (result.kind) {
    'reward' => (
        SukiBadgeArt.gift,
        tr(context, en: 'REWARD', tl: 'REWARD'),
        PixelBoxStyle.gold,
      ),
    'voucher' => (
        SukiBadgeArt.sukiRegular,
        tr(context, en: 'VOUCHER', tl: 'VOUCHER'),
        PixelBoxStyle.parchment,
      ),
    _ => (
        HomePixelArt.stampCheck,
        tr(context, en: 'VISIT', tl: 'BISITA'),
        PixelBoxStyle.green,
      ),
  };
  final next = await showPixelDialog<bool>(
    context: context,
    title: result.title.isEmpty
        ? tr(context, en: 'Done', tl: 'Tapos')
        : result.title,
    content: Column(
      key: ValueKey('loyalty_scan_result_${result.kind}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelSprite(icon, scale: icon.width > 8 ? 3 : 5),
        const SizedBox(height: 8),
        PixelChip(label,
            style: style,
            textColor: style == PixelBoxStyle.green
                ? PixelPalette.white
                : PixelPalette.ink),
        const SizedBox(height: 8),
        Text(result.customer,
            key: const ValueKey('loyalty_scan_customer'),
            textAlign: TextAlign.center,
            style: PixelType.title(context)),
        const SizedBox(height: 4),
        Text(result.detail,
            textAlign: TextAlign.center, style: PixelType.body(context)),
        if (result.pointsAwarded > 0) ...[
          const SizedBox(height: 6),
          PixelChip('+${result.pointsAwarded} Suki Points',
              key: const ValueKey('loyalty_scan_points'),
              style: PixelBoxStyle.gold),
        ],
      ],
    ),
    actions: [
      Builder(
        builder: (ctx) => PixelButton(
          key: const ValueKey('loyalty_scan_next'),
          label: tr(ctx, en: 'Scan next', tl: 'Susunod'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
      Builder(
        builder: (ctx) => PixelButton(
          key: const ValueKey('loyalty_scan_done'),
          label: tr(ctx, en: 'Done', tl: 'Tapos'),
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ],
  );
  return next == true;
}
