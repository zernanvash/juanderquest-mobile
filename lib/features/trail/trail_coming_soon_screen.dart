import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/designer_guide.dart';

class TrailComingSoonScreen extends StatelessWidget {
  const TrailComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('The Trail')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              UiSpecContainer(
                spec: const UiSpec(
                  title: 'The Trail preview',
                  figmaLayer: 'Mobile / Trail / Coming Soon',
                  dimensions: 'Scrollable card, responsive width',
                  dataBinding: 'Static product preview; no route API calls',
                  stateNotes: 'Coming soon; no itinerary is generated',
                  uxNotes:
                      'Clearly distinguish planned features from live routing',
                  deferred: true,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppSpacing.roundedLg,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withValues(alpha: .2),
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Text('COMING SOON',
                            style: AppTypography.labelSmall.copyWith(
                                color: AppColors.woodBrown,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('A better way to explore along your route',
                          style: AppTypography.headlineSmall
                              .copyWith(color: AppColors.woodBrown)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'The Trail is being designed to suggest worthwhile stops between your starting point and destination, shaped by your interests and community feedback.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _TrailIdea(
                          icon: Icons.route_rounded,
                          title: 'Plan a route',
                          body: 'Choose where your trip begins and ends.'),
                      const _TrailIdea(
                          icon: Icons.place_rounded,
                          title: 'Find stops along the way',
                          body:
                              'Discover destinations and local experiences near your route.'),
                      const _TrailIdea(
                          icon: Icons.tune_rounded,
                          title: 'Make it yours',
                          body:
                              'Future suggestions can reflect your interests and travel history.'),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => context.go('/explore'),
                        icon: const Icon(Icons.explore_rounded),
                        label: const Text('Back to Explore'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TrailIdea extends StatelessWidget {
  const _TrailIdea(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTypography.labelLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(body,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ])),
        ]),
      );
}
