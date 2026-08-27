import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
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

  final List<String> _popularSearches = const [
    'Cape Bolinao Lighthouse',
    'Patar White Beach',
    'Hundred Islands',
    'Dasol Salt Beds',
    'Bangus Grill',
    'Minor Basilica of Manaoag',
    'Timmaw Cave',
    'Lingayen Baywalk',
  ];

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All Destinations', 'emoji': '✨'},
    {'id': 'eat_drink', 'label': 'Food & Culinary', 'emoji': '🍜'},
    {'id': 'nature_outdoors', 'label': 'Nature & Beaches', 'emoji': '🏖️'},
    {'id': 'culture_heritage', 'label': 'Heritage & Shrines', 'emoji': '🏛️'},
    {'id': 'activities_wellness', 'label': 'Outdoor & Eco', 'emoji': '🧗'},
    {'id': 'shopping_local', 'label': 'Local MSME Crafts', 'emoji': '🛍️'},
  ];

  final List<String> _municipalities = const [
    'All Municipalities',
    'Alaminos City',
    'Bolinao',
    'Dagupan City',
    'Lingayen',
    'Manaoag',
    'Dasol',
    'Bani',
    'San Fabian',
    'Anda',
    'Burgos',
    'Agno',
    'Infanta',
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


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final query = _searchController.text.trim().toLowerCase();

    final filteredSpots = state.spots.where((spot) {
      // Query filter
      final matchesQuery = query.isEmpty ||
          spot.name.toLowerCase().contains(query) ||
          spot.description.toLowerCase().contains(query) ||
          spot.municipality.toLowerCase().contains(query) ||
          spot.tags.any((t) => t.toLowerCase().contains(query));

      // Category filter
      final matchesCategory = _selectedCategory == 'all' || spot.category == _selectedCategory;

      // Municipality filter
      final matchesMuni = _selectedMunicipality == 'All Municipalities' ||
          spot.municipality.toLowerCase().contains(_selectedMunicipality.toLowerCase());

      // Quiet toggle
      final matchesQuiet = !_quietOnly || (spot.crowdStatus == 'quiet' || spot.crowdStatus == 'moderate');

      // Quest toggle
      final matchesQuest = !_questsOnly || (spot.questId != null && spot.questId!.isNotEmpty);

      return matchesQuery && matchesCategory && matchesMuni && matchesQuiet && matchesQuest;
    }).toList();

    return JdqScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppSpacing.roundedLg,
            border: Border.all(color: AppColors.borderLowContrast),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13, color: AppColors.woodBrown, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search Pangasinan spots, food, beaches...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Popular Searches Horizontal Chips
          if (query.isEmpty) ...[
            const Text(
              'Popular Searches',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _popularSearches.map((term) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppSpacing.roundedPill,
                      border: Border.all(color: AppColors.borderLowContrast),
                    ),
                    child: Text(
                      term,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.woodBrown),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Category Chips Row
          const Text(
            'Categories',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat['id'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = cat['id']!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                    borderRadius: AppSpacing.roundedPill,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLowContrast,
                    ),
                    boxShadow: isSelected ? AppSpacing.cardShadow : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.woodBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Filters Row (Municipality + Toggles)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Municipality Dropdown Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.borderLowContrast),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMunicipality,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.woodBrown, size: 20),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                    items: _municipalities.map((muni) {
                      return DropdownMenuItem<String>(
                        value: muni,
                        child: Text(muni),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMunicipality = val);
                    },
                  ),
                ),
              ),

              // Low Crowd Toggle
              FilterChip(
                label: const Text('🌿 Low Crowd Only'),
                selected: _quietOnly,
                selectedColor: AppColors.crowdQuietBg,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _quietOnly ? AppColors.crowdQuiet : AppColors.woodBrown,
                ),
                backgroundColor: AppColors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.roundedPill,
                  side: BorderSide(
                    color: _quietOnly ? AppColors.crowdQuiet : AppColors.borderLowContrast,
                  ),
                ),
                onSelected: (val) => setState(() => _quietOnly = val),
              ),

              // Quests Only Toggle
              FilterChip(
                label: const Text('🏆 Quests Only'),
                selected: _questsOnly,
                selectedColor: AppColors.sunGold.withOpacity(0.25),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _questsOnly ? AppColors.woodBrown : AppColors.textSecondary,
                ),
                backgroundColor: AppColors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.roundedPill,
                  side: BorderSide(
                    color: _questsOnly ? AppColors.sunGold : AppColors.borderLowContrast,
                  ),
                ),
                onSelected: (val) => setState(() => _questsOnly = val),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search Results Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredSpots.length} Results Found',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
              ),
              if (_selectedCategory != 'all' || _selectedMunicipality != 'All Municipalities' || _quietOnly || _questsOnly || query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      _selectedCategory = 'all';
                      _selectedMunicipality = 'All Municipalities';
                      _quietOnly = false;
                      _questsOnly = false;
                    });
                  },
                  child: const Text(
                    'Clear All Filters',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Search Results Feed
          if (filteredSpots.isEmpty)
            _buildEmptyState()
          else
            ...filteredSpots.map((spot) => _buildSearchResultCard(spot)),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(SpotModel spot) {
    final likeCount = _likes[spot.id] ?? (45 + spot.name.length * 3);
    final isLiked = _likedSpots.contains(spot.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Metadata Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          spot.municipality,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text(
                      'Shared by ${spot.sourceName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    if (spot.trustLevel == 'lgu_verified') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: const BoxDecoration(
                          color: AppColors.lguVerifiedBg,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: AppColors.lguVerified, size: 11),
                            SizedBox(width: 2),
                            Text('LGU Verified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.lguVerified)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.push('/explore/${spot.slug}', extra: spot),
                  child: Text(
                    spot.name,
                    style: AppTypography.headlineSmall.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spot.description,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Edge-to-Edge Photo (Facebook-Style Border Clipping)
          if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => context.push('/explore/${spot.slug}', extra: spot),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      spot.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 36),
                        ),
                      ),
                    ),
                  ),
                  if (spot.questId != null && spot.questId!.isNotEmpty) ...[
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.sunGold,
                          borderRadius: AppSpacing.roundedPill,
                          boxShadow: AppSpacing.cardShadow,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.woodBrown),
                            SizedBox(width: 4),
                            Text(
                              '+250 mJDQ Bounty',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Compact Social & Actions Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like
                    GestureDetector(
                      onTap: () => _toggleLike(spot.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLiked ? const Color(0xFFFFF0F1) : AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 14,
                              color: isLiked ? const Color(0xFFE63946) : AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$likeCount',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isLiked ? const Color(0xFFE63946) : AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Bookmark
                    IconButton(
                      icon: Icon(
                        spot.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 16,
                        color: spot.saved ? AppColors.sunGold : AppColors.textMuted,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => ref.read(spotDiscoveryProvider.notifier).toggleSaved(spot),
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (spot.questId != null && spot.questId!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => context.push('/quests/${spot.questId}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.sunGold,
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 13, color: AppColors.woodBrown),
                              SizedBox(width: 2),
                              Text('Play Quest', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    GestureDetector(
                      onTap: () => _launchDirections(spot),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.navigation_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Navigate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('No matching destinations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.woodBrown)),
          const SizedBox(height: 4),
          const Text('Try adjusting your keywords, town, or category filters.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedCategory = 'all';
                _selectedMunicipality = 'All Municipalities';
                _quietOnly = false;
                _questsOnly = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
            child: const Text('Reset All Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
