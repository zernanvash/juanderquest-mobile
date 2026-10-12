import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class CulturalQuizDetailScreen extends ConsumerStatefulWidget {
  final String quizId;

  const CulturalQuizDetailScreen({
    super.key,
    required this.quizId,
  });

  @override
  ConsumerState<CulturalQuizDetailScreen> createState() => _CulturalQuizDetailScreenState();
}

class _CulturalQuizDetailScreenState extends ConsumerState<CulturalQuizDetailScreen> {
  bool _isStarting = false;
  String? _errorMessage;

  Future<void> _startAttempt(CulturalQuizModel quiz) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to take cultural quizzes.')),
      );
      context.push('/login');
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on your device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission is required to start a location-triggered quiz.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in system settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final session = await ref.read(culturalQuizControllerProvider.notifier).startAttempt(
        quizId: quiz.id,
        lat: position.latitude,
        lng: position.longitude,
      );

      if (!mounted) return;

      context.push(
        '/cultural-quizzes/${quiz.id}/play',
        extra: session,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(culturalQuizDetailProvider(widget.quizId));

    return JdqScaffold(
      appBar: AppBar(title: const Text('Cultural Quiz')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Failed to load quiz: $err', style: AppTypography.bodyMedium),
          ),
        ),
        data: (quiz) {
          if (quiz == null) {
            return const Center(child: Text('Cultural Quiz not found.'));
          }

          final isCooldownActive = quiz.cooldownUntil != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Destination & Quiz Header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${quiz.destinationName} • ${quiz.municipality}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        quiz.title,
                        style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        quiz.description,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Rule and Parameters card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildParamRow(
                        icon: Icons.stars_rounded,
                        iconColor: AppColors.sunGold,
                        title: 'Reward',
                        value: quiz.isCompleted
                            ? 'Learning Only (XP already earned)'
                            : '+${quiz.xpReward} Explorer XP',
                      ),
                      const Divider(height: 16),
                      _buildParamRow(
                        icon: Icons.checklist_rounded,
                        iconColor: AppColors.primary,
                        title: 'Questions',
                        value: '5 multiple-choice (4/5 to pass)',
                      ),
                      const Divider(height: 16),
                      _buildParamRow(
                        icon: Icons.timer_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Time Limit',
                        value: '${quiz.timeLimitMinutes} minutes to submit',
                      ),
                      const Divider(height: 16),
                      _buildParamRow(
                        icon: Icons.radar_rounded,
                        iconColor: AppColors.info,
                        title: 'Start Location',
                        value: 'Within ${quiz.radiusMeters}m of destination',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isCooldownActive)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.sunGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, color: AppColors.secondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Retry cooldown active until:\n${quiz.cooldownUntil}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  PrimaryButton(
                    label: _isStarting ? 'Verifying location...' : 'Start Quiz',
                    isLoading: _isStarting,
                    onPressed: _isStarting ? null : () => _startAttempt(quiz),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Note: You must be physically within ${quiz.radiusMeters}m to start. You may freely move outside the radius while completing the quiz before the timer expires.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParamRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
