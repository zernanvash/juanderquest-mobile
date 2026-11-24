import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../../core/search/fuzzy_search.dart';
import '../../models/spot_model.dart';

/// Owner 2026-11-18 (v0.3.3): what Explore shows under the search box while
/// searching: recent searches when the box is empty, live matches (typos
/// tolerated) once something is typed.
class ExploreSearchResults extends StatelessWidget {
  const ExploreSearchResults({
    super.key,
    required this.query,
    required this.spots,
    this.remoteHits = const [],
    required this.recent,
    required this.onPickRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onOpenSpot,
    required this.onMoreFilters,
  });

  final String query;
  final List<SpotModel> spots;
  final List<SpotSearchHit> remoteHits;
  final List<String> recent;
  final ValueChanged<String> onPickRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<SpotModel> onOpenSpot;
  final VoidCallback onMoreFilters;

  static const maxResults = 30;

  static List<SpotModel> match(
    List<SpotModel> spots,
    String query, {
    List<SpotSearchHit> remoteHits = const [],
  }) {
    final localMatches = FuzzySearch.filter(
      spots,
      query,
      (s) => [s.name, s.municipality, s.category, ...s.tags],
    );
    if (remoteHits.isEmpty) return localMatches;
    final byId = <String, SpotModel>{for (final s in spots) s.id: s};
    final seen = <String>{};
    final merged = <SpotModel>[];
    for (final hit in remoteHits) {
      if (hit.id.isEmpty || !seen.add(hit.id)) continue;
      merged.add(byId[hit.id] ?? hit.toSpotModel());
    }
    for (final local in localMatches) {
      if (seen.add(local.id)) merged.add(local);
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final typed = FuzzySearch.words(query).isNotEmpty;
    return PixelPanel(
      key: const ValueKey('explore_search_results'),
      style: PixelBoxStyle.parchment,
      child: typed ? _matches(context, grid) : _recent(context, grid),
    );
  }

  Widget _header(BuildContext context, String title, {Widget? action}) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: PixelType.labelSmall(context, color: PixelPalette.slate),
            ),
          ),
          if (action != null) action,
        ],
      );

  Widget _recent(BuildContext context, PixelGrid grid) {
    if (recent.isEmpty) {
      return Text(
        'Type a place, town, food or tag.',
        key: const ValueKey('explore_search_hint'),
        style: PixelType.body(context, color: PixelPalette.slate),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          'RECENT SEARCHES',
          action: GestureDetector(
            key: const ValueKey('explore_recent_clear'),
            behavior: HitTestBehavior.opaque,
            onTap: onClearRecent,
            child: Padding(
              padding: EdgeInsets.all(grid.px(1)),
              child: Text(
                'CLEAR',
                style: PixelType.labelSmall(context, color: PixelPalette.red),
              ),
            ),
          ),
        ),
        SizedBox(height: grid.px(1)),
        for (final (i, q) in recent.indexed)
          Semantics(
            button: true,
            label: 'Search $q again',
            child: GestureDetector(
              key: ValueKey('explore_recent_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onPickRecent(q),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(context, color: PixelPalette.ink),
                      ),
                    ),
                    GestureDetector(
                      key: ValueKey('explore_recent_remove_$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onRemoveRecent(q),
                      child: Padding(
                        padding: EdgeInsets.all(grid.px(2)),
                        child: Text(
                          'X',
                          semanticsLabel: 'Remove $q',
                          style: PixelType.labelSmall(context,
                              color: PixelPalette.slate),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _matches(BuildContext context, PixelGrid grid) {
    final found = match(spots, query, remoteHits: remoteHits);
    final shown = found.take(maxResults).toList();
    final countLabel = found.isEmpty
        ? 'NO MATCHES'
        : (found.length == 1 ? '1 PLACE' : '${found.length} PLACES');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          countLabel,
          action: PixelButton(
            key: const ValueKey('explore_more_filters'),
            label: 'Filters',
            variant: PixelButtonVariant.secondary,
            style: PixelBoxStyle.parchment,
            onPressed: onMoreFilters,
          ),
        ),
        if (found.isEmpty) ...[
          SizedBox(height: grid.px(2)),
          Text(
            'Nothing matches "${query.trim()}". Try a town or a shorter word.',
            key: const ValueKey('explore_search_empty'),
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ],
        for (final (i, spot) in shown.indexed) ...[
          if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
          Semantics(
            button: true,
            label: '${spot.name}, ${spot.municipality}',
            child: GestureDetector(
              key: ValueKey('explore_search_result_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpenSpot(spot),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                child: Row(
                  children: [
                    SizedBox(
                      width: grid.px(12),
                      height: grid.px(12),
                      child: ClipRect(child: _thumb(spot)),
                    ),
                    SizedBox(width: grid.px(2)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                PixelType.body(context, color: PixelPalette.ink)
                                    .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            spot.municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.small(context,
                                color: PixelPalette.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _thumb(SpotModel spot) {
    final url = spot.imageUrl;
    final fallback = Container(color: PixelPalette.paperDim);
    if (url == null || url.trim().isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
