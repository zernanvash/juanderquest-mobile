import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/vlog_manifest.dart';
import '../services/trail_vlog_vault.dart';
import '../services/vlog_camera_adapter.dart';
import 'pixel_vlog_hud_overlay.dart';

/// 3-second Setlog-inspired Pixel Viewfinder modal for Stop Check-In clips and
/// optional parked Road Moment clips. Never keeps CameraController alive when closed.
class PixelVlogRecorderSheet extends ConsumerStatefulWidget {
  final String trailId;
  final String trailTitle;
  final int totalStops;
  final double totalKm;
  final int rewardPoints;
  final VlogClipKind kind;
  final int stopPosition;
  final String? spotId;
  final String spotName;
  final String municipality;
  final double currentSpeedMs;
  final VlogFrameStyle frameStyle;

  const PixelVlogRecorderSheet({
    super.key,
    required this.trailId,
    required this.trailTitle,
    required this.totalStops,
    required this.totalKm,
    this.rewardPoints = 0,
    required this.kind,
    required this.stopPosition,
    this.spotId,
    required this.spotName,
    required this.municipality,
    this.currentSpeedMs = 0.0,
    this.frameStyle = VlogFrameStyle.defaultFrame,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String trailId,
    required String trailTitle,
    required int totalStops,
    required double totalKm,
    int rewardPoints = 0,
    required VlogClipKind kind,
    required int stopPosition,
    String? spotId,
    required String spotName,
    required String municipality,
    double currentSpeedMs = 0.0,
    VlogFrameStyle frameStyle = VlogFrameStyle.defaultFrame,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PixelVlogRecorderSheet(
        trailId: trailId,
        trailTitle: trailTitle,
        totalStops: totalStops,
        totalKm: totalKm,
        rewardPoints: rewardPoints,
        kind: kind,
        stopPosition: stopPosition,
        spotId: spotId,
        spotName: spotName,
        municipality: municipality,
        currentSpeedMs: currentSpeedMs,
        frameStyle: frameStyle,
      ),
    );
  }

  @override
  ConsumerState<PixelVlogRecorderSheet> createState() =>
      _PixelVlogRecorderSheetState();
}

