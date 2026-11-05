import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_painting.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';
import 'theater_still_photo.dart';

/// How the stationary spot photo is treated once the details scroll over it
/// (owner 2026-11-05: a busy photo behind the panels is an eyesore). Picked
/// in the Pixel lab.
enum TheaterBackdrop {
  off('Off', 'Photo stays as it is.'),
  dark('Dark', 'Photo dims behind the details.'),
  blur('Blur', 'Photo goes soft and dim.'),
  pixel('Pixelated', 'Photo becomes a pixel painting, lightly dimmed.');

  const TheaterBackdrop(this.label, this.hint);
  final String label;
  final String hint;
}

final theaterBackdropProvider =
    StateProvider<TheaterBackdrop>((ref) => TheaterBackdrop.pixel);

/// The stationary layers above the photo. They never scroll, so pulling the
/// page past its top shows no scrim edge. [reveal] runs 0 → 1 as the details
/// come up: the bottom scrim fades out while the chosen treatment fades in.
class TheaterBackdropLayers extends ConsumerWidget {
  const TheaterBackdropLayers({
    super.key,
    required this.spot,
    required this.reveal,
  });

  final SpotModel spot;
  final ValueListenable<double> reveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(theaterBackdropProvider);
    final height = MediaQuery.sizeOf(context).height;
    final scrim = Align(
      alignment: Alignment.bottomCenter,
      child: TheaterBottomScrim(height: height * 0.65),
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mode == TheaterBackdrop.off)
            scrim
          else ...[
            _Fade(reveal: reveal, invert: true, child: scrim),
            _Fade(
              reveal: reveal,
              child: RepaintBoundary(
                child: TheaterBackdropTreatment(
                  image: TheaterBackdropTreatment.imageFor(spot),
                  mode: mode,
                ),
              ),
            ),
          ],
          const Align(
            alignment: Alignment.topCenter,
            child: TheaterTopScrim(height: 140),
          ),
        ],
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.reveal, required this.child, this.invert = false});

  final ValueListenable<double> reveal;
  final Widget child;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: reveal,
      child: child,
      builder: (context, t, child) {
        final o = invert ? 1 - t : t;
        return Opacity(opacity: o.clamp(0.0, 1.0), child: child);
      },
    );
  }
}

/// The treated photo. Full screen on the spot page; small tiles in the
/// Pixel lab preview.
class TheaterBackdropTreatment extends StatelessWidget {
  const TheaterBackdropTreatment({
    super.key,
    required this.image,
    required this.mode,
    this.blurSigma = 16,
  });

  /// The photo, or null when the place has none (then it is only dimmed).
  final ImageProvider? image;
  final TheaterBackdrop mode;
  final double blurSigma;

  /// The spot page's photo as an image provider.
  static ImageProvider? imageFor(SpotModel spot) {
    final url = SpotStillPhoto.urlFor(spot);
    return url == null ? null : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final source = image;
    Widget plain(ImageProvider img) => Image(
          image: img,
          fit: BoxFit.cover,
          alignment: SpotStillPhoto.alignment,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
    final dim = ColoredBox(
      color: PixelPalette.ink.withValues(
        alpha: switch (mode) {
          TheaterBackdrop.dark => 0.82,
          TheaterBackdrop.pixel => 0.4,
          _ => 0.5,
        },
      ),
    );
    if (mode == TheaterBackdrop.off) {
      return source == null ? const SizedBox.shrink() : plain(source);
    }
    if (source == null || mode == TheaterBackdrop.dark) {
      return Stack(
        fit: StackFit.expand,
        children: [if (source != null) plain(source), dim],
      );
    }

    final Widget photo;
    if (mode == TheaterBackdrop.pixel) {
      // A block-game painting: ~40 px across, the photo's own 12 colours,
      // dithered brush texture (see paintPixels).
      photo = PixelPainting(
        image: source,
        alignment: SpotStillPhoto.alignment,
      );
    } else {
      photo = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: plain(ResizeImage(source, width: 240)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: PixelPalette.ink),
        photo,
        dim,
      ],
    );
  }
}

