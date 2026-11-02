import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../models/spot_model.dart';

class SpotStillPhoto extends StatelessWidget {
  const SpotStillPhoto({
    super.key,
    required this.spot,
  });

  final SpotModel spot;

  @override
  Widget build(BuildContext context) {
    final still = spot.leadStillPhoto;
    final url = still?.url ?? (spot.isVideo ? null : spot.imageUrl);

    if (url == null || url.trim().isEmpty) {
      return const _DitherFallback();
    }

    final mediaQuery = MediaQuery.of(context);
    final cacheWidth = (mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .round()
        .clamp(320, 2160);

    return ColoredBox(
      color: PixelPalette.ink,
      child: Image.network(
        url,
        key: const Key('theater_still_photo_image'),
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.16),
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => const _DitherFallback(),
      ),
    );
  }
}

class _DitherFallback extends StatelessWidget {
  const _DitherFallback();

  @override
  Widget build(BuildContext context) {
    return const DitherBackground(
      key: Key('theater_still_photo_dither'),
      top: PixelPalette.greenDeep,
      bottom: PixelPalette.ink,
    );
  }
}
