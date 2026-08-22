import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/submission_status_badge.dart';
import '../models/submission_model.dart';
import '../providers/submission_provider.dart';

class SubmissionHistoryScreen extends ConsumerStatefulWidget {
  const SubmissionHistoryScreen({super.key});

  @override
  ConsumerState<SubmissionHistoryScreen> createState() => _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState extends ConsumerState<SubmissionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(submissionProvider);

    return JdqScaffold(
      appBar: AppBar(
        title: const Text('Submission History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(submissionProvider.notifier).fetchSubmissions();
        },
        color: AppColors.primary,
        child: AsyncStateView(
          isLoading: subState.isLoading,
          isEmpty: subState.submissions.isEmpty,
          emptyMessage: 'No Submissions Yet',
          emptySubtitle: 'Complete quests or submit destination spots to earn reward points.',
          emptyIcon: Icons.history_rounded,
          onRetry: () => ref.read(submissionProvider.notifier).fetchSubmissions(),
          content: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: subState.submissions.length,
            itemBuilder: (context, index) {
              final sub = subState.submissions[index];
              return _buildSubmissionCard(sub);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(SubmissionModel sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    sub.questTitle,
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SubmissionStatusBadge(status: sub.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.sunGold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '+${sub.rewardPoints} Points',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.woodBrown,
                  ),
                ),
                Text(
                  ' · Submitted on ${sub.submittedAt.split('T').first}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            if (sub.rejectionReason != null && sub.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${sub.rejectionReason}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
