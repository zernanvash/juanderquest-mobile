import 'dart:convert';

/// Whether a 3-second vlog clip was recorded at a trail stop check-in or
/// during a parked roadside moment on a trail leg.
enum VlogClipKind {
  stop('stop'),
  road('road');

  final String key;
  const VlogClipKind(this.key);

  static VlogClipKind fromKey(String? raw) {
    return VlogClipKind.values.firstWhere(
      (k) => k.key == raw,
      orElse: () => VlogClipKind.stop,
    );
  }
}

/// Visual frame skins for the burned-in 2.5D Pixel HUD lower-third plate.
enum VlogFrameStyle {
  defaultFrame('default', 'Default Pixel', false),
  bamboo('bamboo', 'Bamboo Frame', true),
  hiyasGold('hiyas_gold', 'Hiyas Gold', true),
  woodSign('wood_sign', 'Wood Sign', true);

  final String key;
  final String label;
  final bool isPremium;

  const VlogFrameStyle(this.key, this.label, this.isPremium);

  static VlogFrameStyle fromKey(String? raw) {
    return VlogFrameStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => VlogFrameStyle.defaultFrame,
    );
  }
}

/// Audio mixing modes for preview and hardware MP4 export.
enum VlogAudioMode {
  bgmMix('bgm_mix', 'BGM Mix'),
  original('original', 'Original'),
  bgmOnly('bgm_only', 'BGM Only');

  final String key;
  final String label;

  const VlogAudioMode(this.key, this.label);

  static VlogAudioMode fromKey(String? raw) {
    return VlogAudioMode.values.firstWhere(
      (m) => m.key == raw,
      orElse: () => VlogAudioMode.bgmMix,
    );
  }
}

/// Metadata for a single 3-second clip saved in a trail's local vlog folder.
class VlogClipEntry {
  final String id;
  final VlogClipKind kind;
  final int stopPosition;
  final String? spotId;
  final String spotName;
  final String municipality;
  final String capturedAtIso;
  final String filePath;
  final int durationMs;
  final String cameraFacing;

