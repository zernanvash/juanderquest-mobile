import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/providers/cosmetics_provider.dart';
import '../../trail/models/trail_models.dart';
import '../models/vlog_manifest.dart';
import '../services/trail_vlog_vault.dart';
import '../services/vlog_compiler_service.dart';
import 'pixel_vlog_hud_overlay.dart';

/// Provider resolving whether the signed-in traveler unlocked premium Trail Vlog
/// HUD frames via Shop cosmetics or VIP status.
final hasVipVlogFramesProvider = Provider<bool>((ref) {
  final cosmetics = ref.watch(cosmeticsProvider);
  final user = ref.watch(authProvider).user;
  if (cosmetics.owned.isNotEmpty) return true;
  if (user?.cosmetics != null && user!.cosmetics!.isNotEmpty) return true;
  return false;
});

/// Instant sequential preview studio + cosmetic HUD/audio picker + hardware MP4
/// export & social sharing modal for a Trail Vlog.
class TrailVlogStudioSheet extends ConsumerStatefulWidget {
  final TrailVlogManifest manifest;
  final List<TrailStop> stops;
  final List<double> routeCoords;
  final bool? hasVipFramesOverride;

  const TrailVlogStudioSheet({
    super.key,
    required this.manifest,
    this.stops = const [],
    this.routeCoords = const [],
    this.hasVipFramesOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required TrailVlogManifest manifest,
    List<TrailStop> stops = const [],
    List<double> routeCoords = const [],
    bool? hasVipFramesOverride,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrailVlogStudioSheet(
        manifest: manifest,
        stops: stops,
        routeCoords: routeCoords,
        hasVipFramesOverride: hasVipFramesOverride,
      ),
    );
  }

  @override
  ConsumerState<TrailVlogStudioSheet> createState() =>
      _TrailVlogStudioSheetState();
}

