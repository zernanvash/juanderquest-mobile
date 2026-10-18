import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/widgets/hidden_gem_card.dart';
import '../../submissions/models/submission_model.dart';
import '../../submissions/providers/submission_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(choiceEngagementProvider.future);
      ref.read(choiceOverviewProvider.future);
      ref.read(submissionProvider.notifier).fetchSubmissions();
      ref.read(spotDiscoveryProvider.notifier).load();
      ref.read(questProvider.notifier).fetchQuests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final engagement = ref.watch(choiceEngagementProvider);
    final overview = ref.watch(choiceOverviewProvider);
    final spots = ref.watch(spotDiscoveryProvider);
    final quests = ref.watch(questProvider);
    final submissions = ref.watch(submissionProvider);
    final firstName =
        (user?.displayName.trim().split(RegExp(r'\s+')).first ?? 'Traveler');
    final level = ((user?.points ?? 0) ~/ 50) + 1;
    final levelProgress = ((user?.points ?? 0) % 50) / 50;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your journey'),
        actions: [
          IconButton(
            tooltip: 'Explore destinations',
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(choiceEngagementProvider.future),
              ref.refresh(choiceOverviewProvider.future),
              ref.read(submissionProvider.notifier).fetchSubmissions(),
              ref.read(spotDiscoveryProvider.notifier).load(refresh: true),
              ref.read(questProvider.notifier).fetchQuests(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
            children: [
              UiSpecContainer(
                spec: const UiSpec(
                  title: 'Traveler dashboard',
                  figmaLayer: 'Mobile / Dashboard / Home',
                  dimensions:
                      'Responsive, vertically scrollable mobile dashboard',
                  dataBinding:
                      'Authenticated profile, engagement, destinations, quests, submissions, and JuanChoice APIs',
                  stateNotes:
                      'API failures are shown as unavailable; no synthetic activity or ranking data',
                  uxNotes:
                      'One-tap shortcuts keep Explore, map, quests, and JuanChoice close at hand',
                ),
                child: _HeroCard(
                  firstName: firstName,
                  points: user?.points ?? 0,
                  level: level,
                  progress: levelProgress,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionHeading(
                  title: 'Your impact',
                  action: 'View profile',
                  onTap: () => context.go('/profile')),
              const SizedBox(height: AppSpacing.sm),
              engagement.when(
                loading: () => const _LoadingPanel(height: 96),
                error: (_, __) => _UnavailablePanel(
                  message: 'Your travel stats are temporarily unavailable.',
                  onRetry: () => ref.invalidate(choiceEngagementProvider),
                ),
                data: (summary) => _ImpactGrid(summary: summary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading(
                  title: 'Pick your next stop',
                  action: 'Explore all',
                  onTap: () => context.go('/explore')),
              const SizedBox(height: AppSpacing.sm),
              _QuickActions(
                  onExplore: () => context.go('/explore'),
                  onMap: () => context.go('/map'),
                  onQuests: () => context.go('/quests')),
              const SizedBox(height: AppSpacing.md),
              if (spots.isInitialLoading && spots.spots.isEmpty)
                const _LoadingPanel(height: 150)
              else if (spots.failure != null && spots.spots.isEmpty)
                _UnavailablePanel(
                    message: 'Destinations could not be loaded.',
                    onRetry: () => ref
                        .read(spotDiscoveryProvider.notifier)
                        .load(refresh: true))
              else if (spots.spots.isNotEmpty)
                _FeaturedSpot(
                    spot: _recommendedSpot(spots.spots),
                    onTap: () => context.push(
                        '/explore/${Uri.encodeComponent(_recommendedSpot(spots.spots).id)}'))
              else
                const _EmptyPanel(
                    message:
                        'No destinations are available yet. Try again later.'),
              const SizedBox(height: AppSpacing.lg),
              const HiddenGemCard(),
              _SectionHeading(
                  title: 'JuanChoice',
                  action: 'Open',
                  onTap: () => context.go('/choice')),
              const SizedBox(height: AppSpacing.sm),
              overview.when(
                loading: () => const _LoadingPanel(height: 76),
                error: (_, __) => _UnavailablePanel(
                    message: 'JuanChoice status is unavailable.',
                    onRetry: () => ref.invalidate(choiceOverviewProvider)),
                data: (data) => _JuanChoiceCard(
                    overview: data, onTap: () => context.go('/choice')),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading(
                  title: 'Your quests',
                  action: 'See all',
                  onTap: () => context.go('/quests')),
              const SizedBox(height: AppSpacing.sm),
              if (quests.isLoading)
                const _LoadingPanel(height: 70)
              else if (quests.error != null)
                _UnavailablePanel(
                    message: 'Quest list is unavailable.',
                    onRetry: () =>
                        ref.read(questProvider.notifier).fetchQuests())
              else
                _InfoRow(
                  icon: Icons.flag_rounded,
                  title: '${quests.quests.length} quests available',
                  subtitle: 'Visit destinations and complete their activities.',
                  onTap: () => context.go('/quests'),
                ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading(
                  title: 'Recent activity',
                  action: 'History',
                  onTap: () => context.push('/history')),
              const SizedBox(height: AppSpacing.sm),
              if (submissions.isLoading && submissions.submissions.isEmpty)
                const _LoadingPanel(height: 70)
              else if (submissions.error != null &&
                  submissions.submissions.isEmpty)
                _UnavailablePanel(
                    message: 'Recent activity is unavailable.',
                    onRetry: () => ref
                        .read(submissionProvider.notifier)
                        .fetchSubmissions())
              else if (submissions.submissions.isEmpty)
                const _EmptyPanel(
                    message: 'Your quest submissions will appear here.')
              else
                ...submissions.submissions
                    .take(3)
                    .map((item) => _ActivityRow(submission: item)),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.quiz_outlined,
                title: 'Cultural quizzes',
                subtitle:
                    'Discover quizzes near participating heritage and cultural destinations.',
                onTap: () => context.go('/explore'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SpotModel _recommendedSpot(List<SpotModel> items) {
    return items.firstWhere((spot) => spot.reasons.isNotEmpty,
        orElse: () => items.first);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.firstName,
      required this.points,
      required this.level,
      required this.progress});
  final String firstName;
  final int points, level;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          borderRadius: AppSpacing.roundedXl,
          gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back, $firstName',
              style: AppTypography.headlineSmall.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('Keep discovering places and stories near you.',
              style: AppTypography.bodyMedium
                  .copyWith(color: Colors.white.withValues(alpha: .88))),
          const SizedBox(height: AppSpacing.lg),
          Text('$points Explorer XP · Level $level',
              maxLines: 2,
              softWrap: true,
              style: AppTypography.labelLarge
                  .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 9),
          ClipRRect(
              borderRadius: AppSpacing.roundedPill,
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  color: AppColors.sunGold,
                  backgroundColor: Colors.white.withValues(alpha: .22))),
          const SizedBox(height: 5),
          Text('${(progress * 50).round()} / 50 XP to next level',
              style: AppTypography.labelSmall
                  .copyWith(color: Colors.white.withValues(alpha: .85))),
        ]),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(
      {required this.title, required this.action, required this.onTap});
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title,
              style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.woodBrown, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action),
          ),
        ],
      );
}

class _ImpactGrid extends StatelessWidget {
  const _ImpactGrid({required this.summary});
  final ChoiceEngagementSummary summary;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        _StatTile(
            label: 'Visit streak',
            value: '${summary.currentStreak} days',
            icon: Icons.local_fire_department_outlined),
        _StatTile(
            label: 'Verified visits',
            value: '${summary.verifiedVisits}',
            icon: Icons.verified_outlined),
        _StatTile(
            label: 'Destinations',
            value: '${summary.uniqueDestinations}',
            icon: Icons.place_outlined),
        _StatTile(
            label: 'Municipalities',
            value: '${summary.municipalities}',
            icon: Icons.location_city_outlined),
      ]);
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 48) / 2,
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.borderLowContrast)),
            child: Row(children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textMuted))
                  ])),
            ])),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions(
      {required this.onExplore, required this.onMap, required this.onQuests});
  final VoidCallback onExplore, onMap, onQuests;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _ActionButton(
                icon: Icons.explore_outlined,
                label: 'Explore',
                onTap: onExplore)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: Icons.map_outlined, label: 'Map', onTap: onMap)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: Icons.flag_outlined, label: 'Quests', onTap: onQuests)),
      ]);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8)));
}

