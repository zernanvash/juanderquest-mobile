import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class CulturalQuizPlayScreen extends ConsumerStatefulWidget {
  final String quizId;
  final ({CulturalQuizAttemptModel attempt, List<CulturalQuizQuestionModel> questions}) session;

  const CulturalQuizPlayScreen({
    super.key,
    required this.quizId,
    required this.session,
  });

  @override
  ConsumerState<CulturalQuizPlayScreen> createState() => _CulturalQuizPlayScreenState();
}

class _CulturalQuizPlayScreenState extends ConsumerState<CulturalQuizPlayScreen> {
  int _currentIndex = 0;
  final Map<String, String> _selectedOptionByQuestion = {};
  Timer? _countdownTimer;
  late Duration _remaining;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final expires = widget.session.attempt.expiresAt;
    final diff = expires.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final currentDiff = expires.difference(DateTime.now());
      if (currentDiff.isNegative) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
        });
      } else {
        setState(() {
          _remaining = currentDiff;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitQuiz() async {
    final questions = widget.session.questions;
    if (_selectedOptionByQuestion.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all 5 questions before submitting.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final answers = questions.map((q) => (
        questionId: q.id,
        selectedOptionId: _selectedOptionByQuestion[q.id]!,
      )).toList();

      final result = await ref.read(culturalQuizControllerProvider.notifier).submitAttempt(
        attemptId: widget.session.attempt.id,
        answers: answers,
      );

      if (!mounted) return;

      context.pushReplacement(
        '/cultural-quizzes/${widget.quizId}/result',
        extra: result,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.session.questions;
    final currentQ = questions[_currentIndex];
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return JdqScaffold(
      appBar: AppBar(title: Text('Question ${_currentIndex + 1} of ${questions.length}')),
      body: Column(
        children: [
          // Header Timer and Progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / questions.length,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _remaining.inMinutes < 5 ? AppColors.danger.withValues(alpha: 0.12) : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _remaining.inMinutes < 5 ? AppColors.danger : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$minutes:$seconds',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _remaining.inMinutes < 5 ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Question & Options Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${currentQ.ordinal}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    currentQ.questionText,
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Option tiles
                  ...currentQ.options.map((opt) {
                    final isSelected = _selectedOptionByQuestion[currentQ.id] == opt.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.borderLowContrast,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _selectedOptionByQuestion[currentQ.id] = opt.id;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(64 + opt.ordinal),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    opt.optionText,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  if (_submitError != null)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _submitError!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Footer Navigation
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex -= 1;
                        });
                      },
                      child: const Text('Previous'),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _currentIndex < questions.length - 1
                      ? PrimaryButton(
                          label: 'Next',
                          onPressed: () {
                            setState(() {
                              _currentIndex += 1;
                            });
                          },
                        )
                      : PrimaryButton(
                          label: _isSubmitting ? 'Submitting...' : 'Submit Quiz',
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submitQuiz,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
