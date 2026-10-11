import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/hidden_gem_model.dart';
import '../providers/hidden_gem_provider.dart';

/// In-feed, ad-style Hidden Gem card for the mobile Explore feed.
///
/// Mobile counterpart of the web `HiddenGemHighlights` side-panel card: same
/// personalized endpoint and "Not sponsored" disclosure, but laid out as a
/// full-width native feed unit. It is quiet by design — while loading it
/// shows a slim placeholder, and on error or no results it collapses so the
/// feed is never blocked by a recommendation.
class HiddenGemCard extends ConsumerWidget {
  const HiddenGemCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gems = ref.watch(hiddenGemProvider);
    return gems.when(
      loading: () => const _HiddenGemPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HiddenGemAd(gem: items.first),
            ),
    );
  }
}

class _HiddenGemAd extends StatelessWidget {
  const _HiddenGemAd({required this.gem});

  final HiddenGemModel gem;

  void _open(BuildContext context) => context.push('/explore/${Uri.encodeComponent(gem.id)}');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Hidden Gem recommendation, not sponsored: ${gem.name}, ${gem.municipality}',
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedXl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppSpacing.roundedXl,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sponsored-style header strip with honest disclosure.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text(
                            'HIDDEN GEM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.roundedPill,
                          border: Border.all(color: AppColors.borderLowContrast),
                        ),
                        child: const Text(
                          'Not sponsored',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (gem.imageUrl != null)
                        Image.network(
                          gem.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImageFallback(),
                        )
                      else
                        const _ImageFallback(),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              gem.crowdLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gem.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.woodBrown,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              gem.municipality,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        gem.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _open(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text(
                            'View this gem',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.surfaceContainerLow,
        child: Center(child: Icon(Icons.landscape_rounded, color: AppColors.textMuted, size: 36)),
      );
}

class _HiddenGemPlaceholder extends StatelessWidget {
  const _HiddenGemPlaceholder();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          label: 'Loading Hidden Gem recommendation',
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.roundedXl,
              border: Border.all(color: AppColors.borderLowContrast),
            ),
          ),
        ),
      );
}
