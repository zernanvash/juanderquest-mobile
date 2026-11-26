import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../trail/models/trail_models.dart';
import '../models/vlog_manifest.dart';
import '../widgets/pixel_vlog_hud_overlay.dart';
import 'trail_vlog_vault.dart';

/// Builds ordered Trail Vlog timelines, rasterizes 2.5D Pixel HUD overlays /
/// skipped-stop cards / outro stamp cards to PNGs, invokes the native Android
/// Media3 Transformer bridge, and handles Gallery & Share Sheet export.
class VlogCompilerService {
  static const _channel = MethodChannel('com.juanderquest.app/vlog_compiler');

  final TrailVlogVault _vault;
  final Future<Directory> Function() _tempDirProvider;

  VlogCompilerService({
    required TrailVlogVault vault,
    Future<Directory> Function()? tempDirProvider,
  })  : _vault = vault,
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  /// Builds the ordered chronological sequence for preview and export:
  /// For each stop 1..N: optional parked road clip -> stop clip (or 1.5s pixel
  /// card if the stop was checked in without video) -> 2.0s Outro Passport card.
  static List<VlogCompileSegment> buildSegments(
    TrailVlogManifest manifest, {
    List<TrailStop> stops = const [],
    List<double> routeCoords = const [],
  }) {
    final segments = <VlogCompileSegment>[];
    if (manifest.isCustom) {
      // Plan 124d: custom logs play their clips in order, then the outro card.
      final clips = [...manifest.clips]
        ..sort((a, b) => a.stopPosition.compareTo(b.stopPosition));
      for (final clip in clips) {
        segments.add(
          VlogCompileSegment(
            type: 'video',
            path: clip.filePath,
            durationMs: clip.durationMs,
            stopPosition: clip.stopPosition,
            clipKind: VlogClipKind.custom,
            label: clip.spotName.isNotEmpty ? clip.spotName : 'Custom Log',
            subLabel:
                '${clip.municipality} · ${_formatTime(clip.capturedAtIso)}',
          ),
        );
      }
      segments.add(
        VlogCompileSegment(
          type: 'image_card',
          path: '',
          durationMs: 2000,
          stopPosition: clips.length + 1,
          label: manifest.trailTitle,
          subLabel: '${clips.length} CLIPS · CUSTOM JUANLOG',
          isOutro: true,
        ),
      );
      return segments;
    }
    final stopCount = manifest.totalStops > 0
        ? manifest.totalStops
        : (stops.isNotEmpty ? stops.length : manifest.clips.length);

    final stopByPos = <int, TrailStop>{
      for (final s in stops) s.position: s,
    };

    for (var pos = 1; pos <= stopCount; pos++) {
      final road = manifest.roadClipForLeg(pos);
      if (road != null) {
        segments.add(
          VlogCompileSegment(
            type: 'video',
            path: road.filePath,
            durationMs: road.durationMs,
            stopPosition: pos,
            clipKind: VlogClipKind.road,
            label: road.spotName.isNotEmpty ? road.spotName : 'On The Road',
            subLabel:
                '${road.municipality} · ${_formatTime(road.capturedAtIso)}',
          ),
        );
      }

      final stopClip = manifest.stopClipFor(pos);
      if (stopClip != null) {
        segments.add(
          VlogCompileSegment(
            type: 'video',
            path: stopClip.filePath,
            durationMs: stopClip.durationMs,
            stopPosition: pos,
            clipKind: VlogClipKind.stop,
            label: stopClip.spotName,
            subLabel:
                '${stopClip.municipality} · ${_formatTime(stopClip.capturedAtIso)}',
          ),
        );
      } else {
        final stop = stopByPos[pos];
        segments.add(
          VlogCompileSegment(
            type: 'image_card',
            path: '',
            durationMs: 1500,
            stopPosition: pos,
            clipKind: VlogClipKind.stop,
            label: stop?.name ?? 'Stop $pos',
            subLabel: stop?.municipality ?? 'Pangasinan',
          ),
        );
      }
    }

    // Any extra clips whose stopPosition exceeded stopCount (defensive fallback)
    for (final clip in manifest.clips) {
      if (clip.stopPosition > stopCount) {
        segments.add(
          VlogCompileSegment(
            type: 'video',
            path: clip.filePath,
            durationMs: clip.durationMs,
            stopPosition: clip.stopPosition,
            clipKind: clip.kind,
            label: clip.spotName,
            subLabel:
                '${clip.municipality} · ${_formatTime(clip.capturedAtIso)}',
          ),
        );
      }
    }

    segments.add(
      VlogCompileSegment(
        type: 'image_card',
        path: '',
        durationMs: 2000,
        stopPosition: stopCount + 1,
        label: manifest.trailTitle,
        subLabel:
            '$stopCount STOPS · ${manifest.totalKm.toStringAsFixed(1)} KM',
        isOutro: true,
      ),
    );

    return segments;
  }

  static String _formatTime(String iso) {
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return 'Trail Log';
    final h24 = parsed.hour;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final min = parsed.minute.toString().padLeft(2, '0');
    final amPm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$min $amPm';
  }

