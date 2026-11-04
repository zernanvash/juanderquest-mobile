import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
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
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  const PixelAppBar(title: 'Quiz Results'),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelPanel(
                          style: passed
                              ? PixelBoxStyle.green
                              : PixelBoxStyle.red,
                          child: Column(
                            children: [
                              Text(
                                passed ? 'Quiz Passed!' : 'Quiz Incomplete',
                                textAlign: TextAlign.center,
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.white,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'Score: ${result.score} of ${result.totalQuestions} correct (Passing: 4/5)',
                                textAlign: TextAlign.center,
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                              if (passed && result.xpAwarded > 0) ...[
                                SizedBox(height: grid.px(2)),
                                PixelChip(
                                  '+${result.xpAwarded} Explorer XP Awarded',
                                  style: PixelBoxStyle.gold,
                                ),
                              ] else if (passed && result.alreadyCompletedPrior) ...[
                                SizedBox(height: grid.px(2)),
                                Text(
                                  'Learning Replay: XP was previously claimed for this destination.',
                                  textAlign: TextAlign.center,
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.cream,
                                  ),
                                ),
                              ] else if (!passed &&
                                  result.cooldownUntil != null) ...[
                                SizedBox(height: grid.px(2)),
                                Text(
                                  'Retry cooldown is active for 24 hours until:\n${result.cooldownUntil}',
                                  textAlign: TextAlign.center,
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.cream,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        Text('Review & Explanations',
                            style: PixelType.title(context)),
                        SizedBox(height: grid.px(2)),
                        for (final entry in result.breakdown.asMap().entries) ...[
                          _breakdown(context, grid, entry.key + 1, entry.value),
                          SizedBox(height: grid.px(2)),
                        ],
                        SizedBox(height: grid.px(2)),
                        PixelButton(
                          key: const ValueKey('quiz_result_explore'),
                          label: 'Return to Explore',
                          expand: true,
                          onPressed: () => context.go('/explore'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _breakdown(
    BuildContext context,
    PixelGrid grid,
    int index,
    CulturalQuizGradeBreakdownItem item,
  ) {
    return PixelPanel(
      style: item.isCorrect ? PixelBoxStyle.parchment : PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelChip(
                item.isCorrect ? 'Correct' : 'Wrong',
                style:
                    item.isCorrect ? PixelBoxStyle.green : PixelBoxStyle.gold,
                textColor:
                    item.isCorrect ? PixelPalette.white : PixelPalette.ink,
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Text(
                  '$index. ${item.questionText}',
                  style: PixelType.title(
                    context,
                    color:
                        item.isCorrect ? PixelPalette.ink : PixelPalette.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'Explanation:',
            style: PixelType.small(
              context,
              color: item.isCorrect
                  ? PixelPalette.slate
                  : PixelPalette.cream,
            ),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            item.explanation,
            style: PixelType.body(
              context,
              color:
                  item.isCorrect ? PixelPalette.slate : PixelPalette.white,
            ),
          ),
          if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Source: ${item.sourceUrl}',
              style: PixelType.small(
                context,
                color: item.isCorrect
                    ? PixelPalette.greenDark
                    : PixelPalette.sun,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
