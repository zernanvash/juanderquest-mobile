import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class CulturalQuizPlayScreen extends ConsumerStatefulWidget {
  final String quizId;
  final ({
    CulturalQuizAttemptModel attempt,
    List<CulturalQuizQuestionModel> questions
  }) session;

  const CulturalQuizPlayScreen({
    super.key,
    required this.quizId,
    required this.session,
  });

  @override
  ConsumerState<CulturalQuizPlayScreen> createState() =>
      _CulturalQuizPlayScreenState();
}

class _CulturalQuizPlayScreenState
    extends ConsumerState<CulturalQuizPlayScreen> {
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
      showPixelToast(
          context, 'Please answer all 5 questions before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final answers = questions
          .map((q) => (
                questionId: q.id,
                selectedOptionId: _selectedOptionByQuestion[q.id]!,
              ))
          .toList();

      final result =
          await ref.read(culturalQuizControllerProvider.notifier).submitAttempt(
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
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title:
                        'Question ${_currentIndex + 1} of ${questions.length}',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(4),
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: PixelProgressBar(
                                value:
                                    (_currentIndex + 1) / questions.length,
                                segments: questions.length,
                              ),
                            ),
                            SizedBox(width: grid.px(2)),
                            PixelChip(
                              '$minutes:$seconds',
                              style: _remaining.inMinutes < 5
                                  ? PixelBoxStyle.red
                                  : PixelBoxStyle.slot,
                              textColor: _remaining.inMinutes < 5
                                  ? PixelPalette.white
                                  : PixelPalette.ink,
                            ),
                          ],
                        ),
                        SizedBox(height: grid.px(3)),
                        Text(
                          'Question ${currentQ.ordinal}',
                          style: PixelType.small(
                            context,
                            color: PixelPalette.greenDark,
                          ),
                        ),
                        SizedBox(height: grid.px(1)),
                        Text(
                          currentQ.questionText,
                          style: PixelType.title(context),
                        ),
                        SizedBox(height: grid.px(3)),
                        for (final opt in currentQ.options) ...[
                          _option(context, grid, currentQ, opt),
                          SizedBox(height: grid.px(2)),
                        ],
                        if (_submitError != null)
                          PixelPanel(
                            style: PixelBoxStyle.red,
                            child: Text(
                              _submitError!,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _footer(context, grid, questions.length),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _option(
    BuildContext context,
    PixelGrid grid,
    CulturalQuizQuestionModel question,
    CulturalQuizOptionModel option,
  ) {
    final isSelected = _selectedOptionByQuestion[question.id] == option.id;
    return GestureDetector(
      key: ValueKey('quiz_option_${option.id}'),
      onTap: () {
        pixelTick(context);
        setState(() {
          _selectedOptionByQuestion[question.id] = option.id;
        });
      },
      child: PixelPanel(
        style: isSelected ? PixelBoxStyle.green : PixelBoxStyle.parchment,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelChip(
              String.fromCharCode(64 + option.ordinal),
              style: isSelected ? PixelBoxStyle.gold : PixelBoxStyle.slot,
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Text(
                option.optionText,
                style: PixelType.body(
                  context,
                  color: isSelected ? PixelPalette.white : PixelPalette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, PixelGrid grid, int total) {
    final isLast = _currentIndex >= total - 1;
    return Container(
      color: PixelPalette.ink,
      padding: EdgeInsets.fromLTRB(
        grid.px(3),
        grid.px(2),
        grid.px(3),
        grid.px(2) + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          if (_currentIndex > 0) ...[
            Expanded(
              child: PixelButton(
                key: const ValueKey('quiz_previous'),
                label: 'Previous',
                variant: PixelButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  setState(() {
                    _currentIndex -= 1;
                  });
                },
              ),
            ),
            SizedBox(width: grid.px(2)),
          ] else
            const Spacer(),
          Expanded(
            child: isLast
                ? PixelButton(
                    key: const ValueKey('quiz_submit'),
                    label: _isSubmitting ? 'Submitting' : 'Submit quiz',
                    expand: true,
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submitQuiz,
                  )
                : PixelButton(
                    key: const ValueKey('quiz_next'),
                    label: 'Next',
                    expand: true,
                    onPressed: () {
                      setState(() {
                        _currentIndex += 1;
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
