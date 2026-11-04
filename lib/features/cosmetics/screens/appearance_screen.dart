import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/models/cosmetic_item.dart';
import '../../shop/providers/cosmetics_provider.dart';
import '../widgets/cosmetic_avatar.dart';
import '../widgets/display_name.dart';
import '../widgets/profile_banner.dart';

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});
  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cosmeticsProvider.notifier).load());
  }

  Future<void> _reload() => ref.read(cosmeticsProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cosmeticsProvider);
    final user = ref.watch(authProvider).user;
    final name = user?.displayName ?? 'Traveler';
    final load = state.loadout;
    final banner = _owned('banner', load['banner_id'], state);
    final frame = _owned('frame', load['frame_id'], state);
    final title = _owned('title', load['title_id'], state);
    final color = _owned('name_color', load['name_color_id'], state);
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
                    title: 'Appearance',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(4),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _preview(context, grid, name, user?.avatarUrl, banner,
                            frame, title, color),
                        SizedBox(height: grid.px(4)),
                        if (state.isLoading)
                          const Center(
                              child: PixelLoader(label: 'Loading cosmetics'))
                        else if (state.error != null)
                          PixelPanel(
                            style: PixelBoxStyle.red,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Could not load your items',
                                  style: PixelType.title(
                                    context,
                                    color: PixelPalette.white,
                                  ),
                                ),
                                SizedBox(height: grid.px(2)),
                                Text(
                                  state.error!,
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.cream,
                                  ),
                                ),
                                SizedBox(height: grid.px(3)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: PixelButton(
                                    key: const ValueKey('appearance_retry'),
                                    label: 'Retry',
                                    onPressed: () => _reload(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          for (final slot in const [
                            ('banner', 'Banner', 'banner_id'),
                            ('frame', 'Avatar frame', 'frame_id'),
                            ('title', 'Title', 'title_id'),
                            ('name_color', 'Name colour', 'name_color_id')
                          ]) ...[
                            _slot(context, grid, slot.$1, slot.$2, slot.$3,
                                state),
                            SizedBox(height: grid.px(2)),
                          ],
                        ],
                      ],
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

  Widget _preview(
    BuildContext context,
    PixelGrid grid,
    String name,
    String? avatarUrl,
    CosmeticItem? banner,
    CosmeticItem? frame,
    CosmeticItem? title,
    CosmeticItem? color,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: grid.px(36),
            child: ClipRect(
              child: ProfileBanner(
                asset: banner?.asset,
                seed: banner?.seed,
                animate: true,
                height: grid.px(36),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(grid.px(2)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CosmeticAvatar(
                          name: name,
                          imageUrl: avatarUrl,
                          frame: frame?.asset,
                          size: grid.px(27),
                        ),
                        SizedBox(width: grid.px(2)),
                        Expanded(
                          child: DisplayName(
                            name: name,
                            title: title?.asset['text']?.toString(),
                            color: _color(color?.asset['color']),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'Dress up your traveler passport.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }

  Widget _slot(
    BuildContext context,
    PixelGrid grid,
    String kind,
    String label,
    String key,
    CosmeticsState state,
  ) {
    final owned = state.owned
        .where((o) => o.item.kind == kind)
        .map((o) => o.item)
        .toList();
    final current = state.loadout[key]?.toString() ?? '';
    final selected = _find(owned, current);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PixelType.title(context)),
                SizedBox(height: grid.px(1)),
                Text(
                  selected?.name ?? 'None selected',
                  maxLines: 2,
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          SizedBox(width: grid.px(2)),
          PixelButton(
            key: ValueKey('appearance_${kind}_choose'),
            label: 'Choose',
            variant: PixelButtonVariant.secondary,
            onPressed: () => _choose(context, grid, label, owned, selected),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    PixelGrid grid,
    String label,
    List<CosmeticItem> owned,
    CosmeticItem? selected,
  ) async {
    await showPixelDialog<void>(
      context: context,
      title: 'Choose $label',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelButton(
              key: const ValueKey('appearance_pick_none'),
              label: 'None',
              variant: selected == null
                  ? PixelButtonVariant.primary
                  : PixelButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).pop();
                if (selected != null) {
                  ref
                      .read(cosmeticsProvider.notifier)
                      .equip(selected, clear: true);
                }
              },
            ),
            for (final item in owned) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: ValueKey('appearance_pick_${item.id}'),
                label: item.name,
                variant: selected?.id == item.id
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pop();
                  _equip(item);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _equip(CosmeticItem item) async {
    final error = await ref.read(cosmeticsProvider.notifier).equip(item);
    if (error != null && mounted) {
      showPixelToast(context, error);
    }
  }

  CosmeticItem? _find(List<CosmeticItem> items, String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  CosmeticItem? _owned(String kind, dynamic id, CosmeticsState s) {
    if (id == null) return null;
    for (final x in s.owned) {
      if (x.item.id == id && x.item.kind == kind) return x.item;
    }
    return null;
  }

  Color? _color(dynamic hex) {
    try {
      return Color(int.parse(hex.toString().replaceFirst('#', '0xff')));
    } catch (_) {
      return null;
    }
  }
}
