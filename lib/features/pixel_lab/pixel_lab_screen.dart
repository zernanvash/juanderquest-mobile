import 'package:flutter/material.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';

/// Developer preview of the designer's art converted to the brand pixel
/// palette (Plan 75 groundwork, branch design/pixel-ui). Not linked for travelers.
class PixelLabScreen extends StatefulWidget {
  const PixelLabScreen({super.key});

  @override
  State<PixelLabScreen> createState() => _PixelLabScreenState();
}

class _PixelLabScreenState extends State<PixelLabScreen> {
  int _scale = 3;
  bool _dark = false;
  bool _liked = false;
  bool _playLike = false;

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? PixelPalette.ink : PixelPalette.paper;
    final fg = _dark ? PixelPalette.paper : PixelPalette.ink;
    final label = TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600);
    Widget cell(String name, Widget child) => Padding(
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            child,
            const SizedBox(height: 4),
            Text(name, style: label.copyWith(fontSize: 10, fontWeight: FontWeight.w400)),
          ]),
        );
    final stills = DesignerArt.all.entries.where((e) => e.value is PixelArt);
    final anims = DesignerArt.all.entries.where((e) => e.value is PixelFrames);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Pixel lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Designer art in the JuanderQuest pixel palette. '
              'Scale = screen pixels per art pixel (whole numbers only).', style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final s in const [1, 2, 3, 4])
              ChoiceChip(label: Text('${s}x'), selected: _scale == s, onSelected: (_) => setState(() => _scale = s)),
            FilterChip(label: const Text('Dark'), selected: _dark, onSelected: (v) => setState(() => _dark = v)),
          ]),
          const SizedBox(height: 16),
          Text('Try it: like button', style: label),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              key: const ValueKey('pixel_lab_like'),
              onTap: () => setState(() {
                _liked = !_liked;
                _playLike = true;
              }),
              child: _playLike
                  ? PixelAnimation(
                      _liked ? DesignerArt.heartLikeAnim : DesignerArt.heartUnlikeAnim,
                      scale: _scale + 1,
                      loop: false,
                      onDone: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _playLike = false);
                      }),
                    )
                  : PixelSprite(_liked ? DesignerArt.heartLiked : DesignerArt.heartUnliked, scale: _scale + 1),
            ),
            const SizedBox(width: 16),
            PixelAnimation(DesignerArt.juanIdle, scale: _scale + 1),
          ]),
          const SizedBox(height: 16),
          Text('Animations (looping)', style: label),
          Wrap(children: [
            for (final e in anims) cell(e.key, PixelAnimation(e.value as PixelFrames, scale: _scale)),
          ]),
          const SizedBox(height: 16),
          Text('Icons', style: label),
          Wrap(children: [
            for (final e in stills) cell(e.key, PixelSprite(e.value as PixelArt, scale: _scale)),
          ]),
          const SizedBox(height: 16),
          Text('Palette (${PixelPalette.names.length} colours)', style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in PixelPalette.names.entries)
              Tooltip(
                message: e.key,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: e.value, border: Border.all(color: fg, width: 1)),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}
