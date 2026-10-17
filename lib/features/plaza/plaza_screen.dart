import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/jdq_scaffold.dart';
import '../../core/services/push_service.dart';
import '../auth/providers/auth_provider.dart';
import 'plaza_models.dart';
import 'plaza_provider.dart';
import 'activity_text.dart';

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

class _PlazaScreenState extends ConsumerState<PlazaScreen> with SingleTickerProviderStateMixin {
  String _board = 'everyone';
  String _period = 'weekly';
  bool _askedPush = true;

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

  @override
  Widget build(BuildContext context) {
    final standingsKey = '$_board:$_period';
    final standingsAsync = ref.watch(plazaStandingsProvider(standingsKey));
    final feedAsync = ref.watch(plazaFeedProvider);
    final user = ref.watch(authProvider).user;

    return JdqScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Plaza',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.woodBrown,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.woodBrown),
            onPressed: () {
              ref.invalidate(plazaStandingsProvider(standingsKey));
              ref.read(plazaFeedProvider.notifier).loadFeed(reset: true);
            },
            tooltip: 'Refresh Plaza',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(plazaStandingsProvider(standingsKey));
          await ref.read(plazaFeedProvider.notifier).loadFeed(reset: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Header Hero Banner
            _buildHeroBanner(),
            const SizedBox(height: 12),

            // Push Alerts CTA Card if permission not yet asked
            if (!_askedPush && user != null) ...[
              _buildAlertsCard(),
              const SizedBox(height: 12),
            ],

            // Period & Board Switcher Tabs
            _buildControls(),
            const SizedBox(height: 12),

            // Standings Section
            standingsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Text(
                  'Standings unavailable: $err',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
              data: (data) => _buildStandingsContent(data),
            ),
            const SizedBox(height: 20),

            // Feed Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.explore_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Live Explorer Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ],
                ),
                // Mixed vs Following toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mixed', label: Text('All', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'following', label: Text('Following', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {ref.watch(plazaFeedProvider.notifier).scope},
                  onSelectionChanged: (val) {
                    ref.read(plazaFeedProvider.notifier).setScope(val.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Feed List
            feedAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: const Text(
                  'No recent activity to display.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppSpacing.roundedLg,
                      border: Border.all(color: AppColors.borderLowContrast),
                    ),
                    child: const Center(
                      child: Text(
                        'No activities found. Explore quests to appear on the Plaza!',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: activities.map((act) => _buildActivityCard(act)).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.roundedXl,
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.sunGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded, size: 28, color: AppColors.woodBrown),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pangasinan Plaza',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track community ranks, cheer explorer journeys, and follow local adventurers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD8F3DC),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.sunGold),
        borderRadius: AppSpacing.roundedLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Turn on Plaza alerts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.woodBrown),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Know immediately when someone passes your rank.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sunGold,
                        foregroundColor: AppColors.woodBrown,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final granted = await ref.read(pushServiceProvider).requestPermissionAndRegister();
                        if (mounted) {
                          setState(() {
                            _askedPush = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(granted ? 'Alerts enabled!' : 'Notifications declined')),
                          );
                        }
                      },
                      child: const Text('Turn on', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _askedPush = true;
                        });
                      },
                      child: const Text('Not now', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        // Board switch
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _board = 'everyone'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _board == 'everyone' ? AppColors.woodBrown : Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Everyone',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _board == 'everyone' ? Colors.white : AppColors.woodBrown,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _board = 'following'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _board == 'following' ? AppColors.woodBrown : Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Following',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _board == 'following' ? Colors.white : AppColors.woodBrown,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _board = 'town'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _board == 'town' ? AppColors.woodBrown : Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'My Town',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _board == 'town' ? Colors.white : AppColors.woodBrown,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Period switch
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _period = 'weekly'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _period == 'weekly' ? AppColors.primary : Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _period == 'weekly' ? Colors.white : AppColors.woodBrown,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _period = 'all_time'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _period == 'all_time' ? AppColors.primary : Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'All Time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _period == 'all_time' ? Colors.white : AppColors.woodBrown,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandingsContent(Map<String, dynamic> data) {
    final entriesRaw = data['entries'] as List<dynamic>? ?? [];
    final entries = entriesRaw.map((e) => StandingEntryModel.fromJson(e as Map<String, dynamic>)).toList();
    final meRaw = data['me'] as Map<String, dynamic>?;
    final me = meRaw != null ? StandingEntryModel.fromJson(meRaw) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My rank strip if present
        if (me != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Text(
                        '#${me.rank}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.woodBrown),
                        ),
                        Text(
                          '${me.score} pts · ${me.quests} quests',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                if (me.delta != null)
                  Text(
                    me.delta! > 0 ? '▲${me.delta}' : (me.delta! < 0 ? '▼${me.delta!.abs()}' : '—'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: me.delta! > 0 ? AppColors.success : (me.delta! < 0 ? AppColors.danger : AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Roster of top explorers
        Column(
          children: entries.map((scout) {
            final isPodium = scout.rank <= 3;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scout.isSelf ? AppColors.successBg : Colors.white,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: isPodium ? AppColors.sunGold.withOpacity(0.5) : AppColors.borderLowContrast,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPodium ? AppColors.sunGold : AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isPodium
                          ? (scout.rank == 1 ? '🥇' : (scout.rank == 2 ? '🥈' : '🥉'))
                          : '#${scout.rank}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scout.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.woodBrown),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${scout.homeTown ?? 'Pangasinan'} · ${scout.quests} quests',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${scout.score} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityItemModel activity) {
    final formatted = formatActivityText(activity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.sunGold.withOpacity(0.3),
                child: Text(
                  activity.actorName.isNotEmpty ? activity.actorName[0] : 'E',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.woodBrown),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activity.actorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.woodBrown),
                ),
              ),
              if (activity.reason == 'following')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: const Text('Following', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatted.sentence,
            style: const TextStyle(fontSize: 13, color: AppColors.woodBrown, height: 1.3),
          ),
          if (formatted.pointsBadge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
                borderRadius: AppSpacing.roundedSm,
              ),
              child: Text(
                formatted.pointsBadge!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(plazaFeedProvider.notifier).toggleCheer(activity.id);
                },
                borderRadius: AppSpacing.roundedMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: activity.cheeredByMe ? AppColors.warningBg : AppColors.surfaceContainerLow,
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  child: Row(
                    children: [
                      const Text('👏', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.cheerCount}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.commentCount}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
