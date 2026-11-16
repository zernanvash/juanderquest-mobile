import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/submission_model.dart';
import '../providers/submission_provider.dart';

class SubmissionHistoryScreen extends ConsumerStatefulWidget {
  const SubmissionHistoryScreen({super.key});

  @override
  ConsumerState<SubmissionHistoryScreen> createState() =>
      _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState
    extends ConsumerState<SubmissionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true);
    });
  }

  Future<void> _reload() =>
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true);

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(submissionProvider);
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
                    title: 'Proof History',
                    onBack: canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: _reload,
                      child: _body(context, grid, subState),
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

  Widget _body(
    BuildContext context,
    PixelGrid grid,
    SubmissionState state,
  ) {
    if (state.isLoading && state.submissions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: grid.px(24)),
          const Center(child: PixelLoader(label: 'Loading submissions')),
        ],
      );
    }
    if (state.error != null && state.submissions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(grid.px(4)),
        children: [
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load history',
                  style: PixelType.title(context, color: PixelPalette.white),
                ),
                SizedBox(height: grid.px(2)),
                Text(
                  state.error!,
                  style: PixelType.body(context, color: PixelPalette.cream),
                ),
                SizedBox(height: grid.px(3)),
                Align(
                  alignment: Alignment.centerRight,
                  child: PixelButton(
                    key: const ValueKey('submissions_error_retry'),
                    label: 'Retry',
                    onPressed: () => _reload(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (state.submissions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: grid.px(4)),
        children: [
          SizedBox(height: grid.px(6)),
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: PixelEmptyState(
              key: const ValueKey('submissions_empty'),
              title: 'No submissions yet',
              message:
                  'Complete quests or submit destination spots to earn reward points.',
              action: PixelButton(
                key: const ValueKey('submissions_browse_quests'),
                label: 'Browse quests',
                onPressed: () => context.go('/quests'),
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        grid.px(4),
        grid.px(3),
        grid.px(4),
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelSectionTitle(
                'Proof history',
                icon: DesignerArt.questMarker,
                value: '${state.submissions.length}',
                valueColor: PixelPalette.greenDark,
              ),
              SizedBox(height: grid.px(1)),
              for (var i = 0; i < state.submissions.length; i++) ...[
                if (i > 0)
                  Container(height: grid.unit, color: PixelPalette.paperDim),
                _row(context, grid, state.submissions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, PixelGrid grid, SubmissionModel sub) {
    final approved = sub.status == 'approved';
    final rejected = sub.status == 'rejected';
    final statusStyle = approved
        ? PixelBoxStyle.green
        : rejected
            ? PixelBoxStyle.red
            : PixelBoxStyle.gold;
    final statusText = approved
        ? PixelPalette.white
        : rejected
            ? PixelPalette.white
            : PixelPalette.ink;
    final pointsLabel = approved
        ? '+${sub.rewardPoints} points earned'
        : rejected
            ? 'No points awarded'
            : '${sub.rewardPoints} points pending';
    return KeyedSubtree(
      key: ValueKey('submission_${sub.id}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  sub.questTitle,
                  style: PixelType.title(context),
                ),
                PixelChip(
                  sub.status.toUpperCase(),
                  style: statusStyle,
                  textColor: statusText,
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              children: [
                Text(
                  sub.category.replaceAll('_', ' ').toUpperCase(),
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                Text(
                  sub.submittedAt.split('T').first,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(
              pointsLabel,
              style: PixelType.numbers(
                context,
                color: approved ? PixelPalette.greenDark : PixelPalette.woodMid,
              ),
            ),
            if (sub.rejectionReason != null &&
                sub.rejectionReason!.isNotEmpty) ...[
              SizedBox(height: grid.px(1)),
              Text(
                'Reason: ${sub.rejectionReason}',
                style: PixelType.body(context, color: PixelPalette.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
