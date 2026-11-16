import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/cultural_quiz_model.dart';

class CulturalQuizResultScreen extends StatefulWidget {
  final CulturalQuizGradedResultModel result;

  const CulturalQuizResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<CulturalQuizResultScreen> createState() =>
      _CulturalQuizResultScreenState();
}

class _CulturalQuizResultScreenState extends State<CulturalQuizResultScreen> {
  late int _displayScore;

  @override
  void initState() {
    super.initState();
    _displayScore = 0;
    if (GameAudio.instance.buttonSounds.value) {
      unawaited(
        GameAudio.instance.playSfx(
          widget.result.passed ? 'quest_complete' : 'error',
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _displayScore = widget.result.score;
      });
    });
  }

  String _rankLabel(int score) {
    if (score >= 5) return 'CULTURAL MASTER';
    if (score == 4) return 'HERITAGE SCOUT';
    return 'KEEP EXPLORING';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final passed = result.passed;
    final rank = _rankLabel(result.score);
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
                  const PixelAppBar(title: 'Quiz results'),
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
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: grid.px(1.5),
                                runSpacing: grid.px(1),
                                children: [
                                  PixelChip(
                                    rank,
                                    key: const ValueKey('quiz_result_rank'),
                                    style: result.score >= 4
                                        ? PixelBoxStyle.gold
                                        : PixelBoxStyle.slot,
                                    textColor: PixelPalette.ink,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox.square(
                                        dimension: 24,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: result.passed &&
                                                  !(MediaQuery
                                                          .maybeDisableAnimationsOf(
                                                        context,
                                                      ) ??
                                                      false)
                                              ? const PixelAnimation(
                                                  DesignerArt.coinAnim,
                                                  scale: 1,
                                                  loop: false,
                                                )
                                              : PixelSprite(
                                                  DesignerArt
                                                      .coinAnim.frames.first,
                                                  scale: 1,
                                                ),
                                        ),
                                      ),
                                      SizedBox(width: grid.px(1)),
                                      PixelRollingNumber(
                                        value: _displayScore,
                                        format: (v) =>
                                            '$v/${result.totalQuestions}',
                                        style: PixelType.title(
                                          context,
                                          color: PixelPalette.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                        PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PixelSectionTitle(
                                'Review & explanations',
                                icon: DesignerArt.questionMark,
                                value: '${result.breakdown.length}',
                                valueColor: PixelPalette.greenDark,
                              ),
                              SizedBox(height: grid.px(1)),
                              for (var i = 0;
                                  i < result.breakdown.length;
                                  i++) ...[
                                if (i > 0)
                                  Container(
                                    height: grid.unit,
                                    color: PixelPalette.paperDim,
                                  ),
                                _breakdown(
                                  context,
                                  grid,
                                  i + 1,
                                  result.breakdown[i],
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelChip(
                item.isCorrect ? 'Correct' : 'Wrong',
                style: item.isCorrect ? PixelBoxStyle.green : PixelBoxStyle.red,
                textColor: PixelPalette.white,
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Text(
                  '$index. ${item.questionText}',
                  style: PixelType.title(
                    context,
                    color: item.isCorrect
                        ? PixelPalette.ink
                        : PixelPalette.redDeep,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          if (item.correctOrder.isNotEmpty) ...[
            Text(
              'Correct order: ${item.correctOrder.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join(' ')}',
              style: PixelType.small(
                context,
                color: item.isCorrect
                    ? PixelPalette.greenDark
                    : PixelPalette.redDeep,
              ),
            ),
            SizedBox(height: grid.px(1)),
          ],
          Text(
            'Explanation:',
            style: PixelType.small(
              context,
              color: PixelPalette.slate,
            ),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            item.explanation,
            style: PixelType.body(
              context,
              color: PixelPalette.slate,
            ),
          ),
          if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Source: ${item.sourceUrl}',
              style: PixelType.small(
                context,
                color: PixelPalette.greenDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
