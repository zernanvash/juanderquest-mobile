import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_rpg.dart';
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
  pixel('Pixelated', 'Photo turns into big pixels, dimmed.');

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
                child: TheaterBackdropTreatment(spot: spot, mode: mode),
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

/// The treated photo (full screen). Also used by the Pixel lab preview.
class TheaterBackdropTreatment extends StatelessWidget {
  const TheaterBackdropTreatment({
    super.key,
    required this.spot,
    required this.mode,
  });

  final SpotModel spot;
  final TheaterBackdrop mode;

  @override
  Widget build(BuildContext context) {
    final url = SpotStillPhoto.urlFor(spot);
    final dim = ColoredBox(
      color: PixelPalette.ink.withValues(
        alpha: mode == TheaterBackdrop.dark ? 0.82 : 0.5,
      ),
    );
    if (url == null || mode == TheaterBackdrop.dark) return dim;

    final Widget photo;
    if (mode == TheaterBackdrop.pixel) {
      // ~36 art pixels across, scaled up with no smoothing.
      photo = Image.network(
        url,
        fit: BoxFit.cover,
        alignment: SpotStillPhoto.alignment,
        cacheWidth: 36,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      photo = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 16,
          sigmaY: 16,
          tileMode: TileMode.clamp,
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: SpotStillPhoto.alignment,
          cacheWidth: 240,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
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
