import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_text.dart';
import '../core/ar_calibration.dart';

/// Whether this device has seen Juan's AR tutorial.
class ArTutorialPrefs {
  static const key = 'ar_tutorial_seen_v1';
  static const _storage = FlutterSecureStorage();

  static Future<bool> seen() async {
    try {
      return await _storage.read(key: key) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await _storage.write(key: key, value: 'true');
    } catch (_) {}
  }

  /// Debug: show the tutorial again.
  static Future<void> reset() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// Juan's first-time AR tutorial: three short tips, then the set-up.
class ArTutorial extends StatefulWidget {
  const ArTutorial({super.key, required this.onDone});

  final VoidCallback onDone;

  static const tips = [
    "HI, I'M JUAN! LET'S FIND A HIDDEN GEM WITH YOUR CAMERA.",
    'FIRST, A QUICK SET-UP: POINT AT THE FLOOR, THEN LOOK AROUND SLOWLY. I WILL GUIDE YOU.',
    'THEN WALK TO THE GEM, KEEP IT IN THE FRAME AND TAP COLLECT. MOVE SLOWLY AND WATCH YOUR STEP!',
  ];

  @override
  State<ArTutorial> createState() => _ArTutorialState();
}

class _ArTutorialState extends State<ArTutorial> {
  int _tip = 0;

  @override
  Widget build(BuildContext context) {
    final last = _tip == ArTutorial.tips.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDone();
      },
      child: ColoredBox(
        color: PixelPalette.ink.withValues(alpha: 0.6),
        child: _BottomCard(
          footer: Row(
            children: [
              Expanded(
                child: PixelButton(
                  label: 'SKIP',
                  variant: PixelButtonVariant.secondary,
                  expand: true,
                  onPressed: widget.onDone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PixelButton(
                  label: last ? 'GOT IT' : 'NEXT',
                  expand: true,
                  onPressed:
                      last ? widget.onDone : () => setState(() => _tip++),
                ),
              ),
            ],
          ),
          child: _JuanSays(
            caption: 'TIP ${_tip + 1} OF ${ArTutorial.tips.length}',
            text: ArTutorial.tips[_tip],
          ),
        ),
      ),
    );
  }
}

/// The guided set-up, one easy step at a time. Rebuilt by the AR screen on
/// every camera frame, so it just reads [calibration].
class ArCalibrationPanel extends StatelessWidget {
  const ArCalibrationPanel({
    super.key,
    required this.calibration,
    this.trackingHint,
  });

  final ArCalibration calibration;

  /// ARCore's own advice while it is not tracking (e.g. "move more slowly").
  final String? trackingHint;

  @override
  Widget build(BuildContext context) {
    final step = calibration.step ?? CalibrationStep.floor;
    final (title, text) = switch (step) {
      CalibrationStep.compass => (
          'CALIBRATE THE COMPASS',
          'Wave your phone in a figure-8 a few times, away from metal.',
        ),
      CalibrationStep.floor => (
          'FIND THE FLOOR',
          'Point your camera at the floor a few steps ahead and sweep slowly left and right.',
        ),
      CalibrationStep.look => (
          'LOOK AROUND',
          'Now hold your phone up at eye level and turn slowly in a circle.',
        ),
      CalibrationStep.ready => ('ALL SET!', 'Get ready to find the gem.'),
    };
    final tip = calibration.floorTip
        ? 'Shiny or plain floor? Aim at a rug, a tile line or a doorway edge, and turn on more light.'
        : step == CalibrationStep.floor
            ? trackingHint
            : null;
    return Semantics(
      liveRegion: true,
      label: '$title. $text',
      child: _BottomCard(
        child: _JuanSays(
          caption:
              'SET-UP · STEP ${calibration.stepNumber} OF ${calibration.totalSteps}',
          title: title,
          text: text,
          tip: tip,
          progress: calibration.progress,
        ),
      ),
    );
  }
}

/// Card at the bottom of the camera view, above the safe area. The text
/// scrolls if it has to (big text, landscape); [footer] buttons always show.
class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: SingleChildScrollView(child: child)),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Juan's portrait beside a caption, optional title, text, tip and progress.
class _JuanSays extends StatelessWidget {
  const _JuanSays({
    required this.caption,
    required this.text,
    this.title,
    this.tip,
    this.progress,
  });

  final String caption;
  final String? title;
  final String text;
  final String? tip;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelPanel(
          style: PixelBoxStyle.slot,
          padding: 1,
          child: still
              ? PixelSprite(DesignerArt.juanIdle.frames.first, scale: 4)
              : const PixelAnimation(DesignerArt.juanIdle, scale: 4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption,
                  style: PixelType.small(context, color: PixelPalette.gold)),
              if (title != null) ...[
                const SizedBox(height: 4),
                Text(title!,
                    style: PixelType.body(context)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 4),
              Text(text, style: PixelType.body(context)),
              if (tip != null) ...[
                const SizedBox(height: 6),
                Text(tip!,
                    style:
                        PixelType.body(context, color: PixelPalette.redDeep)),
              ],
              if (progress != null) ...[
                const SizedBox(height: 8),
                PixelProgressBar(value: progress!, color: PixelPalette.sun),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
