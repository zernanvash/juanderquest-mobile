import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../shop/models/cosmetic_item.dart';
import 'cosmetic_avatar.dart';
import 'display_name.dart';
import 'profile_banner.dart';

const _slotLabels = {
  'banner': 'Banner',
  'frame': 'Frame',
  'title': 'Title',
  'name_color': 'Name colour',
};

/// Resolves the traveler's equipped cosmetics from the loadout ids (`banner_id`, ...).
Map<String, CosmeticItem> equippedLoadout(
    Map<String, dynamic> loadout, Iterable<CosmeticItem> known) {
  final out = <String, CosmeticItem>{};
  for (final kind in _slotLabels.keys) {
    final id = loadout['${kind}_id'];
    if (id == null) continue;
    for (final item in known) {
      if (item.id == id) {
        out[kind] = item;
        break;
      }
    }
  }
  return out;
}

/// Plan 69: the shop preview looks like the traveler's profile header. The previewed item
/// takes its slot; the traveler's other equipped cosmetics stay on.
class PassportPreview extends StatefulWidget {
  const PassportPreview({
    super.key,
    required this.selected,
    required this.equipped,
    required this.name,
    this.avatarUrl,
    this.actions = const [],
  });

  final CosmeticItem selected;
  final Map<String, CosmeticItem> equipped;
  final String name;
  final String? avatarUrl;
  final List<Widget> actions;

  @override
  State<PassportPreview> createState() => _PassportPreviewState();
}

class _PassportPreviewState extends State<PassportPreview> {
  bool _animated = true;

  Color? _color(dynamic value) {
    try {
      return Color(int.parse(value.toString().replaceFirst('#', '0xff')));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadout = {...widget.equipped, widget.selected.kind: widget.selected};
    final banner = loadout['banner'];
    final procedural = banner?.asset['style'] == 'procedural';
    const bannerHeight = 150.0;
    const avatarSize = 84.0;

    return Column(
      key: const ValueKey('passport_preview'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text('✨ LIVE PASSPORT PREVIEW',
                  style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.primary))),
          if (banner != null)
            TextButton.icon(
                key: const ValueKey('passport_motion_toggle'),
                onPressed: () => setState(() => _animated = !_animated),
                icon:
                    Icon(_animated ? Icons.pause : Icons.play_arrow, size: 16),
                label: Text(_animated ? 'Animated' : 'Still')),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // Profile header, as on the profile screen: banner, avatar overlapping its edge,
        // name below so the artwork stays visible.
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: Colors.white,
            child: Stack(clipBehavior: Clip.none, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Stack(children: [
                  ProfileBanner(
                      asset: banner?.asset,
                      seed: banner?.seed,
                      height: bannerHeight,
                      animate: _animated,
                      forceMotion: true),
                  Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.4),
                              borderRadius: AppSpacing.roundedPill),
                          child: const Text('YOUR PASSPORT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)))),
                  if (procedural && banner?.seed != null)
                    Positioned(
                        bottom: 6,
                        right: 10,
                        child: Text(
                            'seed #${(banner!.seed! & 0xffffffff).toRadixString(16).padLeft(8, '0')}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace'))),
                ]),
                Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, avatarSize / 2 + 8, 16, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DisplayName(
                              name: widget.name,
                              title:
                                  loadout['title']?.asset['text']?.toString(),
                              color:
                                  _color(loadout['name_color']?.asset['color']),
                              style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.woodBrown)),
                          const SizedBox(height: 4),
                          Text('Traveler · Pangasinan',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ])),
              ]),
              Positioned(
                  left: 14,
                  top: bannerHeight - avatarSize / 2,
                  child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 8)
                          ]),
                      child: CosmeticAvatar(
                          name: widget.name,
                          imageUrl: widget.avatarUrl,
                          frame: loadout['frame']?.asset,
                          size: avatarSize - 8))),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final kind in _slotLabels.keys)
            if (loadout[kind] != null)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: kind == widget.selected.kind
                          ? const Color(0xFFFFD166)
                          : AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedPill),
                  child: Text(
                      '${kind == widget.selected.kind ? 'Previewing' : 'Equipped'} ${_slotLabels[kind]}: ${loadout[kind]!.name}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text(widget.selected.name,
            style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
        const SizedBox(height: 4),
        Text(
            '${widget.selected.kind.replaceAll('_', ' ')} · ${widget.selected.rarity}${procedural && widget.selected.kind == 'banner' ? ' · procedural, animated' : ''}',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        if (widget.selected.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.selected.description, style: AppTypography.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        ...widget.actions,
      ],
    );
  }
}
