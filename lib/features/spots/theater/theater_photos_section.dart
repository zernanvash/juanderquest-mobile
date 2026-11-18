import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../models/spot_model.dart';
import 'theater_gallery_dialog.dart';
import 'theater_panel.dart';

/// Owner 2026-11-18: the destination's photos as a preview panel; tapping a
/// photo opens it full screen. This replaces the gallery button in the top
/// bar: the panel is where travelers go to see a destination's photos.
class TheaterPhotosSection extends StatelessWidget {
  const TheaterPhotosSection({
    super.key,
    required this.media,
    this.onAddPhoto,
  });

  final List<SpotPhoto> media;
  final VoidCallback? onAddPhoto;

  /// Thumbnails shown before the last one turns into "+N".
  static const previewCount = 6;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final shown = media.take(previewCount).toList();
    final extra = media.length - shown.length;
    return TheaterPanel(
      key: const ValueKey('spot_photos_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            media.isEmpty ? 'PHOTOS' : 'PHOTOS (${media.length})',
            colors: PixelText3DColors.cream,
          ),
          SizedBox(height: grid.px(2)),
          if (media.isEmpty) ...[
            Text(
              'No photos yet. Visited? Share one for the community.',
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            if (onAddPhoto != null) ...[
              SizedBox(height: grid.px(2)),
              Align(
                alignment: Alignment.centerLeft,
                child: PixelButton(
                  key: const ValueKey('spot_photos_add'),
                  label: 'Add photo',
                  variant: PixelButtonVariant.secondary,
                  onPressed: onAddPhoto,
                ),
              ),
            ],
          ] else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: grid.px(1),
              crossAxisSpacing: grid.px(1),
              children: [
                for (final (i, photo) in shown.indexed)
                  _tile(
                    context,
                    i,
                    photo,
                    more: i == shown.length - 1 && extra > 0 ? extra : 0,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int index, SpotPhoto photo,
      {required int more}) {
    return Semantics(
      button: true,
      label: more > 0
          ? 'Open photos, $more more'
          : 'Open photo ${index + 1} of ${media.length}',
      child: GestureDetector(
        key: ValueKey('spot_photo_tile_$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          pixelTick(context);
          TheaterGalleryDialog.show(context, media: media, initialIndex: index);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: PixelPalette.woodDeep,
                child: photo.isVideo
                    ? const Icon(Icons.play_arrow, color: PixelPalette.paper)
                    : Image.network(
                        photo.url,
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: PixelPalette.mist,
                        ),
                      ),
              ),
              if (more > 0)
                ColoredBox(
                  color: PixelPalette.woodNight.withValues(alpha: 0.7),
                  child: Center(
                    child: Text(
                      '+$more',
                      style:
                          PixelType.title(context, color: PixelPalette.cream),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
