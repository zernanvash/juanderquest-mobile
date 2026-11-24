import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../models/suki_models.dart';
import '../providers/suki_provider.dart';
import '../screens/suki_cards_screen.dart' show SukiErrorPanel;

/// Plan 111 §6 (`/suki/:programId/points`): cursor-paginated Suki Points history.
class SukiPointsHistoryScreen extends ConsumerStatefulWidget {
  const SukiPointsHistoryScreen({
    super.key,
    required this.programId,
    this.cardId,
    this.shopName,
  });

  final String programId;
  final String? cardId;
  final String? shopName;

  @override
  ConsumerState<SukiPointsHistoryScreen> createState() =>
      _SukiPointsHistoryScreenState();
}

class _SukiPointsHistoryScreenState
    extends ConsumerState<SukiPointsHistoryScreen> {
  String? _resolvedCardId;
  int _balance = 0;
  int _lifetime = 0;
  final List<SukiPointsLedgerEntry> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolvedCardId =
        widget.cardId != null && widget.cardId!.isNotEmpty ? widget.cardId : null;
    Future.microtask(_loadInitial);
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var cardId = _resolvedCardId;
      if (cardId == null) {
        final detail =
            await ref.read(sukiApiProvider).program(widget.programId);
        cardId = detail.card?.cardId;
      }
      if (cardId == null || cardId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _items.clear();
          _nextCursor = null;
        });
        return;
      }
      final page = await ref.read(sukiApiProvider).cardPoints(cardId);
      if (!mounted) return;
      setState(() {
        _resolvedCardId = cardId;
        _balance = page.balance;
        _lifetime = page.lifetime;
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cardId = _resolvedCardId;
    final cursor = _nextCursor;
    if (cardId == null || cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await ref.read(sukiApiProvider).cardPoints(cardId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _balance = page.balance;
        _lifetime = page.lifetime;
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) showPixelToast(context, sukiErrorText(context, error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  title: widget.shopName?.isNotEmpty == true
                      ? '${widget.shopName!} · Points'
                      : tr(context, en: 'Suki Points', tl: 'Suki Points'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(child: _body(context, grid)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _body(BuildContext context, PixelGrid grid) {
    if (_loading) {
      return Center(
        child: PixelLoader(
            label: tr(context,
                en: 'Loading points history', tl: 'Kinukuha ang history')),
      );
    }
    if (_error != null) {
      return ListView(
        padding: EdgeInsets.all(grid.gutter),
        children: [SukiErrorPanel(error: _error!)],
      );
    }
    return RefreshIndicator(
      color: PixelPalette.green,
      backgroundColor: PixelPalette.parchment,
      onRefresh: _loadInitial,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            grid.gutter,
            grid.px(3),
            grid.gutter,
            grid.px(8) + MediaQuery.paddingOf(context).bottom),
        children: [
          PixelPanel(
            key: const ValueKey('suki_points_summary'),
            style: PixelBoxStyle.gold,
            padding: 2,
            child: Wrap(
              spacing: grid.px(3),
              runSpacing: grid.px(1),
              children: [
                Text(
                  tr(context,
                      en: 'Balance: $_balance pts',
                      tl: 'Balanse: $_balance pts'),
                  style: PixelType.title(context),
                ),
                Text(
                  tr(context,
                      en: 'Lifetime: $_lifetime pts',
                      tl: 'Kabuuan: $_lifetime pts'),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(3)),
          if (_items.isEmpty)
            PixelPanel(
              style: PixelBoxStyle.parchment,
              padding: 2,
              child: Text(
                tr(context,
                    en: 'No points activity yet.',
                    tl: 'Wala pang points activity.'),
                textAlign: TextAlign.center,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            )
          else
            PixelPanel(
              style: PixelBoxStyle.parchment,
              padding: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0)
                      Container(height: grid.unit, color: PixelPalette.paperDim),
                    _entryRow(context, grid, _items[i]),
                  ],
                ],
              ),
            ),
          if (_nextCursor != null) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('suki_points_load_more'),
              label: tr(context, en: 'Load more', tl: 'Mag-load pa'),
              variant: PixelButtonVariant.secondary,
              loading: _loadingMore,
              expand: true,
              onPressed: _loadMore,
            ),
          ],
        ],
      ),
    );
  }

  Widget _entryRow(
      BuildContext context, PixelGrid grid, SukiPointsLedgerEntry e) {
    final label = switch (e.reason) {
      'visit' => tr(context, en: 'Counter visit', tl: 'Bisita sa counter'),
      'spend' => e.amountSpent != null
          ? tr(context,
              en: 'Spend bonus (₱${e.amountSpent!.round()})',
              tl: 'Spend bonus (₱${e.amountSpent!.round()})')
          : tr(context, en: 'Spend bonus', tl: 'Spend bonus'),
      'redeem' => tr(context, en: 'Points redeemed', tl: 'Ginamit na points'),
      'expire' => tr(context, en: 'Expired points', tl: 'Nag-expire na points'),
      _ => tr(context, en: 'Adjustment', tl: 'Adjustment'),
    };
    final positive = e.delta > 0;
    final date = e.createdAt == null
        ? ''
        : _formatDate(e.createdAt!.toLocal());
    return Padding(
      key: ValueKey('suki_ledger_entry_${e.id}'),
      padding: EdgeInsets.symmetric(vertical: grid.px(1)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PixelType.body(context)),
                if (date.isNotEmpty)
                  Text(date,
                      style: PixelType.small(context, color: PixelPalette.slate)),
              ],
            ),
          ),
          SizedBox(width: grid.px(1)),
          Text(
            positive ? '+${e.delta} pts' : '${e.delta} pts',
            style: PixelType.numbers(
              context,
              color: positive ? PixelPalette.greenDark : PixelPalette.redDeep,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
