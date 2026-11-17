import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_rpg.dart';

/// Animated pixel heart that plays [DesignerArt.heartLikeAnim] or
/// [DesignerArt.heartUnlikeAnim] whenever [liked] transitions.
class SpotLikeHeartIcon extends StatefulWidget {
  const SpotLikeHeartIcon({
    super.key,
    required this.liked,
    this.box = 24,
  });

  final bool liked;
  final double box;

  @override
  State<SpotLikeHeartIcon> createState() => _SpotLikeHeartIconState();
}

class _SpotLikeHeartIconState extends State<SpotLikeHeartIcon> {
  bool _playing = false;
  bool _target = false;

  @override
  void didUpdateWidget(SpotLikeHeartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liked != widget.liked) {
      if (pixelMotion(context)) {
        setState(() {
          _target = widget.liked;
          _playing = true;
        });
      } else {
        setState(() => _playing = false);
      }
    }
  }

  void _done() {
    if (mounted) {
      setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _playing
        ? PixelAnimation(
            key: ValueKey('spot_heart_anim_$_target'),
            _target ? DesignerArt.heartLikeAnim : DesignerArt.heartUnlikeAnim,
            scale: 2,
            loop: false,
            onDone: _done,
          )
        : PixelSprite(
            widget.liked ? DesignerArt.heartLiked : DesignerArt.heartUnliked,
            scale: 2,
          );

    return SizedBox(
      width: widget.box,
      height: widget.box,
      child: FittedBox(
        fit: BoxFit.contain,
        child: child,
      ),
    );
  }
}

/// Boxed 48px-target top-bar like button that animates with [SpotLikeHeartIcon].
class SpotLikeBarButton extends StatefulWidget {
  const SpotLikeBarButton({
    super.key,
    required this.liked,
    required this.semanticLabel,
    required this.onPressed,
    this.iconHeight = 20,
  });

  final bool liked;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double iconHeight;

  @override
  State<SpotLikeBarButton> createState() => _SpotLikeBarButtonState();
}

class _SpotLikeBarButtonState extends State<SpotLikeBarButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            pixelTick(context);
            widget.onPressed();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: PixelPanel(
              style: widget.liked ? PixelBoxStyle.red : PixelBoxStyle.parchment,
              padding: 2,
              pressed: _down,
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: SpotLikeHeartIcon(
                  liked: widget.liked,
                  box: widget.iconHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
