import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import '../studio/pixel/studio_icons.dart';

/// The photo behind the spot page. Plan 98: when the cover photo is missing
/// or fails, it tries the spot's other photos in order, and reports the one
/// it settled on (null when none load) through [onPhotoChanged].
class SpotStillPhoto extends StatefulWidget {
  const SpotStillPhoto({super.key, required this.spot, this.onPhotoChanged});

  final SpotModel spot;
  final ValueChanged<String?>? onPhotoChanged;

  static const alignment = Alignment(0, -0.16);

  /// The cover photo, then every other non-video photo, without repeats.
  static List<String> candidateUrlsFor(SpotModel spot) {
    final urls = <String>[];
    void add(String? url) {
      if (url != null && url.trim().isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    add(spot.leadStillPhoto?.url ?? (spot.isVideo ? null : spot.imageUrl));
    for (final photo in spot.media) {
      if (!photo.isVideo) add(photo.url);
    }
    return urls;
  }

  /// The first photo to try, or null when the place has none.
  static String? urlFor(SpotModel spot) {
    final urls = candidateUrlsFor(spot);
    return urls.isEmpty ? null : urls.first;
  }

  @override
  State<SpotStillPhoto> createState() => _SpotStillPhotoState();
}

class _SpotStillPhotoState extends State<SpotStillPhoto> {
  late List<String> _urls = SpotStillPhoto.candidateUrlsFor(widget.spot);
  int _index = 0;

  String? get _url => _index < _urls.length ? _urls[_index] : null;

  @override
  void didUpdateWidget(SpotStillPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urls = SpotStillPhoto.candidateUrlsFor(widget.spot);
    if (urls.join('\n') != _urls.join('\n')) {
      _urls = urls;
      _index = 0;
      // didUpdateWidget runs during the parent's build; report after it.
      final url = _url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _url == url) widget.onPhotoChanged?.call(url);
      });
    }
  }

  void _failed(String url) {
    // errorBuilder runs during build; move on after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _url != url) return;
      setState(() => _index++);
      widget.onPhotoChanged?.call(_url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return const _DitherFallback();

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
        alignment: SpotStillPhoto.alignment,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) {
          _failed(url);
          return const _DitherFallback();
        },
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

/// Plan 98: the one "no photo" badge, shown when none of a spot's photos load.
class SpotNoPhotoPlaceholder extends StatelessWidget {
  const SpotNoPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const Key('theater_no_photo_placeholder'),
      style: PixelBoxStyle.inkDialogue,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PixelSprite(StudioIcons.camera, scale: 3),
          SizedBox(width: grid.px(2)),
          Flexible(
            child: Text(
              'NO PHOTO AVAILABLE',
              style: PixelType.small(context, color: PixelPalette.paper),
            ),
          ),
        ],
      ),
    );
  }
}
