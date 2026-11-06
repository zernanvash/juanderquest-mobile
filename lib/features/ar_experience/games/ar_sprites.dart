import 'dart:convert';

import 'package:flutter/services.dart';

/// One sprite strip from `assets/ar_sprites/manifest.json` (Plan 77).
///
/// The art is pixel art at 320 px per metre; [pivotX]/[pivotY] are the pixel
/// in a frame that sits on the sprite's position (the ground point for things
/// that stand, the centre for things that fly).
class ArSpriteSheet {
  const ArSpriteSheet({
    required this.name,
    required this.file,
    required this.frames,
    required this.frameW,
    required this.frameH,
    required this.pivotX,
    required this.pivotY,
    this.fps = 12,
  });

  static const pxPerMetre = 320.0;
  static const _dir = 'assets/ar_sprites';

  final String name;
  final String file;
  final int frames;
  final int frameW;
  final int frameH;
  final double pivotX;
  final double pivotY;
  final double fps;

  factory ArSpriteSheet.fromJson(String name, Map<String, dynamic> m) {
    final pivot = (m['pivot'] as List).cast<num>();
    return ArSpriteSheet(
      name: name,
      file: m['file'] as String,
      frames: (m['frames'] as num).toInt(),
      frameW: (m['frameW'] as num).toInt(),
      frameH: (m['frameH'] as num).toInt(),
      pivotX: pivot[0].toDouble(),
      pivotY: pivot[1].toDouble(),
      fps: (m['fps'] as num?)?.toDouble() ?? 12,
    );
  }

  static Future<Map<String, ArSpriteSheet>> loadManifest(AssetBundle bundle) async {
    final json = jsonDecode(await bundle.loadString('$_dir/manifest.json')) as Map<String, dynamic>;
    return {
      for (final e in json.entries) e.key: ArSpriteSheet.fromJson(e.key, e.value as Map<String, dynamic>),
    };
  }

  Future<Uint8List> loadPng(AssetBundle bundle) async =>
      (await bundle.load('$_dir/$file')).buffer.asUint8List();
}

/// One sprite in a native scene. Positions are metres relative to the anchor
/// (world axes, y up from the anchor's floor point). Motion and animation are
/// timed natively from when the scene arrives: position(t) = start + v·t − ½·g·t²
/// (y only), shown from [delay] for [life] seconds (0 = forever).
class ArSprite {
  const ArSprite(
    this.sheet, {
    required this.x,
    required this.y,
    required this.z,
    this.vx = 0,
    this.vy = 0,
    this.vz = 0,
    this.gravity = 0,
    this.scale = 1,
    this.frame = 0,
    this.fps = 0,
    this.loop = false,
    this.delay = 0,
    this.life = 0,
    this.floor = false,
  });

  final String sheet;
  final double x, y, z, vx, vy, vz, gravity, scale, fps, delay, life;
  final int frame;
  final bool loop;

  /// Lies flat on the floor (chalk circle, shadows) instead of standing up facing you.
  final bool floor;

  Map<String, Object> toMap() => {
        'sheet': sheet,
        'x': x,
        'y': y,
        'z': z,
        'vx': vx,
        'vy': vy,
        'vz': vz,
        'gravity': gravity,
        'scale': scale,
        'frame': frame,
        'fps': fps,
        'loop': loop,
        'delay': delay,
        'life': life,
        'floor': floor,
      };
}
