import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../cosmetics/widgets/cosmetic_avatar.dart';
import '../spots/studio/pixel/studio_icons.dart';
import '../vote/pixel/wave3_art.dart';
import 'activity_text.dart';
import 'plaza_models.dart';
import 'plaza_provider.dart';

class PlazaScreen extends ConsumerStatefulWidget {
  final String? initialActivityId;
  final bool initialOpenComments;

  const PlazaScreen({
    super.key,
    this.initialActivityId,
    this.initialOpenComments = false,
  });

  @override
  ConsumerState<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends ConsumerState<PlazaScreen>
    with SingleTickerProviderStateMixin {
  String _board = 'everyone';
  String _period = 'weekly';
  bool _askedPush = true;

  Color? _cosmeticColor(dynamic value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  @override
  void initState() {
    super.initState();
    _checkPushPrompt();
  }

  Future<void> _checkPushPrompt() async {
    final push = ref.read(pushServiceProvider);
    final asked = await push.hasAskedPermission();
    if (mounted) {
      setState(() {
        _askedPush = asked;
      });
    }
  }

  Future<void> _reloadFeed() =>
      ref.read(plazaFeedProvider.notifier).loadFeed(reset: true);

  @override
  Widget build(BuildContext context) {
    final standingsKey = '$_board:$_period';
    final standingsAsync = ref.watch(plazaStandingsProvider(standingsKey));
    final feedAsync = ref.watch(plazaFeedProvider);
    final user = ref.watch(authProvider).user;
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Plaza',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      PixelIconButton(
                        icon: Wave3Art.refresh,
                        semanticLabel: 'Refresh Plaza',
                        onPressed: () {
                          ref.invalidate(plazaStandingsProvider(standingsKey));
                          _reloadFeed();
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: () async {
                        ref.invalidate(plazaStandingsProvider(standingsKey));
                        await _reloadFeed();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          _hero(context, grid),
                          SizedBox(height: grid.px(3)),
                          if (!_askedPush && user != null) ...[
                            _alerts(context, grid),
                            SizedBox(height: grid.px(3)),
                          ],
                          _controls(context, grid),
                          SizedBox(height: grid.px(3)),
                          standingsAsync.when(
                            loading: () => const Center(
                                child: PixelLoader(label: 'Loading standings')),
                            error: (err, _) => _standingsError(
                              context,
                              grid,
                              'Standings unavailable: $err',
                              () => ref.invalidate(
                                  plazaStandingsProvider(standingsKey)),
                              retryKey: const ValueKey('plaza_retry'),
                            ),
                            data: (data) => _standings(context, grid, data),
                          ),
                          SizedBox(height: grid.px(4)),
                          _feedHeader(context, grid),
                          SizedBox(height: grid.px(2)),
                          feedAsync.when(
                            loading: () => const Center(
                                child: PixelLoader(label: 'Loading activity')),
                            error: (err, _) => _standingsError(
                              context,
                              grid,
                              'No recent activity to display.',
                              _reloadFeed,
                              retryKey: const ValueKey('plaza_feed_retry'),
                            ),
                            data: (activities) {
                              if (activities.isEmpty) {
                                return const PixelEmptyState(
                                  key: ValueKey('plaza_feed_empty'),
                                  title: 'No activities yet',
                                  message:
                                      'No activities found. Explore quests to appear on the Plaza!',
                                );
                              }
                              return Column(
                                children: [
                                  for (final activity in activities) ...[
                                    _activity(context, grid, activity),
                                    SizedBox(height: grid.px(2)),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pangasinan Plaza',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Track community ranks, cheer explorer journeys, and follow local adventurers.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
        ],
      ),
    );
  }

  Widget _alerts(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Turn on Plaza alerts', style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            'Know immediately when someone passes your rank.',
            style: PixelType.body(context, color: PixelPalette.goldDeep),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                key: const ValueKey('plaza_alerts_on'),
                label: 'Turn on',
                onPressed: () async {
                  final granted = await ref
                      .read(pushServiceProvider)
                      .requestPermissionAndRegister();
                  if (!mounted || !context.mounted) return;
                  setState(() {
                    _askedPush = true;
                  });
                  showPixelToast(
                    context,
                    granted ? 'Alerts enabled!' : 'Notifications declined',
                  );
                },
              ),
              PixelButton(
                key: const ValueKey('plaza_alerts_not_now'),
                label: 'Not now',
                variant: PixelButtonVariant.secondary,
                onPressed: () {
                  setState(() {
                    _askedPush = true;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context, PixelGrid grid) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolbarChip(
            context,
            grid,
            label: 'Everyone',
            selected: _board == 'everyone',
            onTap: () => setState(() => _board = 'everyone'),
          ),
          SizedBox(width: grid.px(1)),
          _toolbarChip(
            context,
            grid,
            label: 'Following',
            selected: _board == 'following',
            onTap: () => setState(() => _board = 'following'),
          ),
          SizedBox(width: grid.px(1)),
          _toolbarChip(
            context,
            grid,
            label: 'My Town',
            selected: _board == 'town',
            onTap: () => setState(() => _board = 'town'),
          ),
          SizedBox(width: grid.px(2)),
          Container(
            width: 2,
            height: grid.px(5),
            color: PixelPalette.paperDim,
          ),
          SizedBox(width: grid.px(2)),
          _toolbarChip(
            context,
            grid,
            label: 'This Week',
            selected: _period == 'weekly',
            onTap: () => setState(() => _period = 'weekly'),
          ),
          SizedBox(width: grid.px(1)),
          _toolbarChip(
            context,
            grid,
            label: 'All Time',
            selected: _period == 'all_time',
            onTap: () => setState(() => _period = 'all_time'),
          ),
        ],
      ),
    );
  }

  Widget _toolbarChip(
    BuildContext context,
    PixelGrid grid, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return PixelChip(
      label,
      style: selected ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
      textColor: selected ? PixelPalette.ink : PixelPalette.slate,
      onTap: () {
        pixelTick(context);
        onTap();
      },
    );
  }

  Widget _standingsError(
    BuildContext context,
    PixelGrid grid,
    String message,
    VoidCallback retry, {
    Key? retryKey,
  }) {
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(2)),
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              key: retryKey,
              label: 'Retry',
              onPressed: retry,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedHeader(BuildContext context, PixelGrid grid) {
    // Filter under the title, full width: squeezed beside it, "Following"
    // was cut to "FOLLOW…".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Live explorer activity', style: PixelType.title(context)),
        SizedBox(height: grid.px(1)),
        SizedBox(
          key: const ValueKey('plaza_feed_scope'),
          child: PixelSegmented(
            items: const ['All', 'Following'],
            selectedIndex: ref.watch(plazaFeedProvider.notifier).scope == 'mixed'
                ? 0
                : 1,
            onChanged: (index) => ref
                .read(plazaFeedProvider.notifier)
                .setScope(index == 0 ? 'mixed' : 'following'),
          ),
        ),
      ],
    );
  }

  Widget _standings(
      BuildContext context, PixelGrid grid, Map<String, dynamic> data) {
    final entriesRaw = data['entries'] as List<dynamic>? ?? [];
    final entries = entriesRaw
        .map((e) => StandingEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meRaw = data['me'] as Map<String, dynamic>?;
    final me = meRaw != null ? StandingEntryModel.fromJson(meRaw) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (me != null) ...[
          PixelPanel(
            style: PixelBoxStyle.green,
            child: Row(
              children: [
                PixelChip('#${me.rank}',
                    style: PixelBoxStyle.gold),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.displayName,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.white,
                        ),
                      ),
                      Text(
                        '${me.score} pts · ${me.quests} ${me.quests == 1 ? 'quest' : 'quests'}',
                        style: PixelType.body(
                          context,
                          color: PixelPalette.cream,
                        ),
                      ),
                    ],
                  ),
                ),
                if (me.delta != null)
                  Text(
                    me.delta! > 0
                        ? '+${me.delta}'
                        : (me.delta! < 0 ? '${me.delta}' : '-'),
                    style: PixelType.numbers(
                      context,
                      color: PixelPalette.white,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        for (final scout in entries) ...[
          PixelPanel(
            style: scout.isSelf
                ? PixelBoxStyle.green
                : PixelBoxStyle.parchment,
            child: Row(
              children: [
                PixelChip(
                  '#${scout.rank}',
                  style: scout.rank <= 3
                      ? PixelBoxStyle.gold
                      : PixelBoxStyle.slot,
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scout.displayName,
                        maxLines: 2,
                        style: PixelType.title(
                          context,
                          color: scout.isSelf
                              ? PixelPalette.white
                              : PixelPalette.ink,
                        ),
                      ),
                      Text(
                        '${scout.homeTown ?? 'Pangasinan'} · ${scout.quests} ${scout.quests == 1 ? 'quest' : 'quests'}',
                        style: PixelType.body(
                          context,
                          color: scout.isSelf
                              ? PixelPalette.cream
                              : PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: grid.px(2)),
                Text(
                  '${scout.score} pts',
                  style: PixelType.numbers(
                    context,
                    color: scout.isSelf
                        ? PixelPalette.white
                        : PixelPalette.greenDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(1)),
        ],
      ],
    );
  }

  Widget _activity(
      BuildContext context, PixelGrid grid, ActivityItemModel activity) {
    final formatted = formatActivityText(activity);
    return PixelPanel(
      key: ValueKey('plaza_activity_${activity.id}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CosmeticAvatar(
                name: activity.actorName,
                imageUrl: activity.actorAvatar,
                frame:
                    activity.actorCosmetics?['frame']?['asset'] as Map<String, dynamic>?,
                size: grid.px(14),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.actorName,
                      maxLines: 2,
                      style: PixelType.title(
                        context,
                        color: _cosmeticColor(
                                activity.actorCosmetics?['nameColor']?['asset']
                                    ?['color']) ??
                            PixelPalette.ink,
                      ),
                    ),
                    if ((activity.actorCosmetics?['title']?['asset']?['text']
                                ?.toString() ??
                            '')
                        .isNotEmpty)
                      Text(
                        activity.actorCosmetics!['title']['asset']['text']
                            .toString(),
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                  ],
                ),
              ),
              if (activity.reason == 'following')
                const PixelChip('Following',
                    style: PixelBoxStyle.green,
                    textColor: PixelPalette.white),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            formatted.sentence,
            style: PixelType.body(context, color: PixelPalette.wood),
          ),
          if (formatted.pointsBadge != null) ...[
            SizedBox(height: grid.px(1)),
            PixelChip(formatted.pointsBadge!, style: PixelBoxStyle.green,
                textColor: PixelPalette.white),
          ],
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelButton(
                key: ValueKey('plaza_cheer_${activity.id}'),
                label: activity.cheeredByMe
                    ? 'Cheered ${activity.cheerCount}'
                    : 'Cheer ${activity.cheerCount}',
                icon: DesignerArt.heartLiked,
                iconScale: 1,
                variant: activity.cheeredByMe
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                onPressed: () {
                  ref
                      .read(plazaFeedProvider.notifier)
                      .toggleCheer(activity.id);
                },
              ),
              PixelChip(
                '${activity.commentCount} comments',
                icon: StudioIcons.edit,
                iconScale: 2,
                style: PixelBoxStyle.slot,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