  Future<VlogCompileResult> compileTrailVlog({
    required BuildContext context,
    required TrailVlogManifest manifest,
    List<TrailStop> stops = const [],
    List<double> routeCoords = const [],
  }) async {
    final segments = buildSegments(
      manifest,
      stops: stops,
      routeCoords: routeCoords,
    );
    final stopCoords = <double>[
      for (final s in stops) ...[s.lng, s.lat],
    ];
    final tmpDir = await _tempDirProvider();
    final renderDir = Directory(
      '${tmpDir.path}${Platform.pathSeparator}vlog_render_${manifest.trailId.hashCode}',
    );
    if (!await renderDir.exists()) {
      await renderDir.create(recursive: true);
    }

    final prepared = <VlogCompileSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (!context.mounted) break;
      if (seg.type == 'video') {
        final badge = switch (seg.clipKind) {
          VlogClipKind.road => 'ROAD',
          VlogClipKind.custom => 'LOG',
          _ => '${seg.stopPosition}/${manifest.totalStops}',
        };
        final overlayFile = File(
          '${renderDir.path}${Platform.pathSeparator}hud_$i.png',
        );
        await _rasterizeWidgetToPng(
          context,
          overlayFile,
          SizedBox(
            width: 360,
            height: 640,
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 36,
                  child: PixelVlogLowerThird(
                    frameStyle: manifest.frameStyle,
                    badgeText: badge,
                    title: seg.label,
                    subtitle: seg.subLabel,
                  ),
                ),
              ],
            ),
          ),
        );
        prepared.add(seg.withAssets(overlayPngPath: overlayFile.path));
      } else if (seg.isOutro) {
        final cardFile = File(
          '${renderDir.path}${Platform.pathSeparator}outro_$i.png',
        );
        await _rasterizeWidgetToPng(
          context,
          cardFile,
          SizedBox(
            width: 360,
            height: 640,
            child: OutroStampCard(
              trailTitle: manifest.trailTitle,
              totalStops: manifest.totalStops,
              totalKm: manifest.totalKm,
              rewardPoints: manifest.rewardPoints,
              frameStyle: manifest.frameStyle,
            ),
          ),
        );
        prepared.add(seg.withAssets(path: cardFile.path));
      } else {
        final cardFile = File(
          '${renderDir.path}${Platform.pathSeparator}stop_$i.png',
        );
        await _rasterizeWidgetToPng(
          context,
          cardFile,
          SizedBox(
            width: 360,
            height: 640,
            child: SkippedStopCard(
              stopPosition: seg.stopPosition,
              totalStops: manifest.totalStops,
              spotName: seg.label,
              municipality: seg.subLabel,
              frameStyle: manifest.frameStyle,
              routeCoords: routeCoords,
              stopCoords: stopCoords,
            ),
          ),
        );
        prepared.add(seg.withAssets(path: cardFile.path));
      }
    }

    final outputPath = await _vault.compiledOutputPath(manifest.trailId);
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'compileTrailVlog',
      {
        'segments': [for (final s in prepared) s.toJson()],
        'outputPath': outputPath,
        'audioMode': manifest.audioMode.key,
        'bgmAssetKey': manifest.bgmTrackKey,
      },
    );

    final result = VlogCompileResult(
      outputPath: raw?['outputPath']?.toString() ?? outputPath,
      sizeBytes: (raw?['sizeBytes'] as num?)?.toInt() ?? 0,
      durationMs: (raw?['durationMs'] as num?)?.toInt() ??
          segments.fold<int>(0, (sum, s) => sum + s.durationMs),
    );
    await _vault.recordCompilation(manifest.trailId, result);
    return result;
  }

  Future<void> _rasterizeWidgetToPng(
    BuildContext context,
    File targetFile,
    Widget child,
  ) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: AppTheme.pixel,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                devicePixelRatio: 2.0,
              ),
              child: RepaintBoundary(
                key: key,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        await targetFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      image.dispose();
    } finally {
      entry.remove();
    }
  }

  Future<Map<String, String>> extractThumbnails(List<String> clipPaths) async {
    if (clipPaths.isEmpty) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'extractClipThumbnails',
        {'clipPaths': clipPaths},
      );
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<String> saveToGallery(String filePath, String trailTitle) async {
    final safeTitle =
        trailTitle.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').trim();
    final name =
        'JuanDerQuest_${safeTitle.isEmpty ? 'TrailVlog' : safeTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final uri = await _channel.invokeMethod<String>(
      'saveVideoToGallery',
      {
        'filePath': filePath,
        'displayName': name,
      },
    );
    return uri ?? 'Movies/JuanDerQuest/$name';
  }

  Future<void> shareVlog(String filePath, String trailTitle) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'video/mp4')],
        text: 'My Trail Vlog: $trailTitle #JuanderQuest',
      ),
    );
  }
}

final vlogCompilerServiceProvider = Provider<VlogCompilerService>((ref) {
  return VlogCompilerService(vault: ref.watch(trailVlogVaultProvider));
});
