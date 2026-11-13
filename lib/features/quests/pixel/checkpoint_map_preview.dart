import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../models/quest_model.dart';

class CheckpointMapPreview extends ConsumerStatefulWidget {
  const CheckpointMapPreview({
    super.key,
    required this.quest,
    required this.onTap,
  });

  final QuestModel quest;
  final VoidCallback onTap;

  @override
  ConsumerState<CheckpointMapPreview> createState() =>
      _CheckpointMapPreviewState();
}

class _CheckpointMapPreviewState extends ConsumerState<CheckpointMapPreview> {
  late final JdqMap _map;
  late final Future<String> _style;

  @override
  void initState() {
    super.initState();
    _map = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    _syncCameraAndPin();
  }

  @override
  void didUpdateWidget(covariant CheckpointMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quest.id != widget.quest.id ||
        oldWidget.quest.gpsLat != widget.quest.gpsLat ||
        oldWidget.quest.gpsLng != widget.quest.gpsLng) {
      _syncCameraAndPin();
    }
  }

  void _syncCameraAndPin() {
    final point = LatLng(widget.quest.gpsLat, widget.quest.gpsLng);
    unawaited(_map.easeTo(point, 16, reducedMotion: true));
    unawaited(_map.setPins([
      JdqPin(
        'quest:${widget.quest.id}',
        point,
        widget.quest.title,
        quest: true,
      ),
    ]));
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: PixelPanel(
        style: PixelBoxStyle.slot,
        sunken: true,
        padding: 1,
        child: ClipRect(
          child: SizedBox(
            height: 160,
            child: IgnorePointer(
              child: JdqMapCanvas(
                map: _map,
                style: _style,
                fallback: const ColoredBox(
                  color: PixelPalette.paperDim,
                  child: Center(
                    child: PixelSprite(
                      DesignerArt.questMarker,
                      scale: 2,
                    ),
                  ),
                ),
                onFallback: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
