import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../spots/theater/theater_panel.dart';
import '../providers/suki_provider.dart';

/// Shops this close to a destination count as "here".
const sukiSpotRadiusM = 300;

/// Plan 107: "Suki cards here" on a destination page. Shows nothing unless an
/// active Suki shop is within [sukiSpotRadiusM] (or Suki is switched off).
class SpotSukiRow extends ConsumerWidget {
  const SpotSukiRow({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs =
        ref.watch(nearbySukiProgramsProvider((lat: lat, lng: lng))).valueOrNull;
    final here = [
      for (final p in programs ?? const [])
        if (p.distanceM != null && p.distanceM! <= sukiSpotRadiusM) p
    ];
    if (here.isEmpty) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: TheaterPanel(
        key: const ValueKey('spot_suki_row'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'SUKI CARDS HERE', tl: 'SUKI CARDS DITO'),
              colors: PixelText3DColors.cream,
            ),
            for (final (i, p) in here.indexed) ...[
              if (i > 0)
                Container(
                  height: grid.unit,
                  color: PixelPalette.paper.withValues(alpha: 0.18),
                ),
              GestureDetector(
                key: ValueKey('spot_suki_${p.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/suki/${Uri.encodeComponent(p.id)}'),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.merchant.name,
                              style: PixelType.body(context,
                                  color: PixelPalette.paper),
                            ),
                            SizedBox(height: grid.px(0.5)),
                            Text(
                              tr(context,
                                  en: '${p.visitsRequired} visits: ${p.rewardText}',
                                  tl: '${p.visitsRequired} bisita: ${p.rewardText}'),
                              style: PixelType.small(context,
                                  color: PixelPalette.mist),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: grid.px(2)),
                      PixelChip(
                        p.rewardTag,
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
