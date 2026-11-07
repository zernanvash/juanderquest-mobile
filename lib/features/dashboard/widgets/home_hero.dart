import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../profile/providers/profile_stats_provider.dart';
import '../providers/home_daily_provider.dart';

String homeNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 10000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$value';
}

/// Plan 78 RPG Status & Purse Hero:
/// Avatar, Level, XP bar, 3-slot Purse (mJDQ, Stamps, Rep) and 4-stat summary strip.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key, this.user});

  final UserModel? user;

  static Map<String, dynamic>? _cosmeticAsset(
    Map<String, dynamic>? cosmetics,
    String slot,
  ) {
    final item = cosmetics?[slot];
    if (item is! Map || item['asset'] is! Map) return null;
    return Map<String, dynamic>.from(item['asset'] as Map);
  }

  static Color? _cosmeticColor(dynamic value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final authUser = ref.watch(authProvider).user;
    final currentUser = user ?? authUser;
    final stats = ref.watch(profileStatsProvider);
    final engagement = ref.watch(choiceEngagementProvider).valueOrNull;
    final daily = ref.watch(homeDailyProvider).valueOrNull;

    final displayName = currentUser?.displayName.trim().isNotEmpty == true
        ? currentUser!.displayName.trim()
        : 'Traveler';
    final handle = currentUser?.publicHandle;
    final points = currentUser?.points ?? 0;
    final level = (points ~/ 50) + 1;
    final xpInLevel = points % 50;
    final titleAsset = _cosmeticAsset(currentUser?.cosmetics, 'title');
    final nameColorAsset = _cosmeticAsset(currentUser?.cosmetics, 'nameColor');
    final nameColor = _cosmeticColor(nameColorAsset?['color']);
    final cosmeticTitle = titleAsset?['text']?.toString() ?? '';
    final initial = displayName.isEmpty ? 'J' : displayName[0].toUpperCase();
    final avatarUrl = currentUser?.avatarUrl ?? '';
    final validAvatar = avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    final stampsCount = daily?.stamps ?? stats.totalPointsEarned;
    final repCount = currentUser?.scoutReputation ?? 0;
    final questsCount = stats.completedQuestsCount;
    final visitsCount = engagement?.verifiedVisits ?? 0;
    final townsCount = engagement?.municipalities ?? 0;
    final streakDays = daily?.streak ?? engagement?.currentStreak ?? 0;

    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: const ValueKey('home_hero_profile'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/profile'),
                child: PixelPanel(
                  style: PixelBoxStyle.gold,
                  padding: 1,
                  child: SizedBox(
                    width: grid.px(14),
                    height: grid.px(14),
                    child: ClipRect(
                      child: validAvatar
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  _avatarFallback(context, initial),
                            )
                          : _avatarFallback(context, initial),
                    ),
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.title(
                        context,
                        color: nameColor ?? PixelPalette.paper,
                      ),
                    ),
                    if (handle != null) ...[
                      SizedBox(height: grid.px(1)),
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.cream,
                        ),
                      ),
                    ],
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(1),
                      runSpacing: grid.px(1),
                      children: [
                        _chip(
                          context,
                          key: const ValueKey('home_hero_level_chip'),
                          label: 'Level $level',
                          style: PixelBoxStyle.gold,
                          textColor: PixelPalette.ink,
                        ),
                        const PixelMicro(PixelMicroArt.sparkle, scale: 3),
                        if (cosmeticTitle.isNotEmpty)
                          _chip(
                            context,
                            key: const ValueKey('home_hero_title_chip'),
                            label: cosmeticTitle,
                            style: PixelBoxStyle.green,
                            textColor: PixelPalette.white,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          GestureDetector(
            key: const ValueKey('home_hero_level'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelProgressBar(
                  value: xpInLevel / 50,
                  segments: 10,
                  color: PixelPalette.greenBright,
                  showTipGlint: true,
                ),
                SizedBox(height: grid.px(1)),
                PixelText.rich(
                  '{sun:$xpInLevel / 50 XP} to level {paper:${level + 1}} · {paper:$points total XP}',
                  maxLines: 2,
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
          // 3-Slot Currency & Purse Bar (mJDQ, Stamps, Rep)
          Row(
            key: const ValueKey('home_hero_purse_bar'),
            children: [
              Expanded(
                child: _purseSlot(
                  context,
                  grid,
                  key: const ValueKey('home_purse_mjdq'),
                  icon: const PixelMicro(PixelMicroArt.coin, scale: 2),
                  label: '${homeNumber(points)} MJDQ',
                  onTap: () => context.push('/shop'),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: _purseSlot(
                  context,
                  grid,
                  key: const ValueKey('home_purse_stamps'),
                  icon: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
                  label: '${homeNumber(stampsCount)} STAMPS',
                  onTap: () => context.push('/profile/badges'),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: _purseSlot(
                  context,
                  grid,
                  key: const ValueKey('home_purse_rep'),
                  icon: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
                  label: '${homeNumber(repCount)} REP',
                  onTap: () => context.push('/plaza'),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          // 4-Stat Numbers Strip (Quests, Visits, Towns, Streak)
          GestureDetector(
            key: const ValueKey('home_hero_stats_strip'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/profile'),
            child: PixelPanel(
              style: PixelBoxStyle.parchment,
              padding: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: grid.px(1),
                  vertical: grid.px(1),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  children: [
                    _statItem(context, 'QUESTS', '$questsCount'),
                    Text('·', style: PixelType.small(context, color: PixelPalette.slate)),
                    _statItem(context, 'VISITS', '$visitsCount'),
                    Text('·', style: PixelType.small(context, color: PixelPalette.slate)),
                    _statItem(context, 'TOWNS', '$townsCount'),
                    Text('·', style: PixelType.small(context, color: PixelPalette.slate)),
                    _statItem(context, 'STREAK', '${streakDays}D 🔥'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purseSlot(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  SizedBox(width: grid.px(1)),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.ink,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(BuildContext context, String title, String value) {
    return Text(
      '$title: $value',
      style: PixelType.small(context, color: PixelPalette.ink).copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required Key key,
    required String label,
    required PixelBoxStyle style,
    required Color textColor,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/profile'),
          child: PixelChip(label, style: style, textColor: textColor),
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String initial) {
    return DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.greenDeep,
      child: Center(
        child: Text(
          initial,
          style: PixelType.title(context, color: PixelPalette.paper),
        ),
      ),
    );
  }
}
