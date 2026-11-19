import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/open_route.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_frame.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/models/user_model.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../profile/providers/profile_stats_provider.dart';
import '../../settings/home_town.dart';
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
    // Plan 100 WP-7: the home town line; watching the sighting provider
    // records today's town from GPS.
    final homeTown = ref.watch(homeTownProvider).valueOrNull;
    ref.watch(homeTownSightingProvider);

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
    // A bought panel frame (Plan 104b) puts the card on its light fill, so
    // the cream-on-wood text turns dark.
    final frame = PixelFrameSkin.resolve(
      user == null ? ref.watch(panelFramePreviewProvider) : null,
      currentUser?.cosmetics,
    );
    final textMain = frame?.text ?? PixelPalette.paper;
    final textSoft = frame?.textSoft ?? PixelPalette.cream;
    final accentToken = frame?.accentToken ?? 'sun';
    final mainToken = frame?.textToken ?? 'paper';
    final initial = displayName.isEmpty ? 'J' : displayName[0].toUpperCase();
    // v0.3.10: uploaded pictures are root-relative; resolve like CosmeticAvatar.
    final avatarUrl = resolveAvatarUrl(currentUser?.avatarUrl) ?? '';
    final validAvatar = avatarUrl.isNotEmpty;

    final questsCount = stats.completedQuestsCount;
    final visitsCount = engagement?.verifiedVisits ?? 0;
    final townsCount = engagement?.municipalities ?? 0;
    final streakDays = daily?.streak ?? engagement?.currentStreak ?? 0;

    // Owner 2026-11-17: the currencies moved to the top bar
    // ([HomePurseStrip]); the card keeps LEVEL at the top right.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardPanel(
          frame,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    key: const ValueKey('home_hero_profile'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go('/profile'),
                    child: ConstrainedBox(
                      // Design system: tap targets are at least 48x48.
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
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
                            color: nameColor ?? textMain,
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
                              color: textSoft,
                            ),
                          ),
                        ],
                        if (cosmeticTitle.isNotEmpty) ...[
                          SizedBox(height: grid.px(1)),
                          _chip(
                            context,
                            key: const ValueKey('home_hero_title_chip'),
                            label: cosmeticTitle,
                            style: PixelBoxStyle.green,
                            textColor: PixelPalette.white,
                          ),
                        ],
                        if (homeTown != null) ...[
                          SizedBox(height: grid.px(1)),
                          _homeTownLine(context, grid, homeTown, textSoft),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: grid.px(1)),
                  // LEVEL at the top right of the card.
                  _chip(
                    context,
                    key: const ValueKey('home_hero_level_chip'),
                    label: 'Level $level',
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
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
                      // Sun on the green card (green would vanish).
                      color: PixelPalette.sun,
                      showTipGlint: true,
                    ),
                    SizedBox(height: grid.px(1)),
                    PixelText.rich(
                      '{$accentToken:$xpInLevel / 50 XP} to level {$mainToken:${level + 1}} · {$mainToken:$points total XP}',
                      maxLines: 2,
                      style: PixelType.small(context, color: textSoft),
                    ),
                  ],
                ),
              ),
              SizedBox(height: grid.px(2)),
              // Quests, visits, towns, streak: plain on the card.
              GestureDetector(
                key: const ValueKey('home_hero_stats_strip'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/profile'),
                child: ConstrainedBox(
                  // Design system: tap targets are at least 48 tall.
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: grid.px(1),
                        runSpacing: grid.px(1),
                        children: [
                          _statItem(
                              context, 'QUESTS', '$questsCount', textSoft),
                          _statItem(
                              context, 'VISITS', '$visitsCount', textSoft),
                          _statItem(context, 'TOWNS', '$townsCount', textSoft),
                          _statItem(
                              context, 'STREAK', '${streakDays}D', textSoft),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardPanel(PixelFrameSkin? frame, Widget child) {
    if (frame == null) {
      // Owner 2026-11-17: the name card is green.
      return PixelPanel(style: PixelBoxStyle.green, child: child);
    }
    return PixelFramedPanel(
      key: const ValueKey('home_hero_frame'),
      skin: frame,
      child: child,
    );
  }

  Widget _statItem(
      BuildContext context, String title, String value, Color color) {
    return Text(
      '$title: $value',
      style: PixelType.small(context, color: color).copyWith(
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

  Widget _homeTownLine(
    BuildContext context,
    PixelGrid grid,
    HomeTownInfo info,
    Color color,
  ) {
    final String label;
    if (info.town != null) {
      label = info.source == 'gps'
          ? tr(
              context,
              en: '${info.town} · from GPS',
              tl: '${info.town} · mula sa GPS',
            )
          : info.town!;
    } else if (info.gpsEnabled) {
      label = tr(
        context,
        en: 'Home town: finding… (${info.currentDays}/${info.requiredDays} days)',
        tl: 'Sariling bayan: hinahanap… (${info.currentDays}/${info.requiredDays} araw)',
      );
    } else {
      label = tr(
        context,
        en: 'Home town: not set',
        tl: 'Sariling bayan: hindi nakatakda',
      );
    }
    return Row(
      key: const ValueKey('home_hero_home_town'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: FittedBox(child: PixelSprite(DesignerArt.navHome)),
        ),
        SizedBox(width: grid.px(1)),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: color),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(BuildContext context, String initial) {
    return DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.green,
      child: Center(
        child: Text(
          initial,
          style: PixelType.title(context, color: PixelPalette.paper),
        ),
      ),
    );
  }
}

/// Coins, stamps and reputation as icon + number (no words). Owner
/// 2026-11-17: it sits in Home's top bar. Each one opens its page.
class HomePurseStrip extends ConsumerWidget {
  const HomePurseStrip({super.key, this.color = PixelPalette.paper});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);
    final daily = ref.watch(homeDailyProvider).valueOrNull;
    final points = user?.points ?? 0;
    final stampsCount = daily?.stamps ?? stats.totalPointsEarned;
    final repCount = user?.scoutReputation ?? 0;
    return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          key: const ValueKey('home_hero_purse_bar'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: '$points mJDQ',
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const ValueKey('home_purse_mjdq'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openRoute(context, '/shop'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: grid.px(1)),
                    child: MjdqAmount(
                      points,
                      animateOnIncrease: true,
                      idleSpin: true,
                      // Owner 2026-11-17: smaller currencies.
                      style: PixelType.body(context, color: color)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            // Owner 2026-11-17: more room between the currencies.
            SizedBox(width: grid.px(6)),
            _purseSlot(
              context,
              grid,
              key: const ValueKey('home_purse_stamps'),
              // Owner 2026-11-18 (v0.3.1): the designer stamp icon.
              icon: DesignerArt.stampIcon,
              value: homeNumber(stampsCount),
              semantics: '$stampsCount stamps',
              onTap: () => context.push('/profile/badges'),
            ),
            // Owner 2026-11-17: more room between the currencies.
            SizedBox(width: grid.px(6)),
            _purseSlot(
              context,
              grid,
              key: const ValueKey('home_purse_rep'),
              // Owner 2026-11-18: the smiley is reputation (new 13px art in v0.3.4).
              icon: DesignerArt.repSmiley,
              value: homeNumber(repCount),
              semantics: '$repCount reputation',
              onTap: () => context.push('/plaza'),
            ),
          ],
        ));
  }

  Widget _purseSlot(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required PixelArt icon,
    required String value,
    required String semantics,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: grid.px(1)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Owner 2026-11-18 (v0.3.4): the 13px smiley; stamp and smiley
                // share one pixel scale (the smiley's), the size of the coin.
                PixelIconFit(
                  icon,
                  box: 16,
                  scale: PixelIconFit.fitScale(
                    DesignerArt.repSmiley,
                    16,
                    MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
                SizedBox(width: grid.px(1)),
                Text(
                  value,
                  maxLines: 1,
                  style: PixelType.body(context, color: color)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
