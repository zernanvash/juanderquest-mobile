import 'package:flutter/material.dart';
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

/// Pixel lab layout B's compact avatar header, without the wallet (that lives
/// in the Progress tab now).
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.user});

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
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Traveler';
    final handle = user?.handle ?? '@traveler';
    final points = user?.points ?? 0;
    final level = (points ~/ 50) + 1;
    final xpInLevel = points % 50;
    final titleAsset = _cosmeticAsset(user?.cosmetics, 'title');
    final nameColorAsset = _cosmeticAsset(user?.cosmetics, 'nameColor');
    final nameColor = _cosmeticColor(nameColorAsset?['color']);
    final cosmeticTitle = titleAsset?['text']?.toString() ?? '';
    final initial = displayName.isEmpty ? 'J' : displayName[0].toUpperCase();
    final avatarUrl = user?.avatarUrl ?? '';
    final validAvatar = avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

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
                        // Plan 75k: a glint on the level, like an RPG badge.
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
                SizedBox(height: grid.px(1)),
                // Plan 75k: a Hypixel-style scoreboard line.
                Row(
                  key: const ValueKey('home_hero_scoreboard'),
                  children: [
                    const PixelMicro(PixelMicroArt.coin, scale: 3),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      child: PixelText.rich(
                        'Purse: {sun:$points mJDQ} · Rep: {green:${user?.scoutReputation ?? 0}}',
                        maxLines: 1,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.cream,
                        ),
                      ),
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
