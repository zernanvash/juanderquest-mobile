import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/mjdq_amount.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../pixel/home_pixel_art.dart';
import '../providers/home_qotd_provider.dart';

/// Owner 2026-11-17: the Question of the Day sits open on Home (no tap to
/// see it). Answer right here; once answered, the right choice and the
/// explanation stay until tomorrow's question.
class HomeQotdPanel extends ConsumerWidget {
  const HomeQotdPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final async = ref.watch(homeQotdProvider);
    final q = async.valueOrNull;
    final answered = q?.answered == true;

    Widget body;
    if (q == null && async.isLoading) {
      body = const PixelLoader(label: 'Loading question');
    } else if (q == null || !q.hasQuestion) {
      body = Text(
        async.hasError
            ? 'The question could not load. Pull down to refresh.'
            : 'No question today. Check back tomorrow!',
        style: PixelType.body(context, color: PixelPalette.cream),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q.questionText,
            key: const ValueKey('home_qotd_question'),
            style: PixelType.body(context, color: PixelPalette.paper)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          for (final option in q.options) ...[
            SizedBox(height: grid.px(2)),
            PixelTappableSlot(
              key: ValueKey('home_qotd_option_${option.id}'),
              style: q.selectedOptionId == option.id
                  ? (q.correct ? PixelBoxStyle.green : PixelBoxStyle.red)
                  : PixelBoxStyle.parchment,
              padding: 2,
              onTap: answered || q.submitting
                  ? () => showPixelToast(context,
                      'Already answered. A new question comes tomorrow!')
                  : () => ref.read(homeQotdProvider.notifier).answer(option.id),
              child: Text(
                option.text,
                style: PixelType.body(
                  context,
                  color: q.selectedOptionId == option.id
                      ? PixelPalette.white
                      : PixelPalette.ink,
                ),
              ),
            ),
          ],
          if (q.answerError != null) ...[
            SizedBox(height: grid.px(2)),
            Text(
              q.answerError!,
              style: PixelType.small(context, color: PixelPalette.sunLight),
            ),
          ],
          if (answered && (q.explanation ?? '').isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(
              q.explanation!,
              key: const ValueKey('home_qotd_explanation'),
              style: PixelType.small(context, color: PixelPalette.cream),
            ),
          ],
        ],
      );
    }

    return PixelPanel(
      key: const ValueKey('home_qotd_panel'),
      style: PixelBoxStyle.wood,
      padding: PixelPanel.sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PixelSectionTitle(
                  'QUESTION',
                  icon: answered
                      ? HomePixelArt.stampCheck
                      : DesignerArt.questionMark,
                  iconWrap: answered ? null : (icon) => PixelTilt(child: icon),
                  value: answered ? (q!.correct ? 'CORRECT' : 'MISSED') : null,
                ),
              ),
              if (!answered)
                MjdqAmount(
                  5,
                  sign: true,
                  style: PixelType.small(context, color: PixelPalette.sunLight)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          body,
        ],
      ),
    );
  }
}