class _TrailVlogStudioSheetState extends ConsumerState<TrailVlogStudioSheet> {
  late TrailVlogManifest _manifest;
  late List<VlogCompileSegment> _segments;
  int _activeIndex = 0;
  bool _isPlaying = true;
  bool _isCompiling = false;
  String? _statusMessage;
  Timer? _stepTimer;
  AudioPlayer? _bgmPlayer;
  Map<String, String> _thumbs = const {};

  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _manifest = widget.manifest;
    _rebuildSegments();
    unawaited(_loadThumbnails());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlaybackTimers();
    _syncAudio();
  }

  void _rebuildSegments() {
    _segments = VlogCompilerService.buildSegments(
      _manifest,
      stops: widget.stops,
      routeCoords: widget.routeCoords,
    );
    if (_activeIndex >= _segments.length) {
      _activeIndex = 0;
    }
  }

  Future<void> _loadThumbnails() async {
    final paths = _manifest.clips.map((c) => c.filePath).toList();
    if (paths.isEmpty) return;
    final thumbs =
        await ref.read(vlogCompilerServiceProvider).extractThumbnails(paths);
    if (mounted && thumbs.isNotEmpty) {
      setState(() => _thumbs = thumbs);
    }
  }

  void _syncPlaybackTimers() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || !_isPlaying || _segments.length <= 1) {
      _stepTimer?.cancel();
      _stepTimer = null;
      return;
    }
    _stepTimer?.cancel();
    final currentDur = Duration(
      milliseconds: _segments[_activeIndex].durationMs.clamp(800, 3500),
    );
    _stepTimer = Timer(currentDur, () {
      if (!mounted) return;
      setState(() {
        _activeIndex = (_activeIndex + 1) % _segments.length;
      });
      _syncPlaybackTimers();
    });
  }

  Future<void> _syncAudio() async {
    if (_inTest) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final wantBgm =
        !reduce && _isPlaying && _manifest.audioMode != VlogAudioMode.original;
    try {
      if (wantBgm) {
        final player = _bgmPlayer ??= AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0.35);
        await player.play(AssetSource('audio/music/jdq_bgm.mp3'));
      } else if (_bgmPlayer != null) {
        await _bgmPlayer!.pause();
      }
    } catch (_) {}
  }

  Future<void> _selectFrameStyle(
    VlogFrameStyle style,
    bool hasVipFrames,
  ) async {
    if (style.isPremium && !hasVipFrames) {
      showPixelToast(context, 'Unlock in Shop or Juander Pass');
      return;
    }
    final updated = await ref.read(trailVlogVaultProvider).updatePreferences(
          _manifest.trailId,
          frameStyle: style,
        );
    if (!mounted) return;
    setState(() {
      _manifest = updated ?? _manifest.copyWith(frameStyle: style);
      _rebuildSegments();
      _statusMessage = null;
    });
    ref.read(trailVlogRevisionProvider.notifier).state++;
  }

  Future<void> _selectAudioMode(VlogAudioMode mode) async {
    final updated = await ref.read(trailVlogVaultProvider).updatePreferences(
          _manifest.trailId,
          audioMode: mode,
        );
    if (!mounted) return;
    setState(() {
      _manifest = updated ?? _manifest.copyWith(audioMode: mode);
      _statusMessage = null;
    });
    ref.read(trailVlogRevisionProvider.notifier).state++;
    unawaited(_syncAudio());
  }

  Future<String?> _ensureCompiled() async {
    final existing = _manifest.compiledPath;
    if (existing != null && File(existing).existsSync()) {
      return existing;
    }
    setState(() {
      _isCompiling = true;
      _statusMessage = null;
    });
    try {
      final result =
          await ref.read(vlogCompilerServiceProvider).compileTrailVlog(
                context: context,
                manifest: _manifest,
                stops: widget.stops,
                routeCoords: widget.routeCoords,
              );
      final refreshed = await ref
          .read(trailVlogVaultProvider)
          .loadManifest(_manifest.trailId);
      if (mounted) {
        setState(() {
          _manifest = refreshed ??
              _manifest.copyWith(
                compiledPath: () => result.outputPath,
                compiledSizeBytes: () => result.sizeBytes,
              );
        });
        ref.read(trailVlogRevisionProvider.notifier).state++;
      }
      return result.outputPath;
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not compile MP4. Try again.');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isCompiling = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isCompiling) return;
    final path = await _ensureCompiled();
    if (path == null || !mounted) return;
    setState(() => _isCompiling = true);
    try {
      await ref
          .read(vlogCompilerServiceProvider)
          .saveToGallery(path, _manifest.trailTitle);
      if (mounted) {
        setState(() {
          _statusMessage = 'Saved to Gallery (Movies/JuanDerQuest)';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not save to Gallery.');
      }
    } finally {
      if (mounted) setState(() => _isCompiling = false);
    }
  }

  Future<void> _shareVlog() async {
    if (_isCompiling) return;
    final path = await _ensureCompiled();
    if (path == null || !mounted) return;
    try {
      await ref
          .read(vlogCompilerServiceProvider)
          .shareVlog(path, _manifest.trailTitle);
    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not open share sheet.');
      }
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _stepTimer = null;
    final p = _bgmPlayer;
    _bgmPlayer = null;
    if (p != null) {
      unawaited(p.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool hasVipFrames =
        widget.hasVipFramesOverride ?? ref.watch(hasVipVlogFramesProvider);
    final activeSeg = _segments[_activeIndex];
    final totalDurationSec =
        _segments.fold<int>(0, (sum, s) => sum + s.durationMs) / 1000.0;
    final stopCoords = <double>[
      for (final s in widget.stops) ...[s.lng, s.lat],
    ];

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final previewHeight = (media.size.height * 0.36).clamp(130.0, 290.0);

          return Container(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
            decoration: const BoxDecoration(
              color: PixelPalette.paper,
              border: Border(
                top: BorderSide(color: PixelPalette.ink, width: 3),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(grid.px(2.5)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRAIL VLOG STUDIO',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_manifest.trailTitle.toUpperCase()} · '
                                '${_manifest.totalClips} CLIPS · '
                                '${totalDurationSec.toStringAsFixed(1)}S',
                                style: PixelType.small(
                                  context,
                                  color: PixelPalette.slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: grid.px(1)),
                        PixelButton(
                          key: const ValueKey('vlog_studio_close'),
                          label: 'CLOSE',
                          variant: PixelButtonVariant.secondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(1.5)),

                    // 9:16 Instant Storyboard Preview
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isPlaying = !_isPlaying);
                          _syncPlaybackTimers();
                          unawaited(_syncAudio());
                        },
                        child: SizedBox(
                          height: previewHeight,
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: Container(
                              key: const ValueKey('vlog_studio_preview'),
                              decoration: const BoxDecoration(
                                color: PixelPalette.woodNight,
                                border: Border.fromBorderSide(
                                  BorderSide(color: PixelPalette.ink, width: 2),
                                ),
                              ),
                              child: activeSeg.isOutro
                                  ? OutroStampCard(
                                      trailTitle: _manifest.trailTitle,
                                      totalStops: _manifest.totalStops,
                                      totalKm: _manifest.totalKm,
                                      rewardPoints: _manifest.rewardPoints,
                                      frameStyle: _manifest.frameStyle,
                                    )
                                  : activeSeg.type == 'image_card'
                                      ? SkippedStopCard(
                                          stopPosition: activeSeg.stopPosition,
                                          totalStops: _manifest.totalStops,
                                          spotName: activeSeg.label,
                                          municipality: activeSeg.subLabel,
                                          frameStyle: _manifest.frameStyle,
                                          routeCoords: widget.routeCoords,
                                          stopCoords: stopCoords,
                                        )
                                      : _videoSegmentPreview(
                                          context, activeSeg),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: grid.px(1)),

                    // Segment Stepper Strip
                    Row(
                      children: [
                        for (var i = 0; i < _segments.length; i++) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _activeIndex = i);
                                _syncPlaybackTimers();
                              },
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _activeIndex
                                      ? PixelPalette.sun
                                      : (_segments[i].type == 'video'
                                          ? PixelPalette.green
                                          : PixelPalette.parchment),
                                  border: Border.all(
                                    color: PixelPalette.ink,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (i < _segments.length - 1)
                            const SizedBox(width: 2),
                        ],
                      ],
                    ),
                    SizedBox(height: grid.px(1.5)),

                    // Frame Style Selector
                    Text(
                      'HUD FRAME',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.woodDeep,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      key: const ValueKey('vlog_frame_selector'),
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final style in VlogFrameStyle.values)
                          PixelChip(
                            style.isPremium && !hasVipFrames
                                ? '${style.label} [VIP]'
                                : style.label,
                            key: ValueKey('vlog_frame_${style.key}'),
                            style: _manifest.frameStyle == style
                                ? PixelBoxStyle.gold
                                : PixelBoxStyle.parchment,
                            onTap: () => unawaited(
                                _selectFrameStyle(style, hasVipFrames)),
                          ),
                      ],
                    ),
                    SizedBox(height: grid.px(1.5)),

                    // Audio Mix Selector
                    Text(
                      'SOUNDTRACK',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.woodDeep,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      key: const ValueKey('vlog_audio_selector'),
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final mode in VlogAudioMode.values)
                          PixelChip(
                            mode.label,
                            key: ValueKey('vlog_audio_${mode.key}'),
                            style: _manifest.audioMode == mode
                                ? PixelBoxStyle.green
                                : PixelBoxStyle.parchment,
                            textColor: _manifest.audioMode == mode
                                ? PixelPalette.paper
                                : PixelPalette.ink,
                            onTap: () => unawaited(_selectAudioMode(mode)),
                          ),
                      ],
                    ),

                    if (_statusMessage != null) ...[
                      SizedBox(height: grid.px(1.5)),
                      PixelPanel(
                        key: const ValueKey('vlog_studio_status'),
                        style: PixelBoxStyle.parchment,
                        padding: 1,
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: grid.px(2)),

                    // Export Actions
                    Row(
                      children: [
                        Expanded(
                          child: PixelButton(
                            key: const ValueKey('vlog_save_gallery_button'),
                            label: 'SAVE MP4',
                            variant: PixelButtonVariant.secondary,
                            loading: _isCompiling,
                            onPressed: _isCompiling
                                ? null
                                : () => unawaited(_saveToGallery()),
                          ),
                        ),
                        SizedBox(width: grid.px(1.5)),
                        Expanded(
                          child: PixelButton(
                            key: const ValueKey('vlog_share_button'),
                            label: 'SHARE VLOG',
                            variant: PixelButtonVariant.primary,
                            loading: _isCompiling,
                            onPressed: _isCompiling
                                ? null
                                : () => unawaited(_shareVlog()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _videoSegmentPreview(BuildContext context, VlogCompileSegment seg) {
    final thumbPath = _thumbs[seg.path];
    final badge = seg.clipKind == VlogClipKind.road
        ? 'ROAD'
        : '${seg.stopPosition}/${_manifest.totalStops}';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbPath != null && File(thumbPath).existsSync())
          Image.file(File(thumbPath), fit: BoxFit.cover)
        else
          ColoredBox(
            color: PixelPalette.wood,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  _isPlaying ? 'PLAYING 3.0S CLIP' : 'PAUSED',
                  textAlign: TextAlign.center,
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ),
            ),
          ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: PixelVlogLowerThird(
            frameStyle: _manifest.frameStyle,
            badgeText: badge,
            title: seg.label,
            subtitle: seg.subLabel,
          ),
        ),
      ],
    );
  }
}
