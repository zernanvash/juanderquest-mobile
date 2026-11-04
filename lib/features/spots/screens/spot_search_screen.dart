import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
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

/// Dedicated Search & Discovery Workstation Screen for JuanDerQuest Mobile.
class SpotSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialCrowd;

  const SpotSearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialCrowd,
  });

  @override
  ConsumerState<SpotSearchScreen> createState() => _SpotSearchScreenState();
}

class _SpotSearchScreenState extends ConsumerState<SpotSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _selectedCategory = 'all';
  String _selectedMunicipality = 'All Municipalities';
  bool _quietOnly = false;
  bool _questsOnly = false;

  final Map<String, int> _likes = {};
  final Set<String> _likedSpots = {};

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All Destinations'},
    {'id': 'eat_drink', 'label': 'Food & Culinary'},
    {'id': 'nature_outdoors', 'label': 'Nature & Beaches'},
    {'id': 'culture_heritage', 'label': 'Heritage & Shrines'},
    {'id': 'activities_wellness', 'label': 'Outdoor & Eco'},
    {'id': 'shopping_local', 'label': 'Local MSME Crafts'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialCrowd == 'quiet') {
      _quietOnly = true;
    }

    Future.microtask(() {
      ref.read(spotDiscoveryProvider.notifier).initialize();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  void _toggleLike(String spotId) {
    setState(() {
      final currentCount = _likes[spotId] ?? (45 + spotId.hashCode % 120).abs();
      if (_likedSpots.contains(spotId)) {
        _likedSpots.remove(spotId);
        _likes[spotId] = currentCount - 1;
      } else {
        _likedSpots.add(spotId);
        _likes[spotId] = currentCount + 1;
      }
    });
  }

  void _launchDirections(SpotModel spot) {
    context.push(
      '/navigate?lat=${spot.gpsLat}&lng=${spot.gpsLng}&name=${Uri.encodeComponent(spot.name)}&address=${Uri.encodeComponent(spot.address.isNotEmpty ? spot.address : spot.municipality)}',
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'all';
      _selectedMunicipality = 'All Municipalities';
      _quietOnly = false;
      _questsOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final query = _searchController.text.trim().toLowerCase();
    final featuredSearches =
        (state.trending.isNotEmpty ? state.trending : state.spots)
            .map((spot) => spot.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .take(8)
            .toList();
    final municipalities = state.spots
        .map((spot) => spot.municipality.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final municipalityOptions = ['All Municipalities', ...municipalities];
    final selectedMunicipality =
        municipalityOptions.contains(_selectedMunicipality)
            ? _selectedMunicipality
            : 'All Municipalities';

    final filteredSpots = state.spots.where((spot) {
      final matchesQuery = query.isEmpty ||
          spot.name.toLowerCase().contains(query) ||
          spot.description.toLowerCase().contains(query) ||
          spot.municipality.toLowerCase().contains(query) ||
          spot.tags.any((t) => t.toLowerCase().contains(query));
      final matchesCategory =
          _selectedCategory == 'all' || spot.category == _selectedCategory;
      final matchesMuni = selectedMunicipality == 'All Municipalities' ||
          spot.municipality.toLowerCase() == selectedMunicipality.toLowerCase();
      final matchesQuiet = !_quietOnly ||
          (spot.crowdStatus == 'quiet' || spot.crowdStatus == 'moderate');
      final matchesQuest =
          !_questsOnly || (spot.questId != null && spot.questId!.isNotEmpty);
      return matchesQuery &&
          matchesCategory &&
          matchesMuni &&
          matchesQuiet &&
          matchesQuest;
    }).toList();

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
                    title: 'Search Places',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelTextField(
                          key: const ValueKey('search_field'),
                          controller: _searchController,
                          focusNode: _focusNode,
                          label: 'Search places, food, beaches',
                          hint: 'Type a place or experience',
                          onChanged: _onSearchChanged,
                        ),
                        if (query.isNotEmpty) ...[
                          SizedBox(height: grid.px(1)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: PixelButton(
                              key: const ValueKey('search_clear'),
                              label: 'Clear',
                              variant: PixelButtonVariant.secondary,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: grid.px(3)),
                        if (query.isEmpty && featuredSearches.isNotEmpty) ...[
                          Text('Explore Current Destinations',
                              style: PixelType.title(context)),
                          SizedBox(height: grid.px(1)),
                          Wrap(
                            spacing: grid.px(1),
                            runSpacing: grid.px(1),
                            children: [
                              for (final term in featuredSearches)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.text = term;
                                    setState(() {});
                                  },
                                  child: PixelPanel(
                                    style: PixelBoxStyle.parchment,
                                    padding: 1,
                                    child: Text(
                                      term,
                                      style: PixelType.small(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: grid.px(3)),
                        ],
                        Text('Categories', style: PixelType.title(context)),
                        SizedBox(height: grid.px(1)),
                        Wrap(
                          spacing: grid.px(1),
                          runSpacing: grid.px(1),
                          children: [
                            for (final cat in _categories)
                              GestureDetector(
                                key: ValueKey('search_cat_${cat['id']}'),
                                onTap: () => setState(
                                    () => _selectedCategory = cat['id']!),
                                child: PixelPanel(
                                  style: _selectedCategory == cat['id']
                                      ? PixelBoxStyle.green
                                      : PixelBoxStyle.parchment,
                                  padding: 1,
                                  child: Text(
                                    cat['label']!,
                                    style: PixelType.small(
                                      context,
                                      color: _selectedCategory == cat['id']
                                          ? PixelPalette.white
                                          : PixelPalette.ink,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: grid.px(3)),
                        _municipalityField(context, grid, selectedMunicipality,
                            municipalityOptions),
                        SizedBox(height: grid.px(2)),
                        Wrap(
                          spacing: grid.px(2),
                          runSpacing: grid.px(2),
                          children: [
                            _toggle(
                              context,
                              grid,
                              key: const ValueKey('search_quiet'),
                              label: 'Low Crowd Only',
                              on: _quietOnly,
                              onTap: () =>
                                  setState(() => _quietOnly = !_quietOnly),
                            ),
                            _toggle(
                              context,
                              grid,
                              key: const ValueKey('search_quests'),
                              label: 'Quests Only',
                              on: _questsOnly,
                              onTap: () =>
                                  setState(() => _questsOnly = !_questsOnly),
                            ),
                          ],
                        ),
                        SizedBox(height: grid.px(3)),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${filteredSpots.length} Results Found',
                                style: PixelType.title(context),
                              ),
                            ),
                            if (_selectedCategory != 'all' ||
                                _selectedMunicipality != 'All Municipalities' ||
                                _quietOnly ||
                                _questsOnly ||
                                query.isNotEmpty)
                              PixelButton(
                                key: const ValueKey('search_clear_all'),
                                label: 'Clear All Filters',
                                variant: PixelButtonVariant.secondary,
                                onPressed: _clearFilters,
                              ),
                          ],
                        ),
                        SizedBox(height: grid.px(2)),
                        if (filteredSpots.isEmpty)
                          PixelEmptyState(
                            key: const ValueKey('search_empty'),
                            title: 'No matching destinations',
                            message:
                                'Try adjusting your keywords, town, or category filters.',
                            action: PixelButton(
                              label: 'Reset All Filters',
                              onPressed: _clearFilters,
                            ),
                          )
                        else
                          for (final spot in filteredSpots) ...[
                            _resultCard(context, grid, spot),
                            SizedBox(height: grid.px(3)),
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

  Widget _municipalityField(BuildContext context, PixelGrid grid,
      String selected, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MUNICIPALITY',
            style: PixelType.small(context, color: PixelPalette.slate)),
        SizedBox(height: grid.px(1)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final name in options)
              GestureDetector(
                onTap: () => setState(() => _selectedMunicipality = name),
                child: PixelPanel(
                  style: selected == name
                      ? PixelBoxStyle.gold
                      : PixelBoxStyle.parchment,
                  padding: 1,
                  child: Text(name, style: PixelType.small(context)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _toggle(BuildContext context, PixelGrid grid,
      {required Key key,
      required String label,
      required bool on,
      required VoidCallback onTap}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: PixelPanel(
        style: on ? PixelBoxStyle.green : PixelBoxStyle.parchment,
        padding: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelArtCheck(on: on),
            SizedBox(width: grid.px(1)),
            Text(
              label,
              style: PixelType.small(
                context,
                color: on ? PixelPalette.white : PixelPalette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, PixelGrid grid, SpotModel spot) {
    final likeCount = _likes[spot.id] ?? (45 + spot.name.length * 3);
    final isLiked = _likedSpots.contains(spot.id);
    return PixelPanel(
      key: ValueKey('search_spot_${spot.id}'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(spot.municipality, style: PixelBoxStyle.slot),
              Text(
                'Shared by ${spot.sourceName}',
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              if (spot.trustLevel == 'lgu_verified')
                const PixelChip('LGU Verified',
                    style: PixelBoxStyle.green, textColor: PixelPalette.white),
            ],
          ),
          SizedBox(height: grid.px(2)),
          GestureDetector(
            onTap: () => context.push('/explore/${spot.slug}', extra: spot),
            child: Text(spot.name, style: PixelType.title(context)),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            spot.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            GestureDetector(
              onTap: () => context.push('/explore/${spot.slug}', extra: spot),
              child: SizedBox(
                height: grid.px(55),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: Image.network(
                        spot.imageUrl!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const DitherBackground(
                          top: PixelPalette.greenMid,
                          bottom: PixelPalette.greenDeep,
                        ),
                      ),
                    ),
                    if (spot.questId != null && spot.questId!.isNotEmpty)
                      Positioned(
                        top: grid.px(1),
                        right: grid.px(1),
                        child: const PixelChip('+250 mJDQ Bounty'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                key: ValueKey('search_like_${spot.id}'),
                onTap: () => _toggleLike(spot.id),
                child: PixelPanel(
                  style: isLiked ? PixelBoxStyle.red : PixelBoxStyle.slot,
                  padding: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PixelSprite(
                        isLiked
                            ? DesignerArt.heartLiked
                            : DesignerArt.heartUnliked,
                        scale: 2,
                      ),
                      SizedBox(width: grid.px(1)),
                      Text(
                        '$likeCount',
                        style: PixelType.small(
                          context,
                          color:
                              isLiked ? PixelPalette.white : PixelPalette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PixelButton(
                key: ValueKey('search_save_${spot.id}'),
                label: spot.saved ? 'Saved' : 'Save',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    ref.read(spotDiscoveryProvider.notifier).toggleSaved(spot),
              ),
              if (spot.questId != null && spot.questId!.isNotEmpty)
                PixelButton(
                  key: ValueKey('search_play_${spot.id}'),
                  label: 'Play Quest',
                  onPressed: () => context.push('/quests/${spot.questId}'),
                ),
              PixelButton(
                key: ValueKey('search_navigate_${spot.id}'),
                label: 'Navigate',
                variant: PixelButtonVariant.secondary,
                onPressed: () => _launchDirections(spot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PixelArtCheck extends StatelessWidget {
  const PixelArtCheck({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      width: grid.px(5),
      height: grid.px(5),
      child: PixelPanel(
        style: on ? PixelBoxStyle.gold : PixelBoxStyle.slot,
        padding: 0,
        child: on
            ? Center(
                child: Text(
                  'x',
                  style: PixelType.small(context, color: PixelPalette.ink),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
