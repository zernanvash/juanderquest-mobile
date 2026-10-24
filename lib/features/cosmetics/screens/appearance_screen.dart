import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/providers/cosmetics_provider.dart';
import '../../shop/models/cosmetic_item.dart';
import '../widgets/profile_banner.dart';
import '../widgets/cosmetic_avatar.dart';
import '../widgets/display_name.dart';

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
    return JdqScaffold(
        scrollable: true,
        appBar: AppBar(title: const Text('Appearance')),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
              borderRadius: AppSpacing.roundedLg,
              child: ProfileBanner(
                  asset: banner?.asset,
                  seed: banner?.seed,
                  animate: true,
                  height: 150,
                  child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                CosmeticAvatar(
                                    name: name,
                                    imageUrl: user?.avatarUrl,
                                    frame: frame?.asset,
                                    size: 54),
                                const SizedBox(width: 10),
                                Flexible(
                                    child: DisplayName(
                                        name: name,
                                        title: title?.asset['text']?.toString(),
                                        color: _color(color?.asset['color'])))
                              ]))))),
          const SizedBox(height: AppSpacing.lg),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.error != null)
            Text(state.error!, style: const TextStyle(color: AppColors.danger)),
          for (final slot in const [
            ('banner', 'Banner', 'banner_id'),
            ('frame', 'Avatar frame', 'frame_id'),
            ('title', 'Title', 'title_id'),
            ('name_color', 'Name colour', 'name_color_id')
          ])
            _slot(slot.$1, slot.$2, slot.$3, state),
          const SizedBox(height: AppSpacing.lg)
        ]));
  }

  Widget _slot(String kind, String label, String key, CosmeticsState state) {
    final owned = state.owned
        .where((o) => o.item.kind == kind)
        .map((o) => o.item)
        .toList();
    final current = state.loadout[key]?.toString() ?? '';
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: DropdownButtonFormField<String>(
            value: current,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final item in owned)
                DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis))
            ],
            onChanged: (id) async {
              if (id == null) return;
              final item = _find(owned, id);
              if (item == null) {
                if (current.isNotEmpty) {
                  final existing =
                      _find(state.owned.map((o) => o.item).toList(), current);
                  if (existing != null) {
                    await ref
                        .read(cosmeticsProvider.notifier)
                        .equip(existing, clear: true);
                  }
                }
                return;
              }
              final error =
                  await ref.read(cosmeticsProvider.notifier).equip(item);
              if (error != null && mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error)));
              }
            }));
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
