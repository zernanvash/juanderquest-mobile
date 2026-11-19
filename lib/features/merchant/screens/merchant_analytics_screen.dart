import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';

/// Plan 110b: Merchant sponsorship & voucher ROI analytics (`GET /merchant/analytics`).
class MerchantAnalyticsScreen extends ConsumerStatefulWidget {
  const MerchantAnalyticsScreen({super.key});

  @override
  ConsumerState<MerchantAnalyticsScreen> createState() =>
      _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState
    extends ConsumerState<MerchantAnalyticsScreen> {
  static const _windows = [7, 30, 90];

  int _days = 30;
  MerchantAnalyticsData? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(_days));
  }

  Future<void> _load(int days) async {
    setState(() {
      _days = days;
      _loading = true;
    });
    try {
      final result = await ref.read(merchantApiProvider).analytics(days: days);
      if (mounted) setState(() => (_data = result, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final data = _data;
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context,
                      en: 'Shop analytics', tl: 'Estadistika ng shop'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading && data == null
                      ? const Center(
                          child: PixelLoader(label: 'Loading analytics'))
                      : data == null
                          ? Center(
                              child: PixelEmptyState(
                                icon: DesignerArt.gem,
                                title: tr(context,
                                    en: 'Analytics unavailable',
                                    tl: 'Hindi makuha'),
                                message: _error?.toString() ??
                                    'Check your connection and try again.',
                                action: PixelButton(
                                  label: tr(context,
                                      en: 'Retry', tl: 'Subukang muli'),
                                  onPressed: () => _load(_days),
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: PixelPalette.green,
                              backgroundColor: PixelPalette.parchment,
                              onRefresh: () => _load(_days),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    grid.gutter,
                                    grid.px(3),
                                    grid.gutter,
                                    grid.px(8) +
                                        MediaQuery.paddingOf(context).bottom),
                                children: [
                                  Wrap(
                                    spacing: grid.px(1),
                                    runSpacing: grid.px(1),
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        tr(context,
                                            en: 'Window:', tl: 'Panahon:'),
                                        style: PixelType.small(context,
                                            color: PixelPalette.slate),
                                      ),
                                      for (final d in _windows)
                                        GestureDetector(
                                          key: ValueKey('analytics_days_$d'),
                                          onTap: _loading
                                              ? null
                                              : () => _load(d),
                                          child: PixelChip(
                                            '${d}d',
                                            style: _days == d
                                                ? PixelBoxStyle.gold
                                                : PixelBoxStyle.slot,
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  _metricSection(
                                    context,
                                    grid,
                                    key: const ValueKey(
                                        'analytics_funding_panel'),
                                    title: tr(context,
                                        en: 'Sponsorship ROI',
                                        tl: 'Sponsorship ROI'),
                                    icon: DesignerArt.handshake,
                                    metrics: [
                                      (
                                        'Active sponsors',
                                        '${data.funding.activeSponsorships}',
                                      ),
                                      (
                                        'Points committed',
                                        '${data.funding.totalPointsCommitted}',
                                      ),
                                      (
                                        'Points paid',
                                        '${data.funding.totalPointsPaid}',
                                      ),
                                      (
                                        'Funded completions',
                                        '${data.funding.fundedCompletions}',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  _metricSection(
                                    context,
                                    grid,
                                    key: const ValueKey(
                                        'analytics_vouchers_panel'),
                                    title: tr(context,
                                        en: 'Voucher funnel (${data.days}d)',
                                        tl: 'Voucher (${data.days}d)'),
                                    icon: DesignerArt.navShop,
                                    metrics: [
                                      (
                                        'Active offers',
                                        '${data.vouchers.activeCatalogCount}',
                                      ),
                                      (
                                        'Shop redeemed',
                                        '${data.vouchers.shopRedeemedInWindow}',
                                      ),
                                      (
                                        'Quest perks',
                                        '${data.vouchers.perksGrantedInWindow}',
                                      ),
                                      (
                                        'Counter used',
                                        '${data.vouchers.confirmedAtCounterInWindow}',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  _metricSection(
                                    context,
                                    grid,
                                    key: const ValueKey(
                                        'analytics_suki_panel'),
                                    title: tr(context,
                                        en: 'Suki loyalty (${data.days}d)',
                                        tl: 'Suki (${data.days}d)'),
                                    icon: DesignerArt.gem,
                                    metrics: [
                                      (
                                        'Total visits',
                                        '${data.suki.visitsInWindow}',
                                      ),
                                      (
                                        'Unique customers',
                                        '${data.suki.uniqueCustomers}',
                                      ),
                                      (
                                        'Repeat visitors',
                                        '${data.suki.repeatCustomers}',
                                      ),
                                      (
                                        'Rewards issued',
                                        '${data.suki.rewardsIssued}',
                                      ),
                                      (
                                        'Rewards claimed',
                                        '${data.suki.rewardsClaimed}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _metricSection(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required String title,
    required PixelArt icon,
    required List<(String, String)> metrics,
  }) {
    return PixelPanel(
      key: key,
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(title, icon: icon),
          SizedBox(height: grid.px(2)),
          LayoutBuilder(builder: (ctx, constraints) {
            final scale =
                MediaQuery.textScalerOf(ctx).scale(1.0).clamp(1.0, 2.5);
            final gap = grid.px(2);
            final cols = (constraints.maxWidth / (130 * scale))
                .floor()
                .clamp(1, 2);
            final width = (constraints.maxWidth - (cols - 1) * gap) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: width,
                    child: PixelPanel(
                      style: PixelBoxStyle.slot,
                      padding: 1,
                      child: Padding(
                        padding: EdgeInsets.all(grid.px(1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.$1,
                              style: PixelType.small(ctx,
                                  color: PixelPalette.slate),
                            ),
                            SizedBox(height: grid.px(1)),
                            Text(
                              m.$2,
                              style: PixelType.numbers(ctx,
                                  color: PixelPalette.greenDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