class _PixelVlogRecorderSheetState
    extends ConsumerState<PixelVlogRecorderSheet> {
  static const _clipDurationMs = 3000;
  static const _segments = 8;
  static const _tickMs = _clipDurationMs ~/ _segments;

  late final VlogCameraAdapter _adapter;
  bool _initializing = true;
  bool _frontCamera = false;
  bool _isRecording = false;
  bool _isSaving = false;
  String? _capturedFilePath;
  String? _error;
  int _elapsedSegments = 0;
  Timer? _recordTimer;

  bool get _isMovingTooFast => widget.currentSpeedMs > 3.0;

  @override
  void initState() {
    super.initState();
    _adapter = ref.read(vlogCameraAdapterFactoryProvider)();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      await _adapter.initialize(
        frontCamera: _frontCamera,
        enableAudio: true,
      );
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Camera unavailable. Check permissions and try again.';
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_isRecording || _initializing || _capturedFilePath != null) return;
    _frontCamera = !_frontCamera;
    await _initCamera();
  }

  Future<void> _startRecording() async {
    if (_isMovingTooFast ||
        _initializing ||
        _isRecording ||
        !_adapter.isInitialized) {
      return;
    }
    setState(() {
      _isRecording = true;
      _elapsedSegments = 0;
      _error = null;
    });
    try {
      await _adapter.startRecording();
      if (!mounted) return;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(
        const Duration(milliseconds: _tickMs),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          final next = _elapsedSegments + 1;
          if (next >= _segments) {
            timer.cancel();
            _recordTimer = null;
            unawaited(_stopRecording());
          } else {
            setState(() => _elapsedSegments = next);
          }
        },
      );
    } catch (_) {
      _recordTimer?.cancel();
      _recordTimer = null;
      if (mounted) {
        setState(() {
          _isRecording = false;
          _error = 'Could not start recording. Try again.';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!_isRecording) return;
    try {
      final path = await _adapter.stopRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _elapsedSegments = _segments;
        _capturedFilePath = path;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _error = 'Could not finish clip. Please retake.';
        });
      }
    }
  }

  Future<void> _retake() async {
    setState(() {
      _capturedFilePath = null;
      _elapsedSegments = 0;
      _error = null;
    });
  }

  Future<void> _saveClip() async {
    final path = _capturedFilePath;
    if (path == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(trailVlogVaultProvider).saveClip(
            trailId: widget.trailId,
            trailTitle: widget.trailTitle,
            totalStops: widget.totalStops,
            totalKm: widget.totalKm,
            rewardPoints: widget.rewardPoints,
            kind: widget.kind,
            stopPosition: widget.stopPosition,
            spotId: widget.spotId,
            spotName: widget.spotName,
            municipality: widget.municipality,
            sourceFilePath: path,
            durationMs: _clipDurationMs,
            cameraFacing: _frontCamera ? 'front' : 'back',
          );
      ref.read(trailVlogRevisionProvider.notifier).state++;
      await _adapter.dispose();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Could not save clip locally.';
        });
      }
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recordTimer = null;
    unawaited(_adapter.dispose());
    super.dispose();
  }

  String _timeLabel() {
    final now = DateTime.now();
    final h24 = now.hour;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final min = now.minute.toString().padLeft(2, '0');
    final amPm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$min $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final headerLabel = widget.kind == VlogClipKind.stop
        ? 'STOP ${widget.stopPosition}/${widget.totalStops} · ${widget.spotName}'
        : 'ROAD CLIP · LEG ${widget.stopPosition}';
    final badgeText = widget.kind == VlogClipKind.stop
        ? '${widget.stopPosition}/${widget.totalStops}'
        : 'ROAD';
    final remainingSec =
        ((_segments - _elapsedSegments) * _tickMs / 1000).clamp(0.0, 3.0);

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final maxViewfinderH = (media.size.height * 0.44).clamp(130.0, 360.0);

          return Container(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
            decoration: const BoxDecoration(
              color: PixelPalette.woodNight,
              border: Border(
                top: BorderSide(color: PixelPalette.ink, width: 3),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(grid.px(2)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar
                    Row(
                      children: [
                        _barButton(
                          context,
                          key: const ValueKey('vlog_close_button'),
                          label: 'X',
                          enabled: !_isSaving,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                        SizedBox(width: grid.px(1)),
                        Expanded(
                          child: Text(
                            headerLabel.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.cream,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: grid.px(1)),
                        _barButton(
                          context,
                          key: const ValueKey('vlog_flip_camera_button'),
                          label: _frontCamera ? 'FRONT' : 'BACK',
                          enabled: !_isRecording &&
                              !_initializing &&
                              _capturedFilePath == null &&
                              !_isSaving,
                          onTap: () => unawaited(_flipCamera()),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(1.5)),

                    if (_isMovingTooFast) ...[
                      PixelPanel(
                        key: const ValueKey('vlog_speed_warning'),
                        style: PixelBoxStyle.red,
                        padding: 1,
                        child: Text(
                          'PARK FIRST TO VLOG',
                          textAlign: TextAlign.center,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.white,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                    ],

                    if (_error != null) ...[
                      PixelPanel(
                        style: PixelBoxStyle.red,
                        padding: 1,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.white,
                          ),
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                    ],

                    // 9:16 Live Viewfinder + HUD Stamp Preview
                    Center(
                      child: SizedBox(
                        height: maxViewfinderH,
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: PixelPalette.ink,
                              border: Border.fromBorderSide(
                                BorderSide(color: PixelPalette.paper, width: 2),
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_capturedFilePath != null)
                                  ColoredBox(
                                    color: PixelPalette.greenDeep,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '3.0S CLIP CAPTURED',
                                          key: const ValueKey(
                                              'vlog_captured_badge'),
                                          textAlign: TextAlign.center,
                                          style: PixelType.title(
                                            context,
                                            color: PixelPalette.cream,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_initializing)
                                  const Center(
                                    child: PixelLoader(label: 'Camera'),
                                  )
                                else
                                  _adapter.buildPreview(context),
                                if (!_initializing && !_adapter.isAudioEnabled)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    right: 6,
                                    child: Container(
                                      key:
                                          const ValueKey('vlog_mic_off_notice'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      color: PixelPalette.ink
                                          .withValues(alpha: 0.8),
                                      child: Text(
                                        'MIC OFF · CHIPTUNE BGM WILL PLAY',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: PixelType.small(
                                          context,
                                          color: PixelPalette.sunLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 6,
                                  right: 6,
                                  bottom: 6,
                                  child: PixelVlogLowerThird(
                                    frameStyle: widget.frameStyle,
                                    badgeText: badgeText,
                                    title: widget.spotName,
                                    subtitle:
                                        '${widget.municipality} · ${_timeLabel()}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: grid.px(1.5)),

                    // 8-Segment Stepped Countdown Bar
                    Row(
                      key: const ValueKey('vlog_countdown_bar'),
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              for (var i = 0; i < _segments; i++) ...[
                                Expanded(
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: i < _elapsedSegments
                                          ? PixelPalette.red
                                          : PixelPalette.woodMid,
                                      border: Border.all(
                                        color: PixelPalette.ink,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                if (i < _segments - 1) const SizedBox(width: 2),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: grid.px(1.5)),
                        Text(
                          '${remainingSec.toStringAsFixed(1)}S',
                          style: PixelType.small(
                            context,
                            color: PixelPalette.cream,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(2)),

                    // Action Controls
                    if (_capturedFilePath != null)
                      Row(
                        children: [
                          Expanded(
                            child: PixelButton(
                              key: const ValueKey('vlog_retake_button'),
                              label: 'RETAKE',
                              variant: PixelButtonVariant.secondary,
                              onPressed: _isSaving ? null : _retake,
                            ),
                          ),
                          SizedBox(width: grid.px(1.5)),
                          Expanded(
                            flex: 2,
                            child: PixelButton(
                              key: const ValueKey('vlog_use_clip_button'),
                              label: 'SAVE CLIP',
                              variant: PixelButtonVariant.primary,
                              loading: _isSaving,
                              onPressed: _isSaving ? null : _saveClip,
                            ),
                          ),
                        ],
                      )
                    else
                      Center(
                        child: SizedBox(
                          height: 56,
                          width: 200,
                          child: PixelButton(
                            key: const ValueKey('vlog_shutter_button'),
                            label: _isMovingTooFast
                                ? 'PARK FIRST TO VLOG'
                                : (_isRecording ? 'RECORDING…' : 'REC 3S VLOG'),
                            variant: PixelButtonVariant.danger,
                            style: (_isMovingTooFast || _initializing)
                                ? null
                                : PixelBoxStyle.red,
                            onPressed: (_isMovingTooFast ||
                                    _initializing ||
                                    !_adapter.isInitialized)
                                ? null
                                : (_isRecording
                                    ? (_elapsedSegments >= 3
                                        ? () => unawaited(_stopRecording())
                                        : null)
                                    : () => unawaited(_startRecording())),
                          ),
                        ),
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

  Widget _barButton(
    BuildContext context, {
    required Key key,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? PixelPalette.parchment : PixelPalette.slate,
          border: Border.all(color: PixelPalette.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          style: PixelType.small(
            context,
            color: enabled ? PixelPalette.ink : PixelPalette.mist,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
