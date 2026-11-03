import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';

class TheaterGalleryDialog extends StatefulWidget {
  const TheaterGalleryDialog({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  final List<SpotPhoto> media;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required List<SpotPhoto> media,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => TheaterGalleryDialog(
          media: media,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<TheaterGalleryDialog> createState() => _TheaterGalleryDialogState();
}

class _TheaterGalleryDialogState extends State<TheaterGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.media.isEmpty ? 0 : widget.media.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.media.length) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final count = widget.media.length;
    final current = count > 0 ? widget.media[_currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Close button, page counter, credit chip
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: grid.px(2),
                vertical: grid.px(2),
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Close gallery',
                    child: InkWell(
                      key: const Key('gallery_close_btn'),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        alignment: Alignment.center,
                        child: PixelPanel(
                          style: PixelBoxStyle.inkDialogue.copyWith(
                            fill: PixelPalette.ink,
                            outline: PixelPalette.paper,
                            corner: 0,
                            shadowPx: 0,
                          ),
                          padding: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: grid.px(2),
                              vertical: grid.px(1),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '✕ CLOSE',
                                style: PixelType.small(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Text(
                      '${_currentIndex + 1} / $count',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.paper,
                      ),
                    ),
                  if (current?.sourceName != null &&
                      current!.sourceName!.trim().isNotEmpty) ...[
                    SizedBox(width: grid.px(2)),
                    Flexible(
                      child: GestureDetector(
                        onTap: current.sourceUrl != null &&
                                current.sourceUrl!.trim().isNotEmpty
                            ? () => launchUrlString(current.sourceUrl!)
                            : null,
                        child: PixelPanel(
                          style: PixelBoxStyle.inkDialogue.copyWith(
                            fill: PixelPalette.slate,
                            outline: PixelPalette.mist,
                            corner: 0,
                            shadowPx: 0,
                          ),
                          padding: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: grid.px(2),
                              vertical: grid.px(1),
                            ),
                            child: Text(
                              current.sourceName!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.paper,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Middle: Photo PageView
            Expanded(
              child: count == 0
                  ? const Center(
                      child: DitherBackground(
                        top: PixelPalette.greenDeep,
                        bottom: PixelPalette.ink,
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (idx) => setState(() => _currentIndex = idx),
                      itemCount: count,
                      itemBuilder: (context, index) {
                        final item = widget.media[index];
                        return _GallerySlide(photo: item);
                      },
                    ),
            ),

            // Bottom bar: PREV and NEXT 48px buttons
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: grid.px(4),
                vertical: grid.px(2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Previous photo',
                    child: InkWell(
                      key: const Key('gallery_prev_btn'),
                      onTap: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        alignment: Alignment.center,
                        child: PixelPanel(
                          style: _currentIndex > 0
                              ? PixelBoxStyle.parchment.copyWith(corner: 1, shadowPx: 0)
                              : PixelBoxStyle.stone.copyWith(
                                  fill: PixelPalette.slate,
                                  outline: PixelPalette.stone,
                                  corner: 1,
                                  shadowPx: 0,
                                ),
                          padding: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: grid.px(3),
                              vertical: grid.px(2),
                            ),
                            child: Text(
                              '◀ PREV',
                              style: PixelType.small(
                                context,
                                color: _currentIndex > 0
                                    ? PixelPalette.ink
                                    : PixelPalette.stone,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Next photo',
                    child: InkWell(
                      key: const Key('gallery_next_btn'),
                      onTap: _currentIndex < count - 1
                          ? () => _goTo(_currentIndex + 1)
                          : null,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        alignment: Alignment.center,
                        child: PixelPanel(
                          style: _currentIndex < count - 1
                              ? PixelBoxStyle.parchment.copyWith(corner: 1, shadowPx: 0)
                              : PixelBoxStyle.stone.copyWith(
                                  fill: PixelPalette.slate,
                                  outline: PixelPalette.stone,
                                  corner: 1,
                                  shadowPx: 0,
                                ),
                          padding: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: grid.px(3),
                              vertical: grid.px(2),
                            ),
                            child: Text(
                              'NEXT ▶',
                              style: PixelType.small(
                                context,
                                color: _currentIndex < count - 1
                                    ? PixelPalette.ink
                                    : PixelPalette.stone,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GallerySlide extends StatelessWidget {
  const _GallerySlide({required this.photo});

  final SpotPhoto photo;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const DitherBackground(
              top: PixelPalette.greenDeep,
              bottom: PixelPalette.ink,
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: PixelPalette.sun),
              );
            },
          ),
        ),
        if (photo.isVideo)
          Positioned(
            child: Semantics(
              button: true,
              label: 'Play video externally',
              child: PixelButton(
                label: '▶ PLAY VIDEO',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
                onPressed: () => launchUrlString(
                  photo.url,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        if (photo.isVideo)
          Positioned(
            top: grid.px(2),
            right: grid.px(2),
            child: const PixelChip(
              'VIDEO',
              style: PixelBoxStyle.red,
              textColor: PixelPalette.white,
            ),
          ),
      ],
    );
  }
}
