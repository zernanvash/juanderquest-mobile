import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';
import '../theater/theater_title_block.dart';

class SavedSpotsScreen extends ConsumerStatefulWidget {
  const SavedSpotsScreen({super.key});

  @override
  ConsumerState<SavedSpotsScreen> createState() => _SavedSpotsScreenState();
}

class _SavedSpotsScreenState extends ConsumerState<SavedSpotsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(spotDiscoveryProvider.notifier).load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() =>
      ref.read(spotDiscoveryProvider.notifier).load(refresh: true);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final saved = state.spots.where((spot) => spot.saved).toList();
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? saved
        : saved
            .where((spot) =>
                spot.name.toLowerCase().contains(query) ||
                spot.municipality.toLowerCase().contains(query) ||
                spot.category.toLowerCase().contains(query) ||
                spot.description.toLowerCase().contains(query))
            .toList();
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
                    title: 'Saved Places',
                    onBack: canPop ? () => Navigator.of(context).maybePop() : null,
                    actions: [
                      PixelChip('${saved.length} saved',
                          style: PixelBoxStyle.gold),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: _reload,
                      child: _body(context, grid, state, saved, visible),
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

  Widget _body(
    BuildContext context,
    PixelGrid grid,
    SpotDiscoveryState state,
    List<SpotModel> saved,
    List<SpotModel> visible,
  ) {
    if (state.isInitialLoading && saved.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: grid.px(24)),
          const Center(child: PixelLoader(label: 'Loading saved places')),
        ],
      );
    }
    if (state.failure != null && saved.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(grid.px(4)),
        children: [
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load saved places',
                  style: PixelType.title(context, color: PixelPalette.white),
                ),
                SizedBox(height: grid.px(2)),
                Text(
                  state.failure!.message,
                  style: PixelType.body(context, color: PixelPalette.cream),
                ),
                SizedBox(height: grid.px(3)),
                Align(
                  alignment: Alignment.centerRight,
                  child: PixelButton(
                    key: const ValueKey('saved_error_retry'),
                    label: 'Retry',
                    onPressed: () => _reload(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (saved.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: grid.px(12)),
          PixelEmptyState(
            key: const ValueKey('saved_empty'),
            title: 'No saved destinations',
            message: 'Save a place while exploring and it will appear here.',
            action: PixelButton(
              label: 'Explore places',
              onPressed: () => context.go('/explore'),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        grid.px(4),
        grid.px(3),
        grid.px(4),
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          style: PixelBoxStyle.wood,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your saved library',
                style: PixelType.title(context, color: PixelPalette.paper),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                'Places you bookmarked for later.',
                style: PixelType.body(context, color: PixelPalette.cream),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelTextField(
          key: const ValueKey('saved_search'),
          controller: _search,
          label: 'Search saved places',
          hint: 'Name, town, or category',
          onChanged: (value) => setState(() => _query = value),
        ),
        SizedBox(height: grid.px(3)),
        if (visible.isEmpty)
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Text(
              'No saved destination matches "$_query".',
              style: PixelType.body(context),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) SizedBox(height: grid.px(2)),
            _card(context, grid, visible[i]),
          ],
      ],
    );
  }

  Widget _card(BuildContext context, PixelGrid grid, SpotModel spot) {
    final image = spot.imageUrl;
    return GestureDetector(
      key: ValueKey('saved_spot_${spot.id}'),
      onTap: () => context.push(
        '/explore/${Uri.encodeComponent(spot.slug)}',
        extra: spot,
      ),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: ValueKey('saved_thumb_${spot.id}'),
              width: 56,
              height: 56,
              child: ClipRect(
                child: image == null || image.isEmpty
                    ? const DitherBackground(
                        top: PixelPalette.greenMid,
                        bottom: PixelPalette.greenDeep,
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const DitherBackground(
                          top: PixelPalette.greenMid,
                          bottom: PixelPalette.greenDeep,
                        ),
                      ),
              ),
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot.name, style: PixelType.title(context)),
                  SizedBox(height: grid.px(1)),
                  Text(
                    '${spot.municipality} · ${spotCategoryLabel(spot.category).toUpperCase()}',
                    style: PixelType.body(context, color: PixelPalette.slate),
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    spot.saved ? 'SAVED' : 'NOT SAVED',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.greenDark,
                    ),
                  ),
                ],
              ),
            ),
            PixelIconButton(
              key: const ValueKey('saved_remove'),
              icon: _bookmarkArt,
              semanticLabel: 'Remove saved destination',
              onPressed: () async => ref
                  .read(spotDiscoveryProvider.notifier)
                  .toggleSaved(spot),
            ),
          ],
        ),
      ),
    );
  }
}

const _bookmarkArt = PixelArt(
  'wave2dBookmark',
  [
    '................',
    '................',
    '...00000000.....',
    '...0yyyyyy0.....',
    '...0y0000y0.....',
    '...0y0yy0y0.....',
    '...0y0yy0y0.....',
    '...0y0000y0.....',
    '...0yyyyyy0.....',
    '...0yyyyyy0.....',
    '...0yy00yy0.....',
    '...0y0..0y0.....',
    '...00....00.....',
    '................',
  ],
);
