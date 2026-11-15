import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../map/pixel/map_marker_art.dart';
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class NearbyQuizRadarBanner extends ConsumerWidget {
  const NearbyQuizRadarBanner({
    super.key,
    this.onOpenQuiz,
    this.onOpenHub,
  });

  final void Function(String quizId)? onOpenQuiz;
  final VoidCallback? onOpenHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radar = ref.watch(quizRadarProvider);
    final List<NearbyQuizInvitationModel> inRange = radar.inRangeIncomplete;
    if (inRange.isEmpty || !radar.showBanner) {
      return const SizedBox.shrink();
    }

    final grid = PixelGrid.of(context);
    final isSingle = inRange.length == 1;
    final closest = inRange.first;
    final headline = isSingle
        ? 'QUIZ UNLOCKED · ${closest.distanceMeters}m'
        : '${inRange.length} QUIZZES IN RANGE · CLOSEST ${closest.distanceMeters}m';
    final ctaLabel = isSingle
        ? 'PLAY +${closest.xpReward} XP'
        : 'VIEW ALL (${inRange.length})';

    return PixelPanel(
      key: const ValueKey('nearby_quiz_radar_banner'),
      style: PixelBoxStyle.green,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox.square(
                dimension: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: PixelSprite(DesignerArt.questionMark, scale: 1),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: Text(
                  headline,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.sun,
                  ),
                ),
              ),
              SizedBox(width: grid.px(1)),
              GestureDetector(
                key: const ValueKey('nearby_quiz_banner_dismiss'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(quizRadarProvider.notifier).dismissBanner(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: PixelIconButton(
                      icon: MapMarkerArt.iconClose,
                      semanticLabel: 'Dismiss quiz alert',
                      style: PixelBoxStyle.parchment,
                      onPressed: () =>
                          ref.read(quizRadarProvider.notifier).dismissBanner(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isSingle && closest.title.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              closest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.body(context, color: PixelPalette.paper),
            ),
          ],
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('nearby_quiz_banner_cta'),
            label: ctaLabel,
            style: PixelBoxStyle.gold,
            expand: true,
            onPressed: () {
              if (isSingle) {
                if (onOpenQuiz != null) {
                  onOpenQuiz!(closest.quizId);
                } else {
                  context.push('/cultural-quizzes/${closest.quizId}');
                }
              } else {
                if (onOpenHub != null) {
                  onOpenHub!();
                } else {
                  context.push('/cultural-quizzes');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
