import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
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

/// Plan 69 & 75i: pixel-styled live passport preview for cosmetics.
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
    final grid = PixelGrid.of(context);
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Live passport preview',
                style: PixelType.title(context),
              ),
            ),
            if (banner != null)
              GestureDetector(
                key: const ValueKey('passport_motion_toggle'),
                onTap: () {
                  pixelTick(context);
                  setState(() => _animated = !_animated);
                },
                child: PixelPanel(
                  style: PixelBoxStyle.slot,
                  padding: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: grid.px(2),
                      vertical: grid.px(1),
                    ),
                    child: Text(
                      _animated ? 'Animated' : 'Still',
                      style: PixelType.small(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        // Profile header in square pixel panels: banner with square avatar frame.
        PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      ClipRect(
                        child: ProfileBanner(
                          asset: banner?.asset,
                          seed: banner?.seed,
                          height: bannerHeight,
                          animate: _animated,
                          forceMotion: true,
                        ),
                      ),
                      Positioned(
                        top: grid.px(2),
                        right: grid.px(2),
                        child: const PixelChip(
                          'Your passport',
                          style: PixelBoxStyle.slot,
                          textColor: PixelPalette.white,
                        ),
                      ),
                      if (procedural && banner?.seed != null)
                        Positioned(
                          bottom: grid.px(1),
                          right: grid.px(2),
                          child: Text(
                            'seed #${(banner!.seed! & 0xffffffff).toRadixString(16).padLeft(8, '0')}',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.paperDim,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      grid.px(3),
                      avatarSize / 2 + grid.px(2),
                      grid.px(3),
                      grid.px(3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DisplayName(
                          name: widget.name,
                          title: loadout['title']?.asset['text']?.toString(),
                          color: _color(loadout['name_color']?.asset['color']),
                          style: PixelType.title(context),
                        ),
                        SizedBox(height: grid.px(1)),
                        Text(
                          'Traveler · Pangasinan',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: grid.px(3),
                top: bannerHeight - avatarSize / 2,
                child: PixelPanel(
                  style: PixelBoxStyle.gold,
                  padding: 1,
                  child: CosmeticAvatar(
                    name: widget.name,
                    imageUrl: widget.avatarUrl,
                    frame: loadout['frame']?.asset,
                    size: avatarSize - 8,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(2)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final kind in _slotLabels.keys)
              if (loadout[kind] != null)
                PixelChip(
                  '${kind == widget.selected.kind ? 'Previewing' : 'Equipped'} ${_slotLabels[kind]}: ${loadout[kind]!.name}',
                  style: kind == widget.selected.kind
                      ? PixelBoxStyle.gold
                      : PixelBoxStyle.slot,
                ),
          ],
        ),
        SizedBox(height: grid.px(3)),
        Text(
          widget.selected.name,
          style: PixelType.title(context),
        ),
        SizedBox(height: grid.px(1)),
        Text(
          '${widget.selected.kind.replaceAll('_', ' ')} · ${widget.selected.rarity}${procedural && widget.selected.kind == 'banner' ? ' · procedural, animated' : ''}',
          style: PixelType.body(
            context,
            color: PixelPalette.slate,
          ),
        ),
        if (widget.selected.description.isNotEmpty) ...[
          SizedBox(height: grid.px(1)),
          Text(
            widget.selected.description,
            style: PixelType.body(context),
          ),
        ],
        SizedBox(height: grid.px(3)),
        ...widget.actions,
      ],
    );
  }
}
