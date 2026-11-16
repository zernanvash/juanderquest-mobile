import 'package:flutter/material.dart';

import '../../../../core/pixel/pixel_box.dart';

/// Plan 98: an Explore photo that takes no space when the spot has no photo or
/// its photo fails (e.g. taken down), so the card goes straight from the text
/// to the actions. [gapBelow] is part of the photo and disappears with it.
class CollapsibleSpotPhoto extends StatefulWidget {
  const CollapsibleSpotPhoto({
    super.key,
    required this.url,
    required this.aspectRatio,
    required this.gapBelow,
    this.cacheWidth,
  });

  final String? url;
  final double aspectRatio;
  final double gapBelow;
  final int? cacheWidth;

  /// URLs that already failed, so a card scrolled back into view does not
  /// show an empty frame again before collapsing.
  static final Set<String> _failedUrls = {};

  @visibleForTesting
  static void resetFailedUrls() => _failedUrls.clear();

  @override
  State<CollapsibleSpotPhoto> createState() => _CollapsibleSpotPhotoState();
}

class _CollapsibleSpotPhotoState extends State<CollapsibleSpotPhoto> {
  void _failed(String url) {
    CollapsibleSpotPhoto._failedUrls.add(url);
    // errorBuilder runs during build; collapse after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url?.trim();
    if (url == null ||
        url.isEmpty ||
        CollapsibleSpotPhoto._failedUrls.contains(url)) {
      return const SizedBox.shrink(key: Key('explore_photo_collapsed'));
    }
    return Padding(
      padding: EdgeInsets.only(bottom: widget.gapBelow),
      child: PixelPanel(
        style: PixelBoxStyle.slot.copyWith(corner: 0, shadowPx: 0),
        padding: 1,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            cacheWidth: widget.cacheWidth,
            errorBuilder: (_, __, ___) {
              _failed(url);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
