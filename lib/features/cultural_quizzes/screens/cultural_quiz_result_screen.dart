import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/cultural_quiz_model.dart';

class CulturalQuizResultScreen extends StatelessWidget {
  final CulturalQuizGradedResultModel result;

  const CulturalQuizResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;

    return JdqScaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Score Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: passed ? AppColors.success.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: passed ? AppColors.success : AppColors.danger,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    passed ? Icons.military_tech_rounded : Icons.sentiment_dissatisfied_rounded,
                    size: 64,
                    color: passed ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    passed ? 'Quiz Passed!' : 'Quiz Incomplete',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: passed ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Score: ${result.score} of ${result.totalQuestions} correct (Passing: 4/5)',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (passed && result.xpAwarded > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sunGold),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.secondary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '+${result.xpAwarded} Explorer XP Awarded',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (passed && result.alreadyCompletedPrior)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Learning Replay: XP was previously claimed for this destination.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (!passed && result.cooldownUntil != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Retry cooldown is active for 24 hours until:\n${result.cooldownUntil}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Review & Explanations Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review & Explanations',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Breakdown item cards
            ...result.breakdown.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isCorrect ? AppColors.success.withValues(alpha: 0.4) : AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: item.isCorrect ? AppColors.success : AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '$idx. ${item.questionText}',
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explanation:',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.explanation,
                            style: AppTypography.bodySmall,
                          ),
                          if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Source: ${item.sourceUrl}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Return to Explore',
              onPressed: () {
                context.go('/explore');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
