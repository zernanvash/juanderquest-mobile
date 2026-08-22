import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  List<SpotModel> _alternatives = [];
  bool _loadingAlternatives = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.spot.saved;
    Future.microtask(() {
      _loadAlternatives();
      _logInteraction('view');
    });
  }

  Future<void> _logInteraction(String type) async {
    try {
      await ref.read(apiClientProvider).dio.post(
        '/spots/${widget.spot.id}/interactions',
        data: {'type': type},
      );
    } catch (_) {}
  }

  Future<void> _loadAlternatives() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get(
        '/spots/${widget.spot.slug}/alternatives',
      );
      if (mounted && response.statusCode == 200 && response.data['data'] is List) {
        setState(() {
          _alternatives = (response.data['data'] as List)
              .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingAlternatives = false);
      }
    }
  }

  Future<void> _openDirections() async {
    await _logInteraction('directions');
    final spot = widget.spot;
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${spot.gpsLat},${spot.gpsLng}',
    );
    final geoUri = Uri.parse('geo:${spot.gpsLat},${spot.gpsLng}?q=${spot.gpsLat},${spot.gpsLng}(${Uri.encodeComponent(spot.name)})');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch navigation map app.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch navigation map app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final hasImage = spot.imageUrl != null &&
        spot.imageUrl!.isNotEmpty &&
        (spot.imageUrl!.startsWith('http://') || spot.imageUrl!.startsWith('https://'));

    final isBusy = spot.crowdStatus == 'estimated_busy';
    final isQuiet = spot.crowdStatus == 'estimated_quiet' || spot.crowdStatus == 'quiet';

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: _isSaved ? AppColors.sunGold : null,
            ),
            tooltip: _isSaved ? 'Saved to Wishlist' : 'Save Spot',
            onPressed: () {
              setState(() => _isSaved = !_isSaved);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isSaved ? 'Added "${spot.name}" to saved places.' : 'Removed from saved places.'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Destination',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Share link copied: https://jdq.zernanvash.dev/spots/${spot.slug}')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header
            UiSpecContainer(
              spec: const UiSpec(
                title: 'Destination Photography & LGU Verification Header',
                figmaLayer: '#Spot_Detail_Hero_Image',
                dimensions: 'Full width, AspectRatio: 16/10 (1080x675)',
                dataBinding: 'spot.imageUrl / spot.category / spot.trustLevel / spot.municipality',
                stateNotes: 'Network photography with dark contrast gradient & provenance chip',
                uxNotes: 'Displays municipality banner and LGU Verified badge.',
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: hasImage
                        ? Image.network(
                            spot.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildHeaderPlaceholder(spot),
                          )
                        : _buildHeaderPlaceholder(spot),
                  ),

                  // Gradient Overlay for contrast
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Category & Provenance Top Badges
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.9),
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Text(
                            spot.category.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: AppSpacing.roundedPill,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                spot.trustLevel == 'lgu_verified'
                                    ? Icons.verified_rounded
                                    : Icons.public_rounded,
                                size: 13,
                                color: spot.trustLevel == 'lgu_verified'
                                    ? AppColors.sunGold
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                spot.trustLevel == 'lgu_verified'
                                    ? 'LGU VERIFIED'
                                    : spot.sourceName.isNotEmpty
                                        ? spot.sourceName.toUpperCase()
                                        : 'COMMUNITY SPOT',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Municipality & Distance Bottom Banner
                  Positioned(
                    bottom: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.sunGold, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            spot.municipality.isNotEmpty
                                ? '${spot.municipality}, Pangasinan'
                                : 'Pangasinan, Philippines',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ),
                        if (spot.distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              '${spot.distanceKm!.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Address
                  Text(
                    spot.name,
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),

                  if (spot.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      spot.address,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Crowd Status Bar
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'Live Crowd Status & Visitor Density Card',
                      figmaLayer: '#Spot_Crowd_Status_Card',
                      dimensions: 'Full width, Padding: 12dp, Radius: 12dp',
                      dataBinding: 'spot.crowdStatus (estimated_busy / tranquil / moderate)',
                      stateNotes: 'Green (Tranquil Gem) -> Yellow (Moderate) -> Red (High Tourist Traffic)',
                      uxNotes: 'Provides dynamic diversion guidance for tourists.',
                    ),
                    child: _buildCrowdStatusCard(isBusy, isQuiet),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Get Directions',
                          icon: Icons.directions_rounded,
                          onPressed: _openDirections,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Add Photo',
                          icon: Icons.add_a_photo_rounded,
                          onPressed: () => context.push('/spots/new'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sectionGap),

                  // Gamified Quest Card (The Incentive Flywheel)
                  if (spot.questId != null) ...[
                    UiSpecContainer(
                      spec: const UiSpec(
                        title: 'Gamified Location Quest Flywheel Card',
                        figmaLayer: '#Spot_Quest_Flywheel_Card',
                        dimensions: 'Full width, Padding: 16dp, Radius: 16dp',
                        dataBinding: 'spot.questId / quest.rewardPoints',
                        stateNotes: 'Visible only when destination has an active quest attached',
                        uxNotes: 'Prominently showcases the +250 mJDQ Bounty reward and direct check-in CTA.',
                      ),
                      child: _buildQuestIncentiveCard(context, spot),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                  ],

                  // Overview & Description
                  Text(
                    'About this Destination',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    spot.description.isNotEmpty
                        ? spot.description
                        : 'Explore this cultural and scenic gem located in ${spot.municipality}, Pangasinan. Part of the JuanDerQuest eco-tourism network.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),

                  // Tags Wrap
                  if (spot.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spot.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppSpacing.roundedPill,
                            border: Border.all(color: AppColors.borderLowContrast),
                          ),
                          child: Text(
                            '#${tag.replaceAll('_', ' ')}',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sectionGap),

                  // Similar Hidden Gems Nearby
                  _buildAlternativesSection(context),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdStatusCard(bool isBusy, bool isQuiet) {
    if (isBusy) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.crowdBusyBg,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.crowdBusy.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.people_outline_rounded, color: AppColors.crowdBusy, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Peak Visiting Hours Detected',
                    style: TextStyle(
                      color: AppColors.crowdBusy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This spot may be busy based on recent traveler activity. Consider checking out quieter nearby alternatives below for bonus rewards!',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.crowdBusy.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isQuiet) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.crowdQuietBg,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.crowdQuiet.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.eco_rounded, color: AppColors.crowdQuiet, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Low Crowd Pressure — Great tranquil time to visit & photograph!',
                style: TextStyle(
                  color: AppColors.crowdQuiet,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildQuestIncentiveCard(BuildContext context, SpotModel spot) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.sunGold, width: 1.5),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.sunGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.woodBrown, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OPTIONAL DESTINATION QUEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Check-in & Earn +250 mJDQ',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Visit this spot in person to verify GPS proximity, scan the cultural marker, and earn reward points redeemable for Pangasinan merchant vouchers!',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Start Quest at this Spot',
              icon: Icons.rocket_launch_rounded,
              onPressed: () => context.push('/quests/${spot.questId}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Hidden Gems',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.woodBrown,
              ),
            ),
            const Text(
              '10–25 km Radius',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Lesser-known serene alternatives curated across Pangasinan.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),

        if (_loadingAlternatives)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_alternatives.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.roundedMd,
            ),
            child: const Text(
              'No other alternatives found in immediate vicinity.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _alternatives.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final alt = _alternatives[index];
                return _buildAlternativeCard(context, alt);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAlternativeCard(BuildContext context, SpotModel alt) {
    return GestureDetector(
      onTap: () => context.push('/explore/${alt.slug}', extra: alt),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.borderLowContrast),
          boxShadow: AppSpacing.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: alt.imageUrl != null && alt.imageUrl!.isNotEmpty
                    ? Image.network(
                        alt.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCardPlaceholder(alt),
                      )
                    : _buildCardPlaceholder(alt),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alt.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alt.municipality.isNotEmpty ? alt.municipality : 'Pangasinan',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alt.crowdStatus == 'estimated_quiet' ? AppColors.crowdQuietBg : AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Text(
                          alt.crowdStatus == 'estimated_quiet' ? 'Quiet' : alt.category.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: alt.crowdStatus == 'estimated_quiet' ? AppColors.crowdQuiet : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (alt.distanceKm != null)
                        Text(
                          '${alt.distanceKm!.toStringAsFixed(0)} km',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPlaceholder(SpotModel spot) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terrain_rounded, size: 54, color: Colors.white38),
            const SizedBox(height: 6),
            Text(
              spot.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPlaceholder(SpotModel spot) {
    return Container(
      color: AppColors.surfaceContainerLow,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: AppColors.textMuted),
      ),
    );
  }
}
