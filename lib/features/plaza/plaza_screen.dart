import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text_3d.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../cosmetics/widgets/cosmetic_avatar.dart';
import '../spots/widgets/spot_like_heart.dart';
import '../settings/home_town.dart';
import '../vote/pixel/wave3_art.dart';
import 'activity_text.dart';
import 'plaza_models.dart';
import 'plaza_comments_sheet.dart';
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
  // Owner 2026-11-18: "Friends tab first".
  String _board = 'following';
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
    final activityId = widget.initialActivityId;
    if (widget.initialOpenComments && activityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openComments(activityId);
      });
    }
  }

  void _openComments(String activityId) {
    showPlazaComments(
      context,
      activityId: activityId,
      onCountChanged: (count) => ref
          .read(plazaFeedProvider.notifier)
          .setCommentCount(activityId, count),
    );
  }

  void _openProfile(String? handle, String? userId) {
    final key = (handle != null && handle.isNotEmpty) ? handle : userId;
    if (key == null || key.isEmpty) return;
    context.push('/profile/${Uri.encodeComponent(key)}');
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
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
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
                          grid.gutter,
                          grid.px(3),
                          grid.gutter,
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
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
                          // Plan 77: the AR mini-game boards.
                          SizedBox(height: grid.px(2)),
                          PixelButton(
                            key: const ValueKey('plaza_laro_boards'),
                            label: 'Laro boards',
                            variant: PixelButtonVariant.secondary,
                            expand: true,
                            onPressed: () => context.push('/laro'),
                          ),
                          SizedBox(height: grid.px(2)),
                          PixelButton(
                            key: const ValueKey('plaza_find_people'),
                            label: 'Find people',
                            variant: PixelButtonVariant.secondary,
                            expand: true,
                            onPressed: () => context.push('/plaza/people'),
                          ),
                          SizedBox(height: grid.px(4)),
                          feedAsync.when(
                            loading: () => PixelPanel(
                              style: PixelBoxStyle.parchment,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const PixelSectionTitle(
                                    'Live explorer activity',
                                    icon: DesignerArt.navExplore,
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  const Center(
                                    child:
                                        PixelLoader(label: 'Loading activity'),
                                  ),
                                ],
                              ),
                            ),
                            error: (err, _) => _standingsError(
                              context,
                              grid,
                              'No recent activity to display.',
                              _reloadFeed,
                              retryKey: const ValueKey('plaza_feed_retry'),
                            ),
                            data: (activities) {
                              if (activities.isEmpty) {
                                return PixelPanel(
                                  style: PixelBoxStyle.parchment,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const PixelSectionTitle(
                                        'Live explorer activity',
                                        icon: DesignerArt.navExplore,
                                        value: '0',
                                        valueColor: PixelPalette.greenDark,
                                      ),
                                      SizedBox(height: grid.px(2)),
                                      _board == 'following'
                                          ? const PixelEmptyState(
                                              key: ValueKey(
                                                  'plaza_friends_empty'),
                                              title: 'No friends yet',
                                              message:
                                                  'Follow travelers to see their quests here. Tap Find people.',
                                            )
                                          : const PixelEmptyState(
                                              key: ValueKey('plaza_feed_empty'),
                                              title: 'No activities yet',
                                              message:
                                                  'No activities found. Explore quests to appear on the Plaza!',
                                            ),
                                    ],
                                  ),
                                );
                              }
                              return PixelPanel(
                                style: PixelBoxStyle.parchment,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    PixelSectionTitle(
                                      'Live explorer activity',
                                      icon: DesignerArt.navExplore,
                                      value: '${activities.length}',
                                      valueColor: PixelPalette.greenDark,
                                    ),
                                    SizedBox(height: grid.px(1)),
                                    for (var i = 0;
                                        i < activities.length;
                                        i++) ...[
                                      if (i > 0)
                                        Container(
                                          height: grid.unit,
                                          color: PixelPalette.paperDim,
                                        ),
                                      _activity(context, grid, activities[i]),
                                    ],
                                  ],
                                ),
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

  Widget _alerts(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelSectionTitle(
            'Turn on Plaza alerts',
            icon: DesignerArt.notifBell,
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            _toolbarChip(
              context,
              grid,
              label: 'Friends',
              selected: _board == 'following',
              onTap: () {
                setState(() => _board = 'following');
                ref.read(plazaFeedProvider.notifier).setScope('following');
              },
            ),
            _toolbarChip(
              context,
              grid,
              label: 'Everyone',
              selected: _board == 'everyone',
              onTap: () {
                setState(() => _board = 'everyone');
                ref.read(plazaFeedProvider.notifier).setScope('mixed');
              },
            ),
            _toolbarChip(
              context,
              grid,
              label: 'My Town',
              selected: _board == 'town',
              onTap: () {
                setState(() => _board = 'town');
                ref.read(plazaFeedProvider.notifier).setScope('town');
              },
            ),
          ],
        ),
        SizedBox(height: grid.px(1)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            _toolbarChip(
              context,
              grid,
              label: 'This Week',
              selected: _period == 'weekly',
              onTap: () => setState(() => _period = 'weekly'),
            ),
            _toolbarChip(
              context,
              grid,
              label: 'All Time',
              selected: _period == 'all_time',
              onTap: () => setState(() => _period = 'all_time'),
            ),
          ],
        ),
      ],
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

  Widget _standings(
      BuildContext context, PixelGrid grid, Map<String, dynamic> data) {
    final entriesRaw = data['entries'] as List<dynamic>? ?? [];
    final entries = entriesRaw
        .map((e) => StandingEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meRaw = data['me'] as Map<String, dynamic>?;
    final me = meRaw != null ? StandingEntryModel.fromJson(meRaw) : null;

    if (data['reason'] == 'NO_HOME_TOWN') {
      // My Town follows the town you say you are from, not where you played.
      return PixelPanel(
        key: const ValueKey('plaza_no_home_town'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PixelSectionTitle(
              'Which town are you from?',
              icon: DesignerArt.spotMarker,
            ),
            SizedBox(height: grid.px(1)),
            Text(
              'Set your home town to compete with explorers from there, wherever you travel.',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                key: const ValueKey('plaza_set_home_town'),
                label: 'Set home town',
                onPressed: () async {
                  if (await showHomeTownPicker(context, ref)) {
                    ref.invalidate(plazaStandingsProvider('$_board:$_period'));
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            'Standings',
            icon: DesignerArt.plazaTrophy,
            value: '${entries.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          if (me != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Row(
                children: [
                  PixelChip('#${me.rank}', style: PixelBoxStyle.gold),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.displayName,
                          style: PixelType.title(
                            context,
                            color: PixelPalette.greenDark,
                          ),
                        ),
                        Text(
                          '${me.score} pts · ${me.quests} ${me.quests == 1 ? 'quest' : 'quests'}',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.slate,
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
                        color: PixelPalette.greenDark,
                      ),
                    ),
                ],
              ),
            ),
            if (entries.isNotEmpty)
              Container(height: grid.unit, color: PixelPalette.paperDim),
          ],
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            GestureDetector(
              key: ValueKey('plaza_standing_${entries[i].rank}'),
              behavior: HitTestBehavior.opaque,
              onTap: entries[i].isSelf
                  ? null
                  : () => _openProfile(entries[i].handle, entries[i].userId),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                child: Row(
                  children: [
                    PixelChip(
                      '#${entries[i].rank}',
                      style: entries[i].rank <= 3
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.slot,
                    ),
                    SizedBox(width: grid.px(2)),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[i].displayName,
                            maxLines: 2,
                            style: PixelType.title(
                              context,
                              color: entries[i].isSelf
                                  ? PixelPalette.greenDark
                                  : PixelPalette.ink,
                            ),
                          ),
                          Text(
                            '${entries[i].homeTown ?? 'Pangasinan'} · ${entries[i].quests} ${entries[i].quests == 1 ? 'quest' : 'quests'}',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: grid.px(2)),
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${entries[i].score} pts',
                          style: PixelType.numbers(
                            context,
                            color: PixelPalette.greenDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activity(
      BuildContext context, PixelGrid grid, ActivityItemModel activity) {
    final formatted = formatActivityText(activity);
    return KeyedSubtree(
      key: ValueKey('plaza_activity_${activity.id}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: ValueKey('plaza_actor_${activity.id}'),
                  onTap: () => _openProfile(activity.actorHandle, null),
                  child: CosmeticAvatar(
                    name: activity.actorName,
                    imageUrl: activity.actorAvatar,
                    frame: activity.actorCosmetics?['frame']?['asset']
                        as Map<String, dynamic>?,
                    size: grid.px(14),
                  ),
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _openProfile(activity.actorHandle, null),
                        child: Text(
                          activity.actorName,
                          maxLines: 2,
                          style: PixelType.title(
                            context,
                            color: _cosmeticColor(
                                    activity.actorCosmetics?['nameColor']
                                        ?['asset']?['color']) ??
                                PixelPalette.ink,
                          ),
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
                      if (activity.displayReasonChip != null) ...[
                        SizedBox(height: grid.px(1)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: PixelChip(
                            activity.displayReasonChip!,
                            style: _activityReasonStyle(activity.reason),
                            textColor:
                                _activityReasonTextColor(activity.reason),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            Text(
              formatted.sentence,
              style: PixelType.body(context, color: PixelPalette.wood),
            ),
            if (formatted.pointsBadge != null) ...[
              SizedBox(height: grid.px(1)),
              PixelChip(formatted.pointsBadge!,
                  style: PixelBoxStyle.green, textColor: PixelPalette.white),
            ],
            SizedBox(height: grid.px(2)),
            // v0.3.1: a small cheer heart like Explore's like row.
            // v0.3.8 (owner 2026-11-18, "Comments back"): comments return.
            Row(children: [
              Semantics(
                button: true,
                label: activity.cheeredByMe
                    ? 'Remove cheer, ${activity.cheerCount} cheers'
                    : 'Cheer, ${activity.cheerCount} cheers',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: ValueKey('plaza_cheer_${activity.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      pixelTick(context);
                      ref
                          .read(plazaFeedProvider.notifier)
                          .toggleCheer(activity.id);
                    },
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 36, minWidth: 72),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SpotLikeHeartIcon(
                              liked: activity.cheeredByMe, box: 24),
                          SizedBox(width: grid.px(1)),
                          Text(
                            '${activity.cheerCount}',
                            style: PixelType.numbers(
                              context,
                              color: activity.cheeredByMe
                                  ? PixelPalette.red
                                  : PixelPalette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: grid.px(3)),
              Flexible(
                child: PixelChip(
                  activity.commentCount == 1
                      ? '1 comment'
                      : '${activity.commentCount} comments',
                  key: ValueKey('plaza_comments_${activity.id}'),
                  style: PixelBoxStyle.parchment,
                  textColor: PixelPalette.ink,
                  onTap: () => _openComments(activity.id),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static PixelBoxStyle _activityReasonStyle(String reason) {
    switch (reason) {
      case 'following':
        return PixelBoxStyle.green;
      case 'you':
      case 'rival':
      case 'saved_spot':
      case 'popular':
        return PixelBoxStyle.gold;
      default:
        return PixelBoxStyle.slot;
    }
  }

  static Color _activityReasonTextColor(String reason) {
    switch (reason) {
      case 'following':
        return PixelPalette.white;
      case 'you':
      case 'rival':
      case 'saved_spot':
      case 'popular':
        return PixelPalette.ink;
      default:
        return PixelPalette.slate;
    }
  }
}
