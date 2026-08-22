import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _category = '';
  String _intent = '';
  String _sortFlair = 'hot'; // 'hot', 'new', 'quests', 'quiet'
  final Map<String, int> _upvotes = {};
  final Map<String, int> _userVotes = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(spotDiscoveryProvider.notifier).initialize());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) {
    return ref.read(spotDiscoveryProvider.notifier).load(
          query: _search.text,
          category: _category,
          intent: _intent,
          refresh: refresh,
        );
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _handleVote(String spotId, int direction) {
    setState(() {
      final currentVote = _userVotes[spotId] ?? 0;
      final currentCount = _upvotes[spotId] ?? 45;

      if (currentVote == direction) {
        // Untoggle
        _userVotes[spotId] = 0;
        _upvotes[spotId] = currentCount - direction;
      } else {
        _upvotes[spotId] = currentCount + direction - currentVote;
        _userVotes[spotId] = direction;
      }
    });
  }

  Future<void> _launchDirections(SpotModel spot) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${spot.gpsLat},${spot.gpsLng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? user?.demoPoints ?? 1250;

    final categories = state.categories.isEmpty
        ? const ['eat_drink', 'nature_outdoors', 'culture_heritage', 'activities_wellness']
        : state.categories;

    // Filter by flair
    final displayedSpots = state.spots.where((s) {
      if (_sortFlair == 'quests') return s.questId != null && s.questId!.isNotEmpty;
      if (_sortFlair == 'quiet') return s.crowdStatus == 'quiet' || s.crowdStatus == 'moderate';
      return true;
    }).toList();

    return JdqScaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.sunGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_rounded, color: AppColors.woodBrown, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'r/JuanDerQuest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                  Text(
                    'Pangasinan Travel & Quest Feed',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 20),
            ),
            tooltip: 'Share Hidden Gem',
            onPressed: () async {
              final added = await context.push<bool>('/spots/new');
              if (added == true) _load(refresh: true);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Reddit Community Header Banner
            _buildCommunityBanner(),

            const SizedBox(height: 12),

            // Live Overcrowding Diversion Banner
            _buildCrowdDiversionCard(),

            const SizedBox(height: 12),

            // Search Box
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              onSubmitted: (_) => _load(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search hidden beaches, food, waterfalls...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.roundedLg,
                  borderSide: BorderSide(color: AppColors.borderLowContrast),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.roundedLg,
                  borderSide: BorderSide(color: AppColors.borderLowContrast),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.roundedLg,
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Sorting Flairs (Hot, New, Quests, Quiet)
            _buildFlairsRow(),

            const SizedBox(height: 10),

            // Category Sub-Flairs
            _buildCategoryRow(categories),

            if (state.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
              ),

            const SizedBox(height: 14),

            if (state.isInitialLoading)
              const _DestinationSkeleton()
            else if (state.failure != null && state.spots.isEmpty)
              _buildErrorCard(state.failure!.message)
            else if (displayedSpots.isEmpty)
              _buildEmptyCard()
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${displayedSpots.length} Community Posts',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                    ),
                    Text(
                      'Tap post to view details',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Forum-Style Post Feed
              ...displayedSpots.map((spot) => _buildForumPostCard(spot, state)),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF582F0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.roundedXl,
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sunGold,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: const Text(
                  'COMMUNITY FORUM',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                ),
              ),
              const Text(
                '• 3,280 JuanDerers Online',
                style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore Pangasinan\'s Hidden Gems',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Discover tranquil spots, share photo logs, and complete verified cultural quests for reward vouchers.',
            style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdDiversionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.crowdModerateBg,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.sunGold.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded, color: AppColors.woodBrown, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Anti-Overcrowding Bonus Active',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                ),
                Text(
                  'Visit quiet hidden gems outside peak landmarks to earn +1.5x mJDQ Points!',
                  style: TextStyle(fontSize: 11, color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlairsRow() {
    final flairs = [
      {'key': 'hot', 'label': '🔥 Hot'},
      {'key': 'new', 'label': '✨ New'},
      {'key': 'quests', 'label': '🏆 Quests Only'},
      {'key': 'quiet', 'label': '🌿 Quiet Gems'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: flairs.map((f) {
          final isSelected = _sortFlair == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              selectedColor: AppColors.sunGold,
              backgroundColor: AppColors.surfaceContainerLowest,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.woodBrown : AppColors.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedPill,
                side: BorderSide(color: isSelected ? AppColors.sunGold : AppColors.borderLowContrast),
              ),
              onSelected: (_) {
                setState(() => _sortFlair = f['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['', ...categories].map((cat) {
          final isSelected = _category == cat;
          final label = cat.isEmpty ? 'All Categories' : cat.replaceAll('_', ' ');
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: AppColors.primary.withOpacity(0.15),
              backgroundColor: AppColors.surfaceContainerLowest,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedMd,
                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.borderLowContrast),
              ),
              onSelected: (_) {
                setState(() => _category = cat);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildForumPostCard(SpotModel spot, dynamic state) {
    final votes = _upvotes[spot.id] ?? (45 + spot.name.length * 3);
    final userVote = _userVotes[spot.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: InkWell(
        borderRadius: AppSpacing.roundedXl,
        onTap: () => context.push('/explore/${spot.slug}', extra: spot),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post Header (Reddit / Forum metadata)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'p/${spot.municipality.toLowerCase().replaceAll(' ', '')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text(
                    'u/${spot.sourceName.replaceAll(' ', '')}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  if (spot.trustLevel == 'lgu_verified') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.lguVerifiedBg,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, color: AppColors.lguVerified, size: 12),
                          SizedBox(width: 3),
                          Text(
                            'LGU Verified',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.lguVerified),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (spot.crowdStatus == 'quiet') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.crowdQuietBg,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: const Text(
                        '🌿 Quiet',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.crowdQuiet),
                      ),
                    ),
                  ] else if (spot.crowdStatus == 'estimated_busy') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.crowdBusyBg,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: const Text(
                        '⚠️ Peak Activity',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.crowdBusy),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Title
              Text(
                spot.name,
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.woodBrown,
                ),
              ),

              const SizedBox(height: 4),

              // Municipality & Distance
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '${spot.municipality}${spot.distanceKm == null ? '' : ' • ${spot.distanceKm!.toStringAsFixed(1)} km away'}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Photo Container (if photo exists)
              if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: AppSpacing.roundedLg,
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
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
                            decoration: BoxDecoration(
                              color: AppColors.sunGold,
                              borderRadius: AppSpacing.roundedPill,
                              boxShadow: AppSpacing.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
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
                const SizedBox(height: 8),
              ],

              // Description Snippet
              Text(
                spot.description,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // Social Action & Engagement Bar (Reddit style)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Upvote / Downvote Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: userVote == 1 ? AppColors.sunGold : AppColors.textMuted,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => _handleVote(spot.id, 1),
                        ),
                        Text(
                          '$votes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: userVote == 1 ? AppColors.woodBrown : AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: userVote == -1 ? AppColors.danger : AppColors.textMuted,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => _handleVote(spot.id, -1),
                        ),
                      ],
                    ),
                  ),

                  // Tips Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${spot.reasons.length + 3} Tips',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Play Quest Button (if available)
                  if (spot.questId != null && spot.questId!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => context.push('/quests/${spot.questId}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withOpacity(0.2),
                          borderRadius: AppSpacing.roundedPill,
                          border: Border.all(color: AppColors.sunGold),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.woodBrown),
                            SizedBox(width: 2),
                            Text(
                              'Play Quest',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Directions Button
                  IconButton(
                    icon: const Icon(Icons.navigation_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Get Directions',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _launchDirections(spot),
                  ),

                  // Save / Bookmark
                  IconButton(
                    icon: Icon(
                      spot.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 18,
                      color: spot.saved ? AppColors.sunGold : AppColors.textMuted,
                    ),
                    tooltip: 'Bookmark',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => ref.read(spotDiscoveryProvider.notifier).toggleSaved(spot),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.danger),
          const SizedBox(height: 8),
          Text('Failed to load feed', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(error, textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Retry', onPressed: () => _load(refresh: true)),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Column(
        children: [
          const Icon(Icons.explore_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('No posts found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Try adjusting your search query or category filters.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          SecondaryButton(label: 'Reset Filters', onPressed: () {
            setState(() {
              _category = '';
              _intent = '';
              _sortFlair = 'hot';
              _search.clear();
            });
            _load();
          }),
        ],
      ),
    );
  }
}

class _DestinationSkeleton extends StatelessWidget {
  const _DestinationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppSpacing.roundedXl,
            border: Border.all(color: AppColors.borderLowContrast),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 80, height: 12, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
                  const SizedBox(width: 8),
                  Container(width: 60, height: 12, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
                ],
              ),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 120, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedMd)),
            ],
          ),
        ),
      ),
    );
  }
}
