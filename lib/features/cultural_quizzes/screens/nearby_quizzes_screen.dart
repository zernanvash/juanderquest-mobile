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
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class NearbyQuizzesScreen extends ConsumerStatefulWidget {
  const NearbyQuizzesScreen({super.key});

  @override
  ConsumerState<NearbyQuizzesScreen> createState() =>
      _NearbyQuizzesScreenState();
}

class _NearbyQuizzesScreenState extends ConsumerState<NearbyQuizzesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(quizRadarProvider);
      if (state.lastQueryAt == null) {
        ref.read(quizRadarProvider.notifier).refreshFromHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final radar = ref.watch(quizRadarProvider);
    final inRange = radar.inRangeIncomplete;
    final approaching = radar.approachingIncomplete;
    final completed = radar.completed;

    return Scaffold(
      backgroundColor: PixelPalette.paper,
      body: Column(
        children: [
          PixelAppBar(
            title: 'Cultural Quizzes',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
          ),
          Expanded(
            child: DitherBackground(
              top: PixelPalette.cream,
              bottom: PixelPalette.paper,
              child: RefreshIndicator(
                color: PixelPalette.green,
                backgroundColor: PixelPalette.parchment,
                onRefresh: () => ref
                    .read(quizRadarProvider.notifier)
                    .refreshFromHome(force: true),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    grid.px(4),
                    grid.px(3),
                    grid.px(4),
                    grid.px(8) + MediaQuery.paddingOf(context).bottom,
                  ),
            children: [
              _RadarHeaderPanel(
                inRangeCount: inRange.length,
                completedCount: completed.length,
                originLabel: radar.originLabel,
                loading: radar.loading,
                onRefresh: () => ref
                    .read(quizRadarProvider.notifier)
                    .refreshFromHome(force: true),
              ),
              SizedBox(height: grid.px(3)),
              if (radar.error != null) ...[
                PixelPanel(
                  style: PixelBoxStyle.parchment,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        radar.error!,
                        style: PixelType.body(
                          context,
                          color: PixelPalette.redDeep,
                        ),
                      ),
                      SizedBox(height: grid.px(2)),
                      PixelButton(
                        label: 'RETRY RADAR',
                        variant: PixelButtonVariant.secondary,
                        style: PixelBoxStyle.gold,
                        onPressed: () => ref
                            .read(quizRadarProvider.notifier)
                            .refreshFromHome(force: true),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: grid.px(3)),
              ],
              if (radar.loading && radar.items.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: PixelLoader(label: 'Scanning nearby quizzes...'),
                  ),
                ),
              ] else if (inRange.isEmpty &&
                  approaching.isEmpty &&
                  completed.isEmpty) ...[
                PixelPanel(
                  key: const ValueKey('quiz_radar_empty'),
                  style: PixelBoxStyle.parchment,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No cultural quizzes nearby yet',
                        style: PixelType.title(context),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        'Visit heritage spots across Pangasinan to unlock on-site quizzes and earn Explorer XP.',
                        style: PixelType.body(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                      SizedBox(height: grid.px(2)),
                      PixelButton(
                        label: 'EXPLORE SPOTS',
                        variant: PixelButtonVariant.secondary,
                        style: PixelBoxStyle.gold,
                        expand: true,
                        onPressed: () => context.go('/explore'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (inRange.isNotEmpty) ...[
                  Text(
                    'Ready to play',
                    key: const ValueKey('quiz_radar_section_ready'),
                    style: PixelType.title(context),
                  ),
                  SizedBox(height: grid.px(2)),
                  for (final quiz in inRange) ...[
                    _QuizRadarCard(
                      quiz: quiz,
                      mode: _QuizCardMode.ready,
                      onAction: () =>
                          context.push('/cultural-quizzes/${quiz.quizId}'),
                    ),
                    SizedBox(height: grid.px(2)),
                  ],
                  SizedBox(height: grid.px(2)),
                ],
                if (approaching.isNotEmpty) ...[
                  Text(
                    'Walk closer',
                    key: const ValueKey('quiz_radar_section_approaching'),
                    style: PixelType.title(context),
                  ),
                  SizedBox(height: grid.px(2)),
                  for (final quiz in approaching) ...[
                    _QuizRadarCard(
                      quiz: quiz,
                      mode: _QuizCardMode.approaching,
                      onAction: () => context.push(
                        '/navigate?name=${Uri.encodeComponent(quiz.destinationName)}&address=${Uri.encodeComponent(quiz.municipality)}',
                      ),
                    ),
                    SizedBox(height: grid.px(2)),
                  ],
                  SizedBox(height: grid.px(2)),
                ],
                if (completed.isNotEmpty) ...[
                  Text(
                    'Completed',
                    key: const ValueKey('quiz_radar_section_completed'),
                    style: PixelType.title(context),
                  ),
                  SizedBox(height: grid.px(2)),
                  for (final quiz in completed) ...[
                    _QuizRadarCard(
                      quiz: quiz,
                      mode: _QuizCardMode.completed,
                      onAction: () =>
                          context.push('/cultural-quizzes/${quiz.quizId}'),
                    ),
                    SizedBox(height: grid.px(2)),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
          ),
        ],
      ),
    );
  }
}

class _RadarHeaderPanel extends StatelessWidget {
  const _RadarHeaderPanel({
    required this.inRangeCount,
    required this.completedCount,
    required this.originLabel,
    required this.loading,
    required this.onRefresh,
  });

  final int inRangeCount;
  final int completedCount;
  final String originLabel;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(painter: _StaticRadarPainter()),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Radar',
                      style: PixelType.title(context, color: PixelPalette.paper),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      originLabel,
                      style: PixelType.small(context, color: PixelPalette.cream),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(
                '$inRangeCount IN RANGE · $completedCount DONE',
                style: PixelBoxStyle.gold,
              ),
              PixelButton(
                label: loading ? 'SCANNING' : 'SCAN',
                variant: PixelButtonVariant.secondary,
                style: PixelBoxStyle.parchment,
                onPressed: loading ? null : onRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticRadarPainter extends CustomPainter {
  const _StaticRadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = PixelPalette.greenBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final sweepPaint = Paint()
      ..color = PixelPalette.sun
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dotPaint = Paint()
      ..color = PixelPalette.gold
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width - 4, height: size.height - 4),
      ringPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width * 0.55, height: size.height * 0.55),
      ringPaint,
    );
    canvas.drawLine(center, Offset(size.width - 6, 8), sweepPaint);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 6, height: 6),
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticRadarPainter oldDelegate) => false;
}

enum _QuizCardMode { ready, approaching, completed }

class _QuizRadarCard extends StatelessWidget {
  const _QuizRadarCard({
    required this.quiz,
    required this.mode,
    required this.onAction,
  });

  final NearbyQuizInvitationModel quiz;
  final _QuizCardMode mode;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final isReady = mode == _QuizCardMode.ready;
    final isApproaching = mode == _QuizCardMode.approaching;

    final panelStyle = isReady ? PixelBoxStyle.green : PixelBoxStyle.parchment;
    final titleColor = isReady ? PixelPalette.paper : PixelPalette.ink;
    final subColor = isReady ? PixelPalette.cream : PixelPalette.slate;

    final String distanceLine = isReady
        ? '${quiz.distanceMeters}m away (inside ${quiz.radiusMeters}m zone)'
        : isApproaching
            ? '${quiz.distanceMeters}m away · enter ${quiz.radiusMeters}m zone'
            : '${quiz.destinationName} · ${quiz.municipality}';

    final String buttonLabel = isReady
        ? 'PLAY NOW'
        : isApproaching
            ? 'ROUTE'
            : 'REPLAY · 0 XP';

    return PixelPanel(
      style: panelStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                quiz.language.toUpperCase(),
                style: PixelBoxStyle.parchment,
              ),
              if (isReady || isApproaching)
                PixelChip(
                  '+${quiz.xpReward} XP',
                  style: PixelBoxStyle.gold,
                )
              else
                const PixelChip(
                  'DONE',
                  style: PixelBoxStyle.stone,
                  textColor: PixelPalette.white,
                ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(
            quiz.title,
            style: PixelType.title(context, color: titleColor),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            '${quiz.destinationName} · $distanceLine',
            style: PixelType.body(context, color: subColor),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: buttonLabel,
            style: isReady ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
            expand: true,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