class _FeaturedSpot extends StatelessWidget {
  const _FeaturedSpot({required this.spot, required this.onTap});
  final SpotModel spot;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        color: AppColors.surfaceContainerLowest,
        child: InkWell(
            onTap: onTap,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (spot.imageUrl != null)
                Image.network(spot.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder())
              else
                const _ImagePlaceholder(),
              Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLarge
                                .copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(spot.municipality,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                        if (spot.reasons.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(spot.reasons.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.primary))
                        ],
                      ])),
            ])),
      );
}

class _JuanChoiceCard extends StatelessWidget {
  const _JuanChoiceCard({required this.overview, required this.onTap});
  final ChoiceOverview overview;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final current = overview.current;
    final label = current != null
        ? 'Current round: ${current.theme}'
        : overview.previous != null
            ? 'Previous result: ${overview.previous!.periodLabel}'
            : 'Community destination voting';
    return _InfoRow(
        icon: Icons.how_to_vote_outlined,
        title: label,
        subtitle:
            overview.notice ?? 'See the current round and previous results.',
        onTap: onTap);
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.submission});
  final SubmissionModel submission;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _InfoRow(
        icon: submission.status == 'approved'
            ? Icons.check_circle_outline
            : submission.status == 'rejected'
                ? Icons.cancel_outlined
                : Icons.hourglass_top_rounded,
        title: submission.questTitle,
        subtitle:
            '${submission.status[0].toUpperCase()}${submission.status.substring(1)} · ${submission.createdAt.split('T').first}',
        onTap: () => context.push('/history'),
      ));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      color: AppColors.surfaceContainerLowest,
      child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded)));
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
      color: AppColors.surfaceContainerLowest,
      child: ListTile(
          leading:
              const Icon(Icons.cloud_off_outlined, color: AppColors.textMuted),
          title: Text(message),
          trailing: IconButton(
              tooltip: 'Retry',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded))));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      color: AppColors.surfaceContainerLowest,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary))));
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator.adaptive()));
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 150,
      child: ColoredBox(
          color: AppColors.surfaceContainerHigh,
          child: Center(
              child: Icon(Icons.landscape_outlined,
                  size: 42, color: AppColors.textMuted))));
}