  const VlogClipEntry({
    required this.id,
    required this.kind,
    required this.stopPosition,
    this.spotId,
    required this.spotName,
    required this.municipality,
    required this.capturedAtIso,
    required this.filePath,
    this.durationMs = 3000,
    this.cameraFacing = 'back',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.key,
        'stop_position': stopPosition,
        if (spotId != null) 'spot_id': spotId,
        'spot_name': spotName,
        'municipality': municipality,
        'captured_at_iso': capturedAtIso,
        'file_path': filePath,
        'duration_ms': durationMs,
        'camera_facing': cameraFacing,
      };

  factory VlogClipEntry.fromJson(Map<String, dynamic> json) {
    return VlogClipEntry(
      id: json['id']?.toString() ?? '',
      kind: VlogClipKind.fromKey(json['kind']?.toString()),
      stopPosition: (json['stop_position'] as num?)?.toInt() ?? 1,
      spotId: json['spot_id']?.toString(),
      spotName: json['spot_name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      capturedAtIso: json['captured_at_iso']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 3000,
      cameraFacing: json['camera_facing']?.toString() ?? 'back',
    );
  }
}

/// Crash-safe manifest persisted per trail under `trail_vlogs/<trail_id>/`.
class TrailVlogManifest {
  static const defaultBgmTrackKey = 'assets/audio/music/jdq_bgm.mp3';

  final String trailId;
  final String trailTitle;
  final int totalStops;
  final double totalKm;
  final int rewardPoints;
  final VlogFrameStyle frameStyle;
  final VlogAudioMode audioMode;
  final String bgmTrackKey;
  final List<VlogClipEntry> clips;
  final String? compiledPath;
  final String? compiledAtIso;
  final int? compiledSizeBytes;
  final String updatedAtIso;

  const TrailVlogManifest({
    required this.trailId,
    required this.trailTitle,
    required this.totalStops,
    required this.totalKm,
    this.rewardPoints = 0,
    this.frameStyle = VlogFrameStyle.defaultFrame,
    this.audioMode = VlogAudioMode.bgmMix,
    this.bgmTrackKey = defaultBgmTrackKey,
    this.clips = const [],
    this.compiledPath,
    this.compiledAtIso,
    this.compiledSizeBytes,
    this.updatedAtIso = '',
  });

  int get totalClips => clips.length;

  bool hasStopClip(int position) => clips
      .any((c) => c.kind == VlogClipKind.stop && c.stopPosition == position);

  VlogClipEntry? stopClipFor(int position) {
    for (final c in clips) {
      if (c.kind == VlogClipKind.stop && c.stopPosition == position) return c;
    }
    return null;
  }

  VlogClipEntry? roadClipForLeg(int position) {
    for (final c in clips) {
      if (c.kind == VlogClipKind.road && c.stopPosition == position) return c;
    }
    return null;
  }

  TrailVlogManifest copyWith({
    String? trailTitle,
    int? totalStops,
    double? totalKm,
    int? rewardPoints,
    VlogFrameStyle? frameStyle,
    VlogAudioMode? audioMode,
    String? bgmTrackKey,
    List<VlogClipEntry>? clips,
    String? Function()? compiledPath,
    String? Function()? compiledAtIso,
    int? Function()? compiledSizeBytes,
    String? updatedAtIso,
  }) {
    return TrailVlogManifest(
      trailId: trailId,
      trailTitle: trailTitle ?? this.trailTitle,
      totalStops: totalStops ?? this.totalStops,
      totalKm: totalKm ?? this.totalKm,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      frameStyle: frameStyle ?? this.frameStyle,
      audioMode: audioMode ?? this.audioMode,
      bgmTrackKey: bgmTrackKey ?? this.bgmTrackKey,
      clips: clips ?? this.clips,
      compiledPath: compiledPath != null ? compiledPath() : this.compiledPath,
      compiledAtIso:
          compiledAtIso != null ? compiledAtIso() : this.compiledAtIso,
      compiledSizeBytes: compiledSizeBytes != null
          ? compiledSizeBytes()
          : this.compiledSizeBytes,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'trail_id': trailId,
        'trail_title': trailTitle,
        'total_stops': totalStops,
        'total_km': totalKm,
        'reward_points': rewardPoints,
        'frame_style': frameStyle.key,
        'audio_mode': audioMode.key,
        'bgm_track_key': bgmTrackKey,
        'clips': [for (final c in clips) c.toJson()],
        if (compiledPath != null) 'compiled_path': compiledPath,
        if (compiledAtIso != null) 'compiled_at_iso': compiledAtIso,
        if (compiledSizeBytes != null) 'compiled_size_bytes': compiledSizeBytes,
        'updated_at_iso': updatedAtIso,
      };

  String toEncodedJson() => jsonEncode(toJson());

  factory TrailVlogManifest.fromJson(Map<String, dynamic> json) {
    final rawClips = (json['clips'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => VlogClipEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return TrailVlogManifest(
      trailId: json['trail_id']?.toString() ?? '',
      trailTitle: json['trail_title']?.toString() ?? 'Trail Vlog',
      totalStops: (json['total_stops'] as num?)?.toInt() ?? 0,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0.0,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      frameStyle: VlogFrameStyle.fromKey(json['frame_style']?.toString()),
      audioMode: VlogAudioMode.fromKey(json['audio_mode']?.toString()),
      bgmTrackKey: json['bgm_track_key']?.toString() ?? defaultBgmTrackKey,
      clips: rawClips,
      compiledPath: json['compiled_path']?.toString(),
      compiledAtIso: json['compiled_at_iso']?.toString(),
      compiledSizeBytes: (json['compiled_size_bytes'] as num?)?.toInt(),
      updatedAtIso: json['updated_at_iso']?.toString() ?? '',
    );
  }
}

/// Segment passed to the storyboard previewer and native Media3 compiler.
class VlogCompileSegment {
  final String type; // 'video' | 'image_card'
  final String path;
  final String? overlayPngPath;
  final int durationMs;
  final int stopPosition;
  final VlogClipKind? clipKind;
  final String label;
  final String subLabel;
  final bool isOutro;

  const VlogCompileSegment({
    required this.type,
    required this.path,
    this.overlayPngPath,
    required this.durationMs,
    this.stopPosition = 0,
    this.clipKind,
    required this.label,
    required this.subLabel,
    this.isOutro = false,
  });

  VlogCompileSegment withAssets({
    String? path,
    String? overlayPngPath,
  }) {
    return VlogCompileSegment(
      type: type,
      path: path ?? this.path,
      overlayPngPath: overlayPngPath ?? this.overlayPngPath,
      durationMs: durationMs,
      stopPosition: stopPosition,
      clipKind: clipKind,
      label: label,
      subLabel: subLabel,
      isOutro: isOutro,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'path': path,
        if (overlayPngPath != null) 'overlayPngPath': overlayPngPath,
        'durationMs': durationMs,
      };
}

/// Output metadata returned by the hardware MP4 compiler bridge.
class VlogCompileResult {
  final String outputPath;
  final int sizeBytes;
  final int durationMs;

  const VlogCompileResult({
    required this.outputPath,
    required this.sizeBytes,
    required this.durationMs,
  });
}
