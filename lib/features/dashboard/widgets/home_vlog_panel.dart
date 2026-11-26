import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../navigation/providers/active_trail_session_provider.dart';
import '../../trail_vlog/models/vlog_manifest.dart';
import '../../trail_vlog/services/trail_vlog_vault.dart';
import '../../trail_vlog/widgets/pixel_vlog_recorder_sheet.dart';
import '../../trail_vlog/widgets/trail_vlog_studio_sheet.dart';

/// Saved trail and custom vlogs on this phone (newest first). Empty when the
/// vault can't be read (tests, no storage).
final homeSavedVlogsProvider =
    FutureProvider.autoDispose<List<TrailVlogManifest>>((ref) async {
  ref.watch(trailVlogRevisionProvider);
  try {
    return await ref.read(trailVlogVaultProvider).listAllVlogs();
  } catch (_) {
    return const [];
  }
});

/// Plan 124d: JuanLog on Home. One row when idle (NEW CUSTOM VLOG, MY VLOGS);
/// with a trail running in the background it also shows the next stop, an
/// IN RANGE / OUTSIDE TOLERANCE badge, RESUME TRAIL and RECORD CLIP.
/// Recording is never blocked: the recorder shows warnings only.
class HomeVlogPanel extends ConsumerWidget {
  const HomeVlogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final session = ref.watch(activeTrailSessionProvider);
    final saved = ref.watch(homeSavedVlogsProvider).valueOrNull ?? const [];
    final running = session.isRunning && session.destination != null;

    return PixelPanel(
      key: const ValueKey('home_vlog_panel'),
      style: PixelBoxStyle.wood,
      padding: PixelPanel.sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            'JUANLOG',
            value: running ? 'TRAIL RUNNING' : null,
          ),
          SizedBox(height: grid.px(2)),
          if (running) ...[
            _RunningTrail(session: session),
            SizedBox(height: grid.px(2)),
          ],
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: const ValueKey('home_vlog_new_custom'),
                  label: 'NEW CUSTOM VLOG',
                  variant: PixelButtonVariant.primary,
                  onPressed: () => unawaited(_newCustomVlog(context, ref)),
                ),
              ),
              if (saved.isNotEmpty) ...[
                SizedBox(width: grid.px(1.5)),
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('home_vlog_my_vlogs'),
                    label: 'MY VLOGS (${saved.length})',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => unawaited(_showSaved(context, saved)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _newCustomVlog(BuildContext context, WidgetRef ref) async {
    final vault = ref.read(trailVlogVaultProvider);
    final TrailVlogManifest manifest;
    try {
      manifest = await vault.createCustomSession();
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    final saved = await PixelVlogRecorderSheet.show(
      context,
      trailId: manifest.trailId,
      trailTitle: manifest.trailTitle,
      totalStops: 0,
      totalKm: 0,
      kind: VlogClipKind.custom,
      stopPosition: 1,
      spotName: manifest.trailTitle,
      municipality: 'Custom JuanLog',
      isTrailRunning: false,
    );
    final fresh = await vault.loadManifest(manifest.trailId);
    if (saved != true || fresh == null || fresh.totalClips == 0) {
      // Nothing recorded: don't leave an empty log behind.
      await vault.deleteTrailVlog(manifest.trailId);
      return;
    }
    if (!context.mounted) return;
    await TrailVlogStudioSheet.show(context, manifest: fresh);
  }

  Future<void> _showSaved(
    BuildContext context,
    List<TrailVlogManifest> saved,
  ) async {
    final picked = await showModalBottomSheet<TrailVlogManifest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedVlogsSheet(saved: saved),
    );
    if (picked == null || !context.mounted) return;
    await TrailVlogStudioSheet.show(context, manifest: picked);
  }
}

class _RunningTrail extends ConsumerWidget {
  final ActiveTrailSessionState session;

  const _RunningTrail({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final dist = session.distanceToNextStopM;
    final inRange = session.isWithinStopTolerance;
    final next = session.nextStopName;
    return Column(
      key: const ValueKey('home_vlog_running_trail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          (session.trailTitle ?? 'Trail').toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: PixelType.body(context, color: PixelPalette.paper)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        if (next != null) ...[
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                dist != null
                    ? 'NEXT: $next · ${_formatDistance(dist)}'
                    : 'NEXT: $next',
                style: PixelType.small(context, color: PixelPalette.cream),
              ),
              PixelChip(
                inRange ? 'IN RANGE' : 'OUTSIDE TOLERANCE',
                key: const ValueKey('home_vlog_tolerance_badge'),
                style: inRange ? PixelBoxStyle.green : PixelBoxStyle.gold,
                textColor: inRange ? PixelPalette.paper : PixelPalette.ink,
              ),
            ],
          ),
        ],
        SizedBox(height: grid.px(2)),
        Row(
          children: [
            Expanded(
              child: PixelButton(
                key: const ValueKey('home_vlog_resume_trail'),
                label: 'RESUME TRAIL',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    context.push('/navigate', extra: session.destination),
              ),
            ),
            if (session.hasTrail) ...[
              SizedBox(width: grid.px(1.5)),
              Expanded(
                child: PixelButton(
                  key: const ValueKey('home_vlog_record_clip'),
                  label: 'RECORD CLIP',
                  variant: PixelButtonVariant.primary,
                  onPressed: () => unawaited(_recordClip(context, ref)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _recordClip(BuildContext context, WidgetRef ref) async {
    final position = session.nextStopPosition ?? session.totalStops;
    final inRange = session.isWithinStopTolerance;
    // At the stop: a stop clip. Elsewhere: a road clip on the way there.
    await PixelVlogRecorderSheet.show(
      context,
      trailId: session.trailId!,
      trailTitle: session.trailTitle ?? 'Trail',
      totalStops: session.totalStops,
      totalKm: session.totalKm,
      rewardPoints: session.rewardPoints,
      kind: inRange ? VlogClipKind.stop : VlogClipKind.road,
      stopPosition: position < 1 ? 1 : position,
      spotId: session.nextStopSpotId,
      spotName: session.nextStopName ?? 'On The Road',
      municipality: session.nextStopMunicipality ?? '',
      currentSpeedMs: session.speedMs,
      isTrailRunning: true,
      isWithinStopTolerance: inRange,
      distanceToStopMeters: session.distanceToNextStopM,
    );
  }

  static String _formatDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} KM' : '${m.round()} M';
}

class _SavedVlogsSheet extends StatelessWidget {
  final List<TrailVlogManifest> saved;

  const _SavedVlogsSheet({required this.saved});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(top: BorderSide(color: PixelPalette.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('home_vlog_saved_list'),
          shrinkWrap: true,
          padding: EdgeInsets.all(grid.px(2.5)),
          children: [
            PixelSectionTitle('MY VLOGS', value: '${saved.length}'),
            SizedBox(height: grid.px(2)),
            for (final m in saved) ...[
              PixelTappableSlot(
                key: ValueKey('home_vlog_saved_${m.trailId}'),
                style: PixelBoxStyle.parchment,
                padding: 2,
                onTap: () => Navigator.of(context).pop(m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.trailTitle.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(context, color: PixelPalette.ink),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    Text(
                      '${m.isCustom ? 'CUSTOM' : 'TRAIL'} · ${m.totalClips} CLIPS',
                      style:
                          PixelType.small(context, color: PixelPalette.woodMid),
                    ),
                  ],
                ),
              ),
              SizedBox(height: grid.px(1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