/// Pixel lab: the four choices as tappable previews over a real place photo,
/// each with a pretend details panel on top.
class TheaterBackdropPicker extends ConsumerWidget {
  const TheaterBackdropPicker({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(theaterBackdropProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final mode in TheaterBackdrop.values)
              GestureDetector(
                key: ValueKey('lab_backdrop_${mode.name}'),
                onTap: () =>
                    ref.read(theaterBackdropProvider.notifier).state = mode,
                child: _PreviewTile(
                  width: w,
                  image: image,
                  mode: mode,
                  selected: mode == current,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.width,
    required this.image,
    required this.mode,
    required this.selected,
  });

  final double width;
  final ImageProvider image;
  final TheaterBackdrop mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.35;
    Widget line([double factor = 1]) => FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            height: 5,
            margin: const EdgeInsets.only(top: 5),
            color: PixelPalette.mist,
          ),
        );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PixelPalette.ink,
        border: Border.all(
          color: selected ? PixelPalette.sun : PixelPalette.ink,
          width: selected ? 4 : 2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TheaterBackdropTreatment(
            image: image,
            mode: mode,
            // The full-screen blur, scaled down to the tile.
            blurSigma: 16 * width / MediaQuery.sizeOf(context).width,
          ),
          // A pretend details panel, like the spot page's.
          Positioned(
            left: 10,
            right: 10,
            top: height * 0.22,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PixelPalette.ink,
                border: Border.all(color: PixelPalette.slate, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 7, width: 50, color: PixelPalette.paper),
                  line(),
                  line(),
                  line(0.6),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: selected ? PixelPalette.sun : PixelPalette.ink,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  selected ? '${mode.label} ✓' : mode.label,
                  style: PixelType.small(
                    context,
                    color: selected ? PixelPalette.ink : PixelPalette.paper,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Double-tap hearts: a pixel heart pops where the traveler double-tapped,
/// rises and is gone (timer-stepped, like the rest of the pixel motion).
/// It listens to raw pointers, so buttons underneath keep their normal tap.
class TheaterDoubleTapHearts extends StatefulWidget {
  const TheaterDoubleTapHearts({super.key, required this.child});

  final Widget child;

  @override
  State<TheaterDoubleTapHearts> createState() => _TheaterDoubleTapHeartsState();
}

class _TheaterDoubleTapHeartsState extends State<TheaterDoubleTapHearts> {
  final List<_Heart> _hearts = [];
  int _nextId = 0;
  Offset? _downAt;
  DateTime _downTime = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _lastTapAt;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _onDown(PointerDownEvent e) {
    _downAt = e.localPosition;
    _downTime = DateTime.now();
  }

  void _onUp(PointerUpEvent e) {
    final down = _downAt;
    _downAt = null;
    if (down == null) return;
    final now = DateTime.now();
    // A tap, not a drag or a long press.
    if ((e.localPosition - down).distance > 18 ||
        now.difference(_downTime).inMilliseconds > 250) {
      _lastTapAt = null;
      return;
    }
    final last = _lastTapAt;
    if (last != null &&
        now.difference(_lastTapTime).inMilliseconds <= 320 &&
        (e.localPosition - last).distance <= 48) {
      _lastTapAt = null;
      setState(() => _hearts.add(_Heart(_nextId++, e.localPosition)));
    } else {
      _lastTapAt = e.localPosition;
      _lastTapTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _downAt = null,
      child: Stack(
        children: [
          widget.child,
          for (final h in _hearts)
            _PoppingHeart(
              key: ValueKey(h.id),
              at: h.at,
              onDone: () => setState(() => _hearts.remove(h)),
            ),
        ],
      ),
    );
  }
}

class _Heart {
  _Heart(this.id, this.at);
  final int id;
  final Offset at;
}

class _PoppingHeart extends StatefulWidget {
  const _PoppingHeart({super.key, required this.at, required this.onDone});

  final Offset at;
  final VoidCallback onDone;

  @override
  State<_PoppingHeart> createState() => _PoppingHeartState();
}

class _PoppingHeartState extends State<_PoppingHeart> {
  // Stepped frames: pop in, settle, rise and fade.
  // Logical pixels per art pixel (the heart art is 36 wide).
  static const _scales = [
    1.0,
    2.2,
    3.0,
    2.6,
    2.6,
    2.6,
    2.6,
    2.6,
    2.6,
    2.6,
    2.6
  ];
  static const _rise = [0, 0, 0, 0, 2, 5, 9, 14, 20, 27, 35];
  static const _alpha = <double>[1, 1, 1, 1, 1, 1, .9, .75, .55, .35, .15];
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) return;
      if (_frame >= _scales.length - 1) {
        t.cancel();
        widget.onDone();
        return;
      }
      setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = pixelMotion(context);
    final f = motion ? _frame : 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scale = (_scales[f] * dpr).round();
    const art = DesignerArt.heartLiked;
    final w = art.width * scale / dpr;
    final h = art.height * scale / dpr;
    return Positioned(
      left: widget.at.dx - w / 2,
      top: widget.at.dy - h / 2 - (motion ? _rise[f] * 2.0 : 0),
      child: IgnorePointer(
        child: Opacity(
          opacity: motion ? _alpha[f] : 1,
          child: PixelSprite(art, scale: scale),
        ),
      ),
    );
  }
}
