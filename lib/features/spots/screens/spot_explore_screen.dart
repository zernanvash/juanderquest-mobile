import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen> {
  final Map<String, int> _likes = {};
  final Set<String> _likedSpots = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(spotDiscoveryProvider.notifier).initialize());
  }

  Future<void> _load({bool refresh = false}) {
    return ref.read(spotDiscoveryProvider.notifier).load(refresh: refresh);
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
    final user = ref.watch(authProvider).user;
    final userInitial = user?.displayName != null && user!.displayName.isNotEmpty
        ? user.displayName.substring(0, 1).toUpperCase()
        : 'U';

    return JdqScaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'JuanDerQuest',
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
            ],
          ),
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.sunGold.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.sunGold.withOpacity(0.6), width: 1.2),
              ),
              child: const Icon(Icons.view_in_ar_rounded, color: AppColors.woodBrown, size: 18),
            ),
            tooltip: 'AR Spatial Viewfinder & Test Bench',
            onPressed: () => context.push('/ar-test'),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
            ),
            tooltip: 'Search & Filters',
            onPressed: () => context.push('/search'),
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
            // 1. Social Media Search Bar (Tapping opens dedicated /search screen)
            GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.borderLowContrast),
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Search destinations, food, towns...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.borderLowContrast),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.tune_rounded, size: 12, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Live Anti-Crowd Diversion Alert Banner (Directly below search bar)
            _buildLiveAntiCrowdAlert(),

            const SizedBox(height: 12),

            // 3. Post Creation Prompt Box
            GestureDetector(
              onTap: () async {
                final added = await context.push<bool>('/spots/new');
                if (added == true) _load(refresh: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.borderLowContrast),
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        userInitial,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Share a hidden beach, spot, or food tip...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),

            if (state.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
              ),

            const SizedBox(height: 14),

            // 4. Feed Stream List
            if (state.isInitialLoading)
              const _DestinationSkeleton()
            else if (state.failure != null && state.spots.isEmpty)
              _buildErrorCard(state.failure!.message)
            else if (state.spots.isEmpty)
              _buildEmptyCard()
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${state.spots.length} Community Field Reports',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: const Text(
                        'Advanced Search →',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              // Facebook-Style Edge-to-Edge Post Feed
              ...state.spots.map((spot) => _buildForumPostCard(spot)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAntiCrowdAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF3E0),
            const Color(0xFFFFE0B2).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.8)),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withOpacity(0.15),
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE ANTI-CROWD ALERT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE65100),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Hundred Islands Peak Pressure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'High tourist density reported at Alaminos Lucap wharfs. Divert to tranquil nearby spots like Timmaw Cave or Tambobong Beach to unlock +1.5x mJDQ Points!',
            style: TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.35),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.push('/search', extra: {'crowd': 'quiet'}),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFE65100),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filter Tranquil Alternatives',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForumPostCard(SpotModel spot) {
    final likeCount = _likes[spot.id] ?? (45 + spot.name.length * 3);
    final isLiked = _likedSpots.contains(spot.id);

    return UiSpecContainer(
      spec: const UiSpec(
        title: 'Destination Community Post Card',
        figmaLayer: '#Spot_Forum_Card',
        dimensions: 'Full width, Radius: 20dp, Edge-to-Edge photo clip',
        dataBinding: 'spotDiscoveryProvider (municipality, sourceName, trustLevel, crowdStatus, likeCount)',
        stateNotes: 'Instagram Heart Toggle -> Dynamic like counter -> Quest tag link',
        uxNotes: 'Wood brown typography with warm sun gold accents and responsive category wrap.',
      ),
      child: Container(
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
            // 1. Compact Header & Caption Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Header
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
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
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
                              Text(
                                'LGU Verified',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.lguVerified),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Title
                  GestureDetector(
                    onTap: () => context.push('/explore/${spot.slug}', extra: spot),
                    child: Text(
                      spot.name,
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ),

                  // Crowd Status (if busy or quiet)
                  if (spot.crowdStatus == 'estimated_busy') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        color: AppColors.crowdBusyBg,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.crowdBusy),
                          SizedBox(width: 4),
                          Text(
                            'Peak Activity Reported',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.crowdBusy),
                          ),
                        ],
                      ),
                    ),
                  ] else if (spot.crowdStatus == 'quiet') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        color: AppColors.crowdQuietBg,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: const Text(
                        '🌿 Serene & Low Crowd',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.crowdQuiet),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Description Snippet
                  Text(
                    spot.description,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 2. Full-Bleed Edge-to-Edge Photo (Facebook-Style Border Clipping)
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

            // 3. Compact Social Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Like Button
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isLiked ? const Color(0xFFE63946) : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tips Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '${spot.reasons.length + 3} Tips',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

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

                  // Play Quest (if available)
                  if (spot.questId != null && spot.questId!.isNotEmpty)
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
                            Text(
                              'Play Quest',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Navigate Button
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
                          Text(
                            'Navigate',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          const Text('Pull down to refresh destination stream.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          SecondaryButton(label: 'Refresh Feed', onPressed: () => _load(refresh: true)),
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
                  Container(width: 80, height: 12, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
                  const SizedBox(width: 8),
                  Container(width: 60, height: 12, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
                ],
              ),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 16, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
              const SizedBox(height: 8),
              Container(width: 140, height: 12, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedSm)),
              const SizedBox(height: 12),
              Container(width: double.infinity, height: 120, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppSpacing.roundedMd)),
            ],
          ),
        ),
      ),
    );
  }
}
