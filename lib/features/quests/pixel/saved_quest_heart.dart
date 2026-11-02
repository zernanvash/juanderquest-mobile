import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_controls.dart';

class SavedQuestHeart extends StatefulWidget {
  const SavedQuestHeart({
    super.key,
    required this.saved,
    required this.questTitle,
    required this.onToggle,
    this.scale = 2,
  });

  final bool saved;
  final String questTitle;
  final VoidCallback onToggle;
  final int scale;

  @override
  State<SavedQuestHeart> createState() => _SavedQuestHeartState();
}

class _SavedQuestHeartState extends State<SavedQuestHeart> {
  bool _playing = false;
  bool _target = false;

  void _toggle() {
    pixelTick(context);
    setState(() {
      _target = !widget.saved;
      _playing = true;
    });
    widget.onToggle();
  }

  void _done() {
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.saved,
      label: widget.saved
          ? 'Remove ${widget.questTitle} from saved'
          : 'Save ${widget.questTitle}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: _playing
                  ? PixelAnimation(
                      _target
                          ? DesignerArt.heartLikeAnim
                          : DesignerArt.heartUnlikeAnim,
                      scale: widget.scale,
                      loop: false,
                      onDone: _done,
                    )
                  : PixelSprite(
                      widget.saved
                          ? DesignerArt.heartLiked
                          : DesignerArt.heartUnliked,
                      scale: widget.scale,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
