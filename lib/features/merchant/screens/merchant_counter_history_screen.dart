import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';

/// Plan 110b: Counter scan & confirmation log (`GET /merchant/counter/history`).
class MerchantCounterHistoryScreen extends ConsumerStatefulWidget {
  const MerchantCounterHistoryScreen({super.key});

  @override
  ConsumerState<MerchantCounterHistoryScreen> createState() =>
      _MerchantCounterHistoryScreenState();
}

class _MerchantCounterHistoryScreenState
    extends ConsumerState<MerchantCounterHistoryScreen> {
  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('voucher', 'Vouchers'),
    ('visit', 'Visits'),
    ('suki_reward', 'Rewards'),
  ];

  List<MerchantCounterEvent>? _events;
  Object? _error;
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          await ref.read(merchantApiProvider).counterHistory(limit: 50);
      if (mounted) setState(() => (_events = list, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _kindLabel(String kind) => switch (kind) {
        'visit' => 'SUKI VISIT',
        'suki_reward' => 'SUKI REWARD',
        _ => 'VOUCHER',
      };

  PixelBoxStyle _kindStyle(String kind) => switch (kind) {
        'visit' => PixelBoxStyle.green,
        'suki_reward' => PixelBoxStyle.gold,
        _ => PixelBoxStyle.slot,
      };

  Color _kindTextColor(String kind) =>
      kind == 'visit' ? PixelPalette.white : PixelPalette.ink;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final all = _events;
        final visible = all == null
            ? const <MerchantCounterEvent>[]
            : _filter == 'all'
                ? all
                : all.where((e) => e.kind == _filter).toList();
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context,
                      en: 'Counter history', tl: 'Kasaysayan ng counter'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading && all == null
                      ? const Center(
                          child: PixelLoader(label: 'Loading history'))
                      : all == null
                          ? Center(
                              child: PixelEmptyState(
                                icon: DesignerArt.handshake,
                                title: tr(context,
                                    en: 'History unavailable',
                                    tl: 'Hindi makuha'),
                                message: _error?.toString() ??
                                    'Check your connection and try again.',
                                action: PixelButton(
                                  label: tr(context,
                                      en: 'Retry', tl: 'Subukang muli'),
                                  onPressed: _load,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: PixelPalette.green,
                              backgroundColor: PixelPalette.parchment,
                              onRefresh: _load,
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
                                    children: [
                                      for (final f in _filters)
                                        GestureDetector(
                                          key: ValueKey(
                                              'counter_history_filter_${f.$1}'),
                                          onTap: () =>
                                              setState(() => _filter = f.$1),
                                          child: PixelChip(
                                            f.$2,
                                            style: _filter == f.$1
                                                ? PixelBoxStyle.gold
                                                : PixelBoxStyle.slot,
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  if (visible.isEmpty)
                                    PixelEmptyState(
                                      key: const ValueKey(
                                          'counter_history_empty'),
                                      icon: DesignerArt.handshake,
                                      title: tr(context,
                                          en: 'No counter events yet',
                                          tl: 'Wala pang naiscan'),
                                      message: tr(context,
                                          en: 'Confirmed vouchers and Suki visits will appear here.',
                                          tl: 'Lalabas dito ang mga nakumpirmang voucher at Suki.'),
                                    )
                                  else
                                    for (var i = 0;
                                        i < visible.length;
                                        i++) ...[
                                      _eventCard(context, grid, i, visible[i]),
                                      SizedBox(height: grid.px(2)),
                                    ],
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

  Widget _eventCard(
    BuildContext context,
    PixelGrid grid,
    int index,
    MerchantCounterEvent e,
  ) {
    final ts = _formatDate(e.at);
    return PixelPanel(
      key: ValueKey('counter_history_item_$index'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                _kindLabel(e.kind),
                style: _kindStyle(e.kind),
                textColor: _kindTextColor(e.kind),
              ),
              PixelChip(e.customer, style: PixelBoxStyle.slot),
              if (e.method != null)
                PixelChip(e.method!, style: PixelBoxStyle.slot),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(e.detail, style: PixelType.title(context)),
          if (e.code != null)
            Text(e.code!,
                style: PixelType.numbers(context, color: PixelPalette.ink)),
          if (e.staffName != null || ts.isNotEmpty)
            Text(
              [
                if (e.staffName != null) 'Confirmed by ${e.staffName}',
                if (ts.isNotEmpty) ts,
              ].join(' · '),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
        ],
      ),
    );
  }
}
