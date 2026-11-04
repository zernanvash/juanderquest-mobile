import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../profile/providers/profile_stats_provider.dart';
import '../../spots/models/hidden_gem_model.dart';
import '../../spots/providers/hidden_gem_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../providers/home_daily_provider.dart';
import 'home_widgets.dart';

class HomeCollectionTab extends StatelessWidget {
  const HomeCollectionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PassportSection(),
        SizedBox(height: grid.px(2)),
        const _HiddenGemSection(),
      ],
    );
  }
}

class _PassportSection extends ConsumerWidget {
  const _PassportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final daily = ref.watch(homeDailyProvider);
    final claim = ref.watch(homeDailyClaimProvider);
    final stats = ref.watch(profileStatsProvider);
    final spots = ref.watch(spotDiscoveryProvider);
    final earned = [
      stats.ecoPioneerState,
      stats.heritageKeeperState,
      stats.foodExplorerState,
    ].where((state) => state == BadgeState.earned).length;
    final saved = spots.spots.where((spot) => spot.saved).length;
    final badges = <(String, BadgeState, String)>[
      ('Eco Pioneer', stats.ecoPioneerState, 'home_badge_eco'),
      ('Heritage Keeper', stats.heritageKeeperState, 'home_badge_heritage'),
      ('Food Explorer', stats.foodExplorerState, 'home_badge_food'),
    ];
    return HomePanel(
      key: const ValueKey('home_passport_panel'),
      title: 'Passport',
      subtitle: 'Stamps, badges and saved places',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          daily.when(
            loading: () => const HomeInlineLoading(label: 'Loading stamps'),
            error: (_, __) => HomeErrorPanel(
              message: 'Stamps are unavailable.',
              retryKey: const ValueKey('home_collection_stamps_retry'),
              onRetry: () => ref.invalidate(homeDailyProvider),
            ),
            data: (data) {
              final latest = claim.latest;
              final state =
                  latest != null && latest.date == data.date ? latest : data;
              return HomeStatSlot(
                key: const ValueKey('home_collection_stamps'),
                label: 'Passport stamps',
                value: '${state.stamps}',
                onTap: () => context.go('/profile'),
              );
            },
          ),
          SizedBox(height: grid.px(1)),
          HomeStatSlot(
            key: const ValueKey('home_collection_badges'),
            label: 'Badges earned',
            value: '$earned of 3',
            onTap: () => context.go('/profile'),
          ),
          SizedBox(height: grid.px(1)),
          if (spots.failure != null && spots.spots.isEmpty)
            HomeErrorPanel(
              message: 'Saved spots are unavailable.',
              retryKey: const ValueKey('home_collection_saved_retry'),
              onRetry: () =>
                  ref.read(spotDiscoveryProvider.notifier).load(refresh: true),
            )
          else ...[
            HomeStatSlot(
              key: const ValueKey('home_collection_saved'),
              label: 'Saved spots',
              value: '$saved',
              onTap: () => context.push('/saved'),
            ),
            if (saved == 0) ...[
              SizedBox(height: grid.px(1)),
              const HomeEmptyText('No saved spots yet.'),
            ],
          ],
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final badge in badges)
                PixelChip(
                  badge.$1,
                  key: ValueKey(badge.$3),
                  style: badge.$2 == BadgeState.earned
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.slot,
                  textColor: badge.$2 == BadgeState.earned
                      ? PixelPalette.white
                      : PixelPalette.slate,
                  onTap: () => context.go('/profile'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenGemSection extends ConsumerWidget {
  const _HiddenGemSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final gems = ref.watch(hiddenGemProvider);
    return HomePanel(
      key: const ValueKey('home_hidden_gems_panel'),
      title: 'Hidden gem highlights',
      subtitle: 'Discovery picks, not sponsored',
      actionLabel: 'Explore',
      onAction: () => context.push('/explore'),
      child: gems.when(
        loading: () => const HomeInlineLoading(label: 'Finding hidden gems'),
        error: (_, __) => HomeErrorPanel(
          message: 'Hidden gem highlights are unavailable.',
          retryKey: const ValueKey('home_hidden_gems_retry'),
          onRetry: () => ref.invalidate(hiddenGemProvider),
        ),
        data: (items) => items.isEmpty
            ? const HomeEmptyText('No hidden gems today.')
            : Column(
                children: [
                  for (var i = 0; i < items.take(3).length; i++) ...[
                    if (i > 0) SizedBox(height: grid.px(1)),
                    _HiddenGemRow(gem: items[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HiddenGemRow extends StatelessWidget {
  const _HiddenGemRow({required this.gem});

  final HiddenGemModel gem;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      label: 'Open hidden gem ${gem.name}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_hidden_gem_${gem.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/explore/${Uri.encodeComponent(gem.id)}'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          gem.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.body(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      Flexible(
                        child: PixelChip(
                          gem.crowdLabel,
                          style: PixelBoxStyle.slot,
                          textColor: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(0.5)),
                  Text(
                    gem.municipality,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.greenDark,
                    ),
                  ),
                  SizedBox(height: grid.px(0.5)),
                  Text(
                    gem.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
