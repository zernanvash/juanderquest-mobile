import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../trail/models/trail_models.dart';

/// Row of small squares showing trail stop progress:
/// - gold filled = checked in
/// - gold outline = next unchecked stop
/// - parchment = later stop
class TrailTrackerBar extends StatelessWidget {
  final List<TrailStop> stops;
  final int? nextStopPosition;

  const TrailTrackerBar({
    super.key,
    required this.stops,
    this.nextStopPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();

    final resolvedNext = nextStopPosition ??
        stops.where((s) => !s.checkedIn).firstOrNull?.position;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stop in stops)
          _TrackerSquare(
            status: stop.checkedIn
                ? _StopSquareStatus.checkedIn
                : (stop.position == resolvedNext
                    ? _StopSquareStatus.next
                    : _StopSquareStatus.later),
          ),
      ],
    );
  }
}

enum _StopSquareStatus { checkedIn, next, later }

class _TrackerSquare extends StatelessWidget {
  final _StopSquareStatus status;

  const _TrackerSquare({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final double width;
    switch (status) {
      case _StopSquareStatus.checkedIn:
        bg = PixelPalette.sun;
        border = PixelPalette.ink;
        width = 2;
        break;
      case _StopSquareStatus.next:
        bg = PixelPalette.paper;
        border = PixelPalette.sun;
        width = 2;
        break;
      case _StopSquareStatus.later:
        bg = PixelPalette.parchment;
        border = PixelPalette.stone;
        width = 1.5;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: width),
      ),
    );
  }
}
