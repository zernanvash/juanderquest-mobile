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
import '../../spots/models/spot_model.dart';
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
  final Map<String, List<String>> _orderedOptionIdsByQuestion = {};
  final Set<String> _eliminatedOptionIds = {};
  bool _fiftyFiftyUsed = false;
  bool _isUsingLifeline = false;
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

  bool _isQuestionAnswered(CulturalQuizQuestionModel q) {
    if (q.questionType == 'sequence_order') {
      return (_orderedOptionIdsByQuestion[q.id]?.length ?? 0) == q.options.length;
    }
    return _selectedOptionByQuestion.containsKey(q.id);
  }

  Future<void> _useFiftyFifty(CulturalQuizQuestionModel question) async {
    if (_fiftyFiftyUsed || _isUsingLifeline) return;
    setState(() => _isUsingLifeline = true);
    try {
      final eliminated = await ref
          .read(culturalQuizControllerProvider.notifier)
          .useFiftyFifty(
            quizId: widget.quizId,
            attemptId: widget.session.attempt.id,
            questionId: question.id,
          );
      if (!mounted) return;
      setState(() {
        _fiftyFiftyUsed = true;
        _eliminatedOptionIds.addAll(eliminated);
        if (eliminated.contains(_selectedOptionByQuestion[question.id])) {
          _selectedOptionByQuestion.remove(question.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      showPixelToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUsingLifeline = false);
    }
  }

  Future<void> _submitQuiz() async {
    final questions = widget.session.questions;
    if (questions.any((q) => !_isQuestionAnswered(q))) {
      showPixelToast(
          context, 'Please answer all 5 questions before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final hasSequence = questions.any((q) => q.questionType == 'sequence_order');
      final controller = ref.read(culturalQuizControllerProvider.notifier);
      final result = hasSequence
          ? await controller.submitAttemptAnswers(
              attemptId: widget.session.attempt.id,
              answers: questions
                  .map((q) => q.questionType == 'sequence_order'
                      ? (
                          questionId: q.id,
                          selectedOptionId: null,
                          orderedOptionIds: _orderedOptionIdsByQuestion[q.id]!,
                        )
                      : (
                          questionId: q.id,
                          selectedOptionId: _selectedOptionByQuestion[q.id]!,
                          orderedOptionIds: null,
                        ))
                  .toList(),
            )
          : await controller.submitAttempt(
              attemptId: widget.session.attempt.id,
              answers: questions
                  .map((q) => (
                        questionId: q.id,
                        selectedOptionId: _selectedOptionByQuestion[q.id]!,
                      ))
                  .toList(),
            );

      if (!mounted) return;
      if (result.passed) {
        ref.read(quizRadarProvider.notifier).markCompleted(widget.quizId);
      }

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
                        SizedBox(height: grid.px(2)),
                        _buildProgressPips(context, grid, questions),
                        SizedBox(height: grid.px(2)),
                        Wrap(
                          spacing: grid.px(2),
                          runSpacing: grid.px(1),
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            PixelChip(
                              _questionTypeLabel(currentQ.questionType),
                              key: const ValueKey('quiz_question_type_pill'),
                              style: PixelBoxStyle.gold,
                              textColor: PixelPalette.ink,
                            ),
                            Text(
                              'Question ${currentQ.ordinal}',
                              style: PixelType.small(
                                context,
                                color: PixelPalette.greenDark,
                              ),
                            ),
                            if (!_fiftyFiftyUsed &&
                                (currentQ.questionType == 'multiple_choice' ||
                                    currentQ.questionType == 'photo_clue'))
                              PixelButton(
                                key: const ValueKey('quiz_lifeline_fifty_fifty'),
                                label: _isUsingLifeline ? '...' : '50/50',
                                variant: PixelButtonVariant.secondary,
                                onPressed: _isUsingLifeline
                                    ? null
                                    : () => _useFiftyFifty(currentQ),
                              ),
                          ],
                        ),
                        SizedBox(height: grid.px(2)),
                        Text(
                          currentQ.questionText,
                          style: PixelType.title(context),
                        ),
                        SizedBox(height: grid.px(3)),
                        ..._buildQuestionBody(context, grid, currentQ),
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

  String _questionTypeLabel(String type) => switch (type) {
        'true_false' => 'MYTH VS FACT',
        'photo_clue' => 'PHOTO CLUE',
        'sequence_order' => 'SEQUENCE ORDER',
        _ => 'MULTIPLE CHOICE',
      };

  Widget _buildProgressPips(
    BuildContext context,
    PixelGrid grid,
    List<CulturalQuizQuestionModel> questions,
  ) {
    return Wrap(
      spacing: grid.px(1.5),
      runSpacing: grid.px(1),
      children: [
        for (var i = 0; i < questions.length; i++)
          GestureDetector(
            key: ValueKey('quiz_pip_$i'),
            onTap: () {
              pixelTick(context);
              setState(() {
                _currentIndex = i;
              });
            },
            child: PixelChip(
              '${i + 1}',
              style: i == _currentIndex
                  ? PixelBoxStyle.gold
                  : _isQuestionAnswered(questions[i])
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.slot,
              textColor: i == _currentIndex
                  ? PixelPalette.ink
                  : _isQuestionAnswered(questions[i])
                      ? PixelPalette.white
                      : PixelPalette.ink,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildQuestionBody(
    BuildContext context,
    PixelGrid grid,
    CulturalQuizQuestionModel question,
  ) {
    switch (question.questionType) {
      case 'true_false':
        return [_buildTrueFalse(context, grid, question)];
      case 'photo_clue':
        return [
          if (question.mediaUrl != null && question.mediaUrl!.isNotEmpty) ...[
            PixelPanel(
              key: const ValueKey('quiz_photo_clue_frame'),
              style: PixelBoxStyle.slot,
              child: ClipRect(
                child: Image.network(
                  // Spot photos are stored as /api/v1/uploads/... paths.
                  SpotModel.resolveImageUrl(question.mediaUrl!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'Photo clue unavailable',
                        style: PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
          for (var i = 0; i < question.options.length; i++) ...[
            _option(context, grid, question, question.options[i], i),
            SizedBox(height: grid.px(2)),
          ],
        ];
      case 'sequence_order':
        return [_buildSequenceOrder(context, grid, question)];
      default:
        return [
          for (var i = 0; i < question.options.length; i++) ...[
            _option(context, grid, question, question.options[i], i),
            SizedBox(height: grid.px(2)),
          ],
        ];
    }
  }

  Widget _buildTrueFalse(
    BuildContext context,
    PixelGrid grid,
    CulturalQuizQuestionModel question,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 280;
        final cards = question.options.map((opt) {
          final isSelected = _selectedOptionByQuestion[question.id] == opt.id;
          final label = opt.optionText.toUpperCase();
          return GestureDetector(
            key: ValueKey('quiz_option_${opt.id}'),
            onTap: () {
              pixelTick(context);
              setState(() {
                _selectedOptionByQuestion[question.id] = opt.id;
              });
            },
            child: PixelPanel(
              style: isSelected ? PixelBoxStyle.green : PixelBoxStyle.parchment,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: PixelType.title(
                      context,
                      color: isSelected ? PixelPalette.white : PixelPalette.ink,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList();

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i + 1 < cards.length) SizedBox(height: grid.px(2)),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i + 1 < cards.length) SizedBox(width: grid.px(2)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSequenceOrder(
    BuildContext context,
    PixelGrid grid,
    CulturalQuizQuestionModel question,
  ) {
    final selectedOrder = _orderedOptionIdsByQuestion[question.id] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tap items in order (${selectedOrder.length}/${question.options.length})',
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ),
            if (selectedOrder.isNotEmpty)
              PixelButton(
                key: const ValueKey('quiz_sequence_reset'),
                label: 'RESET',
                variant: PixelButtonVariant.secondary,
                onPressed: () {
                  pixelTick(context);
                  setState(() {
                    _orderedOptionIdsByQuestion.remove(question.id);
                  });
                },
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        for (final opt in question.options) ...[
          Builder(
            builder: (context) {
              final rankIndex = selectedOrder.indexOf(opt.id);
              final isPicked = rankIndex >= 0;
              return GestureDetector(
                key: ValueKey('quiz_sequence_option_${opt.id}'),
                onTap: () {
                  pixelTick(context);
                  setState(() {
                    final list = List<String>.of(
                      _orderedOptionIdsByQuestion[question.id] ?? const [],
                    );
                    if (isPicked) {
                      list.remove(opt.id);
                    } else {
                      list.add(opt.id);
                    }
                    if (list.isEmpty) {
                      _orderedOptionIdsByQuestion.remove(question.id);
                    } else {
                      _orderedOptionIdsByQuestion[question.id] = list;
                    }
                  });
                },
                child: PixelPanel(
                  style: isPicked ? PixelBoxStyle.green : PixelBoxStyle.parchment,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelChip(
                        isPicked ? '${rankIndex + 1}' : '?',
                        style: isPicked ? PixelBoxStyle.gold : PixelBoxStyle.slot,
                      ),
                      SizedBox(width: grid.px(2)),
                      Expanded(
                        child: Text(
                          opt.optionText,
                          style: PixelType.body(
                            context,
                            color: isPicked ? PixelPalette.white : PixelPalette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: grid.px(2)),
        ],
      ],
    );
  }

  Widget _option(
    BuildContext context,
    PixelGrid grid,
    CulturalQuizQuestionModel question,
    CulturalQuizOptionModel option,
    int fallbackIndex,
  ) {
    final isEliminated = _eliminatedOptionIds.contains(option.id);
    final isSelected = _selectedOptionByQuestion[question.id] == option.id;
    final letterOrdinal = option.ordinal ?? (fallbackIndex + 1);
    return Opacity(
      opacity: isEliminated ? 0.35 : 1.0,
      child: GestureDetector(
        key: ValueKey('quiz_option_${option.id}'),
        onTap: isEliminated
            ? null
            : () {
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
                String.fromCharCode(64 + letterOrdinal),
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
